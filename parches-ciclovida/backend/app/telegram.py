"""Bot de Telegram (opcional): las funciones clave de la app, empatadas en el chat.

Con TELEGRAM_TOKEN en backend/.env:
- El joven vincula su cuenta abriendo t.me/<bot>?start=<código> desde la app.
- Por el chat recibe los avisos (propuesta de parche, match encontrado, grupo del sábado).
- Y puede hacer desde el chat, con botones:
    /parche    ver su parche o, si aún no tiene, la propuesta que más se ajusta y unirse
    /confirmo  confirmar que va (también con botón en el aviso del sábado)
    /novoy     avisar que no va
    /foro      publicar un mensaje en el foro comunal (solo publicar; leer es en la app)
    /ayuda     la lista de comandos

Sin token, todo esto se apaga y la app solo muestra el aviso interno.
"""

from __future__ import annotations

import logging
from html import escape as h

import httpx
from sqlmodel import Session, select

from . import asistente, config
from .models import Joven

log = logging.getLogger("parches.telegram")
_offset = 0  # último update procesado de getUpdates

# Estado de conversación del foro, por chat. En memoria: el bot corre en una sola instancia.
_foro_esperando: set[str] = set()  # chats a los que se les pidió escribir el mensaje
_foro_pendiente: dict[str, str] = {}  # texto listo, falta elegir la categoría

Botones = list[list[tuple[str, str]]]  # filas de (texto del botón, callback_data)

AYUDA = (
    "Esto es lo que puedo hacer:\n"
    "/parche — tu parche, o uno para elegir ahora mismo\n"
    "/confirmo — confirmar que vas\n"
    "/novoy — avisar que no vas\n"
    "/foro — publicar un mensaje en el foro\n"
    "/ayuda — este mensaje\n"
    "Leer el foro y ver el mapa es en la app 📱"
)
AYUDA_CONVERSACION = (
    "También puedes escribirme normal, como a un parcero 🗣️ Por ejemplo: «quiero trotar el domingo "
    "temprano», «¿quién va conmigo?» o «publica en el foro que me encantó el parche»."
)


def _ayuda() -> str:
    return f"{AYUDA}\n\n{AYUDA_CONVERSACION}" if asistente.disponible() else AYUDA


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
        if not data.get("ok"):
            log.warning("Telegram rechazó %s: %s", metodo, data.get("description"))
        return data.get("result") if data.get("ok") else None
    except Exception as e:  # la app nunca se cae por Telegram
        log.warning("Telegram no respondió (%s): %s", metodo, e)
        return None


def enviar(chat_id: str, texto: str, botones: Botones | None = None) -> None:
    params: dict = {"chat_id": chat_id, "text": texto, "parse_mode": "HTML"}
    if botones:
        params["reply_markup"] = {
            "inline_keyboard": [[{"text": t, "callback_data": d} for t, d in fila] for fila in botones]
        }
    _api("sendMessage", **params)


def iniciar() -> str | None:
    """Al arrancar el servidor: valida el token, resuelve el @ del bot y registra el menú."""
    if not disponible():
        return None
    yo = _api("getMe")
    if not yo:
        log.warning("TELEGRAM_TOKEN configurado pero getMe falló: revisa el token o la red")
        return None
    real = yo.get("username", "")
    # El @ que dice Telegram manda: si el .env trae otro nombre, el enlace t.me
    # llevaría a un bot ajeno y el /start nunca llegaría a este.
    if config.TELEGRAM_BOT and config.TELEGRAM_BOT.lstrip("@").lower() != real.lower():
        log.warning("TELEGRAM_BOT=%s no coincide con el bot del token (@%s): se usa @%s",
                    config.TELEGRAM_BOT, real, real)
    config.TELEGRAM_BOT = real
    _api("setMyCommands", commands=[
        {"command": "parche", "description": "Tu parche, o uno para elegir ya"},
        {"command": "confirmo", "description": "Confirmar que vas"},
        {"command": "novoy", "description": "Avisar que no vas"},
        {"command": "foro", "description": "Publicar en el foro"},
        {"command": "ayuda", "description": "Qué puede hacer este bot"},
    ])
    log.info("Bot de Telegram listo: @%s", config.TELEGRAM_BOT)
    return config.TELEGRAM_BOT


