import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  CORS_ORIGIN: z.string().default('*'),

  MONGO_URI: z.string().default('mongodb://127.0.0.1:27017/swappa'),
  MONGO_DB: z.string().default('swappa_production'),

  JWT_SECRET: z.string().default('dev-access-secret'),
  JWT_REFRESH_SECRET: z.string().default('dev-refresh-secret'),
  JWT_ACCESS_TTL: z.string().default('15m'),
  JWT_REFRESH_TTL: z.string().default('30d'),

  GEMINI_API_KEY: z.string().optional(),

  CLOUDINARY_CLOUD_NAME: z.string().optional(),
  CLOUDINARY_API_KEY: z.string().optional(),
  CLOUDINARY_API_SECRET: z.string().optional(),

  REVENUECAT_WEBHOOK_SECRET: z.string().optional(),

  // Server-only key for Places Autocomplete/Details + Geocoding (never shipped
  // to the Flutter bundle). Restrict it to those APIs + this server's IP(s).
  GOOGLE_MAPS_SERVER_KEY: z.string().optional(),

  // Salts the deterministic per-user location jitter (see locationPresenter.ts)
  // so the offset can't be reproduced by anyone who only knows the user id.
  // Override in production; the dev default is fine for local/staging.
  LOCATION_FUZZ_SALT: z.string().default('dev-location-fuzz-salt'),

  // Email. Priority: Resend → Mailjet → SMTP (e.g. SMTP2GO) → console
  // fallback. MAIL_FROM is the verified sender, e.g. 'SWAPPA <verify@yourdomain>'.
  // Note: Render (and many PaaS hosts) block outbound raw SMTP entirely —
  // Resend/Mailjet go over HTTPS instead, so prefer those when deployed there.
  MAIL_FROM: z.string().optional(),
  // Generic SMTP (SMTP2GO/Brevo/SendGrid/…) — only reliable on hosts that
  // allow outbound SMTP.
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().optional(),
  SMTP_SECURE: z.coerce.boolean().optional(), // true for port 465; else STARTTLS
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  // Mailjet (HTTPS Send API v3.1) — API key/secret from
  // app.mailjet.com/account/apikeys. MAIL_FROM's address must be a verified
  // sender in app.mailjet.com/account/sender (single-address verification via
  // an emailed confirmation link — no DNS/domain access needed).
  MAILJET_API_KEY: z.string().optional(),
  MAILJET_API_SECRET: z.string().optional(),
  // Resend (SDK, HTTPS) — alternative to Mailjet.
  RESEND_API_KEY: z.string().optional(),

  FCM_PROJECT_ID: z.string().optional(),
  FCM_CLIENT_EMAIL: z.string().optional(),
  FCM_PRIVATE_KEY: z.string().optional(),

  RTC_APP_ID: z.string().optional(),
  RTC_APP_CERTIFICATE: z.string().optional(),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  // eslint-disable-next-line no-console
  console.error('Invalid environment configuration:', parsed.error.issues);
  throw new Error('Invalid environment configuration');
}

export const env = parsed.data;
export const isProd = env.NODE_ENV === 'production';
export const isTest = env.NODE_ENV === 'test';
