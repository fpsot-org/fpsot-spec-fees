# SPDX-License-Identifier: Apache-2.0
"""Checks the example files of the FPSOT fees specification.

Usage: python3 -I examples/check-examples.py [ROOT]

ROOT is the repository root, by default the parent of this folder. The check reads
model/fees.yaml with its imports, profiles/, registry/events/ and examples/. It needs the
Python standard library and PyYAML only (examples/requirements.txt).

It runs three kinds of checks, and reports every failure with the rule it breaks.

- Schema checks: each file against its class of the LinkML model, through a small reader of
  the parts of LinkML that the model uses (inheritance, required slots, ranges, types,
  patterns, enumerations, lists and closed classes). It is not a LinkML validator. Events are
  checked against their JSON Schemas with a small reader of the keywords that they use.
- Money and data: every amount is a decimal string with the decimals of its currency, and no
  file holds card data beyond a brand and four digits.
- Structural checks of the rules: profiles cite their sources; schedules publish one value per
  date and each indexed value matches its indexation step, its rate and its rounding; quotes
  price each line from the value in force and match their decision records, whose digests
  match the schedule files; attempts move one way, only after a read at the provider; refunds
  stay within the refundable balance, and only a refund that carries a remission names one;
  remissions rest on decision records; receipts list what moved; payouts add up and every line
  matches one record; events hold no personal value; the English and French features match.
"""
import glob
import hashlib
import json
import os
import re
import sys
from decimal import ROUND_FLOOR, ROUND_HALF_EVEN, ROUND_HALF_UP, Decimal

import yaml

BUILTIN = {"string", "integer", "boolean", "uri", "date", "datetime", "double", "float"}
URI = re.compile(r"^(https?://|mailto:|tel:)\S+$")
UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
MINOR_UNITS = {"CAD": 2, "EUR": 2, "USD": 2, "GBP": 2, "JPY": 0}
FINISHED = {"created": False, "started": False, "submitted": False, "capturable": False,
            "success": True, "failed": True, "cancelled": True, "error": True}
RANK = {"created": 0, "started": 1, "submitted": 2, "capturable": 3}
FAILURE_NEEDED = {"failed", "cancelled", "error"}
SEAL_PROFILES = ["seal-log", "seal-log-preserve"]
CARD_KEYS = re.compile(r"^(pan|cardnumber|primaryaccountnumber|accountnumber|cvv|cvv2|cvc|cvc2|cid|"
                       r"securitycode|cardsecuritycode|expiry|expirydate|expirymonth|expiryyear|"
                       r"expirationdate|expmonth|expyear|track|track1|track2|trackdata|pin|pinblock)$")
DIGIT_RUN = re.compile(r"(?<![0-9])(?:[0-9][ -]?){12,18}[0-9](?![0-9])")
CLASS_RULE = {"FeeProfile": "FEE-010", "FeeSchedule": "FEE-020", "DecisionRecord": "DEC-040",
              "FeesContainer": "FEE-006"}

failures = []


def fail(where, message, rule):
    failures.append(f"FAIL: {where}: {message} ({rule})")


def load(path):
    with open(path, encoding="utf-8") as f:
        if path.endswith((".yaml", ".yml")):
            return yaml.safe_load(f)
        return json.load(f)


def sha256(path):
    with open(path, "rb") as f:
        return hashlib.sha256(f.read()).hexdigest()


class Model:
    """The parts of a LinkML schema that the check reads."""

    def __init__(self, path):
        self.types, self.classes, self.enums = {}, {}, {}
        self.seen = set()
        self._read(path)

    def _read(self, path):
        path = os.path.normpath(path)
        if path in self.seen:
            return
        self.seen.add(path)
        schema = load(path)
        for imp in schema.get("imports") or []:
            if not imp.startswith("linkml:"):
                # LinkML resolves an import against the folder of the schema that imports it.
                self._read(os.path.join(os.path.dirname(path), imp + ".yaml"))
        for key, store in (("types", self.types), ("classes", self.classes), ("enums", self.enums)):
            for name, spec in (schema.get(key) or {}).items():
                if name in store and store[name] != spec:
                    fail(path, f"{name} is defined twice, in this schema and in an import", "FEE-004")
                store[name] = spec

    def attrs(self, cls):
        chain, c = [], cls
        while c:
            chain.append(c)
            c = self.classes[c].get("is_a")
        merged = {}
        for c in reversed(chain):
            for name, slot in (self.classes[c].get("attributes") or {}).items():
                merged[name] = dict(slot or {})
        return merged

    def identifier(self, cls):
        for name, slot in self.attrs(cls).items():
            if slot.get("identifier"):
                return slot
        return None

    def base(self, rng):
        patterns = []
        while rng not in BUILTIN:
            t = self.types[rng]
            if t.get("pattern"):
                patterns.append(t["pattern"])
            rng = t["typeof"]
        return rng, patterns

    def check(self, obj, cls, where, rule, path="$"):
        spec = self.classes[cls]
        if spec.get("class_uri") == "linkml:Any":
            return
        if not isinstance(obj, dict):
            fail(where, f"{path} must be an object of class {cls}", rule)
            return
        attrs = self.attrs(cls)
        for key in obj:
            if key not in attrs:
                fail(where, f"{path}.{key} is not a slot of {cls}", rule)
        for name, slot in attrs.items():
            if name not in obj:
                if slot.get("required") or slot.get("identifier"):
                    fail(where, f"{path}.{name} is required in {cls}", rule)
                continue
            value = obj[name]
            if slot.get("multivalued"):
                if not isinstance(value, list) or not value:
                    fail(where, f"{path}.{name} must be a list with at least one item", rule)
                    continue
                for i, item in enumerate(value):
                    self.value(item, slot, where, rule, f"{path}.{name}[{i}]")
            else:
                self.value(value, slot, where, rule, f"{path}.{name}")

    def value(self, v, slot, where, rule, path):
        rng = slot.get("range", "string")
        if rng in self.enums:
            if v not in (self.enums[rng].get("permissible_values") or {}):
                fail(where, f"{path} has {v!r}, which is not a value of {rng}", rule)
            return
        if rng in self.classes:
            ident = self.identifier(rng)
            if slot.get("inlined") or slot.get("inlined_as_list") or ident is None:
                self.check(v, rng, where, rule, path)
            else:
                self.value(v, ident, where, rule, path)
            return
        base, patterns = self.base(rng)
        if slot.get("pattern"):
            patterns.append(slot["pattern"])
        ok = {"integer": isinstance(v, int) and not isinstance(v, bool),
              "boolean": isinstance(v, bool),
              "uri": isinstance(v, str) and bool(URI.match(v))}.get(base, isinstance(v, str))
        if not ok:
            fail(where, f"{path} has {v!r}, which is not a {rng}", rule)
            return
        for p in patterns:
            if isinstance(v, str) and not re.search(p, v):
                fail(where, f"{path} has {v!r}, which does not match the pattern of {rng}", rule)
        if "minimum_value" in slot and v < slot["minimum_value"]:
            fail(where, f"{path} is below {slot['minimum_value']}", rule)


