import { RequestHandler } from 'express';
import { Types } from 'mongoose';
import { AIRequest } from '../models/aiRequest.model';
import { aiService } from '../services/ai.service';
import { creditService } from '../services/credit.service';
import { AI_ACTION_COST, AiAction } from '../config/limits';

/**
 * Shared reserve→generate→charge flow for credit-metered AI actions.
 * Deducts only on success (FR-017); records an AIRequest for audit.
 */
async function runAiAction<T>(
  userId: string,
  action: AiAction,
  cost: number,
  targetRef: string | null,
  generate: () => Promise<T>,
): Promise<{ result: T; creditsCharged: number; basicAfter: number; boostAfter: number }> {
  const aiReq = await AIRequest.create({
    user: userId,
    action,
    cost,
    state: 'reserved',
    targetRef: targetRef ? new Types.ObjectId(targetRef) : null,
  });
  try {
    const result = await generate();
    const balance = await creditService.spend(userId, action, cost, String(aiReq._id));
    aiReq.state = 'succeeded';
    await aiReq.save();
    return { result, creditsCharged: cost, basicAfter: balance.basicAfter, boostAfter: balance.boostAfter };
  } catch (err) {
    aiReq.state = 'failed';
    await aiReq.save();
    throw err;
  }
}

export const aiController: Record<string, RequestHandler> = {
  /**
   * Icebreaker (FR-024). Reserve → generate → on success deduct credits (Basic→Boost)
   * and record a spend ledger row; on failure deduct nothing (FR-017).
   */
  icebreaker: async (req, res) => {
    const userId = req.auth!.userId;
    const matchUserId = req.body.matchUserId as string;
    const cost = (res.locals.creditCost as number) ?? AI_ACTION_COST.icebreaker;
    const out = await runAiAction(userId, 'icebreaker', cost, matchUserId, () =>
      aiService.icebreaker(userId, matchUserId),
    );
    res.json({
      message: out.result,
      creditsCharged: out.creditsCharged,
      balanceAfter: { basic: out.basicAfter, boost: out.boostAfter },
    });
  },

  insight: async (req, res) => {
    const userId = req.auth!.userId;
    const cost = (res.locals.creditCost as number) ?? AI_ACTION_COST.insight;
    const out = await runAiAction(userId, 'insight', cost, null, () => aiService.insight(userId));
    res.json({
      report: out.result,
      creditsCharged: out.creditsCharged,
      balanceAfter: { basic: out.basicAfter, boost: out.boostAfter },
    });
  },

  rematch: async (req, res) => {
    const userId = req.auth!.userId;
    const cost = (res.locals.creditCost as number) ?? AI_ACTION_COST.rematch;
    const out = await runAiAction(userId, 'rematch', cost, null, () =>
      aiService.deepRematch(userId, { skillId: req.body.skillId, mode: req.body.mode }),
    );
    res.json({
      matches: out.result,
      creditsCharged: out.creditsCharged,
      balanceAfter: { basic: out.basicAfter, boost: out.boostAfter },
    });
  },

  profileOptimizer: async (req, res) => {
    const userId = req.auth!.userId;
    const cost = (res.locals.creditCost as number) ?? AI_ACTION_COST.profile_opt;
    const out = await runAiAction(userId, 'profile_opt', cost, null, () =>
      aiService.profileOptimizer(userId),
    );
    res.json({
      ...out.result,
      creditsCharged: out.creditsCharged,
      balanceAfter: { basic: out.basicAfter, boost: out.boostAfter },
    });
  },
};
