from datetime import date, datetime

from sqlmodel import SQLModel

from app.models.abonnement import PlanAbonnement, StatutAbonnement


class AbonnementRead(SQLModel):
    id: str
    entreprise_id: str
    plan: PlanAbonnement
    statut: StatutAbonnement
    montant: int
    date_debut: date
    date_renouvellement: date | None
    date_paiement: datetime | None
    # Prix qui sera réellement facturé au prochain renouvellement — distinct
    # de `montant` (le prix du DERNIER paiement confirmé, déjà passé) tant
    # qu'aucun paiement n'a encore eu lieu à ce nouveau prix. Toujours
    # renseigné (retombe sur PlatformConfig.abonnement_montant_htg si aucun
    # prix de renouvellement n'est annoncé) — voir read_abonnement.
    montant_prochain_renouvellement: int


class AbonnementPayerResponse(SQLModel):
    redirect_url: str


class PaiementAbonnementRead(SQLModel):
    id: str
    montant: int
    methode: str
    statut: str
    moncash_order_id: str | None
    moncash_transaction_id: str | None
    date_paiement: datetime
    paye_par_nom: str | None


class PaiementEnAttenteRead(PaiementAbonnementRead):
    """Même chose que PaiementAbonnementRead, avec l'entreprise identifiée —
    nécessaire pour la vue superadmin toutes entreprises confondues (voir
    GET /superadmin/paiements-en-attente)."""

    entreprise_id: str
    entreprise_nom: str


class LicenceResponse(SQLModel):
    """Blob de licence signé (Ed25519) — vérifiable côté client sans réseau.

    `data` : payload JSON encodé en base64. `signature` : signature Ed25519
    de `data` (avant encodage), encodée en base64. Le client vérifie avec la
    clé publique embarquée avant de faire confiance au contenu de `data`.
    """

    data: str
    signature: str


class AbonnementVerifierResponse(SQLModel):
    """Réponse de POST /abonnement/verifier.

    `paye` indique si MonCash a confirmé le paiement lors de cet appel :
    - `paye=True`  → l'abonnement est passé à ACTIF, `abonnement` reflète le
      nouvel état (statut, date_paiement, date_renouvellement à jour).
    - `paye=False` → paiement pas encore trouvé/confirmé côté MonCash (cas
      normal de polling après redirection), `abonnement` reflète l'état
      inchangé. Ce n'est pas une erreur, donc pas de 4xx/5xx.
    """

    paye: bool
    abonnement: AbonnementRead
