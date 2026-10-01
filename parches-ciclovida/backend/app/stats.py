"""Agregados para el tablero de la Secretaría. Nunca devuelve personas.

Protecciones:
  * conteos entre 1 y K_CONTEO-1 salen como null con `suprimido: true`
  * promedios con menos de K_PROMEDIO respuestas salen como null
  * los grupos se identifican por su nombre de parche, nunca por sus miembros
"""

from __future__ import annotations

from collections import Counter, defaultdict
from datetime import date
from statistics import mean

from sqlmodel import Session, select

from . import config
from .catalog import ACTIVIDADES, ACTIVIDADES_POR_ID, COMUNAS, FRANJA_NOMBRE, TRAMOS, UNIVERSIDADES, tramo_info
from .models import Asignacion, Encuesta, Grupo, Jornada, Joven, Reporte


def _conteo(n: int) -> dict:
    if 0 < n < config.K_CONTEO:
        return {"valor": None, "suprimido": True}
    return {"valor": n, "suprimido": False}


def _promedio(valores: list[float]) -> float | None:
    return round(mean(valores), 2) if len(valores) >= config.K_PROMEDIO else None


def _pct(parte: int, total: int) -> float | None:
    return round(100 * parte / total, 1) if total else None


def jornadas(session: Session) -> list[dict]:
    filas = session.exec(select(Jornada).order_by(Jornada.fecha.desc())).all()
    salida = []
    for j in filas:
        n = len(session.exec(select(Asignacion.id).where(Asignacion.jornada_fecha == j.fecha)).all())
        salida.append({"fecha": str(j.fecha), "estado": j.estado, "emparejados": n})
    return salida


def _metricas_jornada(session: Session, fecha: date) -> dict:
    asign = session.exec(select(Asignacion).where(Asignacion.jornada_fecha == fecha)).all()
    encuestas = session.exec(select(Encuesta).where(Encuesta.jornada_fecha == fecha)).all()
    asistieron = [e for e in encuestas if e.asistio]
    bienestar = [e.bienestar for e in asistieron if e.bienestar]
    antes = set(session.exec(select(Asignacion.joven_id).where(Asignacion.jornada_fecha < fecha)).all())
    recurrentes = sum(1 for a in asign if a.joven_id in antes)
    return {
        "fecha": str(fecha),
        "nuevos": len(asign) - recurrentes,
        "recurrentes": recurrentes,
        "emparejados": len(asign),
        "parches": len({a.grupo_id for a in asign}),
        "confirmados": sum(1 for a in asign if a.estado == "confirmado"),
        "respuestas": len(encuestas),
        "asistieron": len(asistieron),
        "volverian": sum(1 for e in encuestas if e.volveria),
        "bienestar_promedio": _promedio(bienestar),
        "asistencia_pct": _pct(len(asistieron), len(encuestas)),
        "volverian_pct": _pct(sum(1 for e in encuestas if e.volveria), len(encuestas)),
        "confirmacion_pct": _pct(sum(1 for a in asign if a.estado == "confirmado"), len(asign)),
    }


