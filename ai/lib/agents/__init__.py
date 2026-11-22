import importlib
from types import ModuleType

from agents.common import RenderError


def module(name: str) -> ModuleType:
    try:
        return importlib.import_module(f"agents.{name}")
    except ModuleNotFoundError as error:
        raise RenderError(f"{name} is not supported yet") from error
