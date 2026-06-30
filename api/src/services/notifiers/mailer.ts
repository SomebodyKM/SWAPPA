import { env } from '../../config/env';
import { logger } from '../../utils/logger';

export interface SendEmailInput {
  to: string;
  subject: string;
  text: string;
  html?: string;
}

export interface Mailer {
  send(input: SendEmailInput): Promise<void>;
}

/**
 * Dev/console mailer — prints the email (and any code) to the log instead of
 * sending. Free and works immediately with no provider keys.
 */
class ConsoleMailer implements Mailer {
  async send(input: SendEmailInput): Promise<void> {
    logger.info(`[mailer:console] to=${input.to} subject="${input.subject}"`, input.text);
  }
}

/**
 * Resend mailer (recommended production provider — ~3k emails/mo free).
 * Lazily imports the SDK so the dependency is optional until configured.
 * Configure RESEND_API_KEY + MAIL_FROM to enable (add to env when ready).
 */
class ResendMailer implements Mailer {
  constructor(
    private apiKey: string,
    private from: string,
  ) {}

  async send(input: SendEmailInput): Promise<void> {
    // Implemented when the `resend` package + keys are added.
    // const { Resend } = await import('resend');
    // const resend = new Resend(this.apiKey);
    // await resend.emails.send({ from: this.from, to: input.to, subject: input.subject,
    //   text: input.text, html: input.html });
    logger.warn('[mailer:resend] not yet wired; falling back to console', { to: input.to });
    await new ConsoleMailer().send(input);
  }
}

function buildMailer(): Mailer {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.MAIL_FROM;
  if (apiKey && from && env.NODE_ENV === 'production') {
    return new ResendMailer(apiKey, from);
  }
  return new ConsoleMailer();
}

export const mailer: Mailer = buildMailer();
