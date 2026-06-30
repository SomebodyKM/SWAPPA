import request from 'supertest';
import { createApp } from '../src/app';
import { User } from '../src/models/user.model';
import { Skill } from '../src/models/skill.model';
import { SkillTag } from '../src/models/skillTag.model';
import { CreditTransaction } from '../src/models/creditTransaction.model';
import { aiService } from '../src/services/ai.service';
import { signAccessToken } from '../src/utils/jwt';

const app = createApp();
const auth = (t: string) => ({ Authorization: `Bearer ${t}` });

async function makeUser(basic: number) {
  const u = await User.create({
    email: `${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName: 'u',
    emailVerified: true,
  });
  u.credits.basic.balance = basic;
  await u.save();
  return { id: String(u._id), token: signAccessToken({ sub: String(u._id), role: 'user' }) };
}

async function makeMatch() {
  const u = await User.create({
    email: `${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName: 'Match',
    emailVerified: true,
  });
  const skill = await Skill.create({ name: 'Guitar', nameNormalized: 'guitar', category: 'Music' });
  await SkillTag.create({ user: u._id, skill: skill._id, kind: 'offer', proficiency: 'expert' });
  return String(u._id);
}

describe('US5 — AI Icebreaker spend guard (SC-006/SC-007)', () => {
  it('charges exactly once on success (Basic first) and writes a spend row', async () => {
    const me = await makeUser(1);
    const matchId = await makeMatch();

    const res = await request(app)
      .post('/api/v1/ai/icebreaker')
      .set(auth(me.token))
      .send({ matchUserId: matchId });

    expect(res.status).toBe(200);
    expect(typeof res.body.message).toBe('string');
    expect(res.body.creditsCharged).toBe(1);
    expect(res.body.balanceAfter.basic).toBe(0);

    const spends = await CreditTransaction.countDocuments({ user: me.id, type: 'spend' });
    expect(spends).toBe(1);
  });

  it('returns 402 with no charge when out of credits', async () => {
    const me = await makeUser(0);
    const matchId = await makeMatch();

    const res = await request(app)
      .post('/api/v1/ai/icebreaker')
      .set(auth(me.token))
      .send({ matchUserId: matchId });

    expect(res.status).toBe(402);
    expect(res.body.error.code).toBe('INSUFFICIENT_CREDITS');
    const spends = await CreditTransaction.countDocuments({ user: me.id, type: 'spend' });
    expect(spends).toBe(0);
  });

  it('deducts nothing when generation fails', async () => {
    const me = await makeUser(1);
    const matchId = await makeMatch();
    const spy = jest.spyOn(aiService, 'icebreaker').mockRejectedValueOnce(new Error('boom'));

    const res = await request(app)
      .post('/api/v1/ai/icebreaker')
      .set(auth(me.token))
      .send({ matchUserId: matchId });

    expect(res.status).toBe(500);
    const fresh = await User.findById(me.id);
    expect(fresh!.credits.basic.balance).toBe(1); // unchanged
    const spends = await CreditTransaction.countDocuments({ user: me.id, type: 'spend' });
    expect(spends).toBe(0);
    spy.mockRestore();
  });
});
