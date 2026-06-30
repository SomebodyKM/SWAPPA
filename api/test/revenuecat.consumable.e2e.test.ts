process.env.REVENUECAT_WEBHOOK_SECRET = 'test-secret';

import request from 'supertest';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';
import { CreditTransaction } from '../src/models/creditTransaction.model';

const app = createApp();

async function makeUser() {
  const u = await User.create({
    email: `${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName: 'u',
    emailVerified: true,
  });
  return String(u._id);
}

function boostEvent(appUserId: string, transactionId: string) {
  return {
    event: {
      type: 'NON_RENEWING_PURCHASE',
      id: `evt-${transactionId}`,
      app_user_id: appUserId,
      product_id: 'boost_medium', // 60 credits
      transaction_id: transactionId,
    },
  };
}

describe('US7 — RevenueCat consumable webhook', () => {
  it('credits Boost exactly once (idempotent on transaction id)', async () => {
    const userId = await makeUser();

    const first = await request(app)
      .post('/api/v1/webhooks/revenuecat')
      .set({ Authorization: 'Bearer test-secret' })
      .send(boostEvent(userId, 'txn-1'));
    expect(first.status).toBe(200);

    // Duplicate delivery of the same transaction
    const dup = await request(app)
      .post('/api/v1/webhooks/revenuecat')
      .set({ Authorization: 'Bearer test-secret' })
      .send(boostEvent(userId, 'txn-1'));
    expect(dup.status).toBe(200);

    const user = await User.findById(userId);
    expect(user!.credits.boost.balance).toBe(60); // credited once, not twice

    const purchases = await CreditTransaction.countDocuments({ user: userId, type: 'purchase' });
    expect(purchases).toBe(1);
  });

  it('rejects an unauthenticated webhook', async () => {
    const userId = await makeUser();
    const res = await request(app)
      .post('/api/v1/webhooks/revenuecat')
      .set({ Authorization: 'Bearer wrong' })
      .send(boostEvent(userId, 'txn-2'));
    expect(res.status).toBe(401);
  });
});
