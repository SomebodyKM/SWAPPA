import { Types } from 'mongoose';

export interface PageParams {
  cursor?: string; // ObjectId of the last item from the previous page
  limit: number;
  all: boolean;
}

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

const DEFAULT_LIMIT = 20;
const MAX_LIMIT = 100;

/** Parse `?cursor`, `?limit`, `?all` from a query object. */
export function parsePageParams(query: Record<string, unknown>): PageParams {
  const all = String(query.all) === 'true';
  let limit = Number.parseInt(String(query.limit ?? ''), 10);
  if (Number.isNaN(limit) || limit <= 0) limit = DEFAULT_LIMIT;
  if (limit > MAX_LIMIT) limit = MAX_LIMIT;
  const cursor = typeof query.cursor === 'string' && Types.ObjectId.isValid(query.cursor)
    ? query.cursor
    : undefined;
  return { cursor, limit, all };
}

/** Build a Mongo filter fragment for cursor-based pagination on `_id` (descending). */
export function cursorFilter(cursor?: string): Record<string, unknown> {
  return cursor ? { _id: { $lt: new Types.ObjectId(cursor) } } : {};
}

/** Slice an over-fetched array (limit+1) into a page with nextCursor. */
export function toPage<T extends { _id: Types.ObjectId | string }>(
  docs: T[],
  limit: number,
): Page<T> {
  const hasMore = docs.length > limit;
  const items = hasMore ? docs.slice(0, limit) : docs;
  const nextCursor = hasMore ? String(items[items.length - 1]._id) : null;
  return { items, nextCursor };
}