# ---------------------------------------------------------------------------------------------
# Money, card data and helpers


def dec(m):
    return Decimal(m["amount"])


def walk(node, path="$"):
    yield path, node
    if isinstance(node, dict):
        for k, v in node.items():
            yield from walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}[{i}]")


def check_money(where, doc):
    """Every object with amount and currency follows DAT-050 to DAT-053."""
    for path, node in walk(doc):
        if isinstance(node, dict) and "amount" in node and "currency" in node:
            a, c = node["amount"], node["currency"]
            if not isinstance(a, str):
                fail(where, f"{path}.amount must be a decimal string, never a JSON number", "DAT-052")
                continue
            if not re.fullmatch(r"-?(0|[1-9][0-9]*)(\.[0-9]+)?", a):
                fail(where, f"{path}.amount {a!r} is not a decimal string", "DAT-052")
                continue
            places = len(a.split(".")[1]) if "." in a else 0
            if c in MINOR_UNITS and places != MINOR_UNITS[c]:
                fail(where, f"{path}.amount {a} must have {MINOR_UNITS[c]} decimals for {c}", "DAT-053")
        if isinstance(node, float):
            fail(where, f"{path} holds a binary floating-point number", "DAT-055")


def luhn(digits):
    total = 0
    for i, ch in enumerate(reversed(digits)):
        d = int(ch)
        if i % 2:
            d = d * 2 - 9 if d > 4 else d * 2
        total += d
    return total % 10 == 0


def check_card_data(where, doc):
    """No card data beyond a brand and four digits (FEE-046)."""
    for path, node in walk(doc):
        if isinstance(node, dict):
            for k in node:
                if CARD_KEYS.match(re.sub(r"[^a-z0-9]", "", k.lower())):
                    fail(where, f"{path}.{k} is a card data field: no card data may enter the software", "FEE-046")
        if isinstance(node, str) and not (URI.match(node) or UUID.match(node)):
            for m in DIGIT_RUN.finditer(node):
                digits = re.sub(r"[ -]", "", m.group(0))
                if luhn(digits):
                    fail(where, f"{path} holds a number that looks like a card number", "FEE-046")


def round_to(x, rule):
    """Rounds a Decimal under a rounding rule of a profile (DAT-054, FEE-025)."""
    band = None
    for b in rule["bands"]:
        if x >= Decimal(b["from"]) and ("below" not in b or x < Decimal(b["below"])):
            band = b
    if band is None:
        raise ValueError(f"no band of {rule['code']} covers {x}")
    step = Decimal(band["step"])
    mode = {"nearest-half-up": ROUND_HALF_UP, "nearest-half-even": ROUND_HALF_EVEN,
            "down": ROUND_FLOOR}[rule["method"]]
    return ((x / step).quantize(Decimal(1), rounding=mode) * step).quantize(Decimal("0.01"))


def in_force(values, day):
    hits = [v for v in values if v["validity"]["start"] <= day
            and ("end" not in v["validity"] or day < v["validity"]["end"])]
    return hits


def day_before(day):
    import datetime as dt
    return (dt.date.fromisoformat(day) - dt.timedelta(days=1)).isoformat()


# ---------------------------------------------------------------------------------------------
# Profiles and schedules


def check_profiles(model, root):
    profiles = {}
    for path in sorted(glob.glob(os.path.join(root, "profiles", "*.yaml"))):
        where = os.path.relpath(path, root)
        doc = load(path)
        model.check(doc, "FeeProfile", where, "FEE-010")
        check_money(where, doc)
        code = doc.get("code")
        if code != os.path.basename(path)[:-5]:
            fail(where, f"the code {code} must match the file name", "FEE-010")
        sources = {s["id"]: s for s in doc.get("sources") or []}
        for s in sources.values():
            if s.get("verification") == "read" and not (s.get("url") or s.get("archive")):
                fail(where, f"source {s['id']} is marked read but has no address", "FEE-010")
        cited = []
        for key in ("refundReasons", "roundingRules", "taxTreatments", "parameters"):
            cited += [(key, x.get("code"), x.get("sourceId")) for x in doc.get(key) or []]
        for key in ("remissionRules", "indexationRules"):
            for x in doc.get(key) or []:
                cited += [(key, x.get("code"), s) for s in x.get("sourceIds") or []]
                for cap in x.get("caps") or []:
                    cited.append((key, x.get("code"), cap.get("sourceId")))
        for key, item, sid in cited:
            if code == "core" and sid is None:
                continue
            if sid is None:
                fail(where, f"{key} {item} cites no source", "FEE-011")
            elif sid not in sources:
                fail(where, f"{key} {item} cites source {sid}, which the profile does not list", "FEE-011")
        if code == "core":
            if not doc.get("defaults"):
                fail(where, "core must set the defaults", "FEE-014")
            elif doc["defaults"].get("cardIntegration") != "hosted-redirect":
                fail(where, "the default card integration must be the full redirect hosted-redirect", "FEE-047")
        elif not doc.get("jurisdiction"):
            fail(where, "a jurisdiction profile must name its jurisdiction", "FEE-010")
        elif doc.get("defaults"):
            fail(where, "only core sets defaults", "FEE-014")
        profiles[code] = doc
    for code, doc in profiles.items():
        rules = {r["code"] for p in (profiles.get("core", {}), doc) for r in p.get("roundingRules") or []}
        for ir in doc.get("indexationRules") or []:
            if ir.get("roundingRule") and ir["roundingRule"] not in rules:
                fail(f"profiles/{code}.yaml", f"indexation rule {ir['code']} names rounding rule "
                     f"{ir['roundingRule']}, which no profile defines", "FEE-025")
    return profiles


