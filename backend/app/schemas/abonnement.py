from datetime import date, datetime

from sqlmodel import SQLModel

from app.models.abonnement import PlanAbonnement, StatutAbonnement


class AbonnementRead(SQLModel):
    id: int
    entreprise_id: int
    plan: PlanAbonnement
    statut: StatutAbonnement
    montant: int
    date_debut: date
    date_renouvellement: date | None
    date_paiement: datetime | None


class AbonnementPayerResponse(SQLModel):
    redirect_url: str


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
