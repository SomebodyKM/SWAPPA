import crypto from 'crypto';
import bcrypt from 'bcrypt';
import { Verification } from '../models/verification.model';
import { User, UserDoc } from '../models/user.model';
import { mailer } from './notifiers/mailer';
import { OTP } from '../config/limits';
import { Errors } from '../utils/errors';

function generateCode(length: number): string {
  // numeric OTP, zero-padded
  const max = 10 ** length;
  return crypto.randomInt(0, max).toString().padStart(length, '0');
}

/**
 * Branded HTML for the verification email. The logo is our SWAPPA mark inlined
 * as SVG (the swap loop). Note: some email clients (Gmail/Outlook) strip inline
 * SVG and will show the purple tile only — for guaranteed rendering everywhere,
 * host a PNG of the logo and replace the <svg> below with
 * `<img src="https://…/swappa-logo.png" width="26" height="26" alt="">`.
 */
function verificationEmailHtml(code: string, minutes: number): string {
  return `<!DOCTYPE html>
  <html
    lang="en"
    xmlns="http://www.w3.org/1999/xhtml"
    xmlns:v="urn:schemas-microsoft-com:vml"
    xmlns:o="urn:schemas-microsoft-com:office:office"
  >
    <head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      <meta http-equiv="X-UA-Compatible" content="IE=edge" />
      <meta name="color-scheme" content="light" />
      <meta name="supported-color-schemes" content="light" />
      <link rel="preconnect" href="https://fonts.googleapis.com" />
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
      <link
        href="https://fonts.googleapis.com/css2?family=Fredoka:wght@300..700&family=Nunito+Sans:ital,opsz,wght@0,6..12,200..1000;1,6..12,200..1000&display=swap"
        rel="stylesheet"
      />
      <title>Your SWAPPA verification code</title>
      <style>
        body, table, td, a { -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%; }
        table, td { mso-table-lspace: 0pt; mso-table-rspace: 0pt; }
        img { -ms-interpolation-mode: bicubic; border: 0; height: auto; line-height: 100%; outline: none; text-decoration: none; }
        body { margin: 0; padding: 0; width: 100% !important; height: 100% !important; background-color: #F1EEFB; }
        a { color: #7B5CFF; }
        @media screen and (max-width: 600px) {
          .email-container { width: 100% !important; }
          .fluid-padding { padding-left: 20px !important; padding-right: 20px !important; }
          .code-box { font-size: 32px !important; letter-spacing: 8px !important; padding: 18px 16px !important; }
          .h1 { font-size: 22px !important; }
        }
      </style>
    </head>
    <body style="margin:0; padding:0; background-color:#F1EEFB;">
      <div style="display:none; max-height:0; overflow:hidden; opacity:0; mso-hide:all;">
        Your SWAPPA verification code is inside. It expires in ${minutes} minutes. &#847; &#847; &#847; &#847; &#847;
        &#847; &#847; &#847; &#847; &#847; &#847; &#847; &#847;
      </div>
      <table
        role="presentation"
        width="100%"
        cellpadding="0"
        cellspacing="0"
        border="0"
        style="background-color:#F1EEFB;"
      >
        <tr>
          <td align="center" style="padding: 32px 16px;">
            <table
              role="presentation"
              class="email-container"
              width="600"
              cellpadding="0"
              cellspacing="0"
              border="0"
              style="width:600px; max-width:600px;"
            >
              <tr>
                <td align="center" style="padding-bottom: 24px;">
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="padding-right: 10px;">
                        <img
                          src="https://res.cloudinary.com/de2jiamzv/image/upload/v1782907635/swappa-icon.png"
                          width="40"
                          alt=""
                        />
                      </td>
                      <td
                        valign="middle"
                        style="font-family: Fredoka; font-size: 28px; font-weight: 800; color: #1F1B33; "
                      >
                        SWAPPA
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="background-color:#FFFFFF; border-radius:28px; box-shadow: 0 12px 28px rgba(90,46,229,0.10);">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td
                        style="background:linear-gradient(135deg,#7B5CFF,#5A2EE5); background-color:#7B5CFF; border-radius:28px 28px 0 0; padding: 28px 40px;"
                        class="fluid-padding"
                      >
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td align="center" style="font-family: Arial, Helvetica, sans-serif;">
                              <div
                                style="font-family: Fredoka; display:inline-block; background-color:rgba(255,255,255,0.16); border-radius:999px; padding:6px 16px; font-size:12px; font-weight:700; letter-spacing:1px; color:#FFFFFF; text-transform:uppercase;"
                              >
                                Verify it's you
                              </div>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                    <tr>
                      <td class="fluid-padding" style="padding: 36px 40px 8px 40px;">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td
                              align="center"
                              class="h1"
                              style="font-family: Fredoka; font-size: 24px; font-weight: 800; color: #1F1B33; padding-bottom: 10px;"
                            >
                              Here's your code
                            </td>
                          </tr>
                          <tr>
                            <td
                              align="center"
                              style="font-family: Nunito Sans; font-size: 15px; line-height: 22px; color: #6B6580; padding-bottom: 28px;"
                            >
                              Enter this code in SWAPPA to confirm it's really you.<br />It expires in
                              <strong style="color:#1F1B33;">${minutes} minutes</strong>.
                            </td>
                          </tr>
                        </table>
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td align="center">
                              <table
                                role="presentation"
                                cellpadding="0"
                                cellspacing="0"
                                border="0"
                                style="background-color:#F6F4FF; border: 2px dashed #C9BDFB; border-radius: 18px;"
                              >
                                <tr>
                                  <td
                                    class="code-box"
                                    align="center"
                                    style="padding: 22px 44px; font-family: 'Courier New', Courier, monospace; font-size: 40px; font-weight: 800; letter-spacing: 14px; color: #5A2EE5;"
                                  >
                                    ${code}
                                  </td>
                                </tr>
                              </table>
                            </td>
                          </tr>
                        </table>
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td
                              align="center"
                              style="font-family: Nunito Sans; font-size: 13px; color: #9691A8; padding: 16px 0 30px 0;"
                            >
                              Didn't request this? You can safely ignore this email.
                            </td>
                          </tr>
                        </table>
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td style="border-top: 1px solid #EEEAF9; padding-top: 24px;"></td>
                          </tr>
                        </table>
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                          <tr>
                            <td style="padding-top: 20px; padding-bottom: 28px;">
                              <table
                                role="presentation"
                                cellpadding="0"
                                cellspacing="0"
                                border="0"
                                width="100%"
                                style="background-color:#FFF9EA; border-radius:14px;"
                              >
                                <tr>
                                  <td
                                    style="padding: 16px 18px; font-family: Nunito Sans; font-size: 13px; line-height: 19px; color: #7A6A20;"
                                  >
                                    <strong style="color:#5C4D0F;">Heads up &mdash;</strong> SWAPPA will never call or
                                    email you asking for this code. Never share it with anyone, including someone claiming
                                    to be SWAPPA support.
                                  </td>
                                </tr>
                              </table>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
              <tr>
                <td style="height: 28px; line-height: 28px; font-size: 0;">&nbsp;</td>
              </tr>
              <tr>
                <td align="center" class="fluid-padding" style="padding: 0 40px;">
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td
                        align="center"
                        style="font-family: Nunito Sans; font-size: 12px; line-height: 18px; color: #A39FB5; padding-bottom: 6px;"
                      >
                        Sent by SWAPPA &middot; Learn something new, teach something great.
                      </td>
                    </tr>
                    <tr>
                      <td
                        align="center"
                        style="font-family: Nunito Sans; font-size: 12px; line-height: 18px; color: #C6C2D6;"
                      >
                        &copy; 2026 SWAPPA. All rights reserved.
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
  </html>
  `;
}