def merged(profiles, code, key):
    """The entries of core and of one profile, the profile winning on the same code."""
    out = {}
    for p in ("core", code):
        for x in (profiles.get(p) or {}).get(key) or []:
            out[x["code"]] = x
    return out


def param_values(sched):
    return {p["code"]: p["values"] for p in sched.get("parameters") or []}


def check_schedules(model, root, profiles):
    schedules = {}
    for path in sorted(glob.glob(os.path.join(root, "examples", "schedules", "*.yaml"))):
        where = os.path.relpath(path, root)
        doc = load(path)
        model.check(doc, "FeeSchedule", where, "FEE-020")
        check_money(where, doc)
        check_card_data(where, doc)
        pcode = doc.get("profile")
        if pcode not in profiles:
            fail(where, f"names profile {pcode}, which does not exist", "FEE-010")
            continue
        values = param_values(doc)
        for code, vals in values.items():
            spans = sorted(vals, key=lambda v: v["validity"]["start"])
            for a, b in zip(spans, spans[1:]):
                if "end" not in a["validity"] or a["validity"]["end"] > b["validity"]["start"]:
                    fail(where, f"parameter {code} has two values on {b['validity']['start']}: "
                         "publish one value per date", "FEE-023")
        rounding = merged(profiles, pcode, "roundingRules")
        if doc.get("roundingRule") not in rounding:
            fail(where, f"rounding rule {doc.get('roundingRule')} is not a rule of the profile", "FEE-025")
        treatments = merged(profiles, pcode, "taxTreatments")
        indexation = merged(profiles, pcode, "indexationRules")
        steps = {(s["parameterCode"], s["validFrom"]): s for s in doc.get("indexationSteps") or []}
        for item in doc.get("feeItems") or []:
            ic = item.get("code")
            if item.get("amountParameter") not in values:
                fail(where, f"fee item {ic} names parameter {item.get('amountParameter')}, which the file does not hold", "FEE-020")
                continue
            if item.get("basis") != "flat" and not item.get("unit"):
                fail(where, f"fee item {ic} has the basis {item.get('basis')} but no unit", "FEE-022")
            if item.get("basis") in ("tiered", "banded") and not item.get("tiers"):
                fail(where, f"fee item {ic} has the basis {item.get('basis')} but no tiers", "FEE-022")
            if item.get("taxTreatment") not in treatments:
                fail(where, f"fee item {ic} names tax treatment {item.get('taxTreatment')}, which the profile does not define", "FEE-029")
            for v in values[item["amountParameter"]]:
                if not (isinstance(v.get("value"), dict) and "amount" in v["value"]):
                    fail(where, f"fee item {ic} has a value that is not an amount of money", "DAT-050")
            rule_code = item.get("indexationRule")
            if not rule_code:
                continue
            if rule_code not in indexation:
                fail(where, f"fee item {ic} names indexation rule {rule_code}, which the profile does not define", "FEE-024")
                continue
            rule = indexation[rule_code]
            vals = sorted(values[item["amountParameter"]], key=lambda v: v["validity"]["start"])
            for prev, cur in zip(vals, vals[1:]):
                start = cur["validity"]["start"]
                step = steps.get((item["amountParameter"], start))
                if step is None:
                    fail(where, f"the value of {item['amountParameter']} from {start} has no indexation step", "FEE-024")
                    continue
                check_step(where, step, rule, prev, cur, rounding, profiles[pcode])
    for path in sorted(glob.glob(os.path.join(root, "examples", "schedules", "*.yaml"))):
        doc = load(path)
        schedules[(doc.get("code"), doc.get("version"))] = (doc, sha256(path), os.path.relpath(path, root))
    return schedules


def check_step(where, step, rule, prev, cur, rounding, profile):
    p = f"indexation step of {step['parameterCode']} from {step['validFrom']}"
    if step["indexationRule"] != rule["code"]:
        fail(where, f"{p} names rule {step['indexationRule']}, not the rule of its fee item", "FEE-024")
    if step["previousAmount"] != prev["value"]:
        fail(where, f"{p} starts from {step['previousAmount']['amount']}, not from the value in force the day before", "FEE-024")
    published = Decimal(step["publishedRate"])
    for par in profile.get("parameters") or []:
        if par["code"] == f"{rule['code']}-rate" and in_force([par], step["validFrom"]):
            if Decimal(str(par["value"])) != published:
                fail(where, f"{p} uses the rate {published}, but the profile publishes {par['value']}", "FEE-024")
    rate = published
    for cap in rule.get("caps") or []:
        if in_force([cap], step["validFrom"]):
            rate = min(rate, Decimal(cap["rate"]))
    rate = max(rate, Decimal(0))
    if Decimal(step["appliedRate"]) != rate:
        fail(where, f"{p} applies {step['appliedRate']}, but the rule and its caps give {rate}", "FEE-024")
    before = dec(prev["value"])
    used = rate
    deferred = False
    if rule.get("deferralBelow") and before < dec(rule["deferralBelow"]):
        used = Decimal(step.get("accumulatedRate") or "0")
        if used < rate:
            fail(where, f"{p} must carry the sum of the deferred rates", "FEE-024")
        deferred = before * used / 100 < dec(rule["deferralStep"])
    raw = before * (1 + used / 100)
    if Decimal(step["rawResult"]) != raw:
        fail(where, f"{p} gives the raw result {step['rawResult']}, but {before} at {used}% gives {raw}", "FEE-024")
    if step["deferred"] != deferred:
        fail(where, f"{p} must be deferred: {deferred}", "FEE-024")
    if deferred:
        expected = before.quantize(Decimal("0.01"))
    elif rule.get("roundingRule"):
        expected = round_to(raw, rounding[rule["roundingRule"]])
    else:
        fail(where, f"{p} has no rounding rule to state", "DAT-054")
        return
    if dec(step["result"]) != expected:
        fail(where, f"{p} publishes {step['result']['amount']}, but the rounding rule gives {expected}", "FEE-025")
    if cur["value"] != step["result"]:
        fail(where, f"the value of {step['parameterCode']} from {step['validFrom']} must be the result of its indexation step", "FEE-023")


