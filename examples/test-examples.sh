#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Tests examples/check-examples.py: the repository passes, and each broken copy fails
# for the reason that its case names. Each case copies the files that the check reads,
# breaks one rule, and expects the check to report that rule.
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
check="$here/examples/check-examples.py"
fail=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if ! python3 -I "$check" "$here"; then
  echo "FAIL: the repository itself does not pass"; fail=1
fi

# case_fails NAME EXPECTED-REGEX PYTHON: the script runs in a copy of the repository.
case_fails() {
  local name=$1 want=$2 script=$3 dir="$tmp/$1" out
  mkdir -p "$dir"
  cp -r "$here/model" "$here/profiles" "$here/registry" "$here/examples" "$dir/"
  (cd "$dir" && python3 -I -c "import json, yaml
def rj(p): return json.load(open(p, encoding='utf-8'))
def wj(p, d): json.dump(d, open(p, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
def ry(p): return yaml.safe_load(open(p, encoding='utf-8'))
def wy(p, d): yaml.safe_dump(d, open(p, 'w', encoding='utf-8'), allow_unicode=True, sort_keys=False)
def m(a): return {'amount': a, 'currency': 'CAD'}
PC, PM = 'examples/pleasure-craft/fees.json', 'examples/permit/fees.json'
PS, FS, QS = 'examples/schedules/pleasure-craft-license-fees.yaml', 'examples/schedules/example-federal-permit-fees.yaml', 'examples/schedules/example-quebec-permit-fees.yaml'
RP, RQ, RR = 'examples/decisions/pleasure-craft-quote.json', 'examples/decisions/permit-quote.json', 'examples/decisions/permit-remission.json'
CO, CF, QC = 'profiles/core.yaml', 'profiles/ca-federal.yaml', 'profiles/ca-qc.yaml'
E1, E2 = 'examples/permit/events/payment-attempt-changed.json', 'examples/permit/events/refund-changed.json'
FEN, FFR = 'examples/features/en/fees.feature', 'examples/features/fr/fees.feature'
$script") || { echo "FAIL: case $name: the setup script failed"; fail=1; return; }
  if out=$(python3 -I "$check" "$dir" 2>&1); then
    echo "FAIL: case $name passed but should fail"; fail=1
  elif ! grep -qE -- "$want" <<<"$out"; then
    echo "FAIL: case $name failed for another reason:"; echo "$out" | head -5; fail=1
  else
    echo "ok: case $name fails"
  fi
}

# Money (DAT-050 to DAT-055) and the model (FEE-004).
case_fails amount-as-number 'must be a decimal string, never a JSON number \(DAT-052\)' \
  'd = rj(PM); d["quotes"][0]["total"]["amount"] = 390; wj(PM, d)'
case_fails amount-three-decimals 'must have 2 decimals for CAD \(DAT-053\)' \
  'd = rj(PM); d["quotes"][0]["total"]["amount"] = "390.000"; wj(PM, d)'
case_fails model-redefines-money 'Money is defined twice, in this schema and in an import \(FEE-004\)' \
  'd = ry("model/fees.yaml"); d["classes"]["Money"] = {"description": "A local amount."}; wy("model/fees.yaml", d)'

# Card data (FEE-046 to FEE-048).
case_fails card-number-in-record 'looks like a card number \(FEE-046\)' \
  'd = rj(PM); d["notifications"][0]["providerObjectId"] = "4111111111111111"; wj(PM, d)'
case_fails expiry-on-receipt 'is a card data field: no card data may enter the software \(FEE-046\)' \
  'd = rj(PM); d["receipts"][0]["payments"][0]["cardDisplay"]["expiry"] = "12/29"; wj(PM, d)'
case_fails cvv-in-event 'is a card data field: no card data may enter the software \(FEE-046\)' \
  'd = rj(E1); d["data"]["cvv"] = "123"; wj(E1, d)'
case_fails embedded-form-without-record 'without the record of how the operator meets the SAQ A script criterion \(FEE-048\)' \
  'd = rj(PM); d["attempts"][1]["integration"] = "embedded-hosted-form"; wj(PM, d)'
case_fails core-default-not-redirect 'the default card integration must be the full redirect hosted-redirect \(FEE-047\)' \
  'd = ry(CO); d["defaults"]["cardIntegration"] = "embedded-hosted-form"; wy(CO, d)'

# Attempts and notifications (FEE-041 to FEE-045, FEE-070 to FEE-072).
case_fails status-from-client-redirect 'has .client-redirect., which is not a value of StatusSource' \
  'd = rj(PM); d["attempts"][1]["statusHistory"][3]["source"] = "client-redirect"; wj(PM, d)'
case_fails status-from-unverified-notification 'must be verified, applied and followed by a read .* \(FEE-070, FEE-071\)' \
  'd = rj(PM); d["notifications"][2]["signatureVerified"] = False; wj(PM, d)'
case_fails finished-status-left 'leaves the finished status success for submitted: statuses move one way \(FEE-043\)' \
  'd = rj(PM); a = d["attempts"][1]; a["statusHistory"].append({"status": "submitted", "at": "2026-03-02T14:07:16Z", "source": "provider-read"}); a["status"] = "submitted"; a["finished"] = False; wj(PM, d)'
case_fails finished-flag-wrong 'finished must be True for the status failed \(FEE-042\)' \
  'd = rj(PM); d["attempts"][0]["finished"] = False; wj(PM, d)'
case_fails rejected-notification-read 'is rejected, and the engine reads nothing \(FEE-070\)' \
  'd = rj(PM); d["notifications"][5]["readAt"] = "2026-03-02T14:08:01Z"; wj(PM, d)'
case_fails duplicate-not-marked 'repeats event evt-000105: its outcome is duplicate \(FEE-072\)' \
  'd = rj(PM); d["notifications"][3]["outcome"] = "no-change"; d["notifications"][3]["readAt"] = "2026-03-02T14:06:51Z"; wj(PM, d)'
case_fails two-successes 'has 2 successful attempts: one order is paid once \(FEE-041\)' \
  'd = rj(PM); a = d["attempts"][0]; a["status"] = "success"; del a["failureCode"]; a["statusHistory"][2]["status"] = "success"; wj(PM, d)'
case_fails overlapping-attempts 'starts while attempt .* is not finished \(FEE-041\)' \
  'd = rj(PM); d["attempts"][1]["statusHistory"][0]["at"] = "2026-03-02T14:02:00Z"; wj(PM, d)'
case_fails settled-without-payout 'only a success settles, with the date and the payout \(FEE-044\)' \
  'd = rj(PM); del d["attempts"][1]["settlement"]["payoutId"]; wj(PM, d)'
case_fails order-status-wrong 'the status must be paid, from its amount and attempts \(FEE-045\)' \
  'd = rj(PM); d["orders"][0]["status"] = "awaiting-payment"; wj(PM, d)'

# Schedules, indexation and quotes (FEE-020 to FEE-030).
case_fails schedule-changed-same-version 'does not match: a changed schedule needs a new version \(DEC-037, FEE-020\)' \
  'd = ry(FS); d["parameters"][0]["values"][0]["value"]["amount"] = "355.00"; wy(FS, d)'
case_fails two-values-one-date 'has two values on 2026-03-01: publish one value per date \(FEE-023\)' \
  'd = ry(PS); v = dict(d["parameters"][0]["values"][0]); v["validity"] = {"start": "2026-03-01"}; d["parameters"][0]["values"].append(v); wy(PS, d)'
case_fails indexed-value-not-rounded 'publishes 88.78, but the rounding rule gives 88.75 \(FEE-025\)' \
  'd = ry(QS); d["indexationSteps"][0]["result"]["amount"] = "88.78"; d["parameters"][0]["values"][1]["value"]["amount"] = "88.78"; wy(QS, d)'
case_fails cap-ignored 'applies 5.08, but the rule and its caps give 3 \(FEE-024\)' \
  'd = ry(QC); d["parameters"][1]["value"] = "5.08"; wy(QC, d)
s = ry(QS); s["indexationSteps"][0]["publishedRate"] = "5.08"; s["indexationSteps"][0]["appliedRate"] = "5.08"; wy(QS, s)'
case_fails rate-not-published 'uses the rate 2.10, but the profile publishes 2.05 \(FEE-024\)' \
  'd = ry(QS); d["indexationSteps"][0]["publishedRate"] = "2.10"; wy(QS, d)'
case_fails deferral-ignored 'must be deferred: True \(FEE-024\)' \
  'd = ry(QS); d["indexationSteps"][2]["deferred"] = False; wy(QS, d)'
case_fails value-without-step 'from 2026-01-01 has no indexation step \(FEE-024\)' \
  'd = ry(QS); d["indexationSteps"].pop(0); wy(QS, d)'
case_fails quote-not-from-schedule 'must take the value in force on 2026-03-02, 350.00 from 2025-04-01 \(FEE-027, DEC-037\)' \
  'd = rj(PM); d["quotes"][0]["lines"][0]["unitAmount"]["amount"] = "360.00"; wj(PM, d)'
case_fails quote-total-not-record 'the total must equal the amount of the decision record \(FEE-026, FEE-027\)' \
  'd = rj(RQ); d["amount"]["amount"] = "380.00"; wj(RQ, d)'
case_fails exemption-without-fact 'holds no fact declares-section-35-right \(FEE-028\)' \
  'd = rj(RP); d["inputs"][1]["value"] = False; wj(RP, d)'
case_fails tax-treatment-unknown 'names tax treatment gst-taxable, which the profile does not define \(FEE-029\)' \
  'd = ry(PS); d["feeItems"][0]["taxTreatment"] = "gst-taxable"; wy(PS, d)'

# Profiles (FEE-010 to FEE-014).
case_fails source-not-listed 'cites source tbs-guide, which the profile does not list \(FEE-011\)' \
  'd = ry(CF); d["remissionRules"][0]["sourceIds"].append("tbs-guide"); wy(CF, d)'
case_fails profile-without-jurisdiction 'a jurisdiction profile must name its jurisdiction \(FEE-010\)' \
  'd = ry(QC); del d["jurisdiction"]; wy(QC, d)'

# Refunds, remissions and disputes (FEE-060 to FEE-068).
case_fails refund-over-balance 'more than the refundable balance 350.00 \(FEE-061\)' \
  'd = rj(PM); d["refunds"][1]["amount"]["amount"] = "400.00"; wj(PM, d)'
case_fails stale-balance-echo 'states the refundable balance 390.00, but it is 350.00: the engine must refuse \(FEE-061\)' \
  'd = rj(PM); d["refunds"][1]["refundableBefore"]["amount"] = "390.00"; wj(PM, d)'
case_fails refund-implies-remission 'only a refund for the reason remission names a remission, and it must \(FEE-065\)' \
  'd = rj(PM); d["refunds"][0]["reason"] = "remission"; wj(PM, d)'
case_fails reason-not-in-profile 'gives the reason goodwill, which the profile does not list \(FEE-062\)' \
  'd = rj(PM); d["refunds"][0]["reason"] = "goodwill"; wj(PM, d)'
case_fails deduction-not-stated 'states the part kept for services rendered \(FEE-062\)' \
  'd = rj(PM); del d["refunds"][0]["servicesRenderedDeduction"]; wj(PM, d)'
case_fails remission-without-decision 'rests on no decision record: a remission is a decision \(FEE-064\)' \
  'd = rj(PM); d["remissions"][0]["decisionRecordId"] = "019c4e00-0009-7000-8000-000000000999"; wj(PM, d)'
case_fails remission-amount-differs 'the record must have the outcome remitted and the same amount \(FEE-064\)' \
  'd = rj(RR); d["amount"]["amount"] = "90.00"; wj(RR, d)'
case_fails refund-during-dispute 'was created while dispute .* was open \(FEE-068\)' \
  'd = rj(PM); d["disputes"] = [{"id": "019c4e00-0013-7000-8000-000000000001", "attemptId": d["attempts"][1]["id"], "providerDisputeId": "ex-dp-0001", "status": "under-review", "reason": "credit-not-processed", "amount": m("390.00"), "openedAt": "2026-03-05T12:00:00Z", "createdAt": "2026-03-05T12:00:00Z", "updatedAt": "2026-03-06T12:00:00Z"}]; wj(PM, d)'

# Receipts (FEE-080 to FEE-085).
case_fails receipt-misses-refund 'the refunds must be the successful refunds before its issue \(FEE-081\)' \
  'd = rj(PM); del d["receipts"][1]["refunds"]; wj(PM, d)'
case_fails receipt-changed 'never changes once sealed \(FEE-082\)' \
  'd = rj(PM); d["receipts"][0]["updatedAt"] = "2026-03-03T00:00:00Z"; wj(PM, d)'
case_fails exempt-order-without-receipt 'owes nothing but has no receipt that says so \(FEE-084\)' \
  'd = rj(PC); del d["receipts"]; wj(PC, d)'
case_fails receipt-unsealed 'must be sealed at seal-log or above \(FEE-082\)' \
  'd = rj(PM); d["receipts"][0]["sealProfile"] = "none"; wj(PM, d)'

# Payouts (FEE-090 to FEE-093).
case_fails payout-net-wrong 'gross, fees and net must add up the lines exactly.* \(FEE-090, FEE-093\)' \
  'd = rj(PM); d["payouts"][0]["net"]["amount"] = "345.00"; wj(PM, d)'
case_fails payout-line-amount-off 'does not match PaymentAttempt .* by kind, status, provider id and exact amount \(FEE-091, FEE-093\)' \
  'd = rj(PM); p = d["payouts"][0]; p["lines"][0]["amount"]["amount"] = "389.99"; p["gross"]["amount"] = "349.99"; p["net"]["amount"] = "344.14"; wj(PM, d)'
case_fails reconciled-with-unmatched 'the status is reconciled only when every line matched \(FEE-091\)' \
  'd = rj(PM); l = d["payouts"][0]["lines"][1]; l["matchStatus"] = "unmatched"; del l["matchedType"]; del l["matchedId"]; wj(PM, d)'

# Events (FEE-075, FEE-076).
case_fails reference-in-event 'holds a party id or a payment reference: events hold no personal value \(FEE-076\)' \
  'd = rj(E1); d["data"]["paymentReference"] = "EX-2026-000123"; wj(E1, d)'
case_fails amount-in-event 'holds an amount or card data: events hold ids, codes and instants only \(FEE-076\)' \
  'd = rj(E2); d["data"]["amount"] = m("40.00"); wj(E2, d)'

# Features (FEE-102, TST-032).
case_fails feature-parity 'same tags and steps, with the same quoted values \(TST-032\)' \
  's = open(FFR, encoding="utf-8").read().replace("@fees-002", "@fees-012"); open(FFR, "w", encoding="utf-8").write(s)'
case_fails feature-unknown-item 'names fee item permit-fees, which no schedule holds \(FEE-102\)' \
  's = open(FEN, encoding="utf-8").read().replace("fee item \"permit-fee\"", "fee item \"permit-fees\""); open(FEN, "w", encoding="utf-8").write(s)'

[ $fail -eq 0 ] && echo "PASS: every case"
exit $fail
