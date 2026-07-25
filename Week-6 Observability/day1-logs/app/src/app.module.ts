/**
 * Module wiring. The only observability-relevant line here is `configure()`,
 * which attaches the request logger to every route with `forRoutes('*')`.
 */
import { MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { PrismaService } from './prisma.service';
import { ShopService } from './shop.service';
import { ShopController } from './shop.controller';
import { RequestLoggerMiddleware } from './request-logger.middleware';

@Module({
  controllers: [ShopController],
  providers: [PrismaService, ShopService],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RequestLoggerMiddleware).forRoutes('{*path}');
  }
}
