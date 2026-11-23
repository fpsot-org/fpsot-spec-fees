# Terms needed

Entries in the format of `termbase/terms.yaml` of fpsot-spec-writing, for a pull request to the term base.
The pages of this specification write these terms in plain text for now, and will use the term attributes once the term base has them.
The French forms marked "to confirm" have no record that the writer could check in the Grand dictionnaire terminologique or TERMIUM Plus during this work.
French forms that come from a French text of law that the research read say so in their source.

## Decisions for the lead (provisional French forms)

1. **fee quote → « devis »** (provisional, used on every French page). It is short and plain, but it sounds commercial. Alternatives: « calcul des frais », « établissement des frais ».
2. **fee order → « demande de paiement »** (provisional, used on every French page). It reads naturally for what a payer owes. It collides with the ISO 20022 *request to pay*, which the alignment page also renders « demande de paiement ». Alternatives: « avis de paiement », « commande ».
3. **settlement → « réception des fonds »** (provisional). TERMIUM-style « règlement » would collide with *regulation* on pages full of regulations, and « versement » already renders *payout*. The French pages therefore say « réception des fonds » for the settlement of an attempt, and « versement » for the transfer from the provider.
4. **status code `cancelled`.** The attempt status keeps the spelling of GOV.UK Pay under NAM-007, as the plan asks for a GOV.UK-compatible set. Every other code of this specification is ours and uses US spelling under NAM-006: `canceled` for an order, `canceled-by-payer` and `canceled-by-service` for failure codes. The lead may prefer `canceled` throughout.
5. **deploying body.** The existing definition speaks of the decisions of a decision type only. This specification also uses the term for the body that runs payments for its fees. The entry below proposes a broader definition.

