/**
 * ---------------------------------------------------------------------------
 * logger.ts  --  everything about how this service writes logs.
 * ---------------------------------------------------------------------------
 *
 * Three ideas live in this file. Read them in order.
 *
 * 1. STRUCTURED LOGGING
 *    `console.log('order 42 placed for 3 cups')` is a sentence. A machine can
 *    only find it with a substring search. `{"msg":"order placed","orderId":42,
 *    "quantity":3}` is a record. A machine can filter, group and count it.
 *    We use pino, which writes one JSON object per line to stdout. Fast,
 *    boring, and exactly what a log aggregator wants.
 *
 * 2. LOG LEVELS
 *    A level is a promise you make to your future self at 2am:
 *      trace/debug -- "I only want this when I am actively debugging"
 *      info        -- "this is a normal thing that happened, worth recording"
 *      warn        -- "this is wrong but the system handled it"
 *      error       -- "this request failed and a human may need to know"
 *      fatal       -- "the process is going down"
 *    LOG_LEVEL sets the floor. Anything below it is never even serialised,
 *    which is why leaving debug logs in the code costs you almost nothing
 *    until you turn them on.
 *
 * 3. REQUEST CORRELATION
 *    One HTTP request produces many log lines from many functions. To read
 *    them as a story you need a shared id on every line. Passing a logger
 *    down through every function signature is miserable, so we use Node's
 *    AsyncLocalStorage: a per-request box that any code inside the request
 *    can reach without being handed it. Call `log()` and you get a logger
 *    that already knows the requestId.
 */

import { AsyncLocalStorage } from 'node:async_hooks';
import { LoggerService } from '@nestjs/common';
import pino from 'pino';

/**
 * The root logger. Everything else is a child of this.
 */
export const rootLogger = pino({
  // The floor. Set by LOG_LEVEL in docker-compose.yml -- try flipping it.
  level: process.env.LOG_LEVEL || 'info',

  // `base` fields are stamped onto every single line this process emits.
  // `service` is how we will filter in Loki. `instance` is the container
  // hostname, which matters because we run two copies of this API.
  base: {
    service: process.env.SERVICE_NAME || 'api',
    instance: process.env.HOSTNAME || 'unknown',
  },

  // By default pino writes levels as numbers (30, 40, 50) because it is
  // cheaper. We want readable strings, because we are going to turn this
  // field into a Loki label and "level=error" reads better than "level=50".
  formatters: {
    level: (label) => ({ level: label }),
  },

  // Default is epoch milliseconds. ISO strings cost a little more CPU and are
  // far easier to eyeball in a terminal.
  timestamp: pino.stdTimeFunctions.isoTime,

  // Never let a secret reach the log pipeline. Once it is in Loki it is in
  // backups, in screenshots, and in the browser history of everyone on call.
  redact: {
    paths: ['req.headers.authorization', 'req.headers.cookie', 'password', 'token'],
    censor: '[redacted]',
  },
});

/** What we carry alongside every request. */
export interface RequestContext {
  requestId: string;
  logger: pino.Logger;
}

/**
 * The per-request box. `requestContext.run(value, fn)` makes `value` visible
 * to everything `fn` calls, including code that runs later on a promise or an
 * event callback, without any of it taking the value as an argument.
 */
export const requestContext = new AsyncLocalStorage<RequestContext>();

/**
 * Use this instead of `rootLogger` everywhere inside request handling.
 *
 * Inside a request  -> a child logger that stamps requestId on every line.
 * Outside a request -> the plain root logger (startup, shutdown, timers).
 */
export function log(): pino.Logger {
  return requestContext.getStore()?.logger ?? rootLogger;
}

/**
 * NestJS has its own logger interface and uses it for framework messages
 * ("Nest application successfully started", route mapping, etc). Without this
 * adapter those lines come out as pretty-printed text while ours come out as
 * JSON, and half our log stream becomes unparseable. One format, one pipeline.
 */
export class PinoNestLogger implements LoggerService {
  private write(level: 'info' | 'error' | 'warn' | 'debug' | 'trace', message: any, params: any[]) {
    // Nest calls these as (message, stack?, context?), and `message` is
    // sometimes an Error object rather than a string. If you do not unpack it,
    // JSON.stringify(new Error('boom')) gives you "{}" and you lose the entire
    // failure. That is a real bug people ship. Handle both shapes.
    const err = message instanceof Error ? message : undefined;
    const text = err ? err.message : typeof message === 'string' ? message : JSON.stringify(message);
    const stack = err?.stack ?? params.find((p) => typeof p === 'string' && p.includes('\n'));
    const context = params.find((p) => typeof p === 'string' && !p.includes('\n'));

    rootLogger[level]({ nest: context, stack }, text);
  }
  log(message: any, ...params: any[]) { this.write('info', message, params); }
  error(message: any, ...params: any[]) { this.write('error', message, params); }
  warn(message: any, ...params: any[]) { this.write('warn', message, params); }
  debug(message: any, ...params: any[]) { this.write('debug', message, params); }
  verbose(message: any, ...params: any[]) { this.write('trace', message, params); }
}
