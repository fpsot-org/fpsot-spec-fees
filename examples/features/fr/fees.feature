# language: fr
# SPDX-License-Identifier: Community-Spec-1.0
# Fonctionnalité d’exemple de la spécification FPSOT sur les frais (FEE-102), selon TST-020 à TST-036.
# Elle suit les données d’exemple de examples/ : les barèmes, les enregistrements de décision et les données de frais.
# Chaque personne, numéro et fournisseur est fictif. Toutes les données sont synthétiques (TST-050 à TST-056).
@fees
Fonctionnalité: Devis, paiements, remboursements, remises et versements de frais publics
  Chaque scénario indique les faits, les dates et les données que le moteur de frais doit produire.

  Règle: Un devis est une décision, et une exemption est un fait de cette décision

    @fees-001
    Scénario: Un droit déclaré selon l’article 35 exempte des droits du permis d’embarcation de plaisance
      Étant donné le barème de frais "pleasure-craft-license-fees" à la version "1.0.0" selon le profil "ca-federal"
      Et la personne qui fait la demande déclare le fait "declares-section-35-right" le "2026-03-10"
      Quand le moteur de frais établit le devis de l’élément "pleasure-craft-license-fee" pour la date d’effet "2026-03-10"
      Alors l’enregistrement de décision a le résultat "exempt" et le montant "0.00"
      Et la ligne du devis montre le montant brut "24.00" et l’exemption "section-35-right"
      Et la commande ne reçoit aucune tentative de paiement et a le statut "no-payment-due"

    @fees-002
    Scénario: Un devis postérieur à la dernière valeur publiée ne trouve aucuns frais
      Étant donné le barème de frais "pleasure-craft-license-fees" à la version "1.0.0" selon le profil "ca-federal"
      Quand le moteur de frais établit le devis de l’élément "pleasure-craft-license-fee" pour la date d’effet "2026-04-01"
      Alors l’enregistrement de décision a le type de résultat "not-applicable"
      Et le moteur de frais ne crée aucune commande

  Règle: Un montant indexé est une valeur publiée, jamais une valeur calculée à l’exécution

    @fees-003
    Scénario: L’indexation québécoise de 2026 arrondit par tranche et reporte de petits frais
      Étant donné le barème de frais "example-quebec-permit-fees" à la version "1.1.0" selon le profil "ca-qc"
      Quand le moteur de frais lit l’élément "permit-fee" pour la date d’effet "2026-01-01"
      Alors la valeur est "88.75", fixée par le taux "2.05" à partir de "87.00" avec le résultat brut "88.7835"
      Et la valeur de l’élément "duplicate-permit-fee" reste "2.00" et son indexation est reportée

  Règle: Seule une lecture chez le fournisseur change le statut d’un paiement

    @fees-004
    Scénario: Une tentative refusée puis une tentative réussie paient la commande une seule fois
      Étant donné la commande "EX-2026-000123" avec le montant dû "390.00"
      Et la première tentative atteint le statut "failed" avec le code d’échec "method-rejected"
      Quand la personne qui paie lance une deuxième tentative et le fournisseur confirme le statut "success"
      Alors la commande a le statut "paid"
      Et le reçu de genre "payment" présente un paiement de "390.00" avec la carte montrée comme "visa" et "0005"

    @fees-005
    Scénario: Un avis tardif d’un statut antérieur ne change rien
      Étant donné la tentative dont l’identifiant chez le fournisseur est "ex-pay-7f3a02" a le statut "success"
      Quand un avis signé du statut "submitted" arrive le "2026-03-02T14:07:15Z"
      Alors le moteur de frais lit le paiement chez le fournisseur et consigne le résultat "no-change"
      Et la tentative garde le statut "success"

    @fees-006
    Scénario: Un avis dont la signature est invalide est rejeté sans lecture
      Étant donné la tentative dont l’identifiant chez le fournisseur est "ex-pay-7f3a02" a le statut "success"
      Quand un avis arrive le "2026-03-02T14:08:00Z" et sa signature ne se vérifie pas
      Alors le moteur de frais consigne le résultat "rejected" et ne lit rien

  Règle: Un remboursement déplace de l’argent, et une remise est une décision

    @fees-007
    Scénario: Une modification jamais faite est remboursée en partie
      Étant donné la commande "EX-2026-000123" payée "390.00" le "2026-03-02"
      Quand l’organisme rembourse "40.00" pour le motif "purpose-not-fulfilled" avec la retenue "0.00"
      Alors le remboursement atteint le statut "success" et "350.00" reste remboursable
      Et le reçu de genre "refund" nomme le reçu de genre "payment"

    @fees-008
    Scénario: Une norme de service non respectée mène à une remise versée par remboursement
      Étant donné la commande "EX-2026-000123" dont "350.00" reste remboursable
      Quand l’organisme décide le "2026-05-15" de remettre "87.50" selon l’article 7 de la Loi sur les frais de service
      Alors l’enregistrement de décision a le résultat "remitted" et le montant "87.50"
      Et la remise nomme cet enregistrement et un remboursement pour le motif "remission"
      Et le reçu de genre "remission" présente la remise et les deux remboursements

  Règle: Chaque ligne d’un versement correspond à une donnée

    @fees-009
    Scénario: Un versement compense un paiement, un remboursement et des frais du fournisseur
      Étant donné le versement "ex-po-2026-0313" du "2026-03-13" avec le montant net "344.15"
      Quand le moteur de frais rapproche ses lignes
      Alors la ligne "ex-pay-7f3a02" correspond à la tentative et la ligne "ex-ref-5501" correspond au remboursement
      Et le versement a le statut "reconciled"

  Règle: Un deuxième paiement réussi est remboursé en entier comme paiement en double

    @fees-010
    Scénario: Un virement que la personne a aussi envoyé est remboursé
      Étant donné la demande "EX-2026-000456" payée "88.75" le "2026-02-10" par un formulaire intégré selon la consignation du "2026-01-15"
      Quand la banque montre un virement de "88.75" avec la même référence le "2026-02-12"
      Alors le moteur de frais consigne une deuxième tentative au statut "success"
      Et il rembourse "88.75" sur cette tentative pour le motif "duplicate-payment"
      Et la demande garde le statut "paid"
