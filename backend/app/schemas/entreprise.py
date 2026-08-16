from decimal import Decimal

from sqlmodel import SQLModel


class EntrepriseRegister(SQLModel):
    """Payload d'inscription self-service d'une entreprise (PRD §7.1, §8.1)."""

    nom_entreprise: str
    devise: str = "HTG"

    admin_nom: str
    admin_telephone: str
    admin_email: str | None = None
    admin_password: str


class EntrepriseRead(SQLModel):
    id: str
    nom: str
    devise: str
    adresse: str | None
    telephone_contact: str | None
    format_recu: str
    texte_bas_recu: str | None
    logo_data: str | None
    frais_retrait: Decimal
    statut: str


class EntrepriseProfilUpdate(SQLModel):
    """Mise à jour partielle du profil entreprise (Admin uniquement)."""

    nom: str | None = None
    adresse: str | None = None
    telephone_contact: str | None = None
    format_recu: str | None = None
    texte_bas_recu: str | None = None
    logo_data: str | None = None
    frais_retrait: Decimal | None = None
