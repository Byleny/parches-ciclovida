"""Emparejamiento automático (match), lista de espera, notificaciones y foro comunal."""

from datetime import timedelta

from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app import services
from app.db import engine
from app.main import app
from app.models import Espera, Joven
from test_api import ADMIN, armar, auth, estado, nuevo, parche, setup_function, unir  # noqa: F401


def test_preferencias_persisten_incluso_al_limpiarlas():
    with TestClient(app) as c:
        ana = nuevo(c, "Ana")  # se registra con estación panamericana
        # volver a "Cualquiera" (null) también debe guardarse
        r = c.patch("/api/yo", json={"tramo_id": None, "franja": None}, headers=auth(ana))
        assert r.status_code == 200 and r.json()["tramo_id"] is None
        # y un cambio normal persiste al volver a consultar
        r = c.patch("/api/yo", json={"comuna": 2, "actividad": "trotar", "ritmo": "rapido"}, headers=auth(ana))
        assert r.status_code == 200
        yo = c.get("/api/yo", headers=auth(ana)).json()
        assert yo["comuna"] == 2 and yo["actividad"] == "trotar" and yo["ritmo"] == "rapido"
        assert yo["tramo_id"] is None


def test_historial_muestra_parches_pasados_y_su_gente():
    with TestClient(app) as c:
        tokens = [nuevo(c, n) for n in ["Ana", "Luis", "Sara"]]
        p = parche(c, tokens[0])
        for t in tokens:
            unir(c, t, p["id"])

        # antes de que termine la jornada no hay historial
        assert c.get("/api/yo/historial", headers=auth(tokens[0])).json() == []

        armar(c)
        c.post("/api/admin/finalizar", headers=ADMIN)
        c.post("/api/yo/encuesta", json={"asistio": True, "volveria": True, "bienestar": 5}, headers=auth(tokens[0]))

        h = c.get("/api/yo/historial", headers=auth(tokens[0])).json()
        assert len(h) == 1
        assert h[0]["asistio"] is True and h[0]["volveria"] is True
        g = h[0]["grupo"]
        assert len(g["miembros"]) == 3 and g["miembros"][0]["soy_yo"]
        assert {m["nombre"] for m in g["miembros"]} == {"Ana", "Luis", "Sara"}

        # quien no respondió la encuesta ve el domingo con asistencia sin responder
        h2 = c.get("/api/yo/historial", headers=auth(tokens[1])).json()
        assert len(h2) == 1 and h2[0]["asistio"] is None


def test_declaracion_de_mayoria_de_edad_obligatoria_y_con_constancia():
    from test_api import codigo, registro

    with TestClient(app) as c:
        correo = "mayor@usbcali.edu.co"
        # sin la casilla marcada: rechazado con mensaje claro
        datos = registro("Ana", correo=correo, codigo=codigo(c, correo), declara_mayor=False)
        r = c.post("/api/jovenes", json=datos)
        assert r.status_code == 422 and "18" in r.text

        # con la casilla: pasa, y queda la constancia con fecha en la base
        datos["declara_mayor"] = True
        datos["codigo"] = codigo(c, correo)
        r = c.post("/api/jovenes", json=datos)
        assert r.status_code == 201
        with Session(engine) as s:
            j = s.exec(select(Joven)).one()
            assert j.declara_mayor is True and j.declara_mayor_en is not None


def test_ingreso_con_el_mismo_correo():
    with TestClient(app) as c:
        correo = "vuelve@usbcali.edu.co"
        token = nuevo(c, "Ana", correo=correo)

        # pedir código "para registro" con un correo ya registrado: rechazado con guía
        r = c.post("/api/verificacion", json={"correo": correo})
        assert r.status_code == 409 and "Ya tengo cuenta" in r.json()["detail"]

        # para ingreso sí, y la sesión que devuelve es la misma cuenta de siempre
        r = c.post("/api/verificacion", json={"correo": correo, "para": "ingreso"})
        assert r.status_code == 200
        codigo = r.json()["codigo_demo"]
        s = c.post("/api/sesiones", json={"correo": correo, "codigo": codigo})
        assert s.status_code == 200
        assert s.json()["token"] == token and s.json()["joven"]["nombre"] == "Ana"

        # ingreso con un correo sin cuenta: rechazado al pedir el código
        r = c.post("/api/verificacion", json={"correo": "nadie@usbcali.edu.co", "para": "ingreso"})
        assert r.status_code == 409

        # código equivocado: rechazado
        r = c.post("/api/verificacion", json={"correo": correo, "para": "ingreso"})
        malo = "000000" if r.json()["codigo_demo"] != "000000" else "111111"
        assert c.post("/api/sesiones", json={"correo": correo, "codigo": malo}).status_code == 422


