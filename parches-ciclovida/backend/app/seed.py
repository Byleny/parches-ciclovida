"""Genera datos SINTÉTICOS para la demo del tablero.

    python -m app.seed --reset

Crea jóvenes ficticios marcados como `sintetico` que eligen parches de la lista
que genera el sistema: cuatro domingos pasados con respuestas y encuestas, y el
próximo domingo abierto con parte de la gente ya unida (para que la lista de la
demo no salga vacía).
El tablero muestra un aviso de "datos de demostración" mientras existan.
No son resultados de ningún piloto: no presentarlos como tales.
"""

from __future__ import annotations

import argparse
import random
from datetime import datetime, time, timedelta

from sqlmodel import Session, SQLModel, select

from . import services
from .catalog import SEGMENTO_EDAD, TRAMOS, UNIVERSIDADES, rangos_permitidos
from .db import engine, init_db
from .models import Asignacion, Encuesta, Inscripcion, Jornada, Joven, Salida
from .verificacion import huella

PESO_UNIVERSIDAD = {"univalle": 26, "uao": 14, "usb": 10, "javeriana": 12, "icesi": 10, "usc": 12,
                    "unilibre": 6, "unicatolica": 5, "uniajc": 5}

NOMBRES = (
    "Valentina Santiago Mariana Sebastián Isabella Samuel Sofía Juan Daniela Nicolás Camila Andrés "
    "Laura Felipe Sara Mateo Gabriela Alejandro Paula David Manuela Miguel Luisa Kevin Natalia Jhon "
    "Yuliana Brayan Karen Esteban Ángela Cristian Tatiana Julián Melissa Óscar Vanessa Duván Yeimi Anderson"
).split()

PESO_TRAMO = {
    "panamericana": 16, "ingenio": 14, "brisas": 9, "siloe": 8, "torres-comfandi": 7, "petecuy": 7,
    "corredor-verde": 8, "americas": 7, "prado": 7, "fortaleza": 5, "morichal": 7, "sol-de-oriente": 8,
}


def _elegir(rng: random.Random, opciones: dict[str, float]) -> str:
    return rng.choices(list(opciones), weights=list(opciones.values()))[0]


def _quiz(rng: random.Random) -> str | None:
    """La mayoría responde el quiz de estilo; el resto queda neutro, como pasaría en la realidad."""
    if rng.random() > 0.7:
        return None
    return ",".join(rng.choice(("0", "0.5", "1")) for _ in range(5))


def _joven(rng: random.Random, creado: datetime) -> Joven:
    tramo = _elegir(rng, PESO_TRAMO)
    comuna_tramo = next(t["comuna"] for t in TRAMOS if t["id"] == tramo)
    pesos = {"14-17": 30, "18-22": 45, "23-28": 25}
    rango = _elegir(rng, {r["id"]: pesos[r["id"]] for r in rangos_permitidos()})
    uni = _elegir(rng, PESO_UNIVERSIDAD)
    dominio = next(u["dominios"][0] for u in UNIVERSIDADES if u["id"] == uni)
    mayor = rango != "14-17"
    return Joven(
        nombre=rng.choice(NOMBRES),
        correo_hash=huella(f"sintetico-{rng.getrandbits(64):x}@{dominio}"),
        universidad=uni,
        rango_edad=rango,
        comuna=comuna_tramo if rng.random() < 0.6 else rng.randint(1, 22),
        tramo_id=tramo,
        actividad=_elegir(rng, {"bici": 45, "trotar": 20, "caminar": 25, "patines": 10}),
        ritmo=_elegir(rng, {"tranquilo": 40, "moderado": 40, "rapido": 20}),
        franja=_elegir(rng, {"08:00": 45, "09:30": 35, "11:00": 20}),
        acepta_datos=True,
        autorizacion_version="sintetico",
        declara_mayor=mayor,
        declara_mayor_en=creado if mayor else None,
        permiso_acudiente=not mayor,
        acudiente_nombre=None if mayor else "Acudiente sintético",
        quiz=_quiz(rng),
        sintetico=True,
        creado_en=creado,
    )


