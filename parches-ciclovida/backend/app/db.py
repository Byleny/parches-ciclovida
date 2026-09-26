from sqlmodel import Session, SQLModel, create_engine

from . import config

_args = {"check_same_thread": False} if config.DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(config.DATABASE_URL, connect_args=_args)


def init_db() -> None:
    from . import models  # noqa: F401  registra las tablas

    SQLModel.metadata.create_all(engine)
    _migrar()


def _migrar() -> None:
    """Columnas nuevas sobre una base ya creada (create_all no altera tablas existentes)."""
    if not config.DATABASE_URL.startswith("sqlite"):
        return
    from sqlalchemy import text

    with engine.connect() as con:
        columnas = {fila[1] for fila in con.execute(text("PRAGMA table_info(joven)"))}
        for columna in ("telegram_chat_id", "telegram_codigo", "quiz"):
            if columna not in columnas:
                con.execute(text(f"ALTER TABLE joven ADD COLUMN {columna} VARCHAR"))
        if "quiz_respuestas" not in columnas:
            con.execute(text("ALTER TABLE joven ADD COLUMN quiz_respuestas JSON"))
        if "declara_mayor" not in columnas:
            # cuentas creadas antes de la casilla: sin constancia, no se inventa
            con.execute(text("ALTER TABLE joven ADD COLUMN declara_mayor BOOLEAN NOT NULL DEFAULT 0"))
            con.execute(text("ALTER TABLE joven ADD COLUMN declara_mayor_en DATETIME"))
        con.commit()


def get_session():
    with Session(engine) as session:
        yield session