# ---------------------------------------------------------------------------------------------
# Decision records, quotes, orders, attempts, refunds, remissions, receipts and payouts


def check_records(model, root, schedules):
    records = {}
    for path in sorted(glob.glob(os.path.join(root, "examples", "decisions", "*.json"))):
        where = os.path.relpath(path, root)
        doc = load(path)
        model.check(doc, "DecisionRecord", where, "DEC-040")
        check_money(where, doc)
        for ref in doc.get("parameterSets") or []:
            hit = schedules.get((ref.get("code"), ref.get("version")))
            if hit is None:
                fail(where, f"names parameter set {ref.get('code')} {ref.get('version')}, which no schedule file holds", "DEC-037")
            elif hit[1] != ref.get("digest"):
                fail(where, f"the digest of {hit[2]} does not match: a changed schedule needs a new version", "DEC-037, FEE-020")
        records[doc.get("id")] = (doc, where)
    return records


def check_fees(model, root, profiles, schedules, records):
    data = {}
    files = sorted(glob.glob(os.path.join(root, "examples", "*", "fees.json")))
    for path in files:
        where = os.path.relpath(path, root)
        doc = load(path)
        model.check(doc, "FeesContainer", where, "FEE-006")
        check_money(where, doc)
        check_card_data(where, doc)
        for key, items in doc.items():
            for x in items if isinstance(items, list) else []:
                data.setdefault(key, {})[x.get("id")] = (x, where)
    get = lambda key: data.get(key, {})
    quotes, orders, attempts = get("quotes"), get("orders"), get("attempts")
    notes, refunds, remissions = get("notifications"), get("refunds"), get("remissions")
    disputes, receipts, payouts = get("disputes"), get("receipts"), get("payouts")

    # Quotes (FEE-026 to FEE-030)
    for qid, (q, where) in quotes.items():
        p = f"quote {qid}"
        rec = records.get(q["decisionRecordId"])
        if rec is None:
            fail(where, f"{p} names decision record {q['decisionRecordId']}, which does not exist", "FEE-026")
            continue
        rec = rec[0]
        ref = q["feeSchedule"]
        hit = schedules.get((ref["code"], ref["version"]))
        if hit is None or hit[1] != ref["digest"]:
            fail(where, f"{p} names a schedule whose code, version or digest matches no schedule file", "FEE-027")
            continue
        if ref not in rec.get("parameterSets", []):
            fail(where, f"{p}: the decision record must list the schedule of the quote", "FEE-027, DEC-037")
        if rec.get("effectiveDate") != q["effectiveDate"]:
            fail(where, f"{p}: the effective date must be the one of the decision record", "FEE-027")
        if rec.get("resultKind") != "decided":
            fail(where, f"{p} rests on a record that is not decided: no quote for that result", "FEE-013, FEE-026")
        sched = hit[0]
        items = {i["code"]: i for i in sched["feeItems"]}
        values = param_values(sched)
        treatments = merged(profiles, sched["profile"], "taxTreatments")
        rounding = merged(profiles, sched["profile"], "roundingRules")[sched["roundingRule"]]
        facts = {f["name"]: f.get("value") for f in rec.get("inputs") or []}
        total = Decimal(0)
        for n, line in enumerate(q["lines"], 1):
            lp = f"{p} line {line['lineNumber']}"
            if line["lineNumber"] != n:
                fail(where, f"{lp}: lines must be numbered from 1 with no gap", "FEE-027")
            item = items.get(line["feeItem"])
            if item is None:
                fail(where, f"{lp} names fee item {line['feeItem']}, which the schedule does not hold", "FEE-027")
                continue
            hits = in_force(values[item["amountParameter"]], q["effectiveDate"])
            if len(hits) != 1:
                fail(where, f"{lp}: no single value of {item['amountParameter']} is in force on {q['effectiveDate']}: the engine must refuse", "FEE-013")
                continue
            v = hits[0]
            if line["unitAmount"] != v["value"] or line["valueValidFrom"] != v["validity"]["start"]:
                fail(where, f"{lp} must take the value in force on {q['effectiveDate']}, {v['value']['amount']} from {v['validity']['start']}", "FEE-027, DEC-037")
            gross = dec(line["unitAmount"]) * line["quantity"]
            if item["basis"] == "flat":
                gross = dec(line["unitAmount"])
            if dec(line["grossAmount"]) != gross:
                fail(where, f"{lp}: the gross amount must be {gross}", "FEE-027")
            if line["legalSource"] != item["legalSource"]:
                fail(where, f"{lp} must cite the legal source of its fee item", "FEE-027")
            amount = gross
            if line.get("exemption"):
                ex = {e["code"]: e for e in item.get("exemptions") or []}.get(line["exemption"])
                if ex is None:
                    fail(where, f"{lp} applies exemption {line['exemption']}, which the fee item does not grant", "FEE-028")
                elif facts.get(ex["factCode"]) is not True:
                    fail(where, f"{lp} applies exemption {line['exemption']}, but the decision record holds no fact {ex['factCode']}", "FEE-028")
                amount = Decimal(0)
            if dec(line["amount"]) != amount:
                fail(where, f"{lp}: the amount must be {amount:.2f}", "FEE-027")
            total += dec(line["amount"])
            expected = treatments.get(item["taxTreatment"])
            for tax in line["taxes"]:
                if expected and tax["taxCode"] == expected["taxCode"] and tax["treatment"] != expected["treatment"]:
                    fail(where, f"{lp}: {tax['taxCode']} must be {expected['treatment']} under the profile", "FEE-029")
                if tax["treatment"] == "taxable":
                    if "rate" not in tax:
                        fail(where, f"{lp}: a taxable line needs its rate", "FEE-029")
                        continue
                    t = round_to(dec(line["amount"]) * Decimal(tax["rate"]) / 100, rounding)
                    if dec(tax["amount"]) != t:
                        fail(where, f"{lp}: {tax['taxCode']} must be {t}", "FEE-029, DAT-054")
                elif dec(tax["amount"]) != 0:
                    fail(where, f"{lp}: a tax that is {tax['treatment']} must be 0", "FEE-029")
                total += dec(tax["amount"])
            if expected and expected["taxCode"] not in {t["taxCode"] for t in line["taxes"]}:
                fail(where, f"{lp} must state the treatment of {expected['taxCode']}", "FEE-029")
        if dec(q["total"]) != total:
            fail(where, f"{p}: the total must be the sum of the lines and taxes, {total:.2f}", "FEE-027")
        if rec.get("amount") != q["total"]:
            fail(where, f"{p}: the total must equal the amount of the decision record", "FEE-026, FEE-027")
        if q["validUntil"] <= q["createdAt"] or q["updatedAt"] != q["createdAt"]:
            fail(where, f"{p}: a quote never changes, and is valid after its creation", "FEE-030")

    # Orders and attempts (FEE-040 to FEE-051)
    by_order = {}
    for aid, (a, where) in attempts.items():
        by_order.setdefault(a["orderId"], []).append(a)
        p = f"attempt {aid}"
        if a["orderId"] not in orders:
            fail(where, f"{p} names order {a['orderId']}, which does not exist", "FEE-041")
        if FINISHED.get(a["status"]) != a["finished"]:
            fail(where, f"{p}: finished must be {FINISHED.get(a['status'])} for the status {a['status']}", "FEE-042")
        if (a["status"] in FAILURE_NEEDED) != ("failureCode" in a):
            fail(where, f"{p}: a failure code goes with failed, cancelled and error only", "FEE-043")
        hist = a["statusHistory"]
        if hist[-1]["status"] != a["status"]:
            fail(where, f"{p}: the status must be the last of its history", "FEE-043")
        for prev, cur in zip(hist, hist[1:]):
            if FINISHED[prev["status"]]:
                fail(where, f"{p} leaves the finished status {prev['status']} for {cur['status']}: statuses move one way", "FEE-043")
            elif not FINISHED[cur["status"]] and RANK[cur["status"]] <= RANK[prev["status"]]:
                fail(where, f"{p} goes back from {prev['status']} to {cur['status']}: statuses move one way", "FEE-043")
            if cur["at"] < prev["at"]:
                fail(where, f"{p}: the history must be in order of time", "FEE-043")
        if hist[0]["source"] != "provider-response" or hist[0]["status"] != "created":
            fail(where, f"{p}: the first status is created, from the answer of the provider", "FEE-043")
        for h in hist:
            n = h.get("notificationId")
            if n:
                note = notes.get(n, ({}, ""))[0]
                if not note.get("signatureVerified") or note.get("outcome") != "applied" or note.get("readAt") != h["at"]:
                    fail(where, f"{p}: the status {h['status']} rests on notification {n}, which must be verified, applied and followed by a read at {h['at']}", "FEE-070, FEE-071")
                if note.get("providerObjectId") != a["providerPaymentId"]:
                    fail(where, f"{p}: notification {n} names another payment", "FEE-071")
        st = a["settlement"]
        if st["status"] == "settled":
            if a["status"] != "success" or not st.get("settledDate") or st.get("payoutId") not in payouts:
                fail(where, f"{p}: only a success settles, with the date and the payout", "FEE-044")
        elif "settledDate" in st or "payoutId" in st:
            fail(where, f"{p}: an attempt that is not settled has no payout", "FEE-044")
        if a["integration"] == "embedded-hosted-form" and not embedded_record(root, a):
            fail(where, f"{p} uses an embedded form without the record of how the operator meets the SAQ A script criterion", "FEE-048")
        if a["methodCategory"] != "card" and "cardDisplay" in a:
            fail(where, f"{p}: only a card payment shows a card", "FEE-046")
    for oid, (o, where) in orders.items():
        p = f"order {oid}"
        qs = [quotes.get(q, (None,))[0] for q in o["quoteIds"]]
        if None in qs:
            fail(where, f"{p} names a quote that does not exist", "FEE-040")
            continue
        due = sum((dec(q["total"]) for q in qs), Decimal(0))
        due -= sum((dec(m["amount"]) for m, _ in remissions.values()
                    if m["orderId"] == oid and m["execution"] == "reduction-of-amount-due"), Decimal(0))
        if dec(o["amountDue"]) != due:
            fail(where, f"{p}: the amount due must be {due:.2f}, the sum of its quotes less reductions", "FEE-040")
        if len({q["total"]["currency"] for q in qs} | {o["amountDue"]["currency"]}) != 1:
            fail(where, f"{p}: an order holds one currency", "FEE-040")
        for q in qs:
            if o["createdAt"] > q["validUntil"]:
                fail(where, f"{p} uses quote {q['id']} after its end", "FEE-030")
        mine = by_order.get(oid, [])
        wins = [a for a in mine if a["status"] == "success"]
        if len(wins) > 1:
            fail(where, f"{p} has {len(wins)} successful attempts: one order is paid once", "FEE-041")
        status = ("no-payment-due" if due == 0 else "paid" if wins else
                  o["status"] if o["status"] == "canceled" else "awaiting-payment")
        if o["status"] != status:
            fail(where, f"{p}: the status must be {status}, from its amount and attempts", "FEE-045")
        if due == 0 and mine:
            fail(where, f"{p} owes nothing, so it takes no attempt", "FEE-040")
        spans = sorted((a["statusHistory"][0]["at"], next((h["at"] for h in a["statusHistory"] if FINISHED[h["status"]]), "9999"), a["id"]) for a in mine)
        for x, y in zip(spans, spans[1:]):
            if y[0] < x[1]:
                fail(where, f"{p}: attempt {y[2]} starts while attempt {x[2]} is not finished", "FEE-041")
        for a in mine:
            if a["amount"] != o["amountDue"]:
                fail(where, f"{p}: attempt {a['id']} must ask the amount due", "FEE-041")

    # Notifications (FEE-070 to FEE-072)
    seen = set()
    for nid, (n, where) in sorted(notes.items(), key=lambda kv: kv[1][0]["receivedAt"]):
        p = f"notification {nid}"
        key = (n["provider"], n["providerEventId"])
        if not n["signatureVerified"]:
            if n["outcome"] != "rejected" or "readAt" in n:
                fail(where, f"{p}: a notification whose signature fails is rejected, and the engine reads nothing", "FEE-070")
            continue
        if key in seen:
            if n["outcome"] != "duplicate":
                fail(where, f"{p} repeats event {n['providerEventId']}: its outcome is duplicate", "FEE-072")
            continue
        seen.add(key)
        if n["outcome"] == "duplicate":
            fail(where, f"{p} is the first with its event id, so it is not a duplicate", "FEE-072")
        if "readAt" not in n or n["readAt"] < n["receivedAt"]:
            fail(where, f"{p}: the engine must read the object at the provider after it verifies the notification", "FEE-071")
        if n["outcome"] == "applied" and not any(h.get("notificationId") == nid for a, _ in attempts.values() for h in a["statusHistory"]):
            fail(where, f"{p} is applied but no status rests on it", "FEE-071")

    # Disputes, refunds and remissions (FEE-060 to FEE-069)
    for did, (d, where) in disputes.items():
        a = attempts.get(d["attemptId"], (None,))[0]
        if a is None or a["status"] != "success":
            fail(where, f"dispute {did} must name a successful attempt", "FEE-067")
        if d["status"] == "needs-response" and "evidenceDueDate" not in d:
            fail(where, f"dispute {did} needs its evidence due date", "FEE-067")
        if (d["status"] in ("won", "lost")) != ("closedAt" in d):
            fail(where, f"dispute {did}: only a won or lost dispute is closed", "FEE-067")
    for oid in orders:
        reasons = None
        for q in orders[oid][0]["quoteIds"]:
            sched = schedules.get((quotes[q][0]["feeSchedule"]["code"], quotes[q][0]["feeSchedule"]["version"]))
            if sched:
                reasons = merged(profiles, sched[0]["profile"], "refundReasons")
        mine = sorted((f for f, _ in refunds.values() if f["orderId"] == oid), key=lambda f: f["createdAt"])
        moved = {}
        for f in mine:
            where = refunds[f["id"]][1]
            p = f"refund {f['id']}"
            a = attempts.get(f["attemptId"], (None,))[0]
            if a is None or a["status"] != "success" or a["orderId"] != oid:
                fail(where, f"{p} must go against a successful attempt of its order", "FEE-060")
                continue
            balance = dec(a["amount"]) - moved.get(a["id"], Decimal(0))
            if dec(f["refundableBefore"]) != balance:
                fail(where, f"{p} states the refundable balance {f['refundableBefore']['amount']}, but it is {balance:.2f}: the engine must refuse", "FEE-061")
            if dec(f["amount"]) > balance or dec(f["amount"]) <= 0:
                fail(where, f"{p} returns {f['amount']['amount']}, more than the refundable balance {balance:.2f}", "FEE-061")
            if f["status"] != "error":
                moved[a["id"]] = moved.get(a["id"], Decimal(0)) + dec(f["amount"])
            rule = (reasons or {}).get(f["reason"])
            if rule is None:
                fail(where, f"{p} gives the reason {f['reason']}, which the profile does not list", "FEE-062")
            elif rule["deductServicesRendered"] and "servicesRenderedDeduction" not in f:
                fail(where, f"{p}: the reason {f['reason']} states the part kept for services rendered", "FEE-062")
            if (f["reason"] == "remission") != ("remissionId" in f):
                fail(where, f"{p}: only a refund for the reason remission names a remission, and it must", "FEE-065")
            for d, _ in disputes.values():
                if d["attemptId"] == a["id"] and d["openedAt"] <= f["createdAt"] and d.get("closedAt", "9999") > f["createdAt"]:
                    fail(where, f"{p} was created while dispute {d['id']} was open", "FEE-068")
    used_records = {}
    for mid, (m, where) in remissions.items():
        p = f"remission {mid}"
        rec = records.get(m["decisionRecordId"], (None,))[0]
        if rec is None:
            fail(where, f"{p} rests on no decision record: a remission is a decision", "FEE-064")
            continue
        if rec.get("outcome") != "remitted" or rec.get("amount") != m["amount"]:
            fail(where, f"{p}: the record must have the outcome remitted and the same amount", "FEE-064")
        if m["legalBasis"] not in rec.get("legalAuthorities", []):
            fail(where, f"{p}: the legal basis must be a legal authority of the record", "FEE-064")
        if not any(o.get("id") == m["orderId"] for o in rec.get("objects", [])):
            fail(where, f"{p}: the record must name the order", "FEE-066")
        if m["decisionRecordId"] in used_records:
            fail(where, f"{p} shares its decision record with remission {used_records[m['decisionRecordId']]}: one record per payer and order", "FEE-066")
        used_records[m["decisionRecordId"]] = mid
        if m["execution"] == "refund":
            fs = [refunds.get(r, (None,))[0] for r in m.get("refundIds") or []]
            if not fs or None in fs:
                fail(where, f"{p} is carried out by refund, so it names its refunds", "FEE-064")
                continue
            if any(f.get("remissionId") != mid for f in fs):
                fail(where, f"{p}: each of its refunds must name it", "FEE-065")
            if sum((dec(f["amount"]) for f in fs), Decimal(0)) != dec(m["amount"]):
                fail(where, f"{p}: its refunds must add up to the amount remitted", "FEE-064")
        elif m.get("refundIds"):
            fail(where, f"{p} reduces the amount due, so it names no refund", "FEE-064")
    for fid, (f, where) in refunds.items():
        if "remissionId" in f and f["remissionId"] not in remissions:
            fail(where, f"refund {fid} names remission {f['remissionId']}, which does not exist", "FEE-065")

    # Receipts (FEE-080 to FEE-085)
    by_order_r = {}
    for rid, (r, where) in receipts.items():
        by_order_r.setdefault(r["orderId"], []).append(r)
        p = f"receipt {rid}"
        o = orders.get(r["orderId"], (None,))[0]
        if o is None:
            fail(where, f"{p} names an order that does not exist", "FEE-081")
            continue
        if r["sealProfile"] not in SEAL_PROFILES:
            fail(where, f"{p} must be sealed at seal-log or above", "FEE-082")
        if r["updatedAt"] != r["createdAt"]:
            fail(where, f"{p} never changes once sealed", "FEE-082")
        if r["paymentReference"] != o["paymentReference"] or r["payerPartyId"] != o["payerPartyId"] or r["totalDue"] != o["amountDue"]:
            fail(where, f"{p}: the reference, the payer and the amount due come from the order", "FEE-081")
        expected = []
        for q in o["quoteIds"]:
            qd = quotes[q][0]
            rec = records.get(qd["decisionRecordId"], ({},))[0]
            expected += [dict(l, decisionRecordId=qd["decisionRecordId"], ruleSet=rec.get("ruleSet")) for l in qd["lines"]]
        if r["lines"] != expected:
            fail(where, f"{p}: the lines must be the lines of the quotes, with their records and rule versions", "FEE-081")
        wins = [a for a, _ in attempts.values() if a["orderId"] == o["id"] and a["status"] == "success"]
        want = [{k: v for k, v in {"attemptId": a["id"], "amount": a["amount"], "methodCategory": a["methodCategory"],
                 "cardDisplay": a.get("cardDisplay"), "providerPaymentId": a["providerPaymentId"],
                 "succeededAt": a["statusHistory"][-1]["at"]}.items() if v is not None} for a in wins]
        if (r.get("payments") or []) != want:
            fail(where, f"{p}: the payments must be the successful attempts, with a card shown only as brand and last four", "FEE-081, FEE-083")
        if dec(r["totalPaid"]) != sum((dec(a["amount"]) for a in wins), Decimal(0)):
            fail(where, f"{p}: the total paid must add up the payments", "FEE-081")
        done = [f for f, _ in refunds.values() if f["orderId"] == o["id"] and f["status"] == "success" and f["updatedAt"] <= r["issuedAt"]]
        want_r = [{"refundId": f["id"], "amount": f["amount"], "reason": f["reason"]} for f in sorted(done, key=lambda f: f["updatedAt"])]
        if (r.get("refunds") or []) != want_r:
            fail(where, f"{p}: the refunds must be the successful refunds before its issue", "FEE-081")
        if dec(r["totalRefunded"]) != sum((dec(f["amount"]) for f in done), Decimal(0)):
            fail(where, f"{p}: the total refunded must add up the refunds", "FEE-081")
        rems = [m for m, _ in remissions.values() if m["orderId"] == o["id"] and m["updatedAt"] <= r["issuedAt"]]
        want_m = [{"remissionId": m["id"], "decisionRecordId": m["decisionRecordId"], "amount": m["amount"], "legalBasis": m["legalBasis"]} for m in rems]
        if (r.get("remissions") or []) != want_m:
            fail(where, f"{p}: the remissions must be those carried out before its issue", "FEE-081")
        if r["kind"] in ("refund", "remission") and r.get("previousReceiptId") not in receipts:
            fail(where, f"{p}: a receipt of a refund or a remission names the receipt it follows", "FEE-080")
        taxable = {t["taxCode"] for l in r["lines"] for t in l["taxes"] if t["treatment"] == "taxable"}
        regs = {t["taxCode"] for t in r["payee"].get("taxRegistrations") or []}
        if taxable - regs:
            fail(where, f"{p} charges {', '.join(sorted(taxable - regs))} without the registration number of the payee", "FEE-085")
    for oid, (o, where) in orders.items():
        kinds = [r["kind"] for r in by_order_r.get(oid, [])]
        if o["status"] == "paid" and "payment" not in kinds:
            fail(where, f"order {oid} is paid but has no payment receipt", "FEE-080")
        if o["status"] == "no-payment-due" and "no-payment-due" not in kinds:
            fail(where, f"order {oid} owes nothing but has no receipt that says so", "FEE-084")
        listed = {x["refundId"] for r in by_order_r.get(oid, []) if r["kind"] in ("refund", "remission") for x in r.get("refunds") or []}
        for f, _ in refunds.values():
            if f["orderId"] == oid and f["status"] == "success" and f["id"] not in listed:
                fail(where, f"refund {f['id']} succeeded but no receipt of a refund lists it", "FEE-080")
        listed_m = {x["remissionId"] for r in by_order_r.get(oid, []) if r["kind"] == "remission" for x in r.get("remissions") or []}
        for m, _ in remissions.values():
            if m["orderId"] == oid and m["id"] not in listed_m:
                fail(where, f"remission {m['id']} has no receipt of a remission", "FEE-080")

    # Payouts (FEE-090 to FEE-093)
    for pid, (po, where) in payouts.items():
        p = f"payout {pid}"
        lines = po["lines"]
        gross = sum((dec(l["amount"]) for l in lines), Decimal(0))
        fees = sum((dec(l["fee"]) for l in lines), Decimal(0))
        if dec(po["gross"]) != gross or dec(po["fees"]) != fees or dec(po["net"]) != gross - fees:
            fail(where, f"{p}: gross, fees and net must add up the lines exactly, {gross} - {fees} = {gross - fees}", "FEE-090, FEE-093")
        all_matched = True
        for l in lines:
            lp = f"{p} line {l['lineNumber']}"
            if l["matchStatus"] != "matched":
                all_matched = False
                if "matchedId" in l or "matchedType" in l:
                    fail(where, f"{lp} is unmatched, so it names no record", "FEE-091")
                continue
            store = {"PaymentAttempt": attempts, "Refund": refunds, "Dispute": disputes}.get(l.get("matchedType"), {})
            rec = store.get(l.get("matchedId"), (None,))[0]
            if rec is None:
                fail(where, f"{lp} is matched to a record that does not exist", "FEE-091")
                continue
            if l["matchedType"] == "PaymentAttempt":
                ok = (l["kind"] == "payment" and rec["status"] == "success" and l["amount"] == rec["amount"]
                      and l["providerReference"] == rec["providerPaymentId"] and rec["settlement"].get("payoutId") == pid)
            elif l["matchedType"] == "Refund":
                ok = (l["kind"] == "refund" and rec["status"] == "success" and dec(l["amount"]) == -dec(rec["amount"])
                      and l["providerReference"] == rec["providerRefundId"])
            else:
                ok = l["kind"] in ("dispute-reversal", "dispute-fee") and rec["status"] == "lost" and l["providerReference"] == rec["providerDisputeId"]
            if not ok:
                fail(where, f"{lp} does not match {l['matchedType']} {l['matchedId']} by kind, status, provider id and exact amount", "FEE-091, FEE-093")
                all_matched = False
        if (po["reconciliationStatus"] == "reconciled") != all_matched:
            fail(where, f"{p}: the status is reconciled only when every line matched", "FEE-091")
        for a, _ in attempts.values():
            if a["settlement"].get("payoutId") == pid and not any(l.get("matchedId") == a["id"] for l in lines):
                fail(where, f"{p}: attempt {a['id']} is settled in this payout but no line carries it", "FEE-091")
    return data


