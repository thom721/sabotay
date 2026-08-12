from sqlmodel import SQLModel


class Token(SQLModel):
    access_token: str
    token_type: str = "bearer"


class MotDePasseUpdate(SQLModel):
    mot_de_passe_actuel: str
    nouveau_mot_de_passe: str


class MotDePasseUpdateResponse(SQLModel):
    message: str = "Mot de passe mis à jour"
