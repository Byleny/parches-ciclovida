"""Jóvenes simulados en JSON, respuestas del quiz guardadas tal cual y reporte del emparejamiento."""

import json
from collections import Counter

from fastapi.testclient import TestClient
from sqlmodel import Session, SQLModel, select

from app import reporte, services, sinteticos
from app.catalog import (
    ACTIVIDADES_POR_ID, FRANJA_ORDEN, QUIZ_POR_ID, RITMO_ORDEN, TRAMOS_POR_ID, UNIVERSIDADES_POR_ID, puntuar_quiz,
)
from app.db import engine
from app.main import app
from app.models import Asignacion, Joven
from app.seed import sembrar
from test_api import ADMIN, armar, auth, nuevo, parche, unir


def test_json_de_simulados_es_valido_coherente_y_reproducible():
    datos = json.loads(sinteticos.RUTA.read_text(encoding="utf-8"))
    js = datos["jovenes"]
    assert len(js) == datos["total"] == 1500
    assert len({j["id"] for j in js}) == 1500
    for j in js:
        assert j["estacion"] in TRAMOS_POR_ID and j["actividad"] in ACTIVIDADES_POR_ID and j["hora"] in FRANJA_ORDEN
        assert j["ritmo"] in RITMO_ORDEN and j["universidad"] in UNIVERSIDADES_POR_ID
        assert j["rango_edad"] in ("18-22", "23-28") and 1 <= j["comuna"] <= 22 and 1 <= j["semana_de_ingreso"] <= 4
        assert j["perfil"] in datos["perfiles"]
        if j["quiz"] is not None:
            assert set(j["quiz"]) == {str(k) for k in QUIZ_POR_ID}
            for k, v in j["quiz"].items():  # nada de respuestas imposibles
                assert v in {o["id"] for o in QUIZ_POR_ID[int(k)]["opciones"]}
    # cada perfil responde, en su mayoría, lo típico de su perfil
    for pid, perfil in datos["perfiles"].items():
        respuestas = [j["quiz"] for j in js if j["perfil"] == pid and j["quiz"]]
        for k, tipica in perfil["respuestas_tipicas"].items():
            assert Counter(r[k] for r in respuestas).most_common(1)[0][0] == tipica
    # todas las actividades tienen gente de sobra, y la mayoría responde el quiz
    assert min(Counter(j["actividad"] for j in js).values()) > 150
    assert 0.6 < sum(1 for j in js if j["quiz"]) / len(js) < 0.8
    # el archivo sale idéntico de la semilla
    assert sinteticos.generar() == datos


def test_seed_carga_el_json_con_respuestas_originales():
    r = sembrar(total=240, reset=True)
    assert r["jovenes"] == 240
    with Session(engine) as s:
        js = s.exec(select(Joven)).all()
        assert len(js) == 240 and all(j.sintetico and j.id.startswith("sim-") for j in js)
        con_quiz = [j for j in js if j.quiz_respuestas]
        assert con_quiz and len(con_quiz) < 240
        for j in con_quiz:
            vector = tuple(float(x) for x in j.quiz.split(","))
            assert vector == puntuar_quiz({int(k): v for k, v in j.quiz_respuestas.items()})
            assert services.quiz_de(j) == vector


def test_quiz_guarda_las_respuestas_originales_en_json():
    SQLModel.metadata.drop_all(engine)
    with TestClient(app) as c:
        tok = nuevo(c, "Ana")
        respuestas = {"1": "a", "2": "c", "3": "b", "4": "a", "5": "b"}
        assert c.post("/api/yo/quiz", json={"respuestas": respuestas}, headers=auth(tok)).status_code == 200
        with Session(engine) as s:
            ana = s.exec(select(Joven)).one()
            assert ana.quiz_respuestas == respuestas
            assert ana.quiz == "1,0.5,1,1,0"
            assert services.quiz_de(ana) == (1.0, 0.5, 1.0, 1.0, 0.0)
            # las cuentas que respondieron antes de guardar las respuestas siguen con su vector
            ana.quiz_respuestas = None
            assert services.quiz_de(ana) == (1.0, 0.5, 1.0, 1.0, 0.0)
        yo = c.get("/api/yo", headers=auth(tok)).json()
        assert yo["quiz_respondido"] is True and "quiz_respuestas" not in yo and "quiz" not in yo


