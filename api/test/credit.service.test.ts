import { creditService } from '../src/services/credit.service';
import { User, UserDoc } from '../src/models/user.model';
import { CreditTransaction } from '../src/models/creditTransaction.model';
import { CREDITS } from '../src/config/limits';

async function makeUser(over: Partial<Record<string, unknown>> = {}): Promise<UserDoc> {
  return User.create({
    email: `${Math.random()}@example.com`,
    passwordHash: 'x',
    displayName: 'u',
    emailVerified: true,
    ...over,
  });
}

describe('credit.service (money-path)', () => {
  it('spends Basic before Boost and writes ledger rows', async () => {
    const user = await makeUser();
    user.credits.basic.balance = 1;
    user.credits.boost.balance = 2;
    await user.save();
    const id = String(user._id);

    const r1 = await creditService.spend(id, 'icebreaker', 1, 'ref1');
    expect(r1.basicAfter).toBe(0);
    expect(r1.boostAfter).toBe(2); // basic drained first

    const r2 = await creditService.spend(id, 'icebreaker', 2, 'ref2');
    expect(r2.basicAfter).toBe(0);
    expect(r2.boostAfter).toBe(0); // remainder from boost

    const spends = await CreditTransaction.find({ user: id, type: 'spend' });
    expect(spends).toHaveLength(2);
    const totalDelta = spends.reduce((s, t) => s + t.basicDelta + t.boostDelta, 0);
    expect(totalDelta).toBe(-3); // ledger reconciles with the 3 credits spent
  });

  it('rejects spending more than available (402) and charges nothing', async () => {
    const user = await makeUser();
    user.credits.basic.balance = 0;
    user.credits.boost.balance = 0;
    await user.save();
    await expect(creditService.spend(String(user._id), 'rematch', 3, 'x')).rejects.toMatchObject({
      status: 402,
    });
    const count = await CreditTransaction.countDocuments({ user: user._id, type: 'spend' });
    expect(count).toBe(0);
  });

  it('refills Basic to cap on a cycle boundary (set, not add; no rollover)', async () => {
    const user = await makeUser();
    user.credits.basic.balance = 5;
    user.credits.basic.cap = 20;
    user.credits.basic.lastRefillAt = new Date(Date.now() - CREDITS.refillCycleMs - 1000);
    await user.save();

    const balance = await creditService.getBalance(String(user._id));
    expect(balance.basic.balance).toBe(20); // set to cap, not 25
  });

  it('grants the welcome bonus once', async () => {
    const user = await makeUser();
    await creditService.applyWelcomeGrant(user);
    let fresh = await User.findById(user._id);
    expect(fresh!.credits.basic.balance).toBe(CREDITS.welcomeGrant);

    await creditService.applyWelcomeGrant(fresh!);
    fresh = await User.findById(user._id);
    expect(fresh!.credits.basic.balance).toBe(CREDITS.welcomeGrant); // unchanged
  });
});
