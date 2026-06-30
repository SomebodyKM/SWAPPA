import request from 'supertest';
import { createApp } from '../src/app';

const app = createApp();

describe('Auth + health (US1 foundation)', () => {
  it('reports health', async () => {
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('registers an unverified account (no tokens until verified)', async () => {
    const res = await request(app).post('/api/v1/auth/register').send({
      email: 'alice@example.com',
      password: 'supersecret1',
      displayName: 'Alice',
    });
    expect(res.status).toBe(201);
    expect(res.body.verificationRequired).toBe(true);
    expect(res.body.accessToken).toBeUndefined();
  });

  it('blocks login until the email is verified', async () => {
    await request(app).post('/api/v1/auth/register').send({
      email: 'bob@example.com',
      password: 'supersecret1',
      displayName: 'Bob',
    });
    const res = await request(app).post('/api/v1/auth/login').send({
      emailOrPhone: 'bob@example.com',
      password: 'supersecret1',
    });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('EMAIL_NOT_VERIFIED');
  });

  it('rejects duplicate registration', async () => {
    const payload = { email: 'carol@example.com', password: 'supersecret1', displayName: 'Carol' };
    await request(app).post('/api/v1/auth/register').send(payload);
    const res = await request(app).post('/api/v1/auth/register').send(payload);
    expect(res.status).toBe(409);
  });
});
