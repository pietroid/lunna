import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import type { NextFunction, Request, Response } from 'express';
import { AppModule } from './app.module';
import { LoggingInterceptor } from './common/logging.interceptor';
import { initializeFirebaseAdmin } from './firebase/firebase-admin';

async function bootstrap() {
  // Firebase Admin uses Application Default Credentials (service account
  // identity), not .env secrets. Initialize it before creating the NestJS
  // app so that any provider that calls `getFirestore()`/`getAuth()` at
  // class instantiation time finds the default app already initialized.
  initializeFirebaseAdmin();

  const app = await NestFactory.create(AppModule);
  const logger = new Logger('Bootstrap');

  app.enableCors({
    // Reflects the request's Origin header back to the browser. This is
    // required when `credentials: true` is set because `Access-Control-Allow-Origin`
    // cannot be `*` while credentials are enabled.
    origin: true,
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'Accept'],
    exposedHeaders: ['Authorization'],
    maxAge: 86400,
    preflightContinue: false,
    optionsSuccessStatus: 204,
  });

  // Log every incoming request so we can tell whether CORS preflights and
  // API calls are actually reaching the NestJS process. This runs before
  // guards/interceptors, so it will record OPTIONS requests as well.
  app.use((req: Request, _res: Response, next: NextFunction) => {
    logger.log(
      `REQUEST ${req.method} ${req.url} - Origin: ${req.headers.origin ?? 'none'} - Content-Length: ${req.headers['content-length'] ?? 'none'}`,
    );
    next();
  });

  // Logs response status, timing, user id and errors for every handled request.
  app.useGlobalInterceptors(new LoggingInterceptor());

  await app.listen(process.env.PORT ?? 3000);
  logger.log(`Server listening on port ${process.env.PORT ?? 3000}`);
}
void bootstrap();
