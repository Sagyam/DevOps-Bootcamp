/**
 * ---------------------------------------------------------------------------
 * prisma.service.ts  --  the database client, wired into our log pipeline.
 * ---------------------------------------------------------------------------
 *
 * PrismaClient can emit an event for every query it runs. We forward those
 * events into pino at *debug* level, which gives you a switch: run with
 * LOG_LEVEL=info and you see business events; run with LOG_LEVEL=debug and you
 * see every SQL statement, its parameters and its duration, tagged with the
 * requestId that caused it.
 *
 * That switch is the whole point. Leaving SQL logging on permanently in
 * production is how a 40 GB/day log bill happens. Leaving it *available* costs
 * nothing.
 */

import { Injectable, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { log, rootLogger } from './logger';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  constructor() {
    super({
      // emit: 'event' means "give them to me as callbacks" rather than
      // 'stdout', which would print in Prisma's own format and bypass pino.
      log: [
        { emit: 'event', level: 'query' },
        { emit: 'event', level: 'warn' },
        { emit: 'event', level: 'error' },
      ],
    });

    // `log()` (not rootLogger) so the SQL line inherits the requestId of
    // whatever request triggered it.
    (this as any).$on('query', (e: any) => {
      log().debug({ sql: e.query, params: e.params, durationMs: e.duration }, 'database query');
    });
    (this as any).$on('warn', (e: any) => log().warn({ target: e.target }, e.message));
    (this as any).$on('error', (e: any) => log().error({ target: e.target }, e.message));
  }

  async onModuleInit() {
    await this.$connect();
    rootLogger.info('connected to postgres');
  }

  async onModuleDestroy() {
    await this.$disconnect();
    rootLogger.info('disconnected from postgres');
  }
}
