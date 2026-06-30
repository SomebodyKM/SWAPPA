import mongoose from 'mongoose';
import { env } from './env';
import { logger } from '../utils/logger';

export async function connectDb(uri: string = env.MONGO_URI): Promise<typeof mongoose> {
  mongoose.set('strictQuery', true);
  // Pin the database name so we never fall back to `test` when the URI omits a path.
  await mongoose.connect(uri, { dbName: env.MONGO_DB });
  logger.info(`MongoDB connected (db: ${env.MONGO_DB})`);
  return mongoose;
}

export async function disconnectDb(): Promise<void> {
  await mongoose.disconnect();
  logger.info('MongoDB disconnected');
}
