---
name: fpsot-fees
description: Fee rules for FPSOT software. Use when writing or reviewing code that quotes, collects, refunds or remits a fee that a public body charges under a law; that writes a fee schedule or a fee profile, indexes or rounds an amount, takes card or bank payments through a provider, handles provider notifications or webhooks, issues receipts, reconciles payouts, or emits fee events.
---

# FPSOT fees

Summary of the FPSOT fees specification. It adds no rules of its own.
The spec text in `spec/` wins on any difference. Each line cites its requirement ID.
The model is `model/fees.yaml`; profiles are in `profiles/`, event schemas in `registry/events/`; `examples/check-examples.py` checks the schedules, decision records, fee records and events in `examples/`.

Each line keeps the strength of its rule: "must" and "must not" are MUST and MUST NOT, "should" and "should not" are SHOULD and SHOULD NOT, "may" is MAY.

Other specs own money and rounding statements (DAT), decision records, rule versions and dated parameters (DEC), the payment status of a filing (REG), the party (DMO), authorization (IAM), code lists (VOC), seals and the log (LOG), audit and business events (OBS), idempotency and events (API), secrets (SEC), scenarios and synthetic data (TST). Cite them; never redefine them (FEE-004).

## Scope, roles and legal status

- Applies to software that quotes, collects, refunds or remits a fee under a law; card processing, provider choice, ledgers and debt collection are out of scope (FEE-001).
- State your conformance classes: `engine`, `adapter`, `profile`, `operator` (FEE-002).
- Never claim that a fee, a refund or a remission meets a law, or that a deployment meets PCI DSS (FEE-003).
- Follow the pinned versions (FEE-005); suites check output only, under TST-044 (FEE-006).

## Profiles

- Name the profiles whose law applies; each is a `FeeProfile` file in `profiles/` with sources marked `read` or `to-be-verified`; an archived copy counts as read only when it holds the text in force (FEE-010).
- Every rule and value cites a source of its profile and carries its dates; profiles have their own SemVer, and removing or relaxing a value is a major release (FEE-011).
- Take every rate, threshold, deadline, rounding rule, refund reason and tax treatment from a profile or a schedule, never from code; a flag only selects rules (FEE-012).
- When a needed value is missing for the effective date, return `not-applicable` with a reason code naming it, create no order, assume nothing (FEE-013).
- `core` defaults: full redirect for cards, receipts sealed at `seal-log` or higher, rounding to the cent half up, five refund reasons that a profile may replace by code (FEE-014).

## Schedules and quotes

- A fee schedule is a `FeeSchedule`, which extends the DEC-037 `ParameterSet`; it names its profile; each fee item has a code, a bilingual name, a basis, an amount parameter (or bands that name theirs), a legal source and a tax treatment; a changed schedule takes a new version (FEE-020).
- Amounts are DAT money with the minor-unit decimals; rates are decimal strings in percent; no binary floating point (FEE-021).
- The basis is `flat`, `per-unit`, `tiered`, `banded` or `percentage`; non-flat items name a unit; tiered and banded items list their bands, each with its parameter; a percentage line gives its rate and base value (FEE-022).
- An indexed amount is a published dated value, one per parameter per date; never compute it at run time (FEE-023).
- Each indexed value comes with an `IndexationStep`: rule, published rate and where it appeared, rate after caps, previous amount, raw result, deferral, result, and the accumulated rate when the rule defers or carries forward, equal to the applied rate plus the rate a deferred previous step carried (FEE-024).
- Each schedule names the rounding rule of its quotes and taxes, to the cent unless a cited law says otherwise, and its stage (`per-line` or `per-total`); each rule states its method, steps per band, halfway direction and whether it rounds quotes or indexed values; indexed values round under their indexation rule, or `core` (FEE-025).
- A quote is a DEC decision with one decision record that lists the schedule and its digest; its amount is the total; never price a fee outside a decision record (FEE-026).
- The lines go in a `FeeQuote` that names the record: fee item, quantity, legal source, unit amount in force and its start date, gross, exemption, amount, taxes; the total equals the lines and the record amount; a quote never changes (FEE-027).
- An exemption is one that the fee item grants, triggered by an input fact of the record; a payer's declaration stays `applicant-declaration`, never a verified status; a discretionary waiver goes to `referred` and a person (FEE-028).
- Each line states each tax of its profile: `taxable` with rate and amount, `exempt`, `zero-rated` or `outside-scope`, with its source; a tax that is not taxable is zero; taxes round under the rule of the schedule (FEE-029).
- A quote states the last instant an order may use it; after that, a new quote and decision; penalties and interest are lines of their own decision; each rate they apply, such as an interest rate, is a dated value of the profile, never computed at run time (FEE-030).

