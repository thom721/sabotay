from sqlmodel import SQLModel


class CodeInstallationRead(SQLModel):
    code: str | None
    utilise: bool