def test_reporte_del_emparejamiento():
    sembrar(total=400, reset=True)
    with Session(engine) as s:
        r = reporte.generar(s)
        ultimo_domingo = sorted({a.jornada_fecha for a in s.exec(select(Asignacion)).all()})[-1]
    assert r["fecha"] == str(ultimo_domingo)

    # cada persona aparece en un solo grupo y los tamaños cuadran
    ids = [i["id"] for g in r["grupos"] for i in g["integrantes"]]
    assert len(ids) == len(set(ids)) == r["resumen"]["personas_con_grupo"]
    assert sum(int(n) * c for n, c in r["resumen"]["tamanos"].items()) == len(ids)
    for g in r["grupos"]:
        assert g["tamano"] == len(g["integrantes"])
        assert g["por_que"] and g["estacion"] in g["por_que"][0]
        assert g["cohesion"] >= 0

    # el efecto del quiz se mide contra armar sin quiz y al azar (con pocos simulados el número es
    # ruidoso: aquí solo se revisa la forma; los valores con los 1.500 están en el README)
    ef = r["efecto_del_quiz"]
    assert ef["parches_divididos_por_kmeans"] > 0 and ef["pesos"]["quiz"] > 0
    for medida in ("afinidad_de_estilo_pct", "mismo_ritmo_pct"):
        assert all(0 <= ef[medida][k] <= 100 for k in ("con_quiz", "sin_quiz", "al_azar"))
    assert ef["mismo_ritmo_pct"]["con_quiz"] > ef["mismo_ritmo_pct"]["al_azar"]  # k-means sí junta ritmos

    md = reporte.markdown(r)
    assert md.startswith("# Reporte del emparejamiento") and "¿Sirve el quiz?" in md


def test_coincidencia_mide_que_tan_parecido_es_cada_grupo():
    from app.matching import Participante

    def p(i, ritmo):
        return Participante(id=str(i), tramo="panamericana", franja="08:00", actividad="bici", ritmo=ritmo, rango_edad="18-22")

    iguales = [[p(1, "rapido"), p(2, "rapido"), p(3, "rapido")], [p(4, "tranquilo"), p(5, "tranquilo"), p(6, "tranquilo")]]
    mezclados = [[p(1, "rapido"), p(4, "tranquilo"), p(2, "rapido")], [p(5, "tranquilo"), p(3, "rapido"), p(6, "tranquilo")]]
    assert reporte.coincidencia(iguales, lambda x: x.ritmo) == (6, 6)
    assert reporte.coincidencia(mezclados, lambda x: x.ritmo) == (4, 6)
    # quien no tiene dato (None) no cuenta, y un grupo con un solo dato tampoco
    assert reporte.coincidencia(iguales, lambda x: x.ritmo if x.id in {"1", "2", "4"} else None) == (2, 2)


def test_reporte_no_expone_a_personas_reales_y_pide_clave():
    sembrar(total=300, reset=True)
    with TestClient(app) as c:
        ana = nuevo(c, "Ana")
        c.post("/api/yo/quiz", json={"respuestas": {"1": "a", "2": "a", "3": "b", "4": "a", "5": "b"}}, headers=auth(ana))
        unir(c, ana, parche(c, ana)["id"])
        armar(c)  # arma el próximo domingo, con Ana adentro

        assert c.get("/api/admin/emparejamiento").status_code == 403
        r = c.get("/api/admin/emparejamiento", headers=ADMIN).json()
        reales = [i for g in r["grupos"] for i in g["integrantes"] if not i["sintetico"]]
        assert len(reales) == 1
        assert not {"id", "nombre", "quiz", "perfil"} & set(reales[0])  # ni nombre ni respuestas
        assert "Ana" not in json.dumps(r, ensure_ascii=False)
