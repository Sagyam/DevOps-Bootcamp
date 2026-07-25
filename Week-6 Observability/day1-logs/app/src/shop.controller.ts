/**
 * HTTP surface. Thin on purpose: parse, delegate, return. All the logging
 * that matters lives in shop.service.ts (business events) and
 * request-logger.middleware.ts (one line per request).
 *
 * The @Api* decorators are what build the Swagger page at /docs. Swagger is
 * not observability, but it is the difference between students being able to
 * poke at the system and students copying curl commands from a README.
 */
import { Body, Controller, Get, Param, ParseIntPipe, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ShopService } from './shop.service';
import { CreateOrderDto } from './dto';

@ApiTags('chiya')
@Controller()
export class ShopController {
  constructor(private readonly shop: ShopService) {}

  @Get('healthz')
  @ApiOperation({ summary: 'Liveness probe. Deliberately does not touch the database.' })
  health() {
    return { status: 'ok', instance: process.env.HOSTNAME };
  }

  @Get('teas')
  @ApiOperation({ summary: 'List every tea on the menu' })
  listTeas() {
    return this.shop.listTeas();
  }

  @Get('teas/:id')
  @ApiOperation({ summary: 'Fetch one tea' })
  @ApiResponse({ status: 404, description: 'No tea with that id (produces a warn log)' })
  // ParseIntPipe turns "abc" into a 400 before our code runs. Free input
  // validation, and one less way to get a 500.
  getTea(@Param('id', ParseIntPipe) id: number) {
    return this.shop.getTea(id);
  }

  @Post('orders')
  @ApiOperation({ summary: 'Place an order' })
  @ApiResponse({ status: 409, description: 'Not enough stock (produces a warn log)' })
  @ApiResponse({ status: 503, description: 'Payment gateway failure (produces an error log)' })
  placeOrder(@Body() dto: CreateOrderDto) {
    return this.shop.placeOrder(dto);
  }

  @Get('orders')
  @ApiOperation({ summary: 'Most recent orders' })
  recentOrders(@Query('limit', new ParseIntPipe({ optional: true })) limit?: number) {
    return this.shop.recentOrders(limit ?? 20);
  }
}