```yaml
  - id: fee
    kind: term
    en: {full: "fee", definition: "An amount that a public body charges under a law for a service, a right, a document or the use of a facility."}
    fr: {full: "frais", definition: "Somme qu’un organisme public exige en vertu d’une loi pour un service, un droit, un document ou l’usage d’une installation."}
    source: {name: "Service Fees Act and Loi sur les frais de service, title and section 2 (official French form; the French definition is to confirm)", url: "https://laws-lois.justice.gc.ca/fra/lois/S-8.4/TexteComplet.html", checked: "2026-11-21"}
  - id: fee-schedule
    kind: term
    en: {full: "fee schedule", definition: "A dated parameter file that holds the fees of a body, each with its amounts over time, its legal source and its tax treatment."}
    fr: {full: "barème de frais", definition: "Fichier de paramètres datés qui contient les frais d’un organisme, chacun avec ses montants dans le temps, sa source juridique et son traitement fiscal."}
    source: {name: "FPSOT fees specification, FEE-020; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: fee-item
    kind: term
    en: {full: "fee item", definition: "One fee of a fee schedule, with its basis, the parameter of its amounts, its legal source and its exemptions."}
    fr: {full: "élément de frais", definition: "Frais particuliers d’un barème, avec leur base, le paramètre de leurs montants, leur source juridique et leurs exemptions."}
    source: {name: "FPSOT fees specification, FEE-020 and FEE-022; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: fee-quote
    kind: term
    en: {full: "fee quote", definition: "The lines of one fee decision: each fee, the value in force, any exemption and the taxes, with the total of the decision record."}
    fr: {full: "devis", definition: "Lignes d’une décision sur des frais : chacun des frais, la valeur en vigueur, l’exemption éventuelle et les taxes, avec le total de l’enregistrement de décision."}
    source: {name: "FPSOT fees specification, FEE-026 and FEE-027; French form provisional, see decision 1", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: fee-order
    kind: term
    en: {full: "fee order", definition: "What a payer owes for one or more quotes, with the payment attempts against it."}
    fr: {full: "demande de paiement", definition: "Ce que doit une personne pour un ou plusieurs devis, avec les tentatives de paiement qui s’y rattachent."}
    source: {name: "FPSOT fees specification, FEE-040; French form provisional, see decision 2", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: payment-attempt
    kind: term
    en: {full: "payment attempt", definition: "One try to pay a fee order through a payment provider, with its status and the history of that status."}
    fr: {full: "tentative de paiement", definition: "Essai de payer une demande de paiement par un fournisseur de paiement, avec son statut et l’historique de ce statut."}
    source: {name: "FPSOT fees specification, FEE-041 to FEE-043, after GOV.UK Pay; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: payment-provider
    kind: term
    en: {full: "payment provider", definition: "The service that takes a payment from the payer and sends the funds to the body, such as a card processor or a government payment platform."}
    fr: {full: "fournisseur de paiement", definition: "Service qui reçoit un paiement de la personne et verse les fonds à l’organisme, comme un service de traitement des cartes ou une plateforme gouvernementale de paiement."}
    source: {name: "FPSOT fees specification, FEE-001 and FEE-101; French form to confirm. France says prestataire de services de paiement", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: provider-adapter
    kind: term
    en: {full: "provider adapter", definition: "The component that links a fee engine to one payment provider, and maps the statuses of the provider onto those of the specification."}
    fr: {full: "adaptateur de fournisseur", definition: "Composant qui relie un moteur de frais à un fournisseur de paiement, et fait correspondre les statuts du fournisseur à ceux de la spécification."}
    source: {name: "FPSOT fees specification, FEE-002 and FEE-101; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: fee-engine
    kind: term
    en: {full: "fee engine", definition: "Software that quotes fees, takes payments, refunds, remits and issues receipts, under the rules of the fees specification."}
    fr: {full: "moteur de frais", definition: "Logiciel qui établit des devis, reçoit des paiements, rembourse, remet et délivre des reçus, selon les règles de la spécification sur les frais."}
    source: {name: "FPSOT fees specification, FEE-002; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: refund
    kind: term
    en: {full: "refund", definition: "Money that goes back to a payer because the body should not keep it, such as a fee for a service that it did not provide."}
    fr: {full: "remboursement", definition: "Argent rendu à une personne parce que l’organisme ne devrait pas le garder, comme des frais pour un service qu’il n’a pas rendu."}
    source: {name: "Règlement de 1997 sur le remboursement de recettes, DORS/98-127 (official French form), approved by the lead", url: "https://laws-lois.justice.gc.ca/fra/reglements/DORS-98-127/TexteComplet.html", checked: "2026-11-21"}
  - id: remission
    kind: term
    en: {full: "remission", definition: "A decision under a law to forgive or return all or part of an amount that a payer owed, such as after a missed performance standard."}
    fr: {full: "remise", definition: "Décision prise en vertu d’une loi de renoncer à tout ou partie d’une somme due, ou de la rendre, comme après une norme de rendement non respectée."}
    source: {name: "Loi sur les frais de service, article 7 (official French form), approved by the lead", url: "https://laws-lois.justice.gc.ca/fra/lois/S-8.4/TexteComplet.html", checked: "2026-11-21"}
  - id: dispute
    kind: term
    en: {full: "dispute", definition: "A challenge of a card payment that the bank of the payer opens, which can take the payment back from the body."}
    fr: {full: "contestation", definition: "Remise en cause d’un paiement par carte que la banque de la personne ouvre, et qui peut reprendre le paiement à l’organisme."}
    source: {name: "FPSOT fees specification, FEE-067, after GOV.UK Pay; French form to confirm. A lost dispute is a rétrofacturation (chargeback)", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: receipt
    kind: term
    en: {full: "receipt", definition: "A sealed record of what a fee order cost and of each payment, refund and remission against it."}
    fr: {full: "reçu", definition: "Document cacheté de ce qu’une demande de paiement a coûté et de chaque paiement, remboursement et remise qui s’y rattache."}
    source: {name: "FPSOT fees specification, FEE-080 and FEE-081; French form approved by the lead", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: reconciliation
    kind: term
    en: {full: "reconciliation", definition: "Matching each line of each payout of a provider to one payment attempt, refund or dispute, to the cent."}
    fr: {full: "rapprochement", definition: "Rattachement de chaque ligne de chaque versement d’un fournisseur à une seule tentative de paiement, un seul remboursement ou une seule contestation, au cent près."}
    source: {name: "FPSOT fees specification, FEE-091; French form approved by the lead", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: payout
    kind: term
    en: {full: "payout", definition: "One transfer of funds from a payment provider to the account of the body, which nets payments, refunds and fees."}
    fr: {full: "versement", definition: "Transfert de fonds d’un fournisseur de paiement au compte de l’organisme, qui compense des paiements, des remboursements et des frais."}
    source: {name: "FPSOT fees specification, FEE-090; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: settlement
    kind: term
    en: {full: "settlement", definition: "The fact that a payout carried the funds of a successful payment attempt to the account of the body."}
    fr: {full: "réception des fonds", definition: "Fait qu’un versement a porté les fonds d’une tentative de paiement réussie au compte de l’organisme."}
    source: {name: "FPSOT fees specification, FEE-044; French form provisional, see decision 3", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: indexation-step
    kind: term
    en: {full: "indexation step", definition: "The record, in a fee schedule, of how one indexed value was set: the rule, the published rate, the cap, the raw result, the deferral and the rounded result."}
    fr: {full: "étape d’indexation", definition: "Inscription, dans un barème de frais, de la façon dont une valeur indexée a été fixée : la règle, le taux publié, le plafond, le résultat brut, le report et le résultat arrondi."}
    source: {name: "FPSOT fees specification, FEE-024; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: rounding-rule
    kind: term
    en: {full: "rounding rule", definition: "A rounding method with its step for each band of results and where a result halfway goes."}
    fr: {full: "règle d’arrondi", definition: "Méthode d’arrondi avec son pas pour chaque tranche de résultats et la direction d’un résultat à mi-chemin."}
    source: {name: "FPSOT fees specification, FEE-025, after DAT-054; French form to confirm. The Québec regulation says arrondissement for the act of rounding a fee", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: fee-exemption
    kind: term
    en: {full: "exemption", definition: "A rule of law under which a payer who meets a condition owes no fee, or a smaller one."}
    fr: {full: "exemption", definition: "Règle de droit selon laquelle une personne qui remplit une condition ne doit aucuns frais, ou des frais moindres."}
    source: {name: "FPSOT registry specification, REG-026 (same French form), and FEE-028; to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: waiver
    kind: term
    en: {full: "waiver", definition: "A choice of a person with the authority to excuse a payer from a fee, where the law allows discretion."}
    fr: {full: "dispense", definition: "Choix d’une personne qui a le pouvoir d’exempter une personne de frais, quand la loi laisse une discrétion."}
    source: {name: "FPSOT fees specification, FEE-028, after DEC-026; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: performance-standard
    kind: term
    en: {full: "performance standard", definition: "The public level of service that a federal body must meet for a fee, under the Service Fees Act."}
    fr: {full: "norme de rendement", definition: "Niveau de service public qu’un organisme fédéral doit respecter pour des frais, selon la Loi sur les frais de service."}
    source: {name: "Loi sur les frais de service, articles 4 to 8 (official French form)", url: "https://laws-lois.justice.gc.ca/fra/lois/S-8.4/TexteComplet.html", checked: "2026-11-21"}
  - id: low-materiality-fee
    kind: term
    en: {full: "low-materiality fee", definition: "A federal fee that the Low-materiality Fees Regulations exclude from sections 3 to 18 of the Service Fees Act, such as a fee below $51."}
    fr: {full: "frais de faible importance", definition: "Frais fédéraux que le Règlement sur les frais de faible importance soustrait aux articles 3 à 18 de la Loi sur les frais de service, comme des frais inférieurs à 51 $."}
    source: {name: "Loi sur les frais de service, article 22 (official French form)", url: "https://laws-lois.justice.gc.ca/fra/lois/S-8.4/TexteComplet.html", checked: "2026-11-21"}
  - id: card-data
    kind: term
    en: {full: "card data", definition: "The card number, the security code, the expiry date, the track data and the PIN of a payment card."}
    fr: {full: "données de carte", definition: "Numéro, code de sécurité, date d’expiration, données de piste et NIP d’une carte de paiement."}
    source: {name: "FPSOT fees specification, FEE-046; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: hosted-payment-page
    kind: term
    en: {full: "hosted payment page", definition: "A payment page that the provider serves on its own site, where the payer enters card data."}
    fr: {full: "page de paiement hébergée", definition: "Page de paiement que le fournisseur sert sur son propre site, où la personne saisit ses données de carte."}
    source: {name: "FPSOT fees specification, FEE-047; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: full-redirect
    kind: term
    en: {full: "full redirect", definition: "Sending the browser of the payer from a page of the body to the hosted payment page of the provider, with no part of the payment form on the page of the body."}
    fr: {full: "redirection complète", definition: "Envoi du navigateur de la personne d’une page de l’organisme vers la page de paiement hébergée du fournisseur, sans aucune partie du formulaire de paiement sur la page de l’organisme."}
    source: {name: "FPSOT fees specification, FEE-047, after FAQ 1588 of the PCI Security Standards Council; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: embedded-payment-form
    kind: term
    en: {full: "embedded payment form", definition: "A payment form of the provider that a page of the body embeds, such as in a frame."}
    fr: {full: "formulaire de paiement intégré", definition: "Formulaire de paiement du fournisseur qu’une page de l’organisme intègre, comme dans un cadre."}
    source: {name: "FPSOT fees specification, FEE-048; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: provider-notification
    kind: term
    en: {full: "provider notification", definition: "A signed message that a payment provider sends to tell a body that an object changed, often called a webhook."}
    fr: {full: "avis du fournisseur", definition: "Message signé qu’un fournisseur de paiement envoie pour informer un organisme qu’un objet a changé, souvent appelé webhook."}
    source: {name: "FPSOT fees specification, FEE-070 to FEE-072; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: payment-reference
    kind: term
    en: {full: "payment reference", definition: "The reference of a fee order that the payer sees and quotes, which holds no personal information."}
    fr: {full: "référence de paiement", definition: "Référence d’une demande de paiement que la personne voit et cite, et qui ne contient aucun renseignement personnel."}
    source: {name: "FPSOT fees specification, FEE-040 and FEE-092; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: refundable-balance
    kind: term
    en: {full: "refundable balance", definition: "The part of a successful payment that refunds have not yet returned."}
    fr: {full: "solde remboursable", definition: "Partie d’un paiement réussi que les remboursements n’ont pas encore rendue."}
    source: {name: "FPSOT fees specification, FEE-061, after GOV.UK Pay; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: acquirer
    kind: term
    en: {full: "acquirer", definition: "The financial institution that accepts card payments for a merchant and settles them."}
    fr: {full: "acquéreur", definition: "Institution financière qui accepte les paiements par carte pour un marchand et les règle."}
    source: {name: "FPSOT fees specification, FEE-048; French form to confirm", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: deploying-body
    kind: term
    en: {full: "deploying body", definition: "The public body that answers for a system that it runs, such as the decisions of a decision type or the payments of its fees."}
    fr: {full: "organisme responsable", definition: "Organisme public qui répond d’un système qu’il exploite, comme les décisions d’un type de décision ou les paiements de ses frais."}
    source: {name: "Broader definition proposed by the FPSOT fees specification, FEE-002 and FEE-082, to replace the one of the decisions specification; same French form", url: "https://github.com/fpsot-org/fpsot-spec-fees", checked: "2026-11-21"}
  - id: pci-dss
    kind: abbreviation
    en: {short: "PCI DSS", full: "Payment Card Industry Data Security Standard", definition: "The standard of the PCI Security Standards Council for the security of card data."}
    fr: {short: "PCI DSS", full: "Payment Card Industry Data Security Standard", definition: "Norme du PCI Security Standards Council sur la sécurité des données de cartes de paiement."}
    source: {name: "PCI Security Standards Council (proper name, kept in English; French definition to confirm)", url: "https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants", checked: "2026-11-21"}
  - id: saq
    kind: abbreviation
    en: {short: "SAQ", full: "Self-Assessment Questionnaire", definition: "A questionnaire of the PCI Security Standards Council by which a merchant attests its compliance with PCI DSS, such as SAQ A for merchants that fully outsource card data."}
    fr: {short: "SAQ", full: "questionnaire d’autoévaluation", definition: "Questionnaire du PCI Security Standards Council par lequel un marchand atteste sa conformité à PCI DSS, comme le SAQ A pour les marchands qui confient toutes les données de carte à un tiers."}
    source: {name: "PCI Security Standards Council, notice of 2025-01-30; French form to confirm", url: "https://blog.pcisecuritystandards.org/important-updates-announced-for-merchants-validating-to-self-assessment-questionnaire-a", checked: "2026-11-21"}
  - id: gst
    kind: abbreviation
    en: {short: "GST", full: "goods and services tax", definition: "The federal value-added tax of Canada, under Part IX of the Excise Tax Act."}
    fr: {short: "TPS", full: "taxe sur les produits et services", definition: "Taxe fédérale sur la valeur ajoutée du Canada, selon la partie IX de la Loi sur la taxe d’accise."}
    source: {name: "Excise Tax Act and Loi sur la taxe d’accise (official forms in both languages)", url: "https://laws-lois.justice.gc.ca/fra/lois/E-15/page-120.html", checked: "2026-11-21"}
  - id: qst
    kind: abbreviation
    en: {short: "QST", full: "Québec sales tax", definition: "The value-added tax of Québec, which Revenu Québec administers."}
    fr: {short: "TVQ", full: "taxe de vente du Québec", definition: "Taxe sur la valeur ajoutée du Québec, que Revenu Québec administre."}
    source: {name: "Revenu Québec (official forms in both languages; to confirm)", url: "https://www.revenuquebec.ca/fr/entreprises/taxes/tpstvh-et-tvq/regles-de-base-relatives-a-lapplication-de-la-tpstvh-et-de-la-tvq/types-de-fournitures/fournitures-exonerees/", checked: "2026-11-21"}
```