def test_espera_ofrece_el_mas_parecido_aunque_este_vacio():
    with TestClient(app) as c:
        ana = nuevo(c, "Ana")  # bici en Panamericana, sin nadie más
        e = c.post("/api/yo/match", headers=auth(ana)).json()
        assert e["estado"] == "en_espera"
        p = e["espera"]["mas_parecido"]
        assert p is not None and p["tramo"]["id"] == "panamericana" and p["actividad"] == "bici"
        assert p["inscritos"] == 0
        # "Unirme igual": toma la iniciativa y estrena el parche
        r = unir(c, ana, p["id"])
        assert r.status_code == 200 and r.json()["estado"] == "inscrito"


def match(c, tok):
    return c.post("/api/yo/match", headers=auth(tok)).json()


def test_match_automatico_une_al_parche_con_gente():
    with TestClient(app) as c:
        luis = nuevo(c, "Luis")
        p = parche(c, luis)  # bici, panamericana, 8:00
        unir(c, luis, p["id"])

        # Ana tiene las mismas preferencias: el match la une al parche de Luis sin que elija
        ana = nuevo(c, "Ana")
        e = match(c, ana)
        assert e["estado"] == "inscrito" and e["salida"]["id"] == p["id"]


def test_match_prefiere_el_parche_mas_afin():
    with TestClient(app) as c:
        # dos parches de bici en Panamericana con gente: 8:00 (ritmo rápido) y 9:30 (moderado)
        luis = nuevo(c, "Luis", ritmo="rapido")
        p8 = parche(c, luis, franja="08:00")
        unir(c, luis, p8["id"])
        sara = nuevo(c, "Sara", ritmo="moderado")
        p930 = parche(c, sara, franja="09:30")
        unir(c, sara, p930["id"])

        # Ana es moderada y sin hora preferida: queda con Sara, no con Luis
        ana = nuevo(c, "Ana", ritmo="moderado")
        e = match(c, ana)
        assert e["estado"] == "inscrito" and e["salida"]["id"] == p930["id"]


def test_espera_y_aviso_cuando_aparece_parche():
    with TestClient(app) as c:
        # nadie más inscrito: Ana queda en lista de espera
        ana = nuevo(c, "Ana")
        e = match(c, ana)
        assert e["estado"] == "en_espera" and e["espera"]["sugerencias"] == []

        # pedir match otra vez no duplica la espera
        match(c, ana)
        with Session(engine) as s:
            assert len(s.exec(select(Espera)).all()) == 1

        # Luis se une a un parche compatible; el tick revisa las esperas y une a Ana
        luis = nuevo(c, "Luis")
        p = parche(c, luis)
        unir(c, luis, p["id"])
        with Session(engine) as s:
            assert services.revisar_esperas(s) == 1

        e = estado(c, ana)
        assert e["estado"] == "inscrito" and e["salida"]["id"] == p["id"]

        # y le queda la notificación, que puede marcar como leída
        notis = c.get("/api/yo/notificaciones", headers=auth(ana)).json()
        assert len(notis) == 1 and not notis[0]["leida"] and "parche" in notis[0]["titulo"].lower()
        c.post("/api/yo/notificaciones/leidas", headers=auth(ana))
        assert c.get("/api/yo/notificaciones", headers=auth(ana)).json()[0]["leida"]


