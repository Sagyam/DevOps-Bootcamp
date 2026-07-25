/**
 * ---------------------------------------------------------------------------
 * shop.service.ts  --  the business logic, and every log line that matters.
 * ---------------------------------------------------------------------------
 *
 * Read this file asking one question at each log call: "at 2am, would I be
 * glad this line existed?" That is the only real rule for what to log.
 *
 * Notice the pattern `log().warn({ fields }, 'message')`:
 *   - the message is a short, CONSTANT string
 *   - everything variable goes in the fields object
 *
 * Constant messages are what let you write `{msg="order rejected"}` and get
 * every occurrence. If you interpolate ("order 42 rejected") every line is
 * unique and you are back to substring search.
 */

import {
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { CreateOrderDto } from './dto';
import { log, rootLogger } from './logger';
import { ordersTotal, revenueNprTotal, teaStock } from './metrics';

/** The one tea we keep deliberately scarce, so that 409s actually happen. */
const SCARCE_TEA = 'Ilam Gold (limited)';

/**
 * Probability that the fake payment gateway "times out". This exists so the
 * error logs on your dashboard are not always zero. Set PAYMENT_FAILURE_RATE=0
 * in docker-compose.yml to turn it off, or 0.5 to make the dashboard scream.
 */
const FAILURE_RATE = Number(process.env.PAYMENT_FAILURE_RATE ?? 0.04);

@Injectable()
export class ShopService implements OnModuleInit {
  constructor(private readonly prisma: PrismaService) {}

  onModuleInit() {
    // The load generator will drain the shelves within a couple of minutes.
    // Restocking on a timer keeps the demo alive indefinitely, and gives us a
    // recurring background info log that is NOT tied to any request -- useful
    // for showing that requestId is absent on those lines.
    setInterval(() => this.restock(), 60_000).unref();
  }

  async listTeas() {
    log().debug('fetching tea list');
    const teas = await this.prisma.tea.findMany({ orderBy: { id: 'asc' } });

    // NEW ON DAY 2. A gauge is a snapshot, so somebody has to set it. We do it
    // here because listing teas is the most frequent operation in the system,
    // which means the gauge stays roughly fresh for free.
    //
    // Be honest about what that means: if stock hits zero and recovers between
    // two Prometheus scrapes, this gauge never shows it. That is a property of
    // gauges, not a bug. If you needed to catch the dip you would count the
    // event with a counter as well.
    for (const tea of teas) {
      teaStock.set({ tea: tea.name }, tea.stock);
    }

    log().info({ count: teas.length }, 'tea list served');
    return teas;
  }

  async getTea(id: number) {
    const tea = await this.prisma.tea.findUnique({ where: { id } });

    if (!tea) {
      // WARN, not ERROR. Nothing is broken -- a client asked for something
      // that does not exist. If you log this at error you will train yourself
      // to ignore errors, which is the most expensive habit in operations.
      log().warn({ teaId: id }, 'tea not found');
      // outcome labels are a fixed set of four strings -- safe.
      ordersTotal.inc({ outcome: 'unknown_tea', tea: 'none' });
      throw new NotFoundException(`No tea with id ${id}`);
    }

    log().debug({ teaId: id, name: tea.name }, 'tea found');
    return tea;
  }

  async placeOrder(dto: CreateOrderDto) {
    log().debug({ teaId: dto.teaId, quantity: dto.quantity }, 'order requested');

    const tea = await this.getTea(dto.teaId);

    if (tea.stock < dto.quantity) {
      log().warn(
        { teaId: tea.id, name: tea.name, requested: dto.quantity, available: tea.stock },
        'order rejected: insufficient stock',
      );
      ordersTotal.inc({ outcome: 'rejected_stock', tea: tea.name });
      throw new ConflictException(`Only ${tea.stock} cups of ${tea.name} left`);
    }

    if (Math.random() < FAILURE_RATE) {
      // ERROR. We failed the customer. Note that we log the *cause* as a
      // field, not buried in the sentence -- so a dashboard can group by it.
      log().error(
        { teaId: tea.id, gateway: 'khalti-sandbox', reason: 'upstream_timeout' },
        'payment failed',
      );
      ordersTotal.inc({ outcome: 'payment_failed', tea: tea.name });
      throw new ServiceUnavailableException('Payment gateway timed out, please retry');
    }

    // Two writes that must both happen or neither: decrement stock, create the
    // order. Prisma runs them in one database transaction.
    const order = await this.prisma.$transaction(async (tx) => {
      await tx.tea.update({
        where: { id: tea.id },
        data: { stock: { decrement: dto.quantity } },
      });
      return tx.order.create({
        data: {
          teaId: tea.id,
          quantity: dto.quantity,
          totalNpr: tea.priceNpr * dto.quantity,
        },
      });
    });

    // NEW ON DAY 2. The same event, recorded twice on purpose:
    //   - the log line below keeps every detail of THIS order
    //   - these two counters keep the shape of ALL orders, forever, for free
    // You will use the counters on a dashboard and the log line when someone
    // asks about order 4127 specifically.
    ordersTotal.inc({ outcome: 'placed', tea: tea.name });
    revenueNprTotal.inc(order.totalNpr);
    teaStock.set({ tea: tea.name }, tea.stock - dto.quantity);

    log().info(
      {
        orderId: order.id,
        teaId: tea.id,
        name: tea.name,
        quantity: dto.quantity,
        totalNpr: order.totalNpr,
        stockLeft: tea.stock - dto.quantity,
      },
      'order placed',
    );

    return order;
  }

  async recentOrders(limit = 20) {
    const orders = await this.prisma.order.findMany({
      take: limit,
      orderBy: { id: 'desc' },
      include: { tea: { select: { name: true } } },
    });
    log().debug({ count: orders.length }, 'recent orders served');
    return orders;
  }

  /** Background job. Runs on a timer, so there is no requestId on these lines. */
  private async restock() {
    try {
      const bulk = await this.prisma.tea.updateMany({
        where: { name: { not: SCARCE_TEA } },
        data: { stock: 200 },
      });
      await this.prisma.tea.updateMany({
        where: { name: SCARCE_TEA },
        data: { stock: 3 },
      });
      // rootLogger explicitly: this is not part of any request, and pretending
      // otherwise would be a lie in the data.
      rootLogger.info({ teasRestocked: bulk.count + 1 }, 'shelves restocked');
    } catch (err: any) {
      rootLogger.error({ err: err.message }, 'restock failed');
    }
  }
}
