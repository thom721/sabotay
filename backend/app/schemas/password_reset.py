from sqlmodel import SQLModel

from app.models.password_reset_token import CanalReset


class PasswordResetRequest(SQLModel):
    identifiant: str
    canal: CanalReset


class PasswordResetConfirm(SQLModel):
    identifiant: str
    code: str
    nouveau_mot_de_passe: str


class PasswordResetGenericResponse(SQLModel):
    message: str = "Si un compte existe, un code a été envoyé."
