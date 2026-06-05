# Why you can RECEIVE but cannot SEND on WhatsApp (401)

## The diagnosis

Receiving works because the **inbound webhook** (`POST /webhook`) needs **no
access token** — Meta pushes messages to you. Sending **out** (`POST
/send-message` → `graph.facebook.com/.../messages`) **requires a valid
`WHATSAPP_TOKEN`**. A `401` on send almost always means **the WhatsApp access
token is invalid or expired.**

Meta's **temporary** access tokens (the ones shown on the *WhatsApp → API Setup*
page) **expire after 24 hours.** So sends work for a day, then start failing
with `401` / error code `190` — exactly the "I can receive but can't send"
symptom.

The other common send-only failure is the **24-hour customer-service window**
(error `131047`): WhatsApp only lets you send *free-form* replies within 24h of
the customer's last message. After that you must use an **approved template**.

## What I changed in `app.py` so the cause is now obvious

`/send-message` no longer forwards Meta's raw status (which masqueraded as an
auth error). It now returns **HTTP 502** with the **exact Meta error code,
message, and a fix hint**. So from now on:

| Client sees | Meaning | Fix |
|---|---|---|
| `401` (session expired) | The **admin's app login** token expired | Sign out / sign in again in the app |
| `502` + hint code **190** | **WhatsApp token expired/invalid** | Use a **permanent** token (below) |
| `502` + hint code **131047** | Outside 24h window | Reply within 24h, or use a template |
| `502` + hint code **131030** | Recipient not allow-listed (test mode) | Add the number, or go Live |

## The permanent fix: a System User token (never expires)

1. **Meta Business Settings** → <https://business.facebook.com/settings>
2. **Users → System Users** → *Add* → create an **Admin** system user.
3. Click **Add Assets** → assign your **WhatsApp app** (full control).
4. **Generate New Token** → select the app → permissions:
   `whatsapp_business_messaging` **and** `whatsapp_business_management`.
5. Set token expiration to **Never**. Copy the token.
6. On **Render → your service → Environment**, set:
   - `WHATSAPP_TOKEN` = the new permanent token
   - confirm `WHATSAPP_PHONE_NUMBER_ID` is the **Phone number ID** (not the phone number)
   - (recommended) `WHATSAPP_APP_SECRET` = your Meta app secret, to enable
     webhook signature verification.
7. **Redeploy.** Sending will work and keep working.

## Quick check after deploying

```bash
curl -X POST https://graph.facebook.com/v19.0/<PHONE_NUMBER_ID>/messages \
  -H "Authorization: Bearer <WHATSAPP_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"messaging_product":"whatsapp","to":"<YOUR_TEST_NUMBER>","type":"text","text":{"body":"ping"}}'
```
A `200` with a `messages[].id` = token is good. A `401`/`190` = token still bad.
