process.env.REVENUECAT_WEBHOOK_SECRET = 'test-secret';

import request from 'supertest';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';
import { TIER_LIMITS } from '../src/config/limits';
import { signAccessToken } from '../src/utils/jwt';

const app = createApp();
const hook = (body: unknown) =>
  request(app).post('/api/v1/webhooks/revenuecat').set({ Authorization: 'Bearer test-secret' }).send(body);

async function makeUser() {
  const u = await User.create({
    email: `${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName: 'u',
    emailVerified: true,
  });
  return String(u._id);
}

describe('US8 — Premium subscription lifecycle', () => {
  it('activates Premium then reverts on expiry, preserving data', async () => {
    const userId = await makeUser();

    // INITIAL_PURCHASE → premium + larger Basic cap
    await hook({
      event: {
        type: 'INITIAL_PURCHASE',
        id: 'evt-1',
        app_user_id: userId,
        product_id: 'premium_monthly',
        entitlement_ids: ['premium'],
        expiration_at_ms: Date.now() + 30 * 86_400_000,
      },
    });
    let user = await User.findById(userId);
    expect(user!.tier).toBe('premium');
    expect(user!.credits.basic.cap).toBe(TIER_LIMITS.premium.basicCreditCap);

    // Duplicate delivery is idempotent (same event id)
    await hook({
      event: { type: 'INITIAL_PURCHASE', id: 'evt-1', app_user_id: userId, product_id: 'premium_monthly' },
    });
    user = await User.findById(userId);
    expect(user!.tier).toBe('premium');

    // EXPIRATION → back to free, data preserved
    await hook({ event: { type: 'EXPIRATION', id: 'evt-2', app_user_id: userId } });
    user = await User.findById(userId);
    expect(user!.tier).toBe('free');
    expect(user!.credits.basic.cap).toBe(TIER_LIMITS.free.basicCreditCap);
    expect(user!.email).toBeTruthy(); // account preserved
  });

  it('exposes subscription status via the API', async () => {
    const userId = await makeUser();
    const token = signAccessToken({ sub: userId, role: 'user' });
    const res = await request(app)
      .get('/api/v1/subscription')
      .set({ Authorization: `Bearer ${token}` });
    expect(res.status).toBe(200);
    expect(res.body.tier).toBe('free');
    expect(res.body.premiumBenefits.basicCreditCap).toBe(TIER_LIMITS.premium.basicCreditCap);
  });
});