export const verificationService = {
  /**
   * Create (or refresh) an email verification challenge and send the code.
   * Enforces a resend cooldown. v1 supports the 'email' channel only.
   */
  async sendEmailCode(user: UserDoc): Promise<void> {
    if (!user.email) throw Errors.badRequest('No email on file to verify');

    const existing = await Verification.findOne({ user: user._id, channel: 'email' });
    if (existing && Date.now() - existing.lastSentAt.getTime() < OTP.resendCooldownMs) {
      throw Errors.badRequest('Please wait before requesting another code', {
        retryAfterMs: OTP.resendCooldownMs - (Date.now() - existing.lastSentAt.getTime()),
      });
    }

    const code = generateCode(OTP.length);
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + OTP.ttlMs);

    await Verification.findOneAndUpdate(
      { user: user._id, channel: 'email' },
      {
        user: user._id,
        channel: 'email',
        target: user.email,
        codeHash,
        expiresAt,
        attempts: 0,
        lastSentAt: new Date(),
        consumedAt: null,
      },
      { upsert: true, new: true },
    );

    const minutes = Math.round(OTP.ttlMs / 60000);
    await mailer.send({
      to: user.email,
      subject: 'Your SWAPPA verification code',
      text: `Your SWAPPA verification code is ${code}. It expires in ${minutes} minutes.`,
      html: verificationEmailHtml(code, minutes),
    });
  },

  /** Verify an emailed code; marks the user email-verified on success. */
  async verifyEmail(email: string, code: string): Promise<UserDoc> {
    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) throw Errors.notFound('Account not found');
    if (user.emailVerified) return user;

    const challenge = await Verification.findOne({ user: user._id, channel: 'email' });
    if (!challenge || challenge.consumedAt) throw Errors.badRequest('No active verification code');
    if (challenge.expiresAt.getTime() < Date.now()) {
      throw Errors.badRequest('Verification code expired; request a new one');
    }
    if (challenge.attempts >= OTP.maxAttempts) {
      throw Errors.badRequest('Too many attempts; request a new code');
    }

    const ok = await bcrypt.compare(code, challenge.codeHash);
    if (!ok) {
      challenge.attempts += 1;
      await challenge.save();
      throw Errors.badRequest('Incorrect code');
    }

    challenge.consumedAt = new Date();
    await challenge.save();

    user.emailVerified = true;
    user.verifiedAt = new Date();
    await user.save();
    return user;
  },
};
