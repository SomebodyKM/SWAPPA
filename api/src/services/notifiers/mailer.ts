import dns from 'node:dns';
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
 * Generic SMTP mailer (nodemailer) — works with SMTP2GO / Brevo / SendGrid /
 * Mailjet / SES-SMTP / etc. Configure SMTP_HOST + SMTP_USER + SMTP_PASS +
 * MAIL_FROM. The transporter is created lazily and reused. On failure it logs
 * and falls back to the console so verification still works during setup.
 */
class SmtpMailer implements Mailer {
  // Loosely typed to avoid a hard import of nodemailer's types at module load.
  private transporter: { sendMail(opts: unknown): Promise<unknown> } | null = null;

  constructor(
    private host: string,
    private port: number,
    private secure: boolean,
    private user: string,
    private pass: string,
    private from: string,
  ) {}

  private async getTransporter() {
    if (this.transporter) return this.transporter;
    const nodemailer = await import('nodemailer');

    // nodemailer ^9 resolves both A and AAAA records for the SMTP host and
    // picks *randomly* between them (its own dual-stack fallback logic —
    // there's no `family` option that restricts this). Render's containers
    // have no outbound IPv6 route, so whenever it happens to pick an IPv6
    // address for smtp.gmail.com the connection fails with ENETUNREACH.
    // Resolving to a literal IPv4 address ourselves sidesteps that resolver
    // entirely (a literal IP short-circuits it); `servername` keeps TLS
    // certificate/SNI validation against the real hostname.
    const { address } = await dns.promises.lookup(this.host, { family: 4 });
    this.transporter = nodemailer.createTransport({
      host: address,
      port: this.port,
      secure: this.secure,
      auth: { user: this.user, pass: this.pass },
      servername: this.host,
    } as Parameters<typeof nodemailer.createTransport>[0]);
    return this.transporter;
  }

  async send(input: SendEmailInput): Promise<void> {
    try {
      const transporter = await this.getTransporter();
      await transporter.sendMail({
        from: this.from,
        to: input.to,
        subject: input.subject,
        text: input.text,
        html: input.html,
      });
      logger.info(`[mailer:smtp] sent to=${input.to} via ${this.host}`);
    } catch (err) {
      logger.error(`[mailer:smtp] send failed for ${input.to}; falling back to console`, err);
      await new ConsoleMailer().send(input);
    }
  }
}

/**
 * Resend mailer (transactional email — ~3k emails/mo free). Configure
 * RESEND_API_KEY + MAIL_FROM to enable. If a send fails (e.g. bad key or, in
 * test mode, sending to a non-owner address) it logs the error and falls back
 * to the console so the verification flow still works during setup.
 */
class ResendMailer implements Mailer {
  constructor(
    private apiKey: string,
    private from: string,
  ) {}

  async send(input: SendEmailInput): Promise<void> {
    try {
      const { Resend } = await import('resend');
      const resend = new Resend(this.apiKey);
      const { data, error } = await resend.emails.send({
        from: this.from,
        to: input.to,
        subject: input.subject,
        text: input.text,
        html: input.html ?? `<pre>${input.text}</pre>`,
      });
      if (error) throw new Error(error.message);
      logger.info(`[mailer:resend] sent to=${input.to} id=${data?.id ?? '?'}`);
    } catch (err) {
      logger.error(`[mailer:resend] send failed for ${input.to}; falling back to console`, err);
      await new ConsoleMailer().send(input);
    }
  }
}

function buildMailer(): Mailer {
  // 1. Generic SMTP (SMTP2GO etc.)
  if (env.SMTP_HOST && env.SMTP_USER && env.SMTP_PASS && env.MAIL_FROM) {
    const port = env.SMTP_PORT ?? 587;
    const secure = env.SMTP_SECURE ?? port === 465;
    logger.info(`[mailer] using SMTP (${env.SMTP_HOST}:${port}, from ${env.MAIL_FROM})`);
    return new SmtpMailer(env.SMTP_HOST, port, secure, env.SMTP_USER, env.SMTP_PASS, env.MAIL_FROM);
  }
  // 2. Resend SDK
  if (env.RESEND_API_KEY && env.MAIL_FROM) {
    logger.info(`[mailer] using Resend (from ${env.MAIL_FROM})`);
    return new ResendMailer(env.RESEND_API_KEY, env.MAIL_FROM);
  }
  // 3. Console fallback
  logger.info('[mailer] no email provider configured — using console mailer');
  return new ConsoleMailer();
}

export const mailer: Mailer = buildMailer();
