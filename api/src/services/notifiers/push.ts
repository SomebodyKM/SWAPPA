import { env } from '../../config/env';
import { logger } from '../../utils/logger';

export interface PushMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

let initialized = false;
let messaging: import('firebase-admin').messaging.Messaging | null = null;

async function ensureInit(): Promise<boolean> {
  if (initialized) return messaging !== null;
  initialized = true;
  if (!env.FCM_PROJECT_ID || !env.FCM_CLIENT_EMAIL || !env.FCM_PRIVATE_KEY) {
    logger.debug('[push] FCM not configured — push disabled (dev)');
    return false;
  }
  try {
    const admin = await import('firebase-admin');
    if (admin.apps.length === 0) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId: env.FCM_PROJECT_ID,
          clientEmail: env.FCM_CLIENT_EMAIL,
          // Support escaped newlines from env files.
          privateKey: env.FCM_PRIVATE_KEY.replace(/\\n/g, '\n'),
        }),
      });
    }
    messaging = admin.messaging();
    return true;
  } catch (err) {
    logger.error('[push] FCM init failed', (err as Error).message);
    return false;
  }
}

export const pushService = {
  /** Send a push to a user's device tokens. No-op (logged) when FCM is unconfigured. */
  async send(tokens: string[], msg: PushMessage): Promise<void> {
    if (tokens.length === 0) return;
    const ready = await ensureInit();
    if (!ready || !messaging) {
      logger.debug(`[push] would send "${msg.title}" to ${tokens.length} device(s)`);
      return;
    }
    try {
      await messaging.sendEachForMulticast({
        tokens,
        notification: { title: msg.title, body: msg.body },
        data: msg.data ?? {},
      });
    } catch (err) {
      logger.error('[push] send failed', (err as Error).message);
    }
  },
};