def _indicadores_reto(jovenes: dict, asign: list, grupos: dict) -> dict:
    """Lo que le sirve a la Secretaría para el reto: reparto modal, viajes de ocio (comuna de residencia
    → estación), participación universitaria y tejido social. Todo agregado, con el mismo mínimo K."""
    k = config.K_CONTEO
    con_grupo = [(a, jovenes[a.joven_id], grupos[a.grupo_id]) for a in asign if a.joven_id in jovenes and a.grupo_id in grupos]

    por_act = Counter(g.actividad for _, _, g in con_grupo)
    reparto_modal = [
        {"actividad": a["id"], "nombre": a["nombre"], "familia": a["familia"], "n": _conteo(por_act[a["id"]])}
        for a in ACTIVIDADES
    ]

    od = Counter((j.comuna, g.tramo_id) for _, j, g in con_grupo)
    visibles = sorted(((c, t, n) for (c, t), n in od.items() if n >= k), key=lambda x: (-x[2], x[0], x[1]))
    origen_destino = {
        "pares": [{"comuna": c, "tramo": t, "estacion": tramo_info(t)["nombre"], "n": n} for c, t, n in visibles[:12]],
        "ocultos": sum(1 for n in od.values() if n < k),  # pares con menos de K jóvenes: no se muestran
        "total_pares": len(od),
    }

    por_uni = Counter(j.universidad for _, j, _ in con_grupo)
    universidades = [
        {"id": u["id"], "nombre": u["corto"], "n": _conteo(por_uni[u["id"]])}
        for u in UNIVERSIDADES if por_uni[u["id"]]
    ]
    universidades.sort(key=lambda u: -(u["n"]["valor"] or 0))

    unis_grupo: dict[int, set] = defaultdict(set)
    for _, j, g in con_grupo:
        unis_grupo[g.id].add(j.universidad)
    mixtos = sum(1 for u in unis_grupo.values() if len(u) >= 2)
    tejido = {
        "grupos": len(unis_grupo),
        "mixtos": mixtos,
        "mixtos_pct": _pct(mixtos, len(unis_grupo)),
        "universidades_por_grupo": _promedio([len(u) for u in unis_grupo.values()]) if len(unis_grupo) >= config.K_PROMEDIO else None,
    }

    respondieron = [j for _, j, _ in con_grupo if j.primera_vez is not None]
    primera = sum(1 for j in respondieron if j.primera_vez)
    participacion = {
        "respondieron": len(respondieron),
        "primera_vez_pct": _pct(primera, len(respondieron)) if len(respondieron) >= k else None,
    }
    return {
        "reparto_modal": reparto_modal,
        "origen_destino": origen_destino,
        "universidades": universidades,
        "tejido": tejido,
        "participacion": participacion,
        "lecturas": _lecturas(reparto_modal, origen_destino, universidades, tejido, participacion),
    }


def _lecturas(reparto, od, unis, tejido, participacion) -> list[str]:
    """Frases listas para la Secretaría, solo con cifras que superan el mínimo de anonimato."""
    frases = []
    n1 = lambda v: f"{v:g}".replace(".", ",")  # noqa: E731  decimales con coma
    modal = [r for r in reparto if r["n"]["valor"]]
    total = sum(r["n"]["valor"] for r in modal)
    if total:
        top = max(modal, key=lambda r: r["n"]["valor"])
        a_pie = sum(r["n"]["valor"] for r in modal if r["familia"] == "a_pie")
        frases.append(
            f"{n1(_pct(top['n']['valor'], total))} % de los jóvenes con parche eligió {top['nombre'].lower()}; "
            f"{n1(_pct(a_pie, total))} % va a pie y {n1(_pct(total - a_pie, total))} % sobre ruedas."
        )
    if od["pares"]:
        p = od["pares"][0]
        frases.append(
            f"El viaje de ocio más frecuente sale de la comuna {p['comuna']} hacia la estación {p['estacion']} "
            f"({p['n']} jóvenes): ahí conviene reforzar el acompañamiento y la movilidad."
        )
    if unis:
        frases.append(
            f"Participan {len(unis)} universidades; la que más aporta es {unis[0]['nombre']}."
        )
    if tejido["mixtos_pct"] is not None:
        frases.append(
            f"{n1(tejido['mixtos_pct'])} % de los grupos reúne a estudiantes de 2 o más universidades: "
            "gente que no se conocía empieza a compartir el espacio público."
        )
    if participacion["primera_vez_pct"] is not None:
        frases.append(
            f"{n1(participacion['primera_vez_pct'])} % de quienes respondieron nunca había ido a la CicloVida: "
            "es participación nueva, no solo la de siempre."
        )
    return frases