def test_espera_larga_muestra_sugerencias():
    with TestClient(app) as c:
        ana = nuevo(c, "Ana")
        assert match(c, ana)["estado"] == "en_espera"
        # un parche parecido (patines: misma familia sobre ruedas) con gente, en otra estación
        kev = nuevo(c, "Kevin", actividad="patines", tramo_id="ingenio")
        p = parche(c, kev, tramo="ingenio", actividad="patines")
        unir(c, kev, p["id"])

        # todavía no pasa el lapso: sin sugerencias
        assert estado(c, ana)["espera"]["sugerencias"] == []

        # envejecemos la espera y aparecen, con el parche con gente de primero
        with Session(engine) as s:
            esp = s.exec(select(Espera)).one()
            esp.creado_en = esp.creado_en - timedelta(minutes=60)
            s.add(esp)
            s.commit()
        e = estado(c, ana)
        sug = e["espera"]["sugerencias"]
        assert sug and sug[0]["id"] == p["id"] and sug[0]["inscritos"] == 1

        # cancelar la espera la borra
        e = c.delete("/api/yo/espera", headers=auth(ana)).json()
        assert e["estado"] == "sin_parche"


def test_unirse_a_mano_borra_la_espera():
    with TestClient(app) as c:
        ana = nuevo(c, "Ana")
        assert match(c, ana)["estado"] == "en_espera"
        p = parche(c, ana)
        unir(c, ana, p["id"])
        with Session(engine) as s:
            assert s.exec(select(Espera)).first() is None


SOCIAL = {"1": "a", "2": "a", "3": "b", "4": "a", "5": "a"}
CASERO = {"1": "b", "2": "b", "3": "a", "4": "b", "5": "b"}


def test_quiz_es_opcional_valida_y_privado():
    with TestClient(app) as c:
        cat = c.get("/api/catalogo").json()
        assert len(cat["quiz"]["preguntas"]) == 5

        ana = nuevo(c, "Ana")
        assert c.get("/api/yo", headers=auth(ana)).json()["quiz_respondido"] is False

        # incompleto o con una opción inventada: rechazado
        assert c.post("/api/yo/quiz", json={"respuestas": {"1": "a"}}, headers=auth(ana)).status_code == 422
        malas = {**SOCIAL, "3": "z"}
        assert c.post("/api/yo/quiz", json={"respuestas": malas}, headers=auth(ana)).status_code == 422

        assert c.post("/api/yo/quiz", json={"respuestas": SOCIAL}, headers=auth(ana)).status_code == 200
        # el perfil solo dice que lo respondió: las respuestas y puntajes nunca salen del servidor
        yo = c.get("/api/yo", headers=auth(ana)).json()
        assert yo["quiz_respondido"] is True
        assert "quiz" not in yo and "respuestas" not in yo


def test_match_usa_el_quiz_solo_como_desempate():
    """Dos parches iguales en lo estructural (misma comuna, hora y actividad):
    el quiz inclina la balanza hacia la gente con gustos parecidos."""
    with TestClient(app) as c:
        luis = nuevo(c, "Luis", tramo_id="prado", comuna=11)
        c.post("/api/yo/quiz", json={"respuestas": SOCIAL}, headers=auth(luis))
        p_luis = parche(c, luis, tramo="prado")
        unir(c, luis, p_luis["id"])

        sara = nuevo(c, "Sara", tramo_id="fortaleza", comuna=11)
        c.post("/api/yo/quiz", json={"respuestas": CASERO}, headers=auth(sara))
        p_sara = parche(c, sara, tramo="fortaleza")
        unir(c, sara, p_sara["id"])

        # Ana no fija estación: los dos parches le sirven igual, pero comparte estilo con Luis
        ana = nuevo(c, "Ana", tramo_id=None, comuna=11)
        c.post("/api/yo/quiz", json={"respuestas": SOCIAL}, headers=auth(ana))
        e = c.post("/api/yo/match", headers=auth(ana)).json()
        assert e["estado"] == "inscrito" and e["salida"]["id"] == p_luis["id"]