# ---------------------------------------------------------------- recepción

def procesar_updates(session: Session) -> None:
    """Lee los mensajes y toques de botón pendientes del bot y atiende cada uno."""
    global _offset
    if not disponible():
        return
    updates = _api("getUpdates", offset=_offset, timeout=0) or []
    for u in updates:
        _offset = max(_offset, u["update_id"] + 1)
        try:
            if "callback_query" in u:
                cq = u["callback_query"]
                _api("answerCallbackQuery", callback_query_id=cq["id"])
                msg = cq.get("message") or {}
                chat_id = str((msg.get("chat") or {}).get("id", ""))
                if chat_id:
                    atender_boton(session, chat_id, cq.get("data") or "", msg.get("message_id"))
                continue
            msg = u.get("message") or {}
            texto = (msg.get("text") or "").strip()
            chat_id = str((msg.get("chat") or {}).get("id", ""))
            if chat_id and texto:
                atender(session, chat_id, texto)
        except Exception:  # un mensaje raro no debe tumbar a los demás
            log.exception("Error atendiendo un update de Telegram")
            session.rollback()


def _joven_de(session: Session, chat_id: str) -> Joven | None:
    return session.exec(select(Joven).where(Joven.telegram_chat_id == chat_id)).first()


def atender(session: Session, chat_id: str, texto: str) -> None:
    """Un mensaje de texto: vincular con /start <código>, un comando o el texto del foro."""
    joven = _joven_de(session, chat_id)
    partes = texto.split(maxsplit=1)
    comando = partes[0].lower().split("@")[0] if partes and partes[0].startswith("/") else ""
    resto = partes[1].strip() if len(partes) > 1 else ""

    if comando == "/start":
        candidato = session.exec(select(Joven).where(Joven.telegram_codigo == resto)).first() if resto else None
        if candidato:
            candidato.telegram_chat_id = chat_id
            session.add(candidato)
            session.commit()
            enviar(chat_id, f"¡Listo, {h(candidato.nombre)}! Ya quedamos conectados 🚲\n\n{_ayuda()}")
            enviar_estado(session, chat_id, candidato)
        elif joven:
            enviar(chat_id, f"Tu cuenta ya está vinculada, {h(joven.nombre)}.\n\n{_ayuda()}")
        else:
            enviar(chat_id, "Para vincular tu cuenta, abre Parches CicloVida y toca «Conectar Telegram».")
        return

    if joven is None:
        enviar(chat_id, "No reconozco este chat. Abre Parches CicloVida y toca «Conectar Telegram» para vincularlo.")
        return

    # Texto suelto mientras el bot espera el mensaje del foro
    if not comando and chat_id in _foro_esperando:
        _foro_esperando.discard(chat_id)
        _preguntar_categoria(chat_id, texto)
        return
    if comando:  # cualquier comando cancela un foro a medias
        _foro_esperando.discard(chat_id)
    else:
        _conversar(session, chat_id, joven, texto)
        return

    if comando in ("/parche", "/estado", "/elegir"):
        enviar_estado(session, chat_id, joven, buscar=True)
    elif comando in ("/confirmo", "/novoy"):
        _responder(session, chat_id, joven, comando == "/confirmo")
    elif comando == "/foro":
        if resto:
            _preguntar_categoria(chat_id, resto)
        else:
            _foro_esperando.add(chat_id)
            enviar(chat_id, "¡Dale! Escríbeme lo que quieras contarle a la comunidad: cómo te fue en tu "
                            "parche, qué mejorarías de la app o cómo te sientes. Para salir, /cancelar.")
    elif comando == "/cancelar":
        _foro_pendiente.pop(chat_id, None)
        asistente.olvidar(chat_id)
        enviar(chat_id, "Listo, cancelado. Empezamos de cero cuando quieras.")
    elif comando in ("/ayuda", "/help"):
        enviar(chat_id, _ayuda())
    else:
        enviar(chat_id, f"Ese comando no lo conozco 😅\n\n{_ayuda()}")


