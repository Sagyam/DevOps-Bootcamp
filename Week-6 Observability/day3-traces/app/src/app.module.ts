/**
 * Module wiring.
 *
 * CHANGED SINCE DAY 1: MetricsController is registered, and MetricsMiddleware
 * runs alongside RequestLoggerMiddleware on every route. Order matters only in
 * that both must run before the handler; they are independent of each other.
 */
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { ShopService } from './shop.service';
import { ShopController } from './shop.controller';
import { MetricsController } from './metrics.controller';
import { RequestLoggerMiddleware } from './request-logger.middleware';
import { MetricsMiddleware } from './metrics.middleware';

@Module({
  controllers: [ShopController, MetricsController],
  providers: [PrismaService, ShopService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggerMiddleware, MetricsMiddleware).forRoutes('{*path}');
  }
}
