from sqlmodel import Session, SQLModel, create_engine

from . import config

_args = {"check_same_thread": False} if config.DATABASE_URL.startswith("sqlite") else {}
engine = create_engine(config.DATABASE_URL, connect_args=_args)


def init_db() -> None:
    from . import models  # noqa: F401  registra las tablas

    SQLModel.metadata.create_all(engine)


def get_session():
    with Session(engine) as session:
        yield session