def _conversar(session: Session, chat_id: str, joven: Joven, texto: str) -> None:
    """Texto libre: con Gemini, conversación; sin key, una guía hacia los comandos."""
    from . import services

    if not asistente.disponible():
        enviar(chat_id, f"Por ahora entiendo comandos 🙂\n\n{AYUDA}")
        return
    _api("sendChatAction", chat_id=chat_id, action="typing")
    try:
        respuesta, mostrados = asistente.conversar(session, joven, chat_id, texto)
    except asistente.GeminiNoDisponible:
        # Plan B: aunque no pueda conversar, le cuenta lo más útil (su parche) con los botones de siempre.
        enviar(chat_id, "Uy, ahorita tengo mucha gente hablándome y se me enredó la cadena 🚲 "
                        "Escríbeme de nuevo en un minutico. Mientras tanto, esto es lo que sé de tu parche:")
        enviar_estado(session, chat_id, joven)
        return
    botones: Botones = []
    # Los parches que el asistente mencionó también quedan como botones, por si es más fácil tocar.
    if mostrados and services.estado_para(session, joven)["estado"] not in ("inscrito", "asignado"):
        vistos: set[int] = set()
        for p in mostrados:
            if p["parche_id"] not in vistos and len(vistos) < 3:
                vistos.add(p["parche_id"])
                botones.append([(f"Unirme a {p['nombre']} · {p['hora']}", f"unir:{p['parche_id']}")])
    enviar(chat_id, asistente.a_html(respuesta), botones or None)


def atender_boton(session: Session, chat_id: str, data: str, message_id: int | None = None) -> None:
    """Un toque en un botón del chat."""
    from . import services

    joven = _joven_de(session, chat_id)
    if joven is None:
        enviar(chat_id, "No reconozco este chat. Abre Parches CicloVida y toca «Conectar Telegram».")
        return
    if message_id is not None:  # la decisión ya se tomó: el mensaje queda sin botones
        _api("editMessageReplyMarkup", chat_id=chat_id, message_id=message_id, reply_markup={"inline_keyboard": []})

    accion, _, valor = data.partition(":")
    if accion == "unir" and valor.isdigit():
        _unirse(session, chat_id, joven, int(valor))
    elif accion == "opciones":
        _enviar_opciones(session, chat_id, joven)
    elif accion == "esperar":
        enviar(chat_id, "Perfecto, sigo buscando tu match 🔍 Apenas alguien encaje contigo, te aviso por aquí.")
    elif accion in ("confirmo", "novoy"):
        _responder(session, chat_id, joven, accion == "confirmo")
    elif accion == "foro":
        texto = _foro_pendiente.pop(chat_id, None)
        if valor == "cancelar" or texto is None:
            enviar(chat_id, "Listo, no publiqué nada." if valor == "cancelar"
                   else "Ese mensaje ya no está. Escribe /foro para publicar uno nuevo.")
            return
        _publicar_foro(session, chat_id, joven, valor, texto)
    elif accion == "parche":
        enviar_estado(session, chat_id, joven, buscar=True)


# ---------------------------------------------------------------- parche

