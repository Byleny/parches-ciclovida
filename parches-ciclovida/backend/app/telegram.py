"""Bot de Telegram (opcional).

Con TELEGRAM_TOKEN y TELEGRAM_BOT configurados, el joven vincula su cuenta abriendo
t.me/<bot>?start=<código> desde la app; el bot recibe "/start <código>", guarda el chat
y por ahí le avisa cuando su espera encuentra parche. Sin token, todo esto se apaga
y la app solo muestra el aviso interno.
"""

from __future__ import annotations

import logging

import httpx
from sqlmodel import Session, select

from . import config
from .models import Joven

log = logging.getLogger("parches.telegram")
_offset = 0  # último update procesado de getUpdates


def disponible() -> bool:
    return bool(config.TELEGRAM_TOKEN)


def enlace_para(codigo: str) -> str | None:
    if not disponible() or not config.TELEGRAM_BOT:
        return None
    return f"https://t.me/{config.TELEGRAM_BOT}?start={codigo}"


def _api(metodo: str, **params):
    if not disponible():
        return None
    try:
        r = httpx.post(f"https://api.telegram.org/bot{config.TELEGRAM_TOKEN}/{metodo}", json=params, timeout=10)
        data = r.json()
        return data.get("result") if data.get("ok") else None
    except Exception as e:  # la app nunca se cae por Telegram
        log.warning("Telegram no respondió (%s): %s", metodo, e)
        return None


def enviar(chat_id: str, texto: str) -> None:
    _api("sendMessage", chat_id=chat_id, text=texto, parse_mode="HTML")


def procesar_updates(session: Session) -> None:
    """Lee los "/start <código>" pendientes y vincula cada chat con su joven."""
    global _offset
    if not disponible():
        return
    updates = _api("getUpdates", offset=_offset, timeout=0) or []
    for u in updates:
        _offset = max(_offset, u["update_id"] + 1)
        msg = u.get("message") or {}
        texto = (msg.get("text") or "").strip()
        chat_id = str((msg.get("chat") or {}).get("id", ""))
        if not chat_id or not texto.startswith("/start"):
            continue
        partes = texto.split(maxsplit=1)
        codigo = partes[1].strip() if len(partes) == 2 else ""
        joven = session.exec(select(Joven).where(Joven.telegram_codigo == codigo)).first() if codigo else None
        if joven:
            joven.telegram_chat_id = chat_id
            session.add(joven)
            session.commit()
            enviar(chat_id, f"¡Listo, {joven.nombre}! Por aquí te avisamos cuando encontremos parche para ti 🚲")
        else:
            enviar(chat_id, "Para vincular tu cuenta, abre Parches CicloVida y toca «Conectar Telegram».")
