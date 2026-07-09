import { Skill, SkillDoc, normalizeSkillName } from '../models/skill.model';
import { SkillTag, SkillTagDoc, SkillTagKind, Proficiency } from '../models/skillTag.model';
import { User } from '../models/user.model';
import { tierLimits } from '../config/limits';
import { notificationService } from './notification.service';
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
   * A user proposing a skill not already in the catalog (US9, FR-040). If it
   * already exists (approved or still pending from an earlier proposal),
   * that same entry is returned so the tag can be added right away. A
   * genuinely new one is created `pending` and every admin is notified in
   * real time — it only enters the public catalog once one of them approves it.
   */
  async proposeSkill(name: string, category: string): Promise<SkillDoc> {
    const nameNormalized = normalizeSkillName(name);
    const existing = await Skill.findOne({ nameNormalized });
    if (existing) return existing;

    const skill = await Skill.create({ name: name.trim(), nameNormalized, category, status: 'pending' });
    const admins = await User.find({ role: 'admin', status: 'active' }).select('_id');
    await Promise.all(
      admins.map((admin) =>
        notificationService.notify({
          userId: String(admin._id),
          type: 'skill_submitted',
          title: 'New skill awaiting approval',
          body: `"${skill.name}" (${skill.category}) was proposed`,
          data: { skillId: String(skill._id) },
        }),
      ),
    );
    return skill;
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

    const cap = tierLimits(user.tier).skillTagsPerKind;
    const count = await SkillTag.countDocuments({ user: userId, kind: input.kind });
    if (count >= cap) {
      throw Errors.limitReached(
        `You can ${input.kind === 'offer' ? 'teach' : 'learn'} up to ${cap} skills on the free plan`,
        { limit: cap, kind: input.kind, tier: user.tier, premiumUnlocksMore: user.tier === 'free' },
      );
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
    // Proficiency applies to both offered (skill level) and wanted (current level) tags.
    tag.proficiency = proficiency;
    await tag.save();
    return tag;
  },

  async removeTag(userId: string, tagId: string): Promise<void> {
    const res = await SkillTag.deleteOne({ _id: tagId, user: userId });
    if (res.deletedCount === 0) throw Errors.notFound('Skill tag not found');
  },
};
