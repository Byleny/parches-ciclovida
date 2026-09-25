from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from datetime import date
from pathlib import Path
from typing import Literal

from fastapi import Depends, FastAPI, Header, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, field_validator, model_validator
from sqlmodel import Session, select

from . import config, services, stats, verificacion
from .catalog import (
    ACTIVIDADES_POR_ID, FRANJA_ORDEN, MOTIVOS_IDS, RITMO_ORDEN, SEGMENTO_EDAD, TRAMOS_POR_ID, UNIVERSIDADES_POR_ID, catalogo,
)
from .privacidad import aviso
from .db import engine, get_session, init_db
from .models import Grupo, Joven, Reporte

log = logging.getLogger("parches")
STATIC = Path(__file__).resolve().parent.parent / "static"


def _tick() -> None:
    with Session(engine) as s:
        r = services.tick(s)
        if "grupos" in r:
            log.info("Grupos del sábado: %s", r["grupos"])


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    scheduler = None
    if config.SCHEDULER_ON:
        from apscheduler.schedulers.background import BackgroundScheduler

        scheduler = BackgroundScheduler(timezone=config.TZ)
        scheduler.add_job(_tick, "interval", minutes=5, id="tick", next_run_time=services.ahora().replace(tzinfo=config.TZ))
        scheduler.start()
    yield
    if scheduler:
        scheduler.shutdown(wait=False)


