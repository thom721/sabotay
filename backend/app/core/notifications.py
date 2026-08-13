import asyncio
import logging

import aiosmtplib
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger("sabotaypro.notifications")


async def send_sms(to: str, message: str) -> None:
    """Envoie un SMS via Twilio, ou journalise le message si Twilio n'est pas
    configuré (dev sans compte réel — voir PRD §5.3 / plan de reset)."""
    if not (settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN and settings.TWILIO_FROM_NUMBER):
        logger.info("[SMS fallback] to=%s: %s", to, message)
        return

    from twilio.rest import Client

    def _send() -> None:
        client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
        client.messages.create(to=to, from_=settings.TWILIO_FROM_NUMBER, body=message)

    await asyncio.to_thread(_send)


async def send_email(to: str, subject: str, body: str) -> None:
    """Envoie un email via SMTP. Configuration lue dynamiquement depuis
    `PlatformConfig` (Paramètres → Email, super-admin) — modifiable sans
    redéploiement, contrairement à settings.SMTP_* (.env), gardées en repli
    uniquement si la base n'a rien de configuré (ex. dev). Journalise le
    message au lieu d'échouer si ni l'un ni l'autre n'est configuré."""
    from sqlmodel import select

    from app.core.db import async_session_maker
    from app.models.platform_config import PlatformConfig

    async with async_session_maker() as session:
        result = await session.execute(select(PlatformConfig).limit(1))
        config = result.scalar_one_or_none()

    smtp_host = (config.smtp_host if config else None) or settings.SMTP_HOST
    smtp_port = (config.smtp_port if config else None) or settings.SMTP_PORT
    smtp_user = (config.smtp_user if config else None) or settings.SMTP_USER
    smtp_password = (config.smtp_password if config else None) or settings.SMTP_PASSWORD
    smtp_from = (config.smtp_from_email if config else None) or settings.SMTP_FROM_EMAIL

    if not (smtp_host and smtp_from):
        logger.info("[Email fallback] to=%s subject=%s: %s", to, subject, body)
        return

    message = EmailMessage()
    message["From"] = smtp_from
    message["To"] = to
    message["Subject"] = subject
    message.set_content(body)

    await aiosmtplib.send(
        message,
        hostname=smtp_host,
        port=smtp_port,
        username=smtp_user,
        password=smtp_password,
        start_tls=True,
    )
