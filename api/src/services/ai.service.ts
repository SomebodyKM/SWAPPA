import { env } from '../config/env';
import { User } from '../models/user.model';
import { SkillTag } from '../models/skillTag.model';
import { matchingService, MatchMode, MatchResult } from './matching.service';
import { logger } from '../utils/logger';
import { Errors } from '../utils/errors';

const DEFAULT_MODEL = 'gemini-2.5-flash';

/**
 * Generate text with Gemini (backend-only — Constitution III). Falls back to a
 * deterministic local stub when GEMINI_API_KEY is unset, so dev/tests run free.
 */
async function generateText(prompt: string, fallback: string): Promise<string> {
  if (!env.GEMINI_API_KEY) {
    logger.debug('[ai] GEMINI_API_KEY unset — using local stub');
    return fallback;
  }
  try {
    const { GoogleGenAI } = await import('@google/genai');
    const ai = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
    const res = await ai.models.generateContent({ model: DEFAULT_MODEL, contents: prompt });
    return res.text ?? fallback;
  } catch (err) {
    logger.error('[ai] generation failed', (err as Error).message);
    throw Errors.internal('AI generation failed');
  }
}

async function offeredSkillNames(userId: string): Promise<string[]> {
  const tags = await SkillTag.find({ user: userId, kind: 'offer' }).populate('skill', 'name');
  return tags.map((t) => (t.skill as unknown as { name: string }).name).filter(Boolean);
}
async function wantedSkillNames(userId: string): Promise<string[]> {
  const tags = await SkillTag.find({ user: userId, kind: 'want' }).populate('skill', 'name');
  return tags.map((t) => (t.skill as unknown as { name: string }).name).filter(Boolean);
}

export const aiService = {
  /** Personalized opening message for a specific match (FR-024). */
  async icebreaker(userId: string, matchUserId: string): Promise<string> {
    const [me, match] = await Promise.all([
      User.findById(userId).select('displayName'),
      User.findById(matchUserId).select('displayName'),
    ]);
    if (!me || !match) throw Errors.notFound('User not found');

    const [theyTeach, iTeach] = await Promise.all([
      offeredSkillNames(matchUserId),
      offeredSkillNames(userId),
    ]);
    const theirSkill = theyTeach[0] ?? 'something new';
    const mySkill = iTeach[0] ?? 'a skill of mine';

    const prompt =
      `Write a short, warm, specific opening message (max 2 sentences) from ${me.displayName} ` +
      `to ${match.displayName} on a skill-swap app. ${me.displayName} wants to learn ${theirSkill} ` +
      `and can teach ${mySkill}. Be friendly and propose a swap. No emojis, no preamble.`;

    const fallback =
      `Hi ${match.displayName}! I'd love to learn ${theirSkill} from you — ` +
      `I can teach you ${mySkill} in return. Want to set up a swap?`;

    return generateText(prompt, fallback);
  },

  /** Personalized market analysis: demand for the user's offered skills (FR-025). */
  async insight(userId: string): Promise<{ summary: string; demand: { skill: string; wanters: number }[] }> {
    const offerTags = await SkillTag.find({ user: userId, kind: 'offer' }).populate('skill', 'name');
    const demand = await Promise.all(
      offerTags.map(async (t) => {
        const skill = t.skill as unknown as { _id: unknown; name: string };
        const wanters = await SkillTag.countDocuments({ kind: 'want', skill: skill._id });
        return { skill: skill.name, wanters };
      }),
    );
    demand.sort((a, b) => b.wanters - a.wanters);

    const top = demand[0];
    const prompt =
      `Give a 2-sentence encouraging market insight for a skill-swapper. Their most in-demand ` +
      `teachable skill is "${top?.skill ?? 'n/a'}" wanted by ${top?.wanters ?? 0} people. ` +
      `Suggest how to get more swaps. No preamble.`;
    const fallback = top
      ? `Your most in-demand skill is ${top.skill} (${top.wanters} learners want it). ` +
        `Lead with it in your profile and send a few icebreakers to maximize swaps.`
      : `Add skills you can teach to start attracting swap requests.`;

    const summary = await generateText(prompt, fallback);
    return { summary, demand };
  },

  /** Deeper re-match: wider/uncapped candidate set with reasoning-based ranking (FR-026). */
  async deepRematch(
    userId: string,
    opts: { skillId?: string; mode?: MatchMode },
  ): Promise<MatchResult[]> {
    const result = await matchingService.findMatches(userId, {
      skillId: opts.skillId,
      mode: opts.mode ?? 'remote',
      uncapped: true,
    });
    return result.items;
  },

  /** Suggest a rewritten bio + skill tags to attract more matches (FR-027). */
  async profileOptimizer(
    userId: string,
  ): Promise<{ suggestedBio: string; suggestedTags: string[] }> {
    const user = await User.findById(userId).select('displayName bio');
    if (!user) throw Errors.notFound('User not found');
    const [teach, learn] = await Promise.all([offeredSkillNames(userId), wantedSkillNames(userId)]);

    const prompt =
      `Rewrite a friendly 1-2 sentence skill-swap profile bio for ${user.displayName}, who ` +
      `teaches [${teach.join(', ') || 'n/a'}] and wants to learn [${learn.join(', ') || 'n/a'}]. ` +
      `Current bio: "${user.bio ?? ''}". Return only the bio text.`;
    const fallback =
      `I teach ${teach.join(', ') || 'a few things'} and I'm keen to learn ` +
      `${learn.join(', ') || 'new skills'}. Let's swap!`;

    const suggestedBio = await generateText(prompt, fallback);
    // Suggest complementary tags (kept simple for v1; a future version can use the model).
    const suggestedTags = [...new Set([...teach, ...learn])].slice(0, 5);
    return { suggestedBio, suggestedTags };
  },
};