## Orders and payments

- A `FeeOrder` names its quotes, its payer and a payment reference with no personal information; the amount due is the quote totals less reductions; one currency; a zero order takes no attempt (FEE-040).
- A `PaymentAttempt` names its order and asks the amount due at its creation; never two unfinished attempts at once; should have at most one `success`, and must refund the whole of any second one as `duplicate-payment` (FEE-041).
- Statuses: `created`, `started`, `submitted`, `capturable` (not finished), `success`, `failed`, `cancelled`, `error` (finished); `finished` matches the table (FEE-042).
- Statuses move forward only; a finished status never changes; an earlier status in a read moves nothing back; failures carry a failure code; keep each status with its instant and source in the history (FEE-043).
- Keep settlement apart from status; settle only after `success`; `success` does not prove the funds arrived (FEE-044).
- Order status follows from amount, attempts, refunds and disputes: `no-payment-due`, `paid`, `refunded`, `reversed`, `awaiting-payment`, `canceled`; map it onto the pack list of REG-024, never `refunded` or `reversed` onto paid (FEE-045).
- Never keep, log or pass on card number, security code, expiry, track data or PIN, in any interface, record, log, event or receipt; a card shows only as brand and last four; methods are categories (FEE-046).
- Card payments use a full redirect to the provider's page by default (FEE-047).
- An embedded provider form needs a prior `EmbeddedFormRecord` of how the page meets the SAQ A script criterion: provider, method, checker, date, the acquirer or brand that accepted it, the text it rests on and its validity; each such attempt names the record that covered it (FEE-048).
- The payer's return from the provider never changes a status; read the payment at the provider (FEE-049).
- Create orders, attempts and refunds with an `Idempotency-Key` under API-060 to API-063; send a key of your own for each attempt and refund to the provider; never reuse one (FEE-050).
- Keep the provider's payment id and raw status; each adapter publishes its status mapping; on Stripe an attempt is a charge, never the payment intent (FEE-051).
- The adapter drops every card field from reads and notifications, plus cardholder name, first digits and billing address, before anything is stored, logged or passed on; brand and last four may stay (FEE-052).
- Before a new attempt, cancel each unfinished attempt at the provider, read it again, and create the new one only once the old one is finished; an uncancellable pending transfer blocks until it finishes (FEE-053).

## Refunds, remissions and disputes

- A `Refund` names its order and a successful attempt; statuses `submitted`, `success`, `error`, moving only by the table, with a status history; `submitted` is not an outcome; a refund the provider reverses after `success` stays `success`, stays a reconciliation exception, and a new refund names it (FEE-060).
- Refunds never exceed the refundable balance: attempt amount less non-error refunds less lost disputes; each request states the balance it saw in `refundableBefore`, a different balance is refused, and the check and the creation are one atomic step per attempt (FEE-061).
- Each refund gives a reason of the profile or core, with the services-rendered deduction where the reason asks for it; `purpose-not-fulfilled` for a service not provided (FEE-062).
- Refunds should go back by the method of payment; another method names itself and why (FEE-063).
- A remission rests on its own DEC decision record with outcome `remitted`, the amount and its legal basis; a `Remission` names it and its order; paid fees remit by refunds that add up, unpaid fees by reducing the amount due, and only while no attempt is unfinished; with a dispute open, record the remission with it, hold its refunds until it closes, and leave out what a lost dispute returned (FEE-064).
- A refund never implies a remission: only a refund with reason `remission` names one, and it must; remission reports count remission records only (FEE-065).
- Bulk remission makes one decision record per payer and order (FEE-066).
- A `Dispute` names its attempt; statuses `needs-response`, `under-review`, `won`, `lost`, moving only by the table, with a status history; `needs-response` gives the evidence due date (FEE-067).
- No refund on an attempt while a dispute on it is open (FEE-068).
- A lost dispute shows as a `dispute-reversal` line of minus its amount; a dispute fee, whatever the status, as a `dispute-fee` line of minus the fee; never as a refund (FEE-069).

