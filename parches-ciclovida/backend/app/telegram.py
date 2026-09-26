"""Bot de Telegram (opcional): las funciones clave de la app, empatadas en el chat.

Con TELEGRAM_TOKEN y TELEGRAM_BOT configurados:
- El joven vincula su cuenta abriendo t.me/<bot>?start=<código> desde la app.
- Por el chat recibe los avisos (su espera encontró parche, su grupo del sábado quedó listo).
- Y puede usar comandos que espejan la app:
    /parche    su estado de este domingo (parche, grupo, punto de encuentro)
    /confirmo  confirmar que va (igual que el botón de la app)
    /novoy     avisar que no va
    /ayuda     la lista de comandos

Sin token, todo esto se apaga y la app solo muestra el aviso interno.
"""

from __future__ import annotations

import logging

import httpx
from sqlmodel import Session, select

from . import config
from .models import Joven

log = logging.getLogger("parches.telegram")
_offset = 0  # último update procesado de getUpdates

AYUDA = (
    "Esto es lo que puedo hacer:\n"
    "/parche — tu parche de este domingo\n"
    "/confirmo — confirmar que vas\n"
    "/novoy — avisar que no vas\n"
    "/ayuda — este mensaje\n"
    "Para todo lo demás (elegir parche, foro, mapa) está la app 📱"
)


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


def iniciar() -> str | None:
    """Al arrancar el servidor: valida el token, resuelve el @ del bot y registra el menú.

    Con esto solo hace falta TELEGRAM_TOKEN en el .env: el nombre sale de getMe,
    y el chat muestra los comandos en el botón de menú de Telegram.
    """
    if not disponible():
        return None
    yo = _api("getMe")
    if not yo:
        log.warning("TELEGRAM_TOKEN configurado pero getMe falló: revisa el token o la red")
        return None
    if not config.TELEGRAM_BOT:
        config.TELEGRAM_BOT = yo.get("username", "")
    _api("setMyCommands", commands=[
        {"command": "parche", "description": "Tu parche de este domingo"},
        {"command": "confirmo", "description": "Confirmar que vas"},
        {"command": "novoy", "description": "Avisar que no vas"},
        {"command": "ayuda", "description": "Qué puede hacer este bot"},
    ])
    log.info("Bot de Telegram listo: @%s", config.TELEGRAM_BOT)
    return config.TELEGRAM_BOT


def procesar_updates(session: Session) -> None:
    """Lee los mensajes pendientes del bot y atiende cada uno."""
    global _offset
    if not disponible():
        return
    updates = _api("getUpdates", offset=_offset, timeout=0) or []
    for u in updates:
        _offset = max(_offset, u["update_id"] + 1)
        msg = u.get("message") or {}
        texto = (msg.get("text") or "").strip()
        chat_id = str((msg.get("chat") or {}).get("id", ""))
        if chat_id and texto:
            atender(session, chat_id, texto)


def atender(session: Session, chat_id: str, texto: str) -> None:
    """Un mensaje del chat: vincular con /start <código> o atender un comando."""
    from . import services

    joven = session.exec(select(Joven).where(Joven.telegram_chat_id == chat_id)).first()
    partes = texto.split()
    comando = partes[0].lower().split("@")[0] if partes else ""

    if comando == "/start":
        codigo = partes[1].strip() if len(partes) > 1 else ""
        candidato = session.exec(select(Joven).where(Joven.telegram_codigo == codigo)).first() if codigo else None
        if candidato:
            candidato.telegram_chat_id = chat_id
            session.add(candidato)
            session.commit()
            enviar(chat_id, f"¡Listo, {candidato.nombre}! Por aquí te aviso cuando encontremos parche para ti 🚲\n\n{AYUDA}")
        elif joven:
            enviar(chat_id, f"Tu cuenta ya está vinculada, {joven.nombre}.\n\n{AYUDA}")
        else:
            enviar(chat_id, "Para vincular tu cuenta, abre Parches CicloVida y toca «Conectar Telegram».")
        return

    if joven is None:
        enviar(chat_id, "No reconozco este chat. Abre Parches CicloVida y toca «Conectar Telegram» para vincularlo.")
        return

    if comando in ("/parche", "/estado"):
        enviar(chat_id, _resumen_estado(services.estado_para(session, joven)))
    elif comando in ("/confirmo", "/novoy"):
        va = comando == "/confirmo"
        try:
            services.responder(session, joven, va)
            enviar(chat_id, "¡Buena! Tu parche ya sabe que vas 🚴 Nos vemos el domingo."
                   if va else "Gracias por avisar: tu parche ya lo sabe. ¡Que sea el próximo domingo!")
        except LookupError as e:
            enviar(chat_id, str(e))
    elif comando in ("/ayuda", "/help"):
        enviar(chat_id, AYUDA)
    else:
        enviar(chat_id, f"No te entendí 😅\n\n{AYUDA}")


def _resumen_estado(info: dict) -> str:
    """El mismo estado que muestra la pantalla de inicio, contado en un mensaje."""
    fecha = info["jornada"]["fecha"]
    estado = info["estado"]
    if estado == "asignado":
        g = info["grupo"]
        otros = ", ".join(m["nombre"] for m in g["miembros"] if not m["soy_yo"])
        return (
            f"<b>{g['nombre']}</b> · domingo {fecha}\n"
            f"{g['actividad_nombre']} a las {g['hora_nombre']}\n"
            f"📍 {g['punto_encuentro']} ({g['referencia']})\n"
            f"Van contigo: {otros or 'por definir'}\n"
            f"{g['confirmados']} de {len(g['miembros'])} han confirmado. Responde /confirmo o /novoy."
        )
    if estado == "inscrito":
        s = info["salida"]
        return (
            f"Estás en el <b>{s['nombre']}</b> · domingo {fecha}\n"
            f"{s['actividad_nombre']} a las {s['hora_nombre']} en {s['tramo']['nombre']}.\n"
            "El sábado a las 5:00 p. m. armamos tu grupo y te aviso por aquí."
        )
    if estado == "en_espera":
        return "Sigo buscando un parche con tus mismos planes 🔍 Apenas aparezca, te aviso por aquí."
    if estado == "pausado":
        return "Esta semana estás descansando. Si cambias de idea, elige un parche en la app."
    if estado == "suspendido":
        return "Tu cuenta está en revisión. Si crees que es un error, escríbenos desde la app."
    return f"Aún no tienes parche para el domingo {fecha}. Abre la app y te buscamos uno al toque."
