import importlib
from types import ModuleType


def module(name: str) -> ModuleType:
    return importlib.import_module(f"agents.{name}")
