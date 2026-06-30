/**
 * Sync all Mongoose indexes (creates missing, drops extras) — run on deploy.
 *   ts-node src/scripts/ensureIndexes.ts
 */
import { connectDb, disconnectDb } from '../config/db';
import { logger } from '../utils/logger';

// Import every model so its schema/indexes are registered.
import '../models/user.model';
import '../models/verification.model';
import '../models/skill.model';
import '../models/skillTag.model';
import '../models/conversation.model';
import '../models/message.model';
import '../models/swap.model';
import '../models/session.model';
import '../models/review.model';
import '../models/creditTransaction.model';
import '../models/aiRequest.model';
import '../models/subscription.model';
import '../models/report.model';
import '../models/adminAuditLog.model';
import '../models/notification.model';

import mongoose from 'mongoose';

async function main() {
  await connectDb();
  const names = Object.keys(mongoose.models);
  for (const name of names) {
    await mongoose.models[name].syncIndexes();
    logger.info(`Synced indexes for ${name}`);
  }
  await disconnectDb();
  logger.info('All indexes synced');
}

main().catch((err) => {
  logger.error('ensureIndexes failed', err);
  process.exit(1);
});
