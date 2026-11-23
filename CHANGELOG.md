# Changelog

All notable changes to this specification are listed here.
The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning 2.0.0](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-11-22

### Added

- Scope, conformance classes, legal status, owners of the parts and conformance FEE-001 to FEE-006: any fee that a public body charges under a law; the classes `engine`, `adapter`, `profile` and `operator`; no claim that a fee meets a law or that a deployment meets PCI DSS; each part taken from the specification that owns it; pinned versions; suites that check output only.
- Jurisdiction profiles FEE-010 to FEE-014: profile files with sources marked read or to be verified, where an archived copy counts as read only when it holds the text in force; dated values and profile versions; no law in the core, with flags that only select rules; the result `not-applicable` and no order when a value is missing; core defaults of a full redirect, receipts sealed at `seal-log` or higher, rounding to the cent and five refund reasons. Profiles `core`, `ca-federal` (Service Fees Act, Financial Administration Act and its regulations, Low-materiality Fees Regulations, Schedule V of the Excise Tax Act, and the monthly interest rates from the Bank Rate) and `ca-qc` (chapter VIII.1 of the Loi sur l'administration financière, the rounding regulation, and the cap law with a flag for the fees of its Schedule I) in `profiles/`.
- Schedules and quotes FEE-020 to FEE-030: fee schedules that extend the dated parameter set of DEC-037, with fee items, bases, tax treatments and exemptions; money under DAT-050 to DAT-055; indexed amounts as published dated values, never computed at run time, each with its indexation step and an accumulated rate that follows the previous step; rounding rules with their method, steps, scope and stage, where quotes and taxes round to the cent unless a cited law says otherwise; the quote as a decision whose record holds the total and whose `FeeQuote` holds the lines; exemptions as facts of the decision, self-declarations kept as declarations, waivers referred to a person; tax treatment on each line; quote validity, and penalties and interest as their own decisions, with interest rates as dated values of the profile.
- Orders and payments FEE-040 to FEE-053: fee orders with their payer, reference and amount due; attempts that ask the amount due, one unfinished at a time, and a second success refunded in full as a duplicate payment; the eight statuses of GOV.UK Pay with `finished`; one-way transitions with failure codes and a status history; settlement apart from status; order status, with `refunded` and `reversed`, and its mapping to REG-024; no card data kept, logged or passed on, a card shown only by brand and four digits; a full redirect by default; an embedded form only with an `EmbeddedFormRecord` of how the page meets the SAQ A script criterion; no status change on the return of the payer; idempotent creation under API-060 to API-063; the raw status of the provider and a published mapping; adapters that drop every card field, the cardholder name, the first digits and the billing address; and a cancellation and a read of an unfinished attempt before a new one.
- Refunds, remissions and disputes FEE-060 to FEE-069: refunds against a successful attempt with three statuses, a transition table and a status history, and a new refund after a provider reverses one; a cap at the refundable balance, less lost disputes, with an echo of that balance checked atomically; refund reasons from the profile, with the deduction for services rendered where the law sets one; refunds by another method; remissions as decisions with their legal basis, carried out by refund or, with no unfinished attempt, by a reduction of the amount due, and held while a dispute is open; no refund that implies a remission; one decision record per payer and order; disputes with four statuses, a transition table and a status history; no refund while a dispute is open; lost disputes and dispute fees as payout lines with set amounts.
- Provider notifications and events FEE-070 to FEE-076: signature checks over the raw body in constant time; a read at the provider before any change; quick answers, a stored parsed record instead of the raw body, and duplicates; scheduled reads of unfinished attempts; provider keys as secrets; five CloudEvents types with schemas in `registry/events/`; no party id, payment reference, amount or card data in an event.
- Receipts FEE-080 to FEE-085: a receipt for each paid order and after each refund or remission; its content; seals under the signed records specification; codes rather than rendered text; a receipt for an order with no payment due; tax registration numbers as a recommendation.
- Reconciliation FEE-090 to FEE-095: payouts whose totals add up their lines; each line matched to one attempt, refund or dispute; matching keys; exact comparison; optional import of ISO 20022 statements; export of matched entries only.
- Interfaces, adapters and conformance FEE-100 to FEE-105: idempotent creation and cancellation as a resource; the adapter contract; fixtures and scenarios; synthetic data with no card number at all; an optional GovStack Payments adapter; replacement of an engine or an adapter.
- Informative pages on the alignment with GOV.UK Pay, GovStack Payments, ISO 20022, Stripe, Moneris and PayFiP, and on questions for counsel.
- The LinkML model `model/fees.yaml`, which imports the data types and decisions models.
- Synthetic examples in `examples/`: three fee schedules, among them the pleasure craft license fee of $24 with its exemption, a federal schedule with tiered, banded and percentage fees, and a Québec schedule indexed for 2026 with rounding and a deferral; five decision records; an exempt order with its receipt; an order with a failed and a successful attempt, six notifications, a partial refund, a remission paid by refund, three receipts and a payout; a Québec order paid through an embedded form and then by a duplicate bank transfer that the engine refunds; four events. A check, its test of 106 broken copies and 2 accepted copies, and scenarios in English and French run in the `examples` job of the continuous integration.
- Comparison data with international rows and rows for Canada, Québec and France.
- How-to guide that puts a fee under the specification.

### Known gaps

- The Treasury Board directive on charging, the text of the SAQ A of January 2025 and of FAQ 1588 and 1331, and the official ISO 20022 code sets were not read at the source.
- The full text of SOR/2025-272, the current text of the Québec cap law and its Schedule I, the refund statuses of Stripe and the tax rules on invoices are to be verified.
- The `ca-federal` profile publishes the interest rate up to October 2026; the next release adds the months that follow.
- The quote keeps its lines apart from the decision record, since the decisions specification keeps its record class closed. A later release of the decisions specification may give the record a slot for them.
- No profile sets a Québec sales tax treatment, a Québec remission or a French rule.
- The generated forms of the model under DMO-014 and DMO-015, and the `model/examples/` folder of DMO-017, are deferred to the conformance suite.

[Unreleased]: https://github.com/fpsot-org/fpsot-spec-fees/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fpsot-org/fpsot-spec-fees/releases/tag/v0.1.0
