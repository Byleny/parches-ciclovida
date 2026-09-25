from datetime import date, datetime
from secrets import token_urlsafe
from uuid import uuid4

from sqlalchemy import DateTime
from sqlmodel import Field, SQLModel


# Todas las horas se guardan sin zona, en hora de Cali (UTC-5, sin horario de verano).
def _ahora() -> datetime:
    from .config import TZ

    return datetime.now(TZ).replace(tzinfo=None)


class Joven(SQLModel, table=True):
    id: str = Field(default_factory=lambda: uuid4().hex, primary_key=True)
    token: str = Field(default_factory=lambda: token_urlsafe(24), index=True, unique=True)
    nombre: str = Field(max_length=40)  # solo el nombre de pila: es lo único que ve el grupo
    # Estudiante verificado: del correo institucional solo guardamos su huella HMAC y la universidad.
    correo_hash: str = Field(index=True, unique=True)
    universidad: str = Field(index=True)
    rango_edad: str
    comuna: int = Field(index=True)
    # Preferencias: solo sirven para recomendar parches, el joven elige cuál.
    tramo_id: str | None = Field(default=None, index=True)
    actividad: str
    ritmo: str
    franja: str | None = None
    acepta_datos: bool
    autorizacion_version: str = ""  # versión del aviso de privacidad aceptado
    autorizacion_en: datetime | None = Field(default=None, sa_type=DateTime)  # prueba de la autorización
    permiso_acudiente: bool = False
    acudiente_nombre: str | None = Field(default=None, max_length=80)
    suspendido: bool = False  # por reportes, hasta revisión
    pausa_fecha: date | None = None  # "esta semana no voy"
    sintetico: bool = False  # datos de demostración generados por seed.py
    creado_en: datetime = Field(default_factory=_ahora, sa_type=DateTime)


class Verificacion(SQLModel, table=True):
    """Código de 6 dígitos enviado al correo institucional. Se borra al registrarse."""

    correo_hash: str = Field(primary_key=True)
    codigo_hash: str
    expira: datetime = Field(sa_type=DateTime)
    intentos: int = 0


class Jornada(SQLModel, table=True):
    fecha: date = Field(primary_key=True)
    estado: str = "inscripcion"  # inscripcion | emparejada (grupos armados el sábado) | finalizada
    emparejada_en: datetime | None = Field(default=None, sa_type=DateTime)
    finalizada_en: datetime | None = Field(default=None, sa_type=DateTime)


class Salida(SQLModel, table=True):
    """Un parche de la lista. Lo genera el sistema para cada estación, hora y actividad; el joven elige."""

    id: int | None = Field(default=None, primary_key=True)
    jornada_fecha: date = Field(foreign_key="jornada.fecha", index=True)
    nombre: str
    tramo_id: str = Field(index=True)
    segmento: str
    franja: str
    actividad: str


class Inscripcion(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    salida_id: int = Field(foreign_key="salida.id", index=True)
    joven_id: str = Field(foreign_key="joven.id", index=True)
    jornada_fecha: date = Field(index=True)
    creado_en: datetime = Field(default_factory=_ahora, sa_type=DateTime)


class Grupo(SQLModel, table=True):
    """Grupo de 3 a 6 dentro de un parche. Lo arma k-means el sábado a las 5:00 p. m."""

    id: int | None = Field(default=None, primary_key=True)
    jornada_fecha: date = Field(foreign_key="jornada.fecha", index=True)
    salida_id: int | None = Field(default=None, foreign_key="salida.id", index=True)
    nombre: str
    tramo_id: str = Field(index=True)
    segmento: str
    franja: str
    actividad: str
    nivel: str = "armado"  # armado | juntado (incluye gente de un parche que no se llenó)


class Asignacion(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    grupo_id: int = Field(foreign_key="grupo.id", index=True)
    joven_id: str = Field(foreign_key="joven.id", index=True)
    jornada_fecha: date = Field(index=True)
    estado: str = "pendiente"  # pendiente | confirmado | declinado
    ajustes: str = ""  # "franja,actividad": lo que cambió al juntarlo con otro parche
    tarde: bool = False  # se unió después de que se armaron los grupos
    respondido_en: datetime | None = Field(default=None, sa_type=DateTime)


class Encuesta(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    joven_id: str = Field(foreign_key="joven.id", index=True)
    jornada_fecha: date = Field(index=True)
    grupo_id: int | None = Field(default=None, foreign_key="grupo.id")
    asistio: bool
    volveria: bool
    bienestar: int | None = None  # 1 a 5, solo si asistió
    creado_en: datetime = Field(default_factory=_ahora, sa_type=DateTime)


class Reporte(SQLModel, table=True):
    """Botón "Reportar un problema". Solo lo ve moderación, nunca el tablero."""

    id: int | None = Field(default=None, primary_key=True)
    reporta_id: str | None = Field(default=None, foreign_key="joven.id", index=True)
    reportado_id: str | None = Field(default=None, foreign_key="joven.id", index=True)
    grupo_id: int | None = Field(default=None, foreign_key="grupo.id")
    jornada_fecha: date = Field(index=True)
    motivo: str
    detalle: str = Field(default="", max_length=500)
    revisado: bool = False
    creado_en: datetime = Field(default_factory=_ahora, sa_type=DateTime)
