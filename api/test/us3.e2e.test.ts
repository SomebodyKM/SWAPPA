import request from 'supertest';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';
import { Skill } from '../src/models/skill.model';
import { signAccessToken } from '../src/utils/jwt';

const app = createApp();

async function makeUser(email: string) {
  const u = await User.create({
    email,
    passwordHash: 'x',
    displayName: email.split('@')[0],
    emailVerified: true,
  });
  const token = signAccessToken({ sub: String(u._id), role: 'user' });
  return { id: String(u._id), token };
}

async function makeSkill(name: string) {
  const s = await Skill.create({ name, nameNormalized: name.toLowerCase(), category: 'Music' });
  return String(s._id);
}

const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

describe('US3 — messaging, swaps, scheduling', () => {
  it('runs the full swap → accept → schedule → message loop', async () => {
    const alice = await makeUser('alice3@example.com');
    const bob = await makeUser('bob3@example.com');
    const guitar = await makeSkill('Guitar');
    const spanish = await makeSkill('Spanish');

    // Alice requests a swap with Bob
    const created = await request(app)
      .post('/api/v1/swaps')
      .set(auth(alice.token))
      .send({ partnerId: bob.id, offeredSkillId: guitar, requestedSkillId: spanish });
    expect(created.status).toBe(201);
    expect(created.body.status).toBe('requested');
    const swapId = created.body._id;

    // Bob accepts
    const accepted = await request(app).post(`/api/v1/swaps/${swapId}/accept`).set(auth(bob.token));
    expect(accepted.status).toBe(200);
    expect(accepted.body.status).toBe('active');

    // Alice proposes a remote session (Alice teaches guitar)
    const proposed = await request(app)
      .post(`/api/v1/swaps/${swapId}/sessions`)
      .set(auth(alice.token))
      .send({
        teacherId: alice.id,
        learnerId: bob.id,
        scheduledAt: new Date(Date.now() + 86_400_000).toISOString(),
        format: 'remote',
      });
    expect(proposed.status).toBe(201);
    const sessionId = proposed.body._id;

    // Bob accepts the session
    const sResp = await request(app)
      .post(`/api/v1/sessions/${sessionId}/respond`)
      .set(auth(bob.token))
      .send({ decision: 'accept' });
    expect(sResp.status).toBe(200);
    expect(sResp.body.status).toBe('accepted');

    // A conversation exists; Alice sends a text message
    const convs = await request(app).get('/api/v1/conversations').set(auth(alice.token));
    expect(convs.body.items.length).toBe(1);
    const convId = convs.body.items[0]._id;

    const msg = await request(app)
      .post(`/api/v1/conversations/${convId}/messages`)
      .set(auth(alice.token))
      .send({ type: 'text', body: 'Hey Bob!' });
    expect(msg.status).toBe(201);

    const history = await request(app)
      .get(`/api/v1/conversations/${convId}/messages`)
      .set(auth(bob.token));
    expect(history.body.items.length).toBe(1);
    expect(history.body.items[0].body).toBe('Hey Bob!');
  });

  it('blocks free-tier multimedia messages (Premium required)', async () => {
    const a = await makeUser('mm-a@example.com');
    const b = await makeUser('mm-b@example.com');
    const s1 = await makeSkill('Piano');
    const s2 = await makeSkill('French');
    const created = await request(app)
      .post('/api/v1/swaps')
      .set(auth(a.token))
      .send({ partnerId: b.id, offeredSkillId: s1, requestedSkillId: s2 });
    const convs = await request(app).get('/api/v1/conversations').set(auth(a.token));
    const convId = convs.body.items[0]._id;
    void created;

    const res = await request(app)
      .post(`/api/v1/conversations/${convId}/messages`)
      .set(auth(a.token))
      .send({ type: 'image', mediaUrl: 'https://example.com/x.png' });
    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('PREMIUM_REQUIRED');
  });

  it('enforces the free-tier active-swap limit (2)', async () => {
    const me = await makeUser('limit@example.com');
    const partners = await Promise.all([
      makeUser('p1@example.com'),
      makeUser('p2@example.com'),
      makeUser('p3@example.com'),
    ]);
    const off = await makeSkill('Drums');
    const want = await makeSkill('German');

    const results = [];
    for (const p of partners) {
      const r = await request(app)
        .post('/api/v1/swaps')
        .set(auth(me.token))
        .send({ partnerId: p.id, offeredSkillId: off, requestedSkillId: want });
      results.push(r.status);
    }
    expect(results[0]).toBe(201);
    expect(results[1]).toBe(201);
    expect(results[2]).toBe(403); // limit reached
  });
});
