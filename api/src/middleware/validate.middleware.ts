import { RequestHandler } from 'express';
import { ZodType } from 'zod';
import { Errors } from '../utils/errors';

interface Schemas {
  body?: ZodType;
  query?: ZodType;
  params?: ZodType;
}

/**
 * Validate request parts with Zod. Validated `body`/`params` are written back.
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
      if (!r.success) return next(Errors.badRequest('Invalid request body', r.error.issues));
      req.body = r.data;
    }
    next();
  };
}