## Notifications and events

- Verify each notification's signature over the raw body in constant time, within the provider's time window; an unverified one changes nothing and is recorded as `rejected` (FEE-070).
- After verifying, read the named object at the provider and set status only from that read; record the read and its outcome (FEE-071).
- Answer `2xx` once stored, before acting; store the parsed record, not the raw body, and keep a body only once redacted; a repeated event id is `duplicate` and changes nothing (FEE-072).
- Should poll unfinished attempts at an interval the operator sets (FEE-073).
- Provider keys are secrets under SEC-020 to SEC-024; the endpoint meets API-080 and has no secret in its address (FEE-074).
- Emit OBS-070 business events and CloudEvents `org.fpsot.fees.payment-attempt.changed`, `refund.changed`, `dispute.changed`, `receipt.issued` and `payout.reconciled`, with schemas in `registry/events/` (FEE-075).
- Events hold none of: a party id, a payment reference, an amount, card data; consumers read the record under IAM-050 (FEE-076).

## Receipts

- Issue a `Receipt` when an order is paid, and a new one after each successful refund and each remission, naming the one it follows (FEE-080).
- A receipt holds the order, payee, payer id, reference, quote lines with decision records and rule versions, taxes, payments, refunds, remissions and totals (FEE-081).
- Seal each receipt under LOG-010, with its id as the seal manifest id, at `seal-log` or higher; never change it; correct by a new receipt (FEE-082).
- Receipts hold codes and values, not rendered text; views show labels in the reader's language; no card beyond brand and four digits (FEE-083).
- Should issue a `no-payment-due` receipt for a zero order, showing each exemption and its source (FEE-084).
- A taxed line should show the payee's registration number for that tax; the source of that duty is to be verified (FEE-085).

## Reconciliation

- A `Payout` has lines whose amounts add up to gross and whose fees add up to fees; net is gross less fees; outflows are negative (FEE-090).
- Match each payout line to one attempt, refund or dispute by kind, provider id and amount; unmatched lines stay `unmatched` and the payout is `exceptions`; `reconciled` only when all match; settled attempts name their payout; dispute lines carry the amounts of FEE-069 (FEE-091).
- Keep provider ids and payment references, and for bank transfers the end-to-end id and structured reference; never reuse one (FEE-092).
- Compare amounts exactly in minor units; never write a difference off as rounding (FEE-093).
- May import bank statements; for ISO 20022, should read camt.053 and camt.054 (FEE-094).
- May export matched entries to the ledger, and only matched ones (FEE-095).

## Interfaces and conformance

- Create with `POST` and `Idempotency-Key`; no operation edits or deletes attempts, refunds, remissions or receipts; cancel by creating a cancellation; authorize every request; test against the description under TST-040 (FEE-100).
- Each adapter offers create, read, capture, cancel, drop card fields, refund, read refunds, read disputes, read payouts and verify notifications, or states what its provider lacks, and publishes its mapping (FEE-101).
- Suites hold schedules, decision records, fee records and payouts, and EN/FR scenarios with dates, fee items and statuses; test events under TST-043 (FEE-102).
- Synthetic data only, no card number at all, not even a published test number; fictional provider and bank references (FEE-103).
- May offer a GovStack Payments adapter mapped requirement by requirement (FEE-104).
- A replacement engine or adapter passes the same suite under TST-045 (FEE-105).
