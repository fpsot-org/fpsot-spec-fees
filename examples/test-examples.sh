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

# setup_case NAME PYTHON: the script runs in a copy of the repository.
setup_case() {
  local name=$1 script=$2 dir="$tmp/$1"
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
QM, RI, RQQ = 'examples/quebec-permit/fees.json', 'examples/decisions/permit-inspection-quote.json', 'examples/decisions/quebec-permit-quote.json'
A1, A2 = '019c4e00-0003-7000-8000-000000000001', '019c4e00-0003-7000-8000-000000000002'
def dispute(attempt, status, opened, closed=None, amount='390.00', fee=None, n='1'):
    h = [{'status': 'needs-response', 'at': opened, 'source': 'provider-read'}]
    if status != 'needs-response':
        h.append({'status': status, 'at': closed or opened, 'source': 'provider-read'})
    x = {'id': '019c4e00-0013-7000-8000-00000000000' + n, 'attemptId': attempt, 'providerDisputeId': 'ex-dp-000' + n, 'status': status,
         'statusHistory': h, 'reason': 'fraudulent', 'amount': m(amount), 'openedAt': opened, 'createdAt': opened, 'updatedAt': closed or opened}
    if status == 'needs-response':
        x['evidenceDueDate'] = opened[:10]
    if closed:
        x['closedAt'] = closed
    if fee:
        x['providerFee'] = m(fee)
    return x
def sync():
    import glob, hashlib
    dg = {}
    for p in glob.glob('examples/schedules/*.yaml'):
        y = ry(p); dg[(y['code'], y['version'])] = hashlib.sha256(open(p, 'rb').read()).hexdigest()
    def fx(n):
        if isinstance(n, dict):
            if set(n) == {'code', 'version', 'digest'} and (n['code'], n['version']) in dg:
                n['digest'] = dg[(n['code'], n['version'])]
            for v in n.values(): fx(v)
        elif isinstance(n, list):
            for v in n: fx(v)
    for p in glob.glob('examples/decisions/*.json') + glob.glob('examples/*/fees.json'):
        d = rj(p); fx(d); wj(p, d)
$script") || { echo "FAIL: case $name: the setup script failed"; fail=1; return 1; }
}

# case_fails NAME EXPECTED-REGEX PYTHON: the broken copy fails for the rule that the regex names.
case_fails() {
  local name=$1 want=$2 out
  setup_case "$name" "$3" || return
  if out=$(python3 -I "$check" "$tmp/$name" 2>&1); then
    echo "FAIL: case $name passed but should fail"; fail=1
  elif ! grep -qE -- "$want" <<<"$out"; then
    echo "FAIL: case $name failed for another reason:"; echo "$out" | head -5; fail=1
  else
    echo "ok: case $name fails"
  fi
}

