import request from 'supertest';
import bcrypt from 'bcrypt';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';

const app = createApp();

// zxcvbn flags dictionary-ish passwords like "supersecret1" as weak —
// this one is random enough to pass assertStrongPassword.
const STRONG_PW = 'Zqf7!kRvw2m$Xt';

describe('Auth + health (US1 foundation)', () => {
  it('reports health', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('registers an unverified account (no tokens until verified)', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      email: 'alice@example.com',
      password: STRONG_PW,
      displayName: 'Alice',
    });
    expect(res.status).toBe(201);
    expect(res.body.verificationRequired).toBe(true);
    expect(res.body.accessToken).toBeUndefined();
  });

  it('blocks login until the email is verified', async () => {
    await request(app).post('/api/v1/auth/register').send({
      email: 'bob@example.com',
      password: STRONG_PW,
      displayName: 'Bob',
    });
    const res = await request(app).post('/api/v1/auth/login').send({
      emailOrPhone: 'bob@example.com',
      password: STRONG_PW,
    });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('EMAIL_NOT_VERIFIED');
  });

  it('allows re-registering an email that never got verified', async () => {
    const payload = { email: 'carol@example.com', password: STRONG_PW, displayName: 'Carol' };
    const first = await request(app).post('/api/v1/auth/register').send(payload);
    expect(first.status).toBe(201);
    const firstId = first.body.userId;

    // Never verified — this is the "doesn't count as account created" case,
    // so the same email should be free to register again, not 409.
    const second = await request(app).post('/api/v1/auth/register').send(payload);
    expect(second.status).toBe(201);
    expect(second.body.userId).not.toBe(firstId);

    // The stale first attempt's User doc is actually gone, not just shadowed.
    const stale = await User.findById(firstId);
    expect(stale).toBeNull();
  });

  it('rejects duplicate registration once the email is actually verified', async () => {
    await User.create({
      email: 'dana@example.com',
      passwordHash: await bcrypt.hash(STRONG_PW, 10),
      displayName: 'Dana',
      emailVerified: true,
    });
    const res = await request(app).post('/api/v1/auth/register').send({
      email: 'dana@example.com',
      password: STRONG_PW,
      displayName: 'Dana',
    });
    expect(res.status).toBe(409);
  });
});
