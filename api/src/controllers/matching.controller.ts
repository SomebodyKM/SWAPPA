import { RequestHandler } from 'express';
import { matchingService, MatchMode } from '../services/matching.service';

export const matchingController: Record<string, RequestHandler> = {
  browse: async (req, res) => {
    const q = (res.locals.query ?? {}) as {
      skillId?: string;
      mode?: MatchMode;
      radius?: number;
      mutualOnly?: boolean;
    };
    const result = await matchingService.findMatches(req.auth!.userId, {
      skillId: q.skillId,
      mode: q.mode ?? 'remote',
      radius: q.radius,
      mutualOnly: q.mutualOnly === true,
    });
    res.json({
      items: result.items,
      premiumUnlocksFullList: result.capped,
      shownLimit: result.limit,
      // Total match count is safe to reveal even when capped (no candidate
      // identities), and lets the client show "N more matches" accurately.
      totalCount: result.totalCount,
      // Non-identifying previews of the hidden tail (skill + distance only).
      teasers: result.teasers,
    });
  },
};
