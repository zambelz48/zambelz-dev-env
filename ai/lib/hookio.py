import json
import re
from dataclasses import dataclass
from pathlib import Path

from writer import atomic_write, json_bytes

SAFE_ID = re.compile(r"[^A-Za-z0-9_-]")
CONTEXT_LIMIT = 9000
TRUNCATED = "\n(truncated; run the command again or zzd audit --declared for the full output)"


@dataclass(frozen=True)
class Reply:
    stdout: str = ""
    exit_code: int = 0


def json_reply(data: object) -> Reply:
    return Reply(stdout=json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def joined(warnings: tuple[str, ...], limit: int = CONTEXT_LIMIT) -> str:
    text = "\n\n".join(warnings)

    if len(text) > limit:
        return text[: limit - len(TRUNCATED)] + TRUNCATED

    return text


class PendingQueue:
    def __init__(self, repo_root: Path, conversation: object):
        name = SAFE_ID.sub("_", str(conversation or "unknown"))
        self.path = repo_root / "tmp" / "ai" / "pending" / f"{name}.json"

    def add(self, warnings: tuple[str, ...]) -> None:
        queued = self._read() + list(warnings)

        atomic_write(self.path, json_bytes({"warnings": queued}))

    def take(self) -> list[str]:
        try:
            return self._read()
        finally:
            self.path.unlink(missing_ok=True)

    def _read(self) -> list[str]:
        if not self.path.is_file():
            return []

        data = json.loads(self.path.read_text())

        return [str(item) for item in data["warnings"]]
