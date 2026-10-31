import json
import sys
import tomllib
from pathlib import Path

ECOSYSTEMS = {
    "cargo": "crates.io",
    "go": "Go",
    "gem": "RubyGems",
}


def packages(lock: dict) -> list[dict]:
    found = []
    for tool, entries in lock.get("tools", {}).items():
        backend, _, name = tool.partition(":")
        ecosystem = ECOSYSTEMS.get(backend)
        if ecosystem is None or not name:
            continue
        for entry in entries:
            package = {
                "name": name,
                "version": entry["version"],
                "ecosystem": ecosystem,
            }
            found.append({"package": package})
    return found


def main(argv: list[str]) -> int:
    match argv:
        case [lock_path, out_path]:
            pass
        case _:
            print("usage: audit_lock_to_osv.py <mise.lock> <out.json>",
                  file=sys.stderr)
            return 2
    lock = tomllib.loads(Path(lock_path).read_text())
    result = {"results": [{"packages": packages(lock)}]}
    Path(out_path).write_text(json.dumps(result, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