# case_passes NAME PYTHON: the changed copy still passes, which shows that the check accepts it.
case_passes() {
  local name=$1 out
  setup_case "$name" "$2" || return
  if out=$(python3 -I "$check" "$tmp/$name" 2>&1); then
    echo "ok: case $name passes"
  else
    echo "FAIL: case $name should pass:"; echo "$out" | head -5; fail=1
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
case_fails two-successes 'is a second success, and it needs a duplicate-payment refund of its whole amount \(FEE-041\)' \
  'd = rj(PM); a = d["attempts"][0]; a["status"] = "success"; del a["failureCode"]; a["statusHistory"][2]["status"] = "success"; wj(PM, d)'
case_fails overlapping-attempts 'starts while attempt .* is not finished \(FEE-041, FEE-053\)' \
  'd = rj(PM); d["attempts"][1]["statusHistory"][0]["at"] = "2026-03-02T14:02:00Z"; wj(PM, d)'
case_fails settled-without-payout 'only a success settles, with the date and the payout \(FEE-044\)' \
  'd = rj(PM); del d["attempts"][1]["settlement"]["payoutId"]; wj(PM, d)'
case_fails order-status-wrong 'the status must be paid, from its amount, attempts, refunds and disputes \(FEE-045\)' \
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
  'd = rj(PM); d["disputes"] = [{"id": "019c4e00-0013-7000-8000-000000000001", "attemptId": d["attempts"][1]["id"], "providerDisputeId": "ex-dp-0001", "status": "under-review", "reason": "credit-not-processed", "amount": m("390.00"), "openedAt": "2026-03-05T12:00:00Z", "statusHistory": [{"status": "needs-response", "at": "2026-03-05T12:00:00Z", "source": "provider-read"}, {"status": "under-review", "at": "2026-03-06T12:00:00Z", "source": "provider-read"}], "createdAt": "2026-03-05T12:00:00Z", "updatedAt": "2026-03-06T12:00:00Z"}]; wj(PM, d)'

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

# Card fields that the adapter drops, and the stored notification (FEE-046, FEE-052, FEE-072).
case_fails cardholder-name-in-notification 'is a card field that the adapter drops before anything is stored \(FEE-052\)' \
  'd = rj(PM); d["notifications"][0]["redactedBody"] = json.dumps({"card_details": {"card_brand": "visa", "cardholder_name": "EX PAYER"}}); wj(PM, d)'
case_fails expiry-in-stored-body 'is a card data field: no card data may enter the software \(FEE-046\)' \
  'd = rj(PM); d["notifications"][2]["redactedBody"] = json.dumps({"card_details": {"expiry_date": "12/29"}}); wj(PM, d)'
case_fails first-digits-on-attempt 'is a card field that the adapter drops before anything is stored \(FEE-052\)' \
  'd = rj(PM); d["attempts"][1]["cardDisplay"]["firstDigits"] = "400000"; wj(PM, d)'
case_fails billing-address-in-record 'is a card field that the adapter drops before anything is stored \(FEE-052\)' \
  'd = rj(RQ); d["inputs"][0]["value"] = {"billing_address": {"city": "Example City"}}; wj(RQ, d)'
case_fails raw-body-not-json 'redactedBody is not a JSON body \(FEE-072\)' \
  'd = rj(PM); d["notifications"][0]["redactedBody"] = "card=visa&exp=12-29"; wj(PM, d)'

# Embedded forms (FEE-048): every field of the record, its provider and its dates.
for field in id provider method checkedByPartyId checkedOn acceptedByKind acceptedBy basis validity createdAt updatedAt; do
  case_fails "embedded-form-without-$field" "\\\$\\.embeddedFormRecords\\[0\\]\\.$field is required in EmbeddedFormRecord" \
    "d = rj(QM); del d['embeddedFormRecords'][0]['$field']; wj(QM, d)"
done
case_fails embedded-form-other-provider 'but its embedded form record names other-pay \(FEE-048\)' \
  'd = rj(QM); d["embeddedFormRecords"][0]["provider"] = "other-pay"; wj(QM, d)'
case_fails embedded-form-expired 'falls outside the validity of its embedded form record \(FEE-048\)' \
  'd = rj(QM); d["embeddedFormRecords"][0]["validity"]["end"] = "2026-02-01"; wj(QM, d)'
case_fails embedded-form-checked-late 'must be checked before it holds and before the attempt \(FEE-048\)' \
  'd = rj(QM); d["embeddedFormRecords"][0]["checkedOn"] = "2026-02-11"; wj(QM, d)'
case_fails embedded-form-method-unknown 'is not a value of EmbeddedFormMethod' \
  'd = rj(QM); d["embeddedFormRecords"][0]["method"] = "self-attestation"; wj(QM, d)'
case_fails embedded-form-acceptor-unknown 'is not a value of AcceptingEntityKind' \
  'd = rj(QM); d["embeddedFormRecords"][0]["acceptedByKind"] = "qsa"; wj(QM, d)'
case_fails embedded-form-record-on-redirect 'only an attempt with an embedded form names an embedded form record \(FEE-048\)' \
  'd = rj(PM); d["attempts"][1]["embeddedFormRecordId"] = "019c4e00-0014-7000-8000-000000000101"; wj(PM, d)'

# A second success and the attempt that comes before it (FEE-041, FEE-053).
case_fails second-success-partly-refunded 'is a second success, and it needs a duplicate-payment refund of its whole amount \(FEE-041\)' \
  'd = rj(QM); d["refunds"][0]["amount"] = m("50.00"); wj(QM, d)'
case_fails second-success-other-reason 'is a second success, and it needs a duplicate-payment refund of its whole amount \(FEE-041\)' \
  'd = rj(QM); d["refunds"][0]["reason"] = "overpayment"; wj(QM, d)'

# Refunds: the balance, the echo, the statuses and a reversal (FEE-060, FEE-061, FEE-091).
case_fails concurrent-refunds-same-echo 'states the refundable balance 390.00, but it is 350.00: the engine must refuse \(FEE-061\)' \
  'd = rj(PM); f = dict(d["refunds"][0], id="019c4e00-0005-7000-8000-000000000009", providerRefundId="ex-ref-5509", amount=m("10.00"), reason="overpayment"); del f["servicesRenderedDeduction"]; d["refunds"].append(f); wj(PM, d)'
case_fails balance-ignores-lost-dispute 'states the refundable balance 350.00, but it is 250.00: the engine must refuse \(FEE-061\)' \
  'd = rj(PM); d["disputes"] = [dispute(A2, "lost", "2026-03-20T10:00:00Z", "2026-04-01T10:00:00Z", amount="100.00")]; wj(PM, d)'
case_fails refund-moves-back 'moves from success to submitted, which the table of FEE-060 does not allow \(FEE-060\)' \
  'd = rj(PM); f = d["refunds"][0]; f["statusHistory"].append({"status": "submitted", "at": "2026-03-09T15:03:00Z", "source": "provider-read"}); f["status"] = "submitted"; wj(PM, d)'
case_fails refund-error-then-success 'moves from error to success, which the table of FEE-060 does not allow \(FEE-060\)' \
  'd = rj(PM); f = d["refunds"][0]; f["statusHistory"].insert(1, {"status": "error", "at": "2026-03-09T15:01:00Z", "source": "provider-read"}); wj(PM, d)'
case_fails refund-reversal-not-an-exception 'whose reversal must stay an exception of a payout \(FEE-060, FEE-091\)' \
  'd = rj(PM); f = dict(d["refunds"][0], id="019c4e00-0005-7000-8000-000000000009", providerRefundId="ex-ref-5509", replacesRefundId=d["refunds"][0]["id"], createdAt="2026-03-20T10:00:00Z", updatedAt="2026-03-20T10:05:00Z", refundableBefore=m("390.00")); f["statusHistory"] = [{"status": "submitted", "at": "2026-03-20T10:00:00Z", "source": "provider-response"}, {"status": "success", "at": "2026-03-20T10:05:00Z", "source": "provider-read"}]; d["refunds"].insert(1, f); wj(PM, d)'

# Disputes: the statuses, a remission held by a dispute and the order status (FEE-045, FEE-064, FEE-067, FEE-068).
case_fails dispute-won-then-reviewed 'moves from won to under-review, which the table of FEE-067 does not allow \(FEE-067\)' \
  'd = rj(PM); x = dispute(A2, "won", "2026-06-01T10:00:00Z", "2026-06-20T10:00:00Z"); x["statusHistory"].append({"status": "under-review", "at": "2026-06-21T10:00:00Z", "source": "provider-read"}); x["status"] = "under-review"; del x["closedAt"]; d["disputes"] = [x]; wj(PM, d)'
case_fails dispute-closed-at-other-time 'is closed when it reaches lost, at 2026-06-20T10:00:00Z \(FEE-067, FEE-068\)' \
  'd = rj(PM); x = dispute(A2, "lost", "2026-06-01T10:00:00Z", "2026-06-20T10:00:00Z"); x["closedAt"] = "2026-06-21T10:00:00Z"; d["disputes"] = [x]; d["orders"][0]["status"] = "reversed"; wj(PM, d)'
case_fails order-not-reversed 'the status must be reversed, from its amount, attempts, refunds and disputes \(FEE-045\)' \
  'd = rj(PM); d["disputes"] = [dispute(A2, "lost", "2026-06-01T10:00:00Z", "2026-06-20T10:00:00Z")]; wj(PM, d)'
case_fails order-not-refunded 'the status must be refunded, from its amount, attempts, refunds and disputes \(FEE-045\)' \
  'd = rj(QM); f = dict(d["refunds"][0], id="019c4e00-0005-7000-8000-000000000109", attemptId="019c4e00-0003-7000-8000-000000000101", providerRefundId="ex-pay-rf-9c1b01", reason="overpayment", createdAt="2026-02-14T10:00:00Z", updatedAt="2026-02-14T10:05:00Z"); f["statusHistory"] = [{"status": "success", "at": "2026-02-14T10:05:00Z", "source": "provider-response"}]; d["refunds"].append(f); wj(QM, d)'
case_fails remission-not-held-by-dispute 'was open when the body remitted, so the remission names it and holds its refunds \(FEE-064, FEE-068\)' \
  'd = rj(PM); d["disputes"] = [dispute(A2, "under-review", "2026-05-10T10:00:00Z")]; wj(PM, d)'
case_fails remission-refund-before-dispute-closes 'its refunds wait until dispute .* closes \(FEE-064, FEE-068\)' \
  'd = rj(PM); d["disputes"] = [dispute(A2, "under-review", "2026-05-10T10:00:00Z")]; d["remissions"][0]["heldByDisputeId"] = d["disputes"][0]["id"]; wj(PM, d)'
case_fails remission-ignores-lost-amount 'the refunds leave out what the lost dispute already returned, 50.00 \(FEE-064, FEE-068\)' \
  'd = rj(PM); d["disputes"] = [dispute(A2, "lost", "2026-05-10T10:00:00Z", "2026-05-20T10:00:00Z", amount="50.00")]; d["remissions"][0]["heldByDisputeId"] = d["disputes"][0]["id"]; wj(PM, d)'

# Remissions and the state of the order when the body remits (FEE-064).
case_fails remission-reduces-a-paid-order 'the order was paid when the body remitted, so the remission goes by refund \(FEE-064\)' \
  'd = rj(PM); x = d["remissions"][0]; x["execution"] = "reduction-of-amount-due"; del x["refundIds"]; wj(PM, d)'
case_fails remission-reduces-during-attempt 'was unfinished when the body remitted: cancel it first, or remit by refund \(FEE-064\)' \
  'd = rj(PM); x = d["remissions"][0]; x["execution"] = "reduction-of-amount-due"; del x["refundIds"]; x["createdAt"] = "2026-03-02T14:05:10Z"; wj(PM, d)'
case_fails remission-refunds-an-unpaid-order 'the order was not paid when the body remitted, so the remission reduces the amount due \(FEE-064\)' \
  'd = rj(PM); x = d["remissions"][0]; del x["refundIds"]; x["createdAt"] = "2026-03-02T13:59:40Z"; wj(PM, d)'

# Interest rates as dated values of the profile (FEE-023, FEE-030).
case_fails interest-rate-not-published 'names the rate overdue-interest-rate, which the profile does not publish \(FEE-030\)' \
  'd = ry(CF); d["parameters"] = [p for p in d["parameters"] if p["code"] != "overdue-interest-rate"]; wy(CF, d)'
case_fails interest-rate-not-bank-rate-plus-3 'must be 2.50 plus 3 \(FEE-030\)' \
  'd = ry(CF); [p.update(value="5.25") for p in d["parameters"] if p["code"] == "overdue-interest-rate"]; wy(CF, d)'
case_fails profile-value-twice 'parameter average-bank-rate has two values on 2026-01-01: publish one value per date \(FEE-011, FEE-023\)' \
  'd = ry(CF); d["parameters"].append({"code": "average-bank-rate", "value": "2.75", "validity": {"start": "2026-01-01"}, "sourceId": "bank-of-canada-bank-rate"}); wy(CF, d)'

# Rounding (FEE-025, FEE-029).
case_fails quote-rounds-by-indexation-bands 'rounds indexed values only: quotes and taxes round to the cent unless a cited law says otherwise \(FEE-025\)' \
  'd = ry(QS); d["roundingRule"] = "quebec-indexed-fees"; wy(QS, d); sync()'
case_fails indexation-rounding-for-quotes-only 'which does not round indexed values \(FEE-025\)' \
  'd = ry(QC); d["roundingRules"][0]["appliesTo"] = ["quotes"]; wy(QC, d)'

# Indexation: the cap, the federal threshold and the carry from step to step (FEE-024).
case_fails cap-applied-to-excepted-fee 'applies 3, but the rule and its caps give 5.08 \(FEE-024\)' \
  'd = ry(QC); d["parameters"][1]["value"] = "5.08"; wy(QC, d)
s = ry(QS); s["feeItems"][0]["flags"] = ["cap-law-schedule-i"]; st = s["indexationSteps"][0]; st["publishedRate"] = "5.08"; st["appliedRate"] = "3"; st["rawResult"] = "89.6100"; st["result"] = m("89.50"); s["parameters"][0]["values"][1]["value"] = m("89.50"); wy(QS, s)'
FED_STEPS='d = ry(FS); v = d["parameters"][0]["values"]; v[0]["validity"]["end"] = "2026-04-01"
v.append({"validity": {"start": "2026-04-01", "end": "2027-04-01"}, "value": m("350.00"), "enactedAt": "2026-03-01T15:00:00Z", "legalSource": v[0]["legalSource"]})
v.append({"validity": {"start": "2027-04-01"}, "value": m("354.55"), "enactedAt": "2027-03-01T15:00:00Z", "legalSource": v[0]["legalSource"]})
st = lambda day, rate, acc, prev, raw, defer, res: {"parameterCode": "permit-application-fee-amount", "validFrom": day, "indexationRule": "service-fees-act-cpi", "publishedRate": rate, "rateSource": "https://www.example.org/cpi", "appliedRate": rate, "accumulatedRate": acc, "previousAmount": m(prev), "rawResult": raw, "deferred": defer, "result": m(res)}
d["indexationSteps"] = [st("2026-04-01", "0.6", "0.6", "350.00", "352.1000", True, "350.00"), st("2027-04-01", "0.7", "1.3", "350.00", "354.5500", False, "354.55")]'
case_passes federal-threshold-and-carry-forward "$FED_STEPS"'
wy(FS, d); sync()'
case_fails federal-change-below-threshold 'must be deferred: True \(FEE-024\)' \
  "$FED_STEPS"'
d["indexationSteps"][0]["deferred"] = False; d["indexationSteps"][0]["result"] = m("352.10"); v[1]["value"] = m("352.10"); wy(FS, d); sync()'
case_fails federal-carry-not-from-previous-step 'accumulates 0.7, but the previous step carries 0.6 and the rate is 0.7: 1.3 \(FEE-024\)' \
  "$FED_STEPS"'
d["indexationSteps"][1]["accumulatedRate"] = "0.7"; wy(FS, d); sync()'
case_fails quebec-carry-not-from-previous-step 'accumulates 1.00, but the previous step carries 2.05 and the rate is 1.00: 3.05 \(FEE-024\)' \
  'd = ry(QS); v = d["parameters"][2]["values"]; v.append({"validity": {"start": "2027-01-01"}, "value": m("2.05"), "enactedAt": "2026-12-15T15:00:00Z", "legalSource": v[0]["legalSource"]})
d["indexationSteps"].append(dict(d["indexationSteps"][2], validFrom="2027-01-01", publishedRate="1.00", appliedRate="1.00", accumulatedRate="1.00", rawResult="2.0200", deferred=True, result=m("2.00"))); v[2]["value"] = m("2.00"); wy(QS, d); sync()'

# The gross amount of each basis (FEE-022, FEE-027).
case_fails tiered-gross-wrong 'line 1: the gross amount must be 450.00 \(FEE-027\)' \
  'd = rj(PM); l = d["quotes"][1]["lines"][0]; l["grossAmount"] = m("480.00"); l["amount"] = m("480.00"); wj(PM, d)'
case_fails banded-amount-of-wrong-band 'must take the amount of the band that holds 12, 25.00 from 2025-04-01 \(FEE-022, FEE-027\)' \
  'd = rj(PM); l = d["quotes"][1]["lines"][1]; l["unitAmount"] = m("30.00"); wj(PM, d)'
case_fails banded-priced-as-tiered 'line 2: the gross amount must be 300.00 \(FEE-027\)' \
  'd = rj(PM); l = d["quotes"][1]["lines"][1]; l["grossAmount"] = m("320.00"); l["amount"] = m("320.00"); wj(PM, d)'
case_fails percentage-on-other-base 'line 3: the gross amount must be 40.00 \(FEE-027\)' \
  'd = rj(PM); l = d["quotes"][1]["lines"][2]; l["baseValue"] = m("400.00"); wj(PM, d)'
case_fails percentage-without-base 'a percentage item needs the base value that its rate applies to \(FEE-022\)' \
  'd = rj(PM); del d["quotes"][1]["lines"][2]["baseValue"]; wj(PM, d)'

# Disputes in reconciliation (FEE-069, FEE-091).
DISPUTE_PAYOUT='d = rj(PM); d["disputes"] = [dispute(A2, "under-review", "2026-06-01T10:00:00Z", fee="15.00")]
d["payouts"].append({"id": "019c4e00-0008-7000-8000-000000000002", "provider": "example-pay", "providerPayoutId": "ex-po-2026-0612", "payoutDate": "2026-06-12", "gross": m("-15.00"), "fees": m("0.00"), "net": m("-15.00"), "lines": [{"lineNumber": 1, "kind": "dispute-fee", "providerReference": "ex-dp-0001", "amount": m("-15.00"), "fee": m("0.00"), "matchStatus": "matched", "matchedType": "Dispute", "matchedId": d["disputes"][0]["id"]}], "reconciliationStatus": "reconciled", "createdAt": "2026-06-12T09:00:00Z", "updatedAt": "2026-06-12T09:00:00Z"})'
case_passes dispute-fee-while-under-review "$DISPUTE_PAYOUT"'
wj(PM, d)'
case_fails dispute-fee-not-the-provider-fee 'does not match Dispute .* by kind, status, provider id and exact amount \(FEE-091, FEE-093\)' \
  "$DISPUTE_PAYOUT"'
p = d["payouts"][1]; p["lines"][0]["amount"] = m("-10.00"); p["gross"] = m("-10.00"); p["net"] = m("-10.00"); wj(PM, d)'
case_fails dispute-reversal-not-the-amount 'does not match Dispute .* by kind, status, provider id and exact amount \(FEE-091, FEE-093\)' \
  "$DISPUTE_PAYOUT"'
x = d["disputes"][0]; x["status"] = "lost"; x["closedAt"] = "2026-06-10T10:00:00Z"; x["statusHistory"].append({"status": "lost", "at": "2026-06-10T10:00:00Z", "source": "provider-read"}); d["orders"][0]["status"] = "reversed"
p = d["payouts"][1]; p["lines"][0].update(kind="dispute-reversal", amount=m("-300.00")); p["gross"] = m("-300.00"); p["net"] = m("-300.00"); wj(PM, d)'
case_fails dispute-reversal-while-open 'does not match Dispute .* by kind, status, provider id and exact amount \(FEE-091, FEE-093\)' \
  "$DISPUTE_PAYOUT"'
p = d["payouts"][1]; p["lines"][0].update(kind="dispute-reversal", amount=m("-390.00")); p["gross"] = m("-390.00"); p["net"] = m("-390.00"); wj(PM, d)'

[ $fail -eq 0 ] && echo "PASS: every case"
exit $fail
