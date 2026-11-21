# language: en
# SPDX-License-Identifier: Community-Spec-1.0
# Example feature of the FPSOT fees specification (FEE-102), under TST-020 to TST-036.
# It follows the fixtures of examples/: the schedules, the decision records and the fee records.
# Every person, number and provider is fictional. All data is synthetic (TST-050 to TST-056).
@fees
Feature: Quotes, payments, refunds, remissions and payouts of public fees
  Each scenario states the facts, the dates and the records that the fee engine must produce.

  Rule: A quote is a decision, and an exemption is a fact of that decision

    @fees-001
    Scenario: A declared section 35 right exempts the pleasure craft license fee
      Given the fee schedule "pleasure-craft-license-fees" at version "1.0.0" under the profile "ca-federal"
      And the applicant declares the fact "declares-section-35-right" on "2026-03-10"
      When the fee engine quotes the fee item "pleasure-craft-license-fee" for the effective date "2026-03-10"
      Then the decision record has the outcome "exempt" and the amount "0.00"
      And the quote line shows the gross amount "24.00" and the exemption "section-35-right"
      And the order takes no payment attempt and has the status "no-payment-due"

    @fees-002
    Scenario: A quote after the last published value finds no fee
      Given the fee schedule "pleasure-craft-license-fees" at version "1.0.0" under the profile "ca-federal"
      When the fee engine quotes the fee item "pleasure-craft-license-fee" for the effective date "2026-04-01"
      Then the decision record has the result kind "not-applicable"
      And the fee engine creates no order

  Rule: An indexed amount is a published value, never a value computed at run time

    @fees-003
    Scenario: The Québec indexation of 2026 rounds by band and defers a small fee
      Given the fee schedule "example-quebec-permit-fees" at version "1.1.0" under the profile "ca-qc"
      When the fee engine reads the fee item "permit-fee" for the effective date "2026-01-01"
      Then the value is "88.75", set by the rate "2.05" from "87.00" with the raw result "88.7835"
      And the value of the fee item "duplicate-permit-fee" stays "2.00" with the indexation deferred

  Rule: Only a read at the provider changes a payment status

    @fees-004
    Scenario: A failed attempt and then a successful one pay the order once
      Given the order "EX-2026-000123" with the amount due "390.00"
      And the first attempt reaches the status "failed" with the failure code "method-rejected"
      When the payer starts a second attempt and the provider confirms the status "success"
      Then the order has the status "paid"
      And the receipt of kind "payment" lists one payment of "390.00" with the card shown as "visa" and "0005"

    @fees-005
    Scenario: A late notification of an earlier status changes nothing
      Given the attempt with the provider id "ex-pay-7f3a02" has the status "success"
      When a signed notification of the status "submitted" arrives at "2026-03-02T14:07:15Z"
      Then the fee engine reads the payment at the provider and records the outcome "no-change"
      And the attempt keeps the status "success"

    @fees-006
    Scenario: A notification with a bad signature is rejected without a read
      Given the attempt with the provider id "ex-pay-7f3a02" has the status "success"
      When a notification arrives at "2026-03-02T14:08:00Z" whose signature does not verify
      Then the fee engine records the outcome "rejected" and reads nothing

  Rule: A refund moves money, and a remission is a decision

    @fees-007
    Scenario: An amendment that was never made is refunded in part
      Given the order "EX-2026-000123" paid "390.00" on "2026-03-02"
      When the body refunds "40.00" for the reason "purpose-not-fulfilled" with the deduction "0.00"
      Then the refund reaches the status "success" and "350.00" stays refundable
      And the receipt of kind "refund" names the receipt of kind "payment"

    @fees-008
    Scenario: A missed performance standard leads to a remission paid by refund
      Given the order "EX-2026-000123" with "350.00" still refundable
      When the body decides on "2026-05-15" to remit "87.50" under section 7 of the Service Fees Act
      Then the decision record has the outcome "remitted" and the amount "87.50"
      And the remission names that record and a refund for the reason "remission"
      And the receipt of kind "remission" lists the remission and both refunds

  Rule: Every payout line matches one record

    @fees-009
    Scenario: A payout nets a payment, a refund and a provider fee
      Given the payout "ex-po-2026-0313" of "2026-03-13" with the net amount "344.15"
      When the fee engine matches its lines
      Then the line "ex-pay-7f3a02" matches the attempt and the line "ex-ref-5501" matches the refund
      And the payout has the status "reconciled"