def enviar_estado(session: Session, chat_id: str, joven: Joven, buscar: bool = False) -> None:
    """Lo mismo que muestra la pantalla de inicio, contado en el chat y con botones.

    Con `buscar`, si aún no tiene parche corre el match automático, igual que la app.
    """
    from . import services

    info = services.estado_para(session, joven)
    if buscar and info["estado"] == "sin_parche":
        services.emparejar_automatico(session, joven, avisar_telegram=False)
        info = services.estado_para(session, joven)
        if info["estado"] == "inscrito":
            s = info["salida"]
            enviar(chat_id, f"¡Match! 🎉 Te uní al <b>{h(s['nombre'])}</b>: hay gente con tus mismos planes.\n\n"
                            + _resumen_estado(info))
            return
    if info["estado"] == "en_espera":
        propuesta = propuesta_para(session, joven, info)
        if propuesta:
            enviar(chat_id, *propuesta)
            return
    if info["estado"] == "asignado":
        enviar(chat_id, _resumen_estado(info), [[("✅ Confirmo, voy", "confirmo"), ("❌ No voy", "novoy")]])
        return
    enviar(chat_id, _resumen_estado(info))


def propuesta_para(session: Session, joven: Joven, info: dict | None = None) -> tuple[str, Botones] | None:
    """"Hola X, todavía no tenemos parche confirmado…" con el parche que más se ajusta y sus botones."""
    from . import services

    info = info or services.estado_para(session, joven)
    p = (info.get("espera") or {}).get("mas_parecido")
    if not p:
        return None
    gente = ("Aún no hay nadie inscrito: ¡puedes ser quien lo arranque!" if p["inscritos"] == 0
             else f"Ya van {p['inscritos']} {'estudiante' if p['inscritos'] == 1 else 'estudiantes'}.")
    texto = (
        f"Hola {h(joven.nombre)}, todavía no tenemos parche confirmado: estamos buscando un match "
        "perfecto para ti 🔍\n\nPero si quieres elegir uno ahora mismo, este es el que más se ajusta "
        f"a tus preferencias:\n\n{_ficha(p)}\n{gente}"
    )
    botones = [
        [("✅ Unirme a este parche", f"unir:{p['id']}")],
        [("🔎 Ver otras opciones", "opciones")],
        [("⏳ Prefiero esperar el match", "esperar")],
    ]
    return texto, botones


def _ficha(p: dict) -> str:
    return (
        f"<b>{h(p['nombre'])}</b>\n"
        f"{h(p['actividad_nombre'])} a las {h(p['hora_nombre'])} · Estación {h(p['tramo']['nombre'])}\n"
        f"📍 {h(p['punto_encuentro'])} ({h(p['referencia'])})"
    )


def _enviar_opciones(session: Session, chat_id: str, joven: Joven) -> None:
    from . import services

    info = services.estado_para(session, joven)
    ya = (info.get("espera") or {}).get("mas_parecido") or {}
    opciones = [s for s in services.sugerencias_para(session, joven, limite=5) if s["id"] != ya.get("id")][:4]
    if not opciones:
        enviar(chat_id, "Por ahora no hay otras opciones parecidas. En la app puedes ver todos los parches.")
        return
    lineas = [f"{i + 1}. {_ficha(s)}\n   {s['inscritos']} inscritos" for i, s in enumerate(opciones)]
    botones = [[(f"{i + 1}. Unirme a {s['nombre']}", f"unir:{s['id']}")] for i, s in enumerate(opciones)]
    botones.append([("⏳ Prefiero esperar el match", "esperar")])
    enviar(chat_id, "Otras opciones que te pueden servir:\n\n" + "\n\n".join(lineas), botones)


def _unirse(session: Session, chat_id: str, joven: Joven, salida_id: int) -> None:
    from . import services

    info = services.estado_para(session, joven)
    actual = (info.get("salida") or {}).get("id")
    if info["estado"] in ("inscrito", "asignado") and actual != salida_id:
        # Cambiarse de parche deja un lugar libre en un grupo: esa decisión se toma en la app.
        enviar(chat_id, "Ya estás en otro parche. Si quieres cambiarte, hazlo desde la app.")
        return
    try:
        services.unirse(session, joven, salida_id)
    except LookupError as e:
        enviar(chat_id, h(str(e)))
        return
    info = services.estado_para(session, joven)
    enviar(chat_id, "¡Listo! Te uniste 🙌\n\n" + _resumen_estado(info))