def embedded_record(root, attempt):
    """The operator record of FEE-048, in examples/operator-records.yaml when a deployment has one."""
    path = os.path.join(root, "examples", "operator-records.yaml")
    if not os.path.exists(path):
        return False
    for r in load(path).get("embeddedFormRecords") or []:
        if r.get("provider") == attempt["provider"] and r.get("basis") in ("script-controls", "provider-confirmation") and r.get("recordedAt"):
            return True
    return False


# ---------------------------------------------------------------------------------------------
# Events and features


def schema_check(value, schema, where, path):
    t = schema.get("type")
    kinds = {"object": dict, "string": str, "array": list, "boolean": bool}
    if t == "integer":
        if not isinstance(value, int) or isinstance(value, bool):
            fail(where, f"{path} must be an integer", "API-103")
            return
        if "minimum" in schema and value < schema["minimum"]:
            fail(where, f"{path} is below its minimum", "API-103")
        return
    if t in kinds and not isinstance(value, kinds[t]):
        fail(where, f"{path} must be of type {t}", "API-103")
        return
    if "enum" in schema and value not in schema["enum"]:
        fail(where, f"{path} has {value!r}, which is not allowed by the event schema", "API-103")
    if "pattern" in schema and isinstance(value, str) and not re.search(schema["pattern"], value):
        fail(where, f"{path} does not match the pattern of the event schema", "API-103")
    if t == "object":
        for k in schema.get("required") or []:
            if k not in value:
                fail(where, f"{path}.{k} is required by the event schema", "API-103")
        for k, v in value.items():
            if k in (schema.get("properties") or {}):
                schema_check(v, schema["properties"][k], where, f"{path}.{k}")
            elif schema.get("additionalProperties") is False:
                fail(where, f"{path}.{k} is not allowed by the event schema", "API-103")


