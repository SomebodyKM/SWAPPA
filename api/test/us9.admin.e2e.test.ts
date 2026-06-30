import request from 'supertest';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';
import { AdminAuditLog } from '../src/models/adminAuditLog.model';
import { signAccessToken } from '../src/utils/jwt';

const app = createApp();
const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

async function makeUser(role: 'user' | 'admin' = 'user') {
  const u = await User.create({
    email: `${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName: 'u',
    emailVerified: true,
    role,
  });
  return { id: String(u._id), token: signAccessToken({ sub: String(u._id), role }) };
}

describe('US9 — admin & moderation', () => {
  it('forbids non-admins from admin routes', async () => {
    const user = await makeUser('user');
    const res = await request(app).get('/api/v1/admin/users').set(auth(user.token));
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('ADMIN_ONLY');
  });

  it('lets an admin manage skills and ban/unban users, with audit logging', async () => {
    const admin = await makeUser('admin');
    const target = await makeUser('user');

    // Create a skill
    const skill = await request(app)
      .post('/api/v1/admin/skills')
      .set(auth(admin.token))
      .send({ name: 'Pottery', category: 'Crafts' });
    expect(skill.status).toBe(201);

    // Ban the target user
    const ban = await request(app)
      .post(`/api/v1/admin/users/${target.id}/ban`)
      .set(auth(admin.token))
      .send({ reason: 'spam' });
    expect(ban.status).toBe(200);

    // Banned user is blocked at the auth layer
    const blocked = await request(app).get('/api/v1/users/me').set(auth(target.token));
    expect(blocked.status).toBe(403);
    expect(blocked.body.error.code).toBe('ACCOUNT_INACTIVE');

    // Unban restores access
    await request(app).post(`/api/v1/admin/users/${target.id}/unban`).set(auth(admin.token));
    const restored = await request(app).get('/api/v1/users/me').set(auth(target.token));
    expect(restored.status).toBe(200);

    // Audit log recorded each privileged action
    const audits = await AdminAuditLog.countDocuments({ admin: admin.id });
    expect(audits).toBeGreaterThanOrEqual(3); // skill_create, user_ban, user_unban
  });

  it('moderates reports', async () => {
    const admin = await makeUser('admin');
    const reporter = await makeUser('user');
    const target = await makeUser('user');

    await request(app)
      .post('/api/v1/safety/reports')
      .set(auth(reporter.token))
      .send({ targetUserId: target.id, reason: 'inappropriate' });

    const open = await request(app).get('/api/v1/admin/reports?status=open').set(auth(admin.token));
    expect(open.body.items.length).toBe(1);
    const reportId = open.body.items[0]._id;

    const resolved = await request(app)
      .post(`/api/v1/admin/reports/${reportId}/resolve`)
      .set(auth(admin.token))
      .send({ note: 'warned' });
    expect(resolved.body.status).toBe('resolved');
  });
});
