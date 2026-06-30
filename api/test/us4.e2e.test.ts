import request from 'supertest';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';
import { Skill } from '../src/models/skill.model';
import { Swap } from '../src/models/swap.model';
import { Session } from '../src/models/session.model';
import { signAccessToken } from '../src/utils/jwt';

const app = createApp();

async function makeUser(email: string) {
  const u = await User.create({
    email,
    passwordHash: 'x',
    displayName: email.split('@')[0],
    emailVerified: true,
  });
  return { id: String(u._id), token: signAccessToken({ sub: String(u._id), role: 'user' }) };
}
async function makeSkill(name: string) {
  const s = await Skill.create({ name, nameNormalized: name.toLowerCase(), category: 'Music' });
  return String(s._id);
}
const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

async function activeSwap(a: { id: string; token: string }, b: { id: string; token: string }) {
  const off = await makeSkill(`off-${Math.random()}`);
  const want = await makeSkill(`want-${Math.random()}`);
  const created = await request(app)
    .post('/api/v1/swaps')
    .set(auth(a.token))
    .send({ partnerId: b.id, offeredSkillId: off, requestedSkillId: want });
  await request(app).post(`/api/v1/swaps/${created.body._id}/accept`).set(auth(b.token));
  return created.body._id as string;
}

describe('US4 — complete swap, reviews, no-show/abandon', () => {
  it('completes a swap when both confirm and gates reviews until completion', async () => {
    const alice = await makeUser('a4@example.com');
    const bob = await makeUser('b4@example.com');
    const swapId = await activeSwap(alice, bob);

    // Review before completion is rejected
    const early = await request(app)
      .post(`/api/v1/swaps/${swapId}/review`)
      .set(auth(alice.token))
      .send({ rating: 5 });
    expect(early.status).toBe(409);

    // Propose + accept a session
    const proposed = await request(app)
      .post(`/api/v1/swaps/${swapId}/sessions`)
      .set(auth(alice.token))
      .send({
        teacherId: alice.id,
        learnerId: bob.id,
        scheduledAt: new Date(Date.now() + 3_600_000).toISOString(),
        format: 'remote',
      });
    const sessionId = proposed.body._id;
    await request(app).post(`/api/v1/sessions/${sessionId}/respond`).set(auth(bob.token)).send({ decision: 'accept' });

    // Both confirm completion
    await request(app).post(`/api/v1/sessions/${sessionId}/confirm-complete`).set(auth(alice.token));
    const done = await request(app)
      .post(`/api/v1/sessions/${sessionId}/confirm-complete`)
      .set(auth(bob.token));
    expect(done.body.status).toBe('completed');

    const swap = await request(app).get(`/api/v1/swaps/${swapId}`).set(auth(alice.token));
    expect(swap.body.status).toBe('completed');

    // Now a review is allowed and updates the reviewee's rating
    const review = await request(app)
      .post(`/api/v1/swaps/${swapId}/review`)
      .set(auth(alice.token))
      .send({ rating: 5, comment: 'Great teacher' });
    expect(review.status).toBe(201);

    const dup = await request(app)
      .post(`/api/v1/swaps/${swapId}/review`)
      .set(auth(alice.token))
      .send({ rating: 4 });
    expect(dup.status).toBe(409);

    const bobProfile = await request(app).get(`/api/v1/users/${bob.id}`).set(auth(alice.token));
    expect(bobProfile.body.ratingAvg).toBe(5);
    expect(bobProfile.body.ratingCount).toBe(1);
  });

  it('enforces the no-show abandon grace window (FR-038)', async () => {
    const alice = await makeUser('a4b@example.com');
    const bob = await makeUser('b4b@example.com');
    const swapId = await activeSwap(alice, bob);

    // Create a past, accepted session directly (API forbids scheduling in the past)
    const session = await Session.create({
      swap: swapId,
      teacher: alice.id,
      learner: bob.id,
      proposedBy: alice.id,
      scheduledAt: new Date(Date.now() - 3_600_000),
      format: 'remote',
      status: 'accepted',
    });

    // Alice reports Bob's no-show
    const noShow = await request(app)
      .post(`/api/v1/sessions/${session._id}/no-show`)
      .set(auth(alice.token));
    expect(noShow.status).toBe(200);
    expect(noShow.body.status).toBe('no_show');

    // Abandon immediately → blocked by grace window
    const tooEarly = await request(app).post(`/api/v1/swaps/${swapId}/abandon`).set(auth(alice.token));
    expect(tooEarly.status).toBe(403);
    expect(tooEarly.body.error.code).toBe('ABANDON_NOT_YET_ALLOWED');

    // Fast-forward the window, then abandon succeeds
    await Swap.updateOne({ _id: swapId }, { abandonAllowedAt: new Date(Date.now() - 1000) });
    const ok = await request(app).post(`/api/v1/swaps/${swapId}/abandon`).set(auth(alice.token));
    expect(ok.status).toBe(200);
    expect(ok.body.status).toBe('abandoned');
  });
});
