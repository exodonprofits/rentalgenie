# Payment inbox setup

Forwarded Zelle and Venmo alerts become pending payments a landlord confirms with one tap. Nothing
is written to the rent ledger without that confirmation.

```
bank / Venmo alert → Gmail filter → Postmark inbound → n8n → Supabase → dashboard confirm card
```

---

## 1. Postmark

1. Create a server (the free tier covers normal volume).
2. Open its **Default Inbound Stream → Settings**.
3. Set the webhook URL to `https://<your-n8n>/webhook/rg-payment-inbox`.
   Use `/webhook/`, not `/webhook-test/`. It only responds while the workflow is active.
4. Copy the inbound address, which looks like `abc123@inbound.postmarkapp.com`.

A company's own address is that address with its inbox token added before the `@`:
`abc123+<token>@inbound.postmarkapp.com`. Postmark passes the token as `MailboxHash`.

The token lives in `companies.payment_inbox_token` and is generated automatically for new companies.

---

## 2. n8n

1. Import `json/rental-genie-payment-inbox.n8n.json`.
2. Add two credentials:
   - **Supabase** — project URL plus the **service-role** key. The ingest function is not callable
     with the anon key.
   - **Anthropic** — an API key. n8n's connection test may show "bad request" even when the key is
     fine; a real request through the node is the reliable check.
3. Activate the workflow.

**The nodes:** the webhook receives the email; *Parse alert* reads Chase and Venmo formats with
rules and routes everything else to *AI extract* (Claude Haiku) for extraction; results go to
*Ingest payment*; Gmail's forwarding-verification email is caught and its link saved; marketing and
outgoing payments are skipped.

---

## 3. Gmail

1. **Settings → Forwarding and POP/IMAP → Add a forwarding address**, and paste the company address.
2. Gmail emails a confirmation link to that address. It travels through the pipeline and appears as
   a **Confirm Gmail forwarding** button in the dashboard's Rent inbox setup panel. That button
   appearing means the whole chain works.
3. Create a filter so only payment alerts are forwarded:

   ```
   from:(no.reply.alerts@chase.com OR venmo@venmo.com) subject:("received money" OR "paid you")
   ```

   Choose **Forward it to** the company address.

---

## 4. Bank alerts

Most banks send no alert for incoming Zelle payments by default, or only above a threshold. Turn on
an alert for every payment received, or nothing arrives.

---

## How matching works

Each payment is scored against every lease on:

- **Payer name** — a remembered alias scores highest, then an exact tenant-name match, then a
  partial match. Confirming a payment stores the alias, so the same payer matches automatically
  next time.
- **Amount** — equal to the rent, equal to the outstanding balance, a whole number of months, or a
  partial payment.
- **Memo** — mentions of rent or the property name.

A payment with no name link and an amount that fits no lease is marked `ignored`, which keeps
unrelated payments (a salon or personal Venmo on the same bank account) out of the queue. Ignored
rows keep no payer name and no email body.

On confirmation the amount is applied to unpaid months oldest-first, so a payment covering arrears
splits across them. Anything left over is recorded as a prepayment.

---

## Safety

- **Sender checks.** Chase and Venmo alerts are verified against the email's authentication results.
  Anything that fails is still queued but labelled "Unverified sender". Payments read by the AI
  fallback always carry that label.
- **Duplicates.** The original message ID is stored per company, so re-forwarding an email changes
  nothing.
- **Never automatic.** Version 1 only queues payments; a landlord confirms every one.
- **Scope.** Only mail matching the Gmail filter is forwarded; the rest of the inbox is never seen.

---

## Troubleshooting

| Symptom | Where to look |
|---|---|
| Nothing arrives | n8n **Executions** — did the webhook fire? Then Postmark's inbound activity log. |
| Webhook fires, nothing queued | The ingest call's response: `unknown_inbox` means the token didn't match; `ignored` means the payment didn't look like rent. |
| Payment lands on the wrong property | Change the property in the confirm card. The corrected payer alias is remembered. |
| Gmail verification button never appears | Check `companies.payment_inbox_verify_url`. Empty means Gmail's email never reached the workflow. |
