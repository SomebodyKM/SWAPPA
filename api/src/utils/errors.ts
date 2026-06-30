/** Typed application error with an HTTP status and a stable machine code. */
export class AppError extends Error {
  status: number;
  code: string;
  details?: unknown;

  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

export const Errors = {
  badRequest: (msg = 'Bad request', details?: unknown) =>
    new AppError(400, 'BAD_REQUEST', msg, details),
  unauthorized: (msg = 'Unauthorized') => new AppError(401, 'UNAUTHORIZED', msg),
  forbidden: (msg = 'Forbidden', code = 'FORBIDDEN', details?: unknown) =>
    new AppError(403, code, msg, details),
  notFound: (msg = 'Not found') => new AppError(404, 'NOT_FOUND', msg),
  conflict: (msg = 'Conflict', code = 'CONFLICT') => new AppError(409, code, msg),
  paymentRequired: (msg = 'Insufficient credits', details?: unknown) =>
    new AppError(402, 'INSUFFICIENT_CREDITS', msg, details),
  limitReached: (msg = 'Limit reached', details?: unknown) =>
    new AppError(403, 'LIMIT_REACHED', msg, details),
  premiumRequired: (msg = 'Premium required', details?: unknown) =>
    new AppError(403, 'PREMIUM_REQUIRED', msg, details),
  internal: (msg = 'Internal server error') => new AppError(500, 'INTERNAL', msg),
};