def check_events(root, data):
    schemas = {}
    for path in sorted(glob.glob(os.path.join(root, "registry", "events", "*.schema.json"))):
        s = load(path)
        name = os.path.basename(path)[: -len(".schema.json")]
        if s.get("title") != name or not re.fullmatch(r"org\.fpsot\.fees\.[a-z0-9-]+\.[a-z0-9-]+", name):
            fail(os.path.relpath(path, root), "an event type is org.fpsot.fees.<resource>.<event>, named like its file", "NAM-050, FEE-075")
        if s.get("additionalProperties") is not False:
            fail(os.path.relpath(path, root), "the event schema must close its data", "FEE-076")
        schemas[name] = s
    personal = set()
    for key in ("orders", "receipts"):
        for x, _ in data.get(key, {}).values():
            personal |= {x["payerPartyId"], x["paymentReference"]}
    ids = {i for store in data.values() for i in store}
    for path in sorted(glob.glob(os.path.join(root, "examples", "*", "events", "*.json"))):
        where = os.path.relpath(path, root)
        e = load(path)
        check_card_data(where, e)
        for k in ("specversion", "id", "source", "type", "time", "datacontenttype", "subject", "dataschema", "data"):
            if k not in e:
                fail(where, f"the event lacks the attribute {k}", "API-101")
        if e.get("specversion") != "1.0":
            fail(where, "the event must be a CloudEvents 1.0 event", "API-100")
        s = schemas.get(e.get("type"))
        if s is None:
            fail(where, f"the type {e.get('type')} has no schema in registry/events/", "API-103, FEE-075")
            continue
        if e.get("dataschema") != s.get("$id"):
            fail(where, "dataschema must be the $id of the schema of its type", "API-103")
        schema_check(e.get("data"), s, where, "$.data")
        for path_, node in walk(e):
            if isinstance(node, str) and node in personal:
                fail(where, f"{path_} holds a party id or a payment reference: events hold no personal value", "FEE-076")
            if isinstance(node, dict) and ("amount" in node or "cardDisplay" in node or "lastFour" in node):
                fail(where, f"{path_} holds an amount or card data: events hold ids, codes and instants only", "FEE-076")
        if e.get("subject") not in ids:
            fail(where, "the subject must be the id of a record of the examples", "FEE-075")


