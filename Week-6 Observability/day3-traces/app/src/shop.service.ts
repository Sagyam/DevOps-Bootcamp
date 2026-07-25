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
import { SpanStatusCode, trace } from '@opentelemetry/api';

/**
 * NEW ON DAY 3.
 *
 * A tracer is a factory for spans. The string is the "instrumentation scope" --
 * it shows up in Jaeger and tells you which library or module created a span.
 * Use your package name. One tracer per module is plenty.
 */
const tracer = trace.getTracer('chiya-shop');

/**
 * How much arithmetic the fake "blend score" does. This number is the knob
 * that makes the endpoint slow. It blocks the Node event loop, which is a
 * different and worse kind of slow than waiting on I/O -- see the comments in
 * pairings() below.
 */
const BLEND_ITERATIONS = Number(process.env.BLEND_ITERATIONS ?? 4_000_000);

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
  constructor(private readonly prisma: PrismaService) { }

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

  /**
   * -------------------------------------------------------------------------
   * GET /teas/:id/pairings  --  the deliberately slow endpoint.
   * -------------------------------------------------------------------------
   *
   * Day 2's dashboard will tell you this route has a bad p95. It will not tell
   * you which of the three things below is responsible. That is what the
   * manual spans in this method are for.
   *
   * Three problems, three different shapes in the flame graph:
   *
   *   1. an N+1 query loop  -> a picket fence of many short database spans
   *   2. a slow dependency  -> one long span that is WAITING (not our CPU)
   *   3. a CPU-bound loop   -> one long span that is BLOCKING the event loop
   *
   * Learning to tell those three shapes apart by eye is most of what reading
   * traces is. Open one in Jaeger before you read further.
   */
  async pairings(teaId: number) {
    // startActiveSpan does two things: it creates the span, and it makes it
    // the CURRENT span for everything inside the callback. That is what lets
    // the spans below nest under it automatically instead of being siblings.
    return tracer.startActiveSpan('shop.pairings', async (span) => {
      try {
        // Attributes are the "why" of a span. A span that only says it took
        // 900ms is half a clue. Add the inputs that explain the duration.
        span.setAttribute('chiya.tea_id', teaId);

        const tea = await this.getTea(teaId);
        span.setAttribute('chiya.tea_name', tea.name);

        // ------------------------------------------------------------------
        // PROBLEM 1: the N+1 query.
        //
        // One query to list the teas, then one more query PER TEA. Five teas
        // means six round trips. This is the single most common performance
        // bug in any application that uses an ORM, and it is invisible in
        // metrics: each query is fast, the endpoint is slow.
        //
        // In Jaeger this looks like a row of identical short bars. Once you
        // have seen that shape you will recognise it instantly, forever.
        // ------------------------------------------------------------------
        const popularity = await tracer.startActiveSpan(
          'shop.popularity_n_plus_1',
          async (inner) => {
            const allTeas = await this.prisma.tea.findMany();
            const rows: Array<{ tea: string; orders: number }> = [];

            for (const other of allTeas) {
              const orders = await this.prisma.order.count({ where: { teaId: other.id } });
              rows.push({ tea: other.name, orders });
            }

            inner.setAttribute('chiya.query_count', allTeas.length + 1);
            inner.end();
            return rows;
          },
        );

        // ------------------------------------------------------------------
        // PROBLEM 2: a slow dependency.
        //
        // Pretend we call a supplier's pricing API. We are WAITING on the
        // network -- the CPU is free and other requests are served normally
        // during this time.
        //
        // In the trace this is a long bar. In the Node.js metrics it is
        // invisible, because waiting costs nothing. Remember that contrast.
        // ------------------------------------------------------------------
        await tracer.startActiveSpan('supplier.price_lookup', async (inner) => {
          inner.setAttribute('peer.service', 'supplier-api');
          await new Promise((resolve) => setTimeout(resolve, 120));
          inner.end();
        });

        // ------------------------------------------------------------------
        // PROBLEM 3: CPU-bound work on the event loop.
        //
        // This is the dangerous one. Node runs your JavaScript on ONE thread.
        // While this loop runs, nothing else in this process moves -- not other
        // requests, not timers, not the health check.
        //
        // Go look at "Event loop lag (p99)" on the Day 2 dashboard while this
        // endpoint is being hit. Problem 2 does not move it. This does. That
        // difference is why "slow" is not one thing.
        // ------------------------------------------------------------------
        const blendScore = tracer.startActiveSpan('shop.blend_score', (inner) => {
          const startedAt = Date.now();
          let acc = 0;
          for (let i = 1; i < BLEND_ITERATIONS; i++) {
            acc += Math.sqrt(i) * Math.sin(i);
          }
          inner.setAttribute('chiya.iterations', BLEND_ITERATIONS);
          inner.setAttribute('chiya.event_loop_blocked_ms', Date.now() - startedAt);
          inner.end();
          return acc;
        });

        popularity.sort((a, b) => b.orders - a.orders);
        const result = {
          tea: tea.name,
          blendScore: Math.round(Math.abs(blendScore) % 100),
          pairsWellWith: popularity.slice(0, 3).map((p) => p.tea),
        };

        log().info({ teaId, pairings: result.pairsWellWith.length }, 'pairings computed');
        return result;
      } catch (err: any) {
        // A span that ends without this looks SUCCESSFUL in Jaeger, even
        // though the request failed. Forgetting these two lines is the most
        // common manual-instrumentation bug there is.
        span.recordException(err);
        span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
        throw err;
      } finally {
        // In a finally block, because a span that is never ended is never
        // exported. The trace just silently lacks it.
        span.end();
      }
    });
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
