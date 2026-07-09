import zxcvbn from 'zxcvbn';
import { AppError } from './errors';

/** Minimum acceptable zxcvbn score (0–4). 3 = "somewhat guessable" or better. */
const MIN_SCORE = 3;

/**
 * Reject weak passwords using zxcvbn. `userInputs` (email, name) make the
 * estimate stricter so users can't base a password on their own details.
 * Throws a 400 `WEAK_PASSWORD` error (tagged to the `password` field) on failure.
 */
export function assertStrongPassword(password: string, userInputs: string[] = []): void {
  const result = zxcvbn(password, userInputs.filter(Boolean));
  if (result.score < MIN_SCORE) {
    const message =
      result.feedback.warning ||
      result.feedback.suggestions[0] ||
      'That password is too weak — try a longer mix of words, numbers and symbols.';
    throw new AppError(400, 'WEAK_PASSWORD', message, { field: 'password', score: result.score });
  }
}
