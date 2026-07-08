import { RequestHandler } from 'express';
import { ZodType, ZodError } from 'zod';
import { AppError, Errors } from '../utils/errors';

interface Schemas {
  body?: ZodType;
  query?: ZodType;
  params?: ZodType;
}

/** First error message per top-level field, for field-scoped UI errors. */
function fieldErrors(error: ZodError): Record<string, string> {
  const out: Record<string, string> = {};
  for (const issue of error.issues) {
    const key = issue.path[0];
    if (typeof key === 'string' && !(key in out)) out[key] = issue.message;
  }
  return out;
}

/**
 * Validate request parts with Zod. Validated `body`/`params` are written back.
 * Body validation failures return a `VALIDATION` error with per-field messages
 * so the client can highlight the exact field.
 * Note: in Express 5 `req.query` is read-only, so parsed query is exposed on
 * `res.locals.query` instead of mutating `req.query`.
 */
export function validate(schemas: Schemas): RequestHandler {
  return (req, res, next) => {
    if (schemas.params) {
      const r = schemas.params.safeParse(req.params);
      if (!r.success) return next(Errors.badRequest('Invalid path parameters', r.error.issues));
      req.params = r.data as typeof req.params;
    }
    if (schemas.query) {
      const r = schemas.query.safeParse(req.query);
      if (!r.success) return next(Errors.badRequest('Invalid query parameters', r.error.issues));
      res.locals.query = r.data;
    }
    if (schemas.body) {
      const r = schemas.body.safeParse(req.body);
      if (!r.success) {
        return next(
          new AppError(400, 'VALIDATION', 'Please fix the highlighted fields', {
            fieldErrors: fieldErrors(r.error),
          }),
        );
      }
      req.body = r.data;
    }
    next();
  };
}
