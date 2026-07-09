import express, { Application } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import routes from './routes';
import { apiLimiter } from './middleware/rateLimit.middleware';
import { notFound, errorHandler } from './middleware/error.middleware';
import { env } from './config/env';

/**
 * Builds the Express application: middleware → routes → error handling.
 * (Express 5 auto-forwards rejected promises from async handlers to errorHandler.)
 */
export function createApp(): Application {
  const app = express();

  // Render (and most PaaS hosts) sit behind a reverse proxy — without this,
  // express-rate-limit reads the proxy's IP instead of the real client's,
  // and `req.ip`/`req.secure` are wrong.
  app.set('trust proxy', 1);

  app.use(helmet());
  app.use(cors({ origin: env.CORS_ORIGIN }));
  app.use(express.json({ limit: '1mb' }));
  app.use(express.urlencoded({ extended: true }));

  app.use('/api/v1', apiLimiter, routes);

  // 404 + central error handler (must be last).
  app.use(notFound);
  app.use(errorHandler);

  return app;
}