def feature_shape(path):
    tags, steps = [], []
    for line in open(path, encoding="utf-8"):
        s = line.strip()
        if s.startswith("@"):
            tags.append(s)
        elif re.match(r"^(Given|When|Then|And|But|Étant donné|Quand|Alors|Et|Mais)\b", s):
            steps.append(tuple(re.findall(r'"([^"]*)"', s)))
    return tags, steps


def check_features(root, schedules):
    items = {i["code"] for s, _, _ in schedules.values() for i in s["feeItems"]}
    for en in sorted(glob.glob(os.path.join(root, "examples", "features", "en", "*.feature"))):
        fr = en.replace(os.sep + "en" + os.sep, os.sep + "fr" + os.sep)
        where = os.path.relpath(fr, root)
        if not os.path.exists(fr):
            fail(where, "each feature exists in English and in French", "TST-030")
            continue
        for f, lang in ((en, "en"), (fr, "fr")):
            if open(f, encoding="utf-8").readline().strip() != f"# language: {lang}":
                fail(os.path.relpath(f, root), f"the first line must be # language: {lang}", "TST-031")
        if feature_shape(en) != feature_shape(fr):
            fail(where, "the English and French versions must have the same tags and steps, with the same quoted values", "TST-032")
        for line in open(en, encoding="utf-8"):
            m = re.search(r'fee item "([^"]+)"', line)
            if m and m.group(1) not in items:
                fail(os.path.relpath(en, root), f"names fee item {m.group(1)}, which no schedule holds", "FEE-102")


def main():
    root = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), ".."))
    model = Model(os.path.join(root, "model", "fees.yaml"))
    for path in sorted(glob.glob(os.path.join(root, "profiles", "*.yaml"))):
        check_card_data(os.path.relpath(path, root), load(path))
    profiles = check_profiles(model, root)
    schedules = check_schedules(model, root, profiles)
    records = check_records(model, root, schedules)
    data = check_fees(model, root, profiles, schedules, records)
    check_events(root, data)
    check_features(root, schedules)
    for f in failures:
        print(f)
    if failures:
        print(f"{len(failures)} failure(s)")
        return 1
    print("OK: the examples meet the checked rules")
    return 0


if __name__ == "__main__":
    sys.exit(main())
