"""Emparejamiento automático (match), lista de espera, notificaciones y foro comunal."""

from datetime import timedelta

from fastapi.testclient import TestClient
from sqlmodel import Session, select

from app import services
from app.db import engine
from app.main import app
from app.models import Espera, Joven
from test_api import auth, estado, nuevo, parche, setup_function, unir  # noqa: F401


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