app = FastAPI(title="Parches CicloVida", version="0.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


# ---------------------------------------------------------------- esquemas

class Preferencias(BaseModel):
    """Solo sirven para recomendar parches: el joven elige a cuál se une."""

    comuna: int = Field(ge=1, le=22)
    tramo_id: str | None = None
    actividad: str
    ritmo: str
    franja: str | None = None

    @field_validator("tramo_id")
    @classmethod
    def _tramo(cls, v):
        if v is not None and v not in TRAMOS_POR_ID:
            raise ValueError("Tramo desconocido")
        return v

    @field_validator("actividad")
    @classmethod
    def _act(cls, v):
        if v not in ACTIVIDADES_POR_ID:
            raise ValueError("Actividad desconocida")
        return v

    @field_validator("ritmo")
    @classmethod
    def _ritmo(cls, v):
        if v not in RITMO_ORDEN:
            raise ValueError("Ritmo desconocido")
        return v

    @field_validator("franja")
    @classmethod
    def _franja(cls, v):
        if v is not None and v not in FRANJA_ORDEN:
            raise ValueError("Franja desconocida")
        return v


class CorreoIn(BaseModel):
    correo: str = Field(max_length=120)


class Registro(Preferencias):
    correo: str = Field(max_length=120)  # institucional; no se guarda, solo su huella
    codigo: str = Field(min_length=6, max_length=6)
    nombre: str = Field(min_length=2, max_length=40)
    rango_edad: str
    acepta_datos: bool
    permiso_acudiente: bool = False
    acudiente_nombre: str | None = Field(default=None, max_length=80)

    @field_validator("nombre")
    @classmethod
    def _nombre(cls, v):
        return v.strip().split()[0].capitalize()  # solo el nombre de pila

    @field_validator("correo")
    @classmethod
    def _correo(cls, v):
        verificacion.universidad_valida(v)
        return verificacion.normalizar(v)

    @model_validator(mode="after")
    def _consentimientos(self):
        if self.rango_edad not in SEGMENTO_EDAD:
            raise ValueError("Rango de edad desconocido")
        if not self.acepta_datos:
            raise ValueError("Necesitamos tu autorización de tratamiento de datos")
        if SEGMENTO_EDAD[self.rango_edad] == "menor":
            if not config.PERMITIR_MENORES:
                raise ValueError("Por ahora el piloto es solo para jóvenes de 18 a 28 años")
            if not self.permiso_acudiente or len((self.acudiente_nombre or "").strip()) < 3:
                raise ValueError("Si tienes entre 14 y 17 años necesitamos la autorización y el nombre de tu acudiente")
        else:
            self.acudiente_nombre = None
        return self


class Cambio(BaseModel):
    comuna: int | None = Field(default=None, ge=1, le=22)
    tramo_id: str | None = None
    actividad: str | None = None
    ritmo: str | None = None
    franja: str | None = None
    pausar_esta_semana: bool | None = None


class Respuesta(BaseModel):
    va: bool


class Union(BaseModel):
    parche_id: int


class EncuestaIn(BaseModel):
    asistio: bool
    volveria: bool
    bienestar: int | None = Field(default=None, ge=1, le=5)  # opcional: puede ser dato sensible


class ReporteIn(BaseModel):
    grupo_id: int
    motivo: str
    ref: int | None = None  # integrante del parche; vacío = sobre el grupo en general
    detalle: str = Field(default="", max_length=500)

    @field_validator("motivo")
    @classmethod
    def _motivo(cls, v):
        if v not in MOTIVOS_IDS:
            raise ValueError("Motivo desconocido")
        return v


# ---------------------------------------------------------------- dependencias

def joven_actual(authorization: str = Header(default=""), session: Session = Depends(get_session)) -> Joven:
    token = authorization.removeprefix("Bearer ").strip()
    joven = session.exec(select(Joven).where(Joven.token == token)).first() if token else None
    if not joven:
        raise HTTPException(401, "Sesión no válida")
    return joven


def admin(x_admin_key: str = Header(default="")) -> None:
    if x_admin_key != config.ADMIN_KEY:
        raise HTTPException(403, "Clave de administración incorrecta")


def perfil(j: Joven) -> dict:
    return {
        "id": j.id, "nombre": j.nombre, "rango_edad": j.rango_edad, "comuna": j.comuna,
        "universidad": UNIVERSIDADES_POR_ID[j.universidad]["nombre"],
        "tramo_id": j.tramo_id, "actividad": j.actividad, "ritmo": j.ritmo, "franja": j.franja,
        "pausa_fecha": str(j.pausa_fecha) if j.pausa_fecha else None,
    }


# ---------------------------------------------------------------- app móvil

@app.get("/health")
def health():
    return {"ok": True}


@app.get("/api/catalogo")
def get_catalogo(session: Session = Depends(get_session)):
    data = catalogo()
    data["proxima_jornada"] = str(services.jornada_abierta(session).fecha)
    return data


@app.get("/api/aviso-privacidad")
def aviso_privacidad():
    return aviso()


@app.post("/api/verificacion")
def pedir_codigo(body: CorreoIn, session: Session = Depends(get_session)):
    """Envía un código de 6 dígitos al correo institucional. Sin servidor de correo (demo), lo devuelve."""
    try:
        return verificacion.solicitar(session, body.correo, services.ahora())
    except verificacion.CorreoInvalido as e:
        raise HTTPException(422, str(e))
    except LookupError as e:
        raise HTTPException(409, str(e))
    except RuntimeError as e:
        raise HTTPException(503, str(e))


@app.post("/api/jovenes", status_code=201)
def registrar(body: Registro, session: Session = Depends(get_session)):
    try:
        uni, huella = verificacion.comprobar(session, body.correo, body.codigo, services.ahora())
    except verificacion.CorreoInvalido as e:
        raise HTTPException(422, str(e))
    if session.exec(select(Joven.id).where(Joven.correo_hash == huella)).first():
        raise HTTPException(409, "Ese correo ya tiene una cuenta")
    joven = Joven(
        **body.model_dump(exclude={"correo", "codigo"}), correo_hash=huella, universidad=uni["id"],
        autorizacion_version=config.AVISO_VERSION, autorizacion_en=services.ahora(),
    )
    session.add(joven)
    session.commit()
    session.refresh(joven)
    return {"token": joven.token, "joven": perfil(joven)}


@app.get("/api/yo")
def yo(joven: Joven = Depends(joven_actual)):
    return perfil(joven)


@app.patch("/api/yo")
def cambiar(body: Cambio, joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    datos = body.model_dump(exclude_none=True)
    pausa = datos.pop("pausar_esta_semana", None)
    if datos:
        Preferencias(**{**perfil(joven), **datos})  # valida
    j = services.jornada_abierta(session)
    for k, v in datos.items():
        setattr(joven, k, v)
    if pausa is not None:
        joven.pausa_fecha = j.fecha if pausa else None
    session.add(joven)
    session.commit()
    if pausa:
        services.quitar_de_la_jornada(session, joven.id, j.fecha)
        session.commit()
    session.refresh(joven)
    return perfil(joven)


@app.delete("/api/yo", status_code=204)
def borrar(joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    services.borrar_joven(session, session.merge(joven))


@app.get("/api/yo/parche")
def mi_parche(joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    return services.estado_para(session, joven)


@app.get("/api/parches")
def parches(
    tramo: str | None = None,
    franja: str | None = None,
    actividad: str | None = None,
    joven: Joven = Depends(joven_actual),
    session: Session = Depends(get_session),
):
    """Los parches que generó el sistema para el próximo domingo, para elegir uno."""
    return services.listar_parches(session, joven, tramo=tramo, franja=franja, actividad=actividad)


@app.post("/api/yo/parche")
def unirme(body: Union, joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    try:
        services.unirse(session, joven, body.parche_id)
    except LookupError as e:
        raise HTTPException(409, str(e))
    return services.estado_para(session, joven)


@app.delete("/api/yo/parche")
def salirme(joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    services.salir(session, joven)
    return services.estado_para(session, joven)


@app.post("/api/yo/parche/respuesta")
def responder(body: Respuesta, joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    try:
        services.responder(session, joven, body.va)
    except LookupError as e:
        raise HTTPException(409, str(e))
    return services.estado_para(session, joven)


@app.post("/api/yo/encuesta")
def encuesta(body: EncuestaIn, joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    try:
        services.guardar_encuesta(session, joven, body.asistio, body.volveria, body.bienestar)
    except LookupError as e:
        raise HTTPException(409, str(e))
    return services.estado_para(session, joven)


@app.post("/api/yo/reportes", status_code=201)
def reportar(body: ReporteIn, joven: Joven = Depends(joven_actual), session: Session = Depends(get_session)):
    try:
        services.reportar(session, joven, body.grupo_id, body.motivo, body.detalle, body.ref)
    except LookupError as e:
        raise HTTPException(409, str(e))
    return {"ok": True, "mensaje": "Recibimos tu reporte. Lo revisa una persona del equipo."}


# ---------------------------------------------------------------- administración (demo y operación)

@app.post("/api/admin/armar-grupos", dependencies=[Depends(admin)])
def admin_armar_grupos(session: Session = Depends(get_session)):
    """Para la demo: adelanta lo del sábado 5:00 p. m. (grupos por k-means dentro de cada parche)."""
    try:
        return services.armar_grupos(session, services.jornada_abierta(session).fecha)
    except ValueError as e:
        raise HTTPException(409, str(e))


@app.post("/api/admin/finalizar", dependencies=[Depends(admin)])
def admin_finalizar(session: Session = Depends(get_session)):
    """Para la demo: da por terminada la jornada abierta y abre la encuesta."""
    j = services.jornada_abierta(session)
    j.estado = "finalizada"
    j.finalizada_en = services.ahora()
    session.add(j)
    session.commit()
    return {"finalizada": str(j.fecha), "siguiente": str(services.jornada_abierta(session).fecha)}


@app.get("/api/admin/jornada", dependencies=[Depends(admin)])
def admin_jornada(session: Session = Depends(get_session)):
    j = services.jornada_abierta(session)
    return {**services.resumen_jornada(session, j.fecha), "estado": j.estado}


@app.get("/api/admin/reportes", dependencies=[Depends(admin)])
def admin_reportes(pendientes: bool = True, session: Session = Depends(get_session)):
    """Cola de moderación. Es lo único que muestra personas, y solo con la clave de administración."""
    q = select(Reporte).order_by(Reporte.creado_en.desc())
    if pendientes:
        q = q.where(Reporte.revisado == False)  # noqa: E712
    salida = []
    for r in session.exec(q).all():
        reportado = session.get(Joven, r.reportado_id) if r.reportado_id else None
        grupo = session.get(Grupo, r.grupo_id) if r.grupo_id else None
        salida.append({
            "id": r.id, "fecha": str(r.jornada_fecha), "motivo": r.motivo, "detalle": r.detalle,
            "parche": grupo.nombre if grupo else None,
            "tramo": TRAMOS_POR_ID[grupo.tramo_id]["nombre"] if grupo else None,
            "reportado": {"id": reportado.id, "nombre": reportado.nombre, "suspendido": reportado.suspendido} if reportado else None,
            "creado_en": r.creado_en.isoformat(),
        })
    return salida


@app.post("/api/admin/reportes/{reporte_id}/revisar", dependencies=[Depends(admin)])
def admin_revisar(reporte_id: int, reactivar: bool = False, session: Session = Depends(get_session)):
    r = session.get(Reporte, reporte_id)
    if not r:
        raise HTTPException(404, "No existe ese reporte")
    r.revisado = True
    session.add(r)
    if reactivar and r.reportado_id:
        j = session.get(Joven, r.reportado_id)
        if j:
            j.suspendido = False
            session.add(j)
    session.commit()
    return {"ok": True}


# ---------------------------------------------------------------- tablero

@app.get("/api/tablero/jornadas")
def tablero_jornadas(session: Session = Depends(get_session)):
    return stats.jornadas(session)


@app.get("/api/tablero/resumen")
def tablero_resumen(fecha: date | None = Query(default=None), session: Session = Depends(get_session)):
    if fecha is None:
        lista = stats.jornadas(session)
        cerradas = [j for j in lista if j["estado"] == "finalizada"]
        fecha = date.fromisoformat((cerradas or lista)[0]["fecha"]) if lista else services.jornada_abierta(session).fecha
    return stats.resumen(session, fecha)


@app.get("/")
def raiz():
    return RedirectResponse("/tablero/")


app.mount("/tablero", StaticFiles(directory=STATIC / "tablero", html=True), name="tablero")