def resumen(session: Session, fecha: date) -> dict:
    jornada = session.get(Jornada, fecha)
    jovenes = {j.id: j for j in session.exec(select(Joven)).all()}
    asign = session.exec(select(Asignacion).where(Asignacion.jornada_fecha == fecha)).all()
    grupos = {g.id: g for g in session.exec(select(Grupo).where(Grupo.jornada_fecha == fecha)).all()}
    encuestas = session.exec(select(Encuesta).where(Encuesta.jornada_fecha == fecha)).all()
    enc_por_joven = {e.joven_id: e for e in encuestas}

    m = _metricas_jornada(session, fecha)
    inscritos_total = len(jovenes)
    kpis = {
        "inscritos": inscritos_total,
        "parches": m["parches"],
        "emparejados": m["emparejados"],
        "confirmacion_pct": m["confirmacion_pct"],
        "asistencia_pct": m["asistencia_pct"],
        "volverian_pct": m["volverian_pct"],
        "bienestar_promedio": m["bienestar_promedio"],
        "respuestas": m["respuestas"],
        "reportes": len(session.exec(select(Reporte.id).where(Reporte.jornada_fecha == fecha)).all()),
    }
    embudo = [
        {"paso": "Inscritos", "valor": inscritos_total},
        {"paso": "Con parche", "valor": m["emparejados"]},
        {"paso": "Confirmaron", "valor": m["confirmados"]},
        {"paso": "Fueron", "valor": m["asistieron"]},
        {"paso": "Volverían", "valor": m["volverian"]},
    ]

    # por comuna de residencia
    insc_c = Counter(j.comuna for j in jovenes.values())
    emp_c = Counter(jovenes[a.joven_id].comuna for a in asign if a.joven_id in jovenes)
    asis_c = Counter(jovenes[e.joven_id].comuna for e in encuestas if e.asistio and e.joven_id in jovenes)
    bien_c: dict[int, list[int]] = defaultdict(list)
    for e in encuestas:
        if e.asistio and e.bienestar and e.joven_id in jovenes:
            bien_c[jovenes[e.joven_id].comuna].append(e.bienestar)
    por_comuna = [
        {
            "comuna": c["id"],
            "inscritos": _conteo(insc_c[c["id"]]),
            "con_parche": _conteo(emp_c[c["id"]]),
            "fueron": _conteo(asis_c[c["id"]]),
            "bienestar_promedio": _promedio(bien_c[c["id"]]),
        }
        for c in COMUNAS
    ]

    # por tramo (estación de la CicloVida)
    por_tramo = []
    for t in TRAMOS:
        a_t = [a for a in asign if grupos.get(a.grupo_id) and grupos[a.grupo_id].tramo_id == t["id"]]
        fueron = sum(1 for a in a_t if (e := enc_por_joven.get(a.joven_id)) and e.asistio)
        por_tramo.append({
            "tramo": t["id"], "nombre": t["nombre"], "comuna": t["comuna"], "lat": t["lat"], "lng": t["lng"],
            "parches": len({a.grupo_id for a in a_t}),
            "con_parche": len(a_t),
            "fueron": fueron,
        })

    # por grupo: solo números del grupo, sin personas
    miembros_g: dict[int, list[Asignacion]] = defaultdict(list)
    for a in asign:
        miembros_g[a.grupo_id].append(a)
    por_grupo = []
    for gid, lista in miembros_g.items():
        g = grupos.get(gid)
        if not g:
            continue
        encs = [enc_por_joven[a.joven_id] for a in lista if a.joven_id in enc_por_joven]
        bien = [e.bienestar for e in encs if e.asistio and e.bienestar]
        por_grupo.append({
            "grupo": g.nombre,
            "tramo": tramo_info(g.tramo_id)["nombre"],
            "hora": FRANJA_NOMBRE[g.franja],
            "franja": g.franja,
            "actividad": ACTIVIDADES_POR_ID[g.actividad]["nombre"],
            "nivel": g.nivel,
            "tamano": len(lista),
            "confirmados": sum(1 for a in lista if a.estado == "confirmado"),
            "respuestas": len(encs),
            "fueron": sum(1 for e in encs if e.asistio),
            "volverian": sum(1 for e in encs if e.volveria),
            "bienestar_promedio": _promedio(bien),
        })
    por_grupo.sort(key=lambda r: (r["tramo"], r["franja"], r["grupo"]))

    dist = Counter(e.bienestar for e in encuestas if e.asistio and e.bienestar)
    tendencia = [
        _metricas_jornada(session, j.fecha)
        for j in session.exec(select(Jornada).order_by(Jornada.fecha)).all()
        if j.estado == "finalizada"
    ]

    reto = _indicadores_reto(jovenes, asign, grupos)

    return {
        "fecha": str(fecha),
        "estado": jornada.estado if jornada else "sin_datos",
        **reto,
        "datos_sinteticos": any(j.sintetico for j in jovenes.values()),
        "anonimato": {"k_conteo": config.K_CONTEO, "k_promedio": config.K_PROMEDIO},
        "kpis": kpis,
        "embudo": embudo,
        "por_comuna": por_comuna,
        "por_tramo": por_tramo,
        "por_grupo": por_grupo,
        "bienestar_distribucion": [dist.get(i, 0) for i in range(1, 6)],
        "tendencia": tendencia,
    }
