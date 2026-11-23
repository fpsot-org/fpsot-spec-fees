# Instructions for agents

This repository holds the FPSOT fees specification: what software must record and prove about each fee that a public body charges under a law. It covers the fee schedule as dated parameters with indexation steps and rounding; the quote as a decision of the decisions specification, with its lines and exemptions; the fee order and its payment attempts, with eight statuses that move one way only after a read at the provider; refunds, remissions and disputes as separate records, where only a decision makes a remission; provider notifications and outbound events; sealed receipts; and the reconciliation of each payout line. Card data never enters the software.

- The normative text is in `spec/en/` and `spec/fr/`. Every rule has an ID such as `FEE-001`.
- Follow `skill/SKILL.md` when you write or review code that quotes, collects, refunds or remits a fee, handles payment provider notifications, issues receipts, reconciles payouts, or writes a fee schedule or a fee profile. The spec text wins on any difference.
- Every page exists in English and in French, with the same file name and the same IDs.
- Terms and abbreviations come from the term base of `fpsot-spec-writing`. Add a missing term there first; `TERMS-NEEDED.md` lists the ones this spec waits for.
- This is a layer 2 specification. It may cite every published layer 0 and layer 1 specification, and the registry specification, by rule ID. It cites the capability specification only by topic.
- Other specifications own money and rounding statements (data types), decision records, rule versions and dated parameters (decisions), the payment status of a filing (registry), the party (data models), authorization (identity), code lists (vocabularies), seals and the transparency log (log), audit and business events (observability), idempotency and events (api-restful), secrets (security) and scenarios (testing). Cite their rules; never redefine them.
- Card data stays at the provider: no card number, security code, expiry date or track data in any file, log, event, fixture or test, not even a test card number. A card shows only as a brand and four digits.
- `model/fees.yaml` is the source of the record forms. `model/imports/` holds unchanged copies of the data types and decisions models. When you change the model, a profile, a schedule or a fixture, run `bash examples/test-examples.sh`.
- Jurisdiction values live in `profiles/` and in fee schedules, never in the model or the check script. An indexed amount is a published dated value with its indexation step, never a value computed at run time.
- Examples hold synthetic data only: fictional people, bodies, providers and regulations, references starting with `EX`, domains reserved for documentation.
- Do not copy text from statutes, regulations or standards. Summarize in your own words and cite the exact version, with an archived copy.
- Do not state a legal point as a rule. Points that need a lawyer go in an informative note or in `questions-for-counsel.adoc`, and a text that nobody read at the source is marked "to be verified". France has comparison data only, no profile.
- Commits follow Conventional Commits and are signed. Pull requests are squash-merged.