def test_bot_telegram_empata_las_funciones(monkeypatch):
    """El bot espeja la app: /start vincula, /parche muestra el estado, /confirmo confirma,
    y el aviso del sábado también llega por el chat."""
    from app import telegram

    enviados: list[tuple[str, str]] = []
    monkeypatch.setattr(telegram, "enviar", lambda chat, texto: enviados.append((chat, texto)))

    with TestClient(app) as c:
        tokens = [nuevo(c, n) for n in ["Ana", "Luis", "Sara"]]
        p = parche(c, tokens[0])
        for t in tokens:
            unir(c, t, p["id"])

        with Session(engine) as s:
            ana = s.exec(select(Joven).where(Joven.nombre == "Ana")).one()
            ana.telegram_codigo = "abc123"
            s.add(ana)
            s.commit()

            # chat sin vincular: lo manda a la app
            telegram.atender(s, "555", "/parche")
            assert "Conectar Telegram" in enviados[-1][1]
            # /start con el código: vincula y saluda con la ayuda
            telegram.atender(s, "555", "/start abc123")
            assert "Ana" in enviados[-1][1] and "/parche" in enviados[-1][1]
            # /parche antes del sábado: inscrito, el grupo se arma después
            telegram.atender(s, "555", "/parche")
            assert p["nombre"] in enviados[-1][1] and "sábado" in enviados[-1][1]
            # /confirmo antes de tiempo: el mismo mensaje claro de la app
            telegram.atender(s, "555", "/confirmo")
            assert "sábado" in enviados[-1][1]
            # comando inventado: ayuda
            telegram.atender(s, "555", "/baile")
            assert "/ayuda" in enviados[-1][1] or "/parche" in enviados[-1][1]

        armar(c)
        # el aviso del sábado llegó al chat vinculado (y solo a ese: Luis y Sara no vincularon)
        avisos = [t for chat, t in enviados if chat == "555" and "grupo del domingo" in t]
        assert len(avisos) == 1 and "/confirmo" in avisos[0]

        with Session(engine) as s:
            telegram.atender(s, "555", "/confirmo")
            assert "vas" in enviados[-1][1]
            # /parche ya asignado: punto de encuentro y compañeros
            telegram.atender(s, "555", "/parche")
            assert "Luis" in enviados[-1][1] and "📍" in enviados[-1][1]

        assert estado(c, tokens[0])["mi_respuesta"] == "confirmado"


def test_foro_publicar_listar_borrar():
    with TestClient(app) as c:
        ana = nuevo(c, "ana maría")
        luis = nuevo(c, "Luis")

        r = c.post("/api/foro", json={"categoria": "parches", "texto": "El parche Samán estuvo genial"},
                   headers=auth(ana))
        assert r.status_code == 201 and r.json()["nombre"] == "Ana" and r.json()["universidad"] == "USB Cali"
        c.post("/api/foro", json={"categoria": "app", "texto": "Me gustaría ver el clima del domingo"},
               headers=auth(luis))

        lista = c.get("/api/foro", headers=auth(ana)).json()
        assert len(lista) == 2 and lista[0]["texto"].startswith("Me gustaría")  # más reciente primero
        assert lista[1]["es_mio"] and not lista[0]["es_mio"]

        solo_app = c.get("/api/foro", params={"categoria": "app"}, headers=auth(ana)).json()
        assert len(solo_app) == 1

        # solo el autor puede borrar
        ajeno = c.delete(f"/api/foro/{lista[0]['id']}", headers=auth(ana))
        assert ajeno.status_code == 409
        assert c.delete(f"/api/foro/{lista[1]['id']}", headers=auth(ana)).status_code == 204
        assert len(c.get("/api/foro", headers=auth(ana)).json()) == 1

        # categoría inventada: rechazada
        assert c.post("/api/foro", json={"categoria": "otra", "texto": "hola"}, headers=auth(ana)).status_code == 422


def test_catalogo_trae_foro_espera_y_coordenadas():
    with TestClient(app) as c:
        cat = c.get("/api/catalogo").json()
        assert {x["id"] for x in cat["foro_categorias"]} == {"parches", "app", "animo"}
        assert cat["espera_minutos"] > 0
        assert all("lat" in t and "lng" in t for t in cat["tramos"])


def test_borrar_datos_limpia_espera_y_foro():
    with TestClient(app) as c:
        ana = nuevo(c, "Ana")
        match(c, ana)
        c.post("/api/foro", json={"categoria": "animo", "texto": "Muy contenta de salir"}, headers=auth(ana))
        assert c.delete("/api/yo", headers=auth(ana)).status_code == 204
        with Session(engine) as s:
            assert s.exec(select(Espera)).first() is None
            assert s.exec(select(Joven)).first() is None
        luis = nuevo(c, "Luis")
        assert c.get("/api/foro", headers=auth(luis)).json() == []
