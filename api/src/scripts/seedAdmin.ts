/**
 * Promote a user to admin (or create one). Usage:
 *   ts-node src/scripts/seedAdmin.ts <email>
 * The user must already exist (and ideally be verified). Run with the API env loaded.
 */
import { connectDb, disconnectDb } from '../config/db';
import { User } from '../models/user.model';
import { logger } from '../utils/logger';

async function main() {
  const email = process.argv[2];
  if (!email) {
    logger.error('Usage: ts-node src/scripts/seedAdmin.ts <email>');
    process.exit(1);
  }
  await connectDb();
  const user = await User.findOne({ email: email.toLowerCase() });
  if (!user) {
    logger.error(`No user found with email ${email}`);
    await disconnectDb();
    process.exit(1);
  }
  user.role = 'admin';
  await user.save();
  logger.info(`Promoted ${email} to admin`);
  await disconnectDb();
}

main().catch((err) => {
  logger.error('seedAdmin failed', err);
  process.exit(1);
});
