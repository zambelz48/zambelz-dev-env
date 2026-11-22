import json
import re
from dataclasses import dataclass

DELIMITER = "---"
KEY = re.compile(r"[a-z][a-z0-9-]*")


class FrontmatterError(Exception):
    pass


@dataclass(frozen=True)
class Document:
    fields: dict[str, str]
    body: str


def _unquote(value: str, source: str, line_number: int) -> str:
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        return value[1:-1]

    if value[:1] in "\"'":
        raise FrontmatterError(f"{source}:{line_number}: unterminated quoted value")

    return value


def _field(line: str, source: str, line_number: int) -> tuple[str, str]:
    key, separator, value = line.partition(":")

    if not separator or not KEY.fullmatch(key):
        raise FrontmatterError(f"{source}:{line_number}: expected 'key: value', got {line!r}")

    text = _unquote(value.strip(), source, line_number)

    if not text:
        raise FrontmatterError(f"{source}:{line_number}: '{key}' has no value")

    return key, text


def parse(text: str, source: str) -> Document:
    lines = text.replace("\r\n", "\n").split("\n")

    if lines[0] != DELIMITER:
        raise FrontmatterError(f"{source}:1: expected '{DELIMITER}' to open the frontmatter")

    fields: dict[str, str] = {}

    for index, line in enumerate(lines[1:], start=2):
        if line == DELIMITER:
            return Document(fields, "\n".join(lines[index:]))

        key, value = _field(line, source, index)

        if key in fields:
            raise FrontmatterError(f"{source}:{index}: duplicate key '{key}'")

        fields[key] = value

    raise FrontmatterError(f"{source}: the frontmatter is never closed with '{DELIMITER}'")


def render(fields: dict[str, str], body: str) -> str:
    lines = [DELIMITER]

    for key, value in fields.items():
        lines.append(f"{key}: {json.dumps(value, ensure_ascii=False)}")

    lines.append(DELIMITER)

    return "\n".join(lines) + "\n" + body