def _unir(s: Session, joven: Joven, fecha) -> None:
    """El joven sintético elige el parche de su estación, hora y actividad preferidas."""
    salida = s.exec(select(Salida).where(
        Salida.jornada_fecha == fecha, Salida.tramo_id == joven.tramo_id, Salida.franja == joven.franja,
        Salida.actividad == joven.actividad, Salida.segmento == SEGMENTO_EDAD[joven.rango_edad],
    )).first()
    if salida is not None:
        s.add(Inscripcion(salida_id=salida.id, joven_id=joven.id, jornada_fecha=fecha))


def sembrar(total: int = 260, semanas: int = 4, reset: bool = False, semilla: int = 2026) -> dict:
    rng = random.Random(semilla)
    if reset:
        SQLModel.metadata.drop_all(engine)
    init_db()
    hoy = services.ahora().date()
    proximo = services.proximo_domingo(hoy)
    domingos = [proximo - timedelta(days=7 * k) for k in range(semanas, 0, -1)]
    # la gente se va sumando semana a semana
    cortes = [round(total * f) for f in (0.35, 0.6, 0.8, 1.0)][-semanas:] if semanas <= 4 else None
    cortes = cortes or [round(total * (i + 1) / semanas) for i in range(semanas)]

    with Session(engine) as s:
        creados = 0
        for domingo, meta in zip(domingos, cortes):
            lunes = domingo - timedelta(days=6)
            while creados < meta:
                s.add(_joven(rng, datetime.combine(lunes, time(rng.randint(7, 21), rng.randint(0, 59)))))
                creados += 1
            s.commit()

            s.add(Jornada(fecha=domingo))
            s.commit()
            services.asegurar_parches(s, domingo)
            jovenes = s.exec(select(Joven).where(Joven.sintetico == True)).all()  # noqa: E712
            for j in jovenes:
                if rng.random() < 0.82:
                    _unir(s, j, domingo)
            s.commit()
            services.armar_grupos(s, domingo)

            for a in s.exec(select(Asignacion).where(Asignacion.jornada_fecha == domingo)).all():
                r = rng.random()
                a.estado = "confirmado" if r < 0.72 else "declinado" if r < 0.82 else "pendiente"
                s.add(a)
                responde = {"confirmado": 0.85, "pendiente": 0.4, "declinado": 0.15}[a.estado]
                if rng.random() > responde:
                    continue
                prob_fue = {"confirmado": 0.88, "pendiente": 0.3, "declinado": 0.05}[a.estado]
                fue = rng.random() < prob_fue
                s.add(Encuesta(
                    joven_id=a.joven_id, jornada_fecha=domingo, grupo_id=a.grupo_id, asistio=fue,
                    volveria=rng.random() < (0.8 if fue else 0.35),
                    bienestar=_elegir(rng, {1: 2, 2: 5, 3: 18, 4: 40, 5: 35}) if fue else None,
                    creado_en=datetime.combine(domingo, time(15, 0)),
                ))
            jornada = s.get(Jornada, domingo)
            jornada.estado = "finalizada"
            jornada.finalizada_en = datetime.combine(domingo, time(13, 0))
            s.add(jornada)
            s.commit()

        abierta = services.jornada_abierta(s)
        for j in s.exec(select(Joven).where(Joven.sintetico == True)).all():  # noqa: E712
            if rng.random() < 0.5:
                _unir(s, j, abierta.fecha)
        s.commit()
        return {"jovenes": creados, "domingos": [str(d) for d in domingos], "proxima": str(abierta.fecha)}


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--jovenes", type=int, default=260)
    ap.add_argument("--semanas", type=int, default=4)
    ap.add_argument("--reset", action="store_true", help="borra la base antes de sembrar")
    args = ap.parse_args()
    print(sembrar(args.jovenes, args.semanas, args.reset))
