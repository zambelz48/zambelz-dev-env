import tomllib
from pathlib import Path

from model import Kind


class CatalogError(Exception):
    pass


class Catalog:
    def __init__(self, path: Path):
        self.path = path

        try:
            self.data: dict = tomllib.loads(path.read_text())
        except FileNotFoundError as error:
            raise CatalogError(f"the audit catalog {path} is missing") from error
        except tomllib.TOMLDecodeError as error:
            raise CatalogError(f"the audit catalog {path} is not valid TOML: {error}") from error

    def entry(self, kind: Kind, name: str) -> dict | None:
        section = self.data.get(str(kind), {})
        value = section.get(name)

        if value is None or not isinstance(value, dict):
            return None

        return value

    def repo(self, kind: Kind, name: str) -> str | None:
        entry = self.entry(kind, name)

        if entry is None:
            return None

        return entry.get("repo")
