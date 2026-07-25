/**
 * Process entrypoint: build the Nest app, mount Swagger, listen.
 */
import 'reflect-metadata';
import { ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { PinoNestLogger, rootLogger } from './logger';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    // Hand Nest our pino adapter so framework log lines are JSON too.
    logger: new PinoNestLogger(),
  });

  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,   // "2" -> 2
      whitelist: true,   // silently drop fields we did not declare
    }),
  );

  const doc = SwaggerModule.createDocument(
    app,
    new DocumentBuilder()
      .setTitle('Chiya Shop API')
      .setDescription('The service we spend three days observing.')
      .setVersion('1.0')
      .build(),
  );
  SwaggerModule.setup('docs', app, doc);

  // 0.0.0.0, not localhost. Inside a container, binding to localhost means
  // nothing outside the container can reach you -- a classic first-day bug.
  await app.listen(3000, '0.0.0.0');
  rootLogger.info({ port: 3000, docs: '/docs' }, 'chiya-api listening');
}

bootstrap();