def _responder(session: Session, chat_id: str, joven: Joven, va: bool) -> None:
    from . import services

    try:
        services.responder(session, joven, va)
        enviar(chat_id, "¡Buena! Tu parche ya sabe que vas 🚴 Nos vemos el domingo."
               if va else "Gracias por avisar: tu parche ya lo sabe. ¡Que sea el próximo domingo!")
    except LookupError as e:
        enviar(chat_id, h(str(e)))


def _resumen_estado(info: dict) -> str:
    """El mismo estado que muestra la pantalla de inicio, contado en un mensaje."""
    fecha = info["jornada"]["fecha"]
    estado = info["estado"]
    if estado == "asignado":
        g = info["grupo"]
        otros = ", ".join(h(m["nombre"]) for m in g["miembros"] if not m["soy_yo"])
        return (
            f"<b>{h(g['nombre'])}</b> · domingo {fecha}\n"
            f"{h(g['actividad_nombre'])} a las {h(g['hora_nombre'])}\n"
            f"📍 {h(g['punto_encuentro'])} ({h(g['referencia'])})\n"
            f"Van contigo: {otros or 'por definir'}\n"
            f"{g['confirmados']} de {len(g['miembros'])} han confirmado."
        )
    if estado == "inscrito":
        s = info["salida"]
        return (
            f"Estás en el <b>{h(s['nombre'])}</b> · domingo {fecha}\n"
            f"{h(s['actividad_nombre'])} a las {h(s['hora_nombre'])} en {h(s['tramo']['nombre'])}.\n"
            "El sábado a las 5:00 p. m. armamos tu grupo y te aviso por aquí."
        )
    if estado == "en_espera":
        return "Sigo buscando un parche con tus mismos planes 🔍 Apenas aparezca, te aviso por aquí."
    if estado == "pausado":
        return "Esta semana estás descansando. Si cambias de idea, elige un parche en la app."
    if estado == "suspendido":
        return "Tu cuenta está en revisión. Si crees que es un error, escríbenos desde la app."
    return f"Aún no tienes parche para el domingo {fecha}. Escribe /parche y te busco uno al toque."


# ---------------------------------------------------------------- foro

def _preguntar_categoria(chat_id: str, texto: str) -> None:
    from .catalog import FORO_CATEGORIAS

    texto = texto.strip()
    if len(texto) < 2:
        enviar(chat_id, "Ese mensaje quedó muy corto. Escribe /foro y cuéntanos un poco más.")
        return
    if len(texto) > config.FORO_MAX:
        enviar(chat_id, f"Ese mensaje es muy largo (máximo {config.FORO_MAX} caracteres). Intenta resumirlo con /foro.")
        return
    _foro_pendiente[chat_id] = texto
    botones = [[(c["nombre"], f"foro:{c['id']}")] for c in FORO_CATEGORIAS]
    botones.append([("Cancelar", "foro:cancelar")])
    enviar(chat_id, "¿En qué tema lo publico?", botones)


def _publicar_foro(session: Session, chat_id: str, joven: Joven, categoria: str, texto: str) -> None:
    from . import services
    from .catalog import FORO_CATEGORIAS, FORO_IDS

    if categoria not in FORO_IDS:
        enviar(chat_id, "Ese tema no existe. Escribe /foro para intentarlo de nuevo.")
        return
    try:
        services.foro_publicar(session, joven, categoria, texto)
    except LookupError as e:
        enviar(chat_id, h(str(e)))
        return
    nombre = next(c["nombre"] for c in FORO_CATEGORIAS if c["id"] == categoria)
    enviar(chat_id, f"¡Publicado en «{h(nombre)}»! ✅ Lo ves junto a los demás en la pestaña Foro de la app.")
