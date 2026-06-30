import { Skill, SkillDoc, normalizeSkillName } from '../models/skill.model';
import { SkillTag, SkillTagDoc, SkillTagKind, Proficiency } from '../models/skillTag.model';
import { User } from '../models/user.model';
import { tierLimits } from '../config/limits';
import { Errors } from '../utils/errors';

export const skillService = {
  /** Search the approved catalog; `all` returns the full catalog for pickers. */
  async search(query: string | undefined, all: boolean): Promise<SkillDoc[]> {
    const filter: Record<string, unknown> = { status: 'approved' };
    if (query && query.trim()) {
      filter.nameNormalized = { $regex: normalizeSkillName(query), $options: 'i' };
    }
    const q = Skill.find(filter).sort({ name: 1 });
    if (!all) q.limit(50);
    return q.exec();
  },

  async categories(): Promise<string[]> {
    return Skill.distinct('category', { status: 'approved' });
  },

  async getById(id: string): Promise<SkillDoc> {
    const skill = await Skill.findById(id);
    if (!skill) throw Errors.notFound('Skill not found');
    return skill;
  },

  /**
   * Find-or-create a catalog entry. For MVP this creates an approved skill;
   * US9 (task T093) will restrict catalog mutation to admins and create
   * user-proposed skills as `pending` for approval.
   */
  async findOrCreate(name: string, category: string): Promise<SkillDoc> {
    const nameNormalized = normalizeSkillName(name);
    const existing = await Skill.findOne({ nameNormalized });
    if (existing) return existing;
    return Skill.create({ name: name.trim(), nameNormalized, category, status: 'approved' });
  },

  async listTags(userId: string): Promise<SkillTagDoc[]> {
    return SkillTag.find({ user: userId }).populate('skill').sort({ createdAt: -1 });
  },

  async addTag(
    userId: string,
    input: { skillId: string; kind: SkillTagKind; proficiency?: Proficiency },
  ): Promise<SkillTagDoc> {
    const user = await User.findById(userId).select('tier');
    if (!user) throw Errors.notFound('User not found');

    const cap = tierLimits(user.tier).skillTags;
    const count = await SkillTag.countDocuments({ user: userId });
    if (count >= cap) {
      throw Errors.limitReached('Skill tag limit reached', {
        limit: cap,
        tier: user.tier,
        premiumUnlocksMore: user.tier === 'free',
      });
    }

    const skill = await Skill.findById(input.skillId);
    if (!skill) throw Errors.notFound('Skill not found');
    if (input.kind === 'offer' && !input.proficiency) {
      throw Errors.badRequest('Proficiency is required for skills you offer to teach');
    }

    try {
      return await SkillTag.create({
        user: userId,
        skill: input.skillId,
        kind: input.kind,
        proficiency: input.proficiency,
      });
    } catch (err) {
      if ((err as { code?: number }).code === 11000) {
        throw Errors.conflict('You already have this skill tag', 'TAG_EXISTS');
      }
      throw err;
    }
  },

  async updateTag(
    userId: string,
    tagId: string,
    proficiency: Proficiency,
  ): Promise<SkillTagDoc> {
    const tag = await SkillTag.findOne({ _id: tagId, user: userId });
    if (!tag) throw Errors.notFound('Skill tag not found');
    if (tag.kind !== 'offer') throw Errors.badRequest('Proficiency only applies to offered skills');
    tag.proficiency = proficiency;
    await tag.save();
    return tag;
  },

  async removeTag(userId: string, tagId: string): Promise<void> {
    const res = await SkillTag.deleteOne({ _id: tagId, user: userId });
    if (res.deletedCount === 0) throw Errors.notFound('Skill tag not found');
  },
};
