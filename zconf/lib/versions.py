import re
import subprocess
import sys
import tomllib
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from check_pins import is_exact, lock_platforms, missing_platforms

VERSION = re.compile(r"(?P<prefix>\D*?)(?P<nums>\d+(?:\.\d+)*)(?P<rest>.*)")
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
BARE_KEY = re.compile(r"[A-Za-z0-9_-]+")


def load_tools(config: Path) -> dict:
    return tomllib.loads(config.read_text()).get("tools", {})


def versions_of(value: object) -> list[str]:
    match value:
        case str():
            return [value]
        case list():
            return [v for v in value if isinstance(v, str)]
        case {"version": str() as version}:
            return [version]
        case _:
            return []


def line_of(version: str, depth: int) -> str | None:
    match_ = VERSION.fullmatch(version)
    if match_ is None:
        return None
    nums = match_["nums"].split(".")
    if nums[0] == "0":
        depth = max(depth, 2)
    return match_["prefix"] + ".".join(nums[:depth])


def queries(tool: str, pins: list[str], major: bool) -> list[tuple[str, str]]:
    if major:
        pins = pins[:1]
    majors = [line_of(v, 1) for v in pins]
    out = []
    for version, line in zip(pins, majors):
        if DATE.fullmatch(version) or line is None:
            out.append((version, tool))
        elif major:
            prefix = VERSION.fullmatch(version)["prefix"].rstrip("-")
            out.append((version, f"{tool}@{prefix}" if prefix else tool))
        else:
            depth = 2 if majors.count(line) > 1 else 1
            out.append((version, f"{tool}@{line_of(version, depth)}"))
    return out


def latest(query: str) -> str | None:
    result = subprocess.run(
        ["mise", "latest", query], capture_output=True, text=True
    )
    candidate = result.stdout.strip()
    if result.returncode != 0 or not candidate:
        return None
    return candidate.splitlines()[-1]


def outdated(config: Path, major: bool, only: list[str]) -> int:
    jobs = []
    for tool, value in load_tools(config).items():
        if only and tool not in only:
            continue
        if tool.startswith("http:"):
            print(f"WARN: {tool} is not checked (http backend)",
                  file=sys.stderr)
            continue
        for version, query in queries(tool, versions_of(value), major):
            jobs.append((tool, version, query))
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda job: latest(job[2]), jobs))
    for (tool, version, query), candidate in zip(jobs, results):
        if candidate is None:
            print(f"WARN: cannot check {tool} ({query})", file=sys.stderr)
        elif candidate != version:
            print(f"{tool} {version} {candidate}")
    return 0


def key_of(tool: str) -> str:
    if BARE_KEY.fullmatch(tool):
        return f"tools.{tool}"
    return f'tools."{tool}"'


def mise_set(config: Path, key: str, value: str | list[str]) -> int:
    match value:
        case list():
            args = [key, ",".join(value), "--type", "list"]
        case _:
            args = [key, value, "--type", "string"]
    return subprocess.run(
        ["mise", "config", "set", "-f", str(config), *args]
    ).returncode


def set_version(config: Path, tool: str, old: str, new: str) -> int:
    value = load_tools(config).get(tool)
    pinned = versions_of(value)
    if old not in pinned:
        print(f"ERROR: {tool} {old} is not pinned", file=sys.stderr)
        return 1
    if new != old and new in pinned:
        print(f"ERROR: {tool} {new} is already pinned", file=sys.stderr)
        return 1
    match value:
        case str():
            return mise_set(config, key_of(tool), new)
        case list():
            updated = [new if v == old else v for v in value]
            return mise_set(config, key_of(tool), updated)
        case _:
            return mise_set(config, key_of(tool) + ".version", new)


def use_version(config: Path, tool: str, version: str) -> int:
    if not is_exact(version):
        print(
            f"ERROR: {tool} {version} is not an exact version; "
            "give the full version, such as 24.11.1",
            file=sys.stderr,
        )
        return 1
    value = load_tools(config).get(tool)
    match value:
        case None:
            return mise_set(config, key_of(tool), version)
        case str() if value == version:
            return 0
        case str():
            return mise_set(config, key_of(tool), [version, value])
        case list():
            rest = [v for v in value if v != version]
            return mise_set(config, key_of(tool), [version, *rest])
        case _:
            print(
                f"ERROR: {tool} is a table entry with one version; "
                "edit it with `set`",
                file=sys.stderr,
            )
            return 1


def has_platforms(entries: list[dict]) -> bool:
    return any(key.startswith("platforms.") for e in entries for key in e)


# mise lock exits 0 for a version with no downloads and writes it without
# platforms, so a tool locked with platforms before must keep them.
def check_locked(
    config: Path, lock: Path, before: Path, tool: str, version: str
) -> int:
    def entries_of(path: Path) -> list[dict]:
        return tomllib.loads(path.read_text()).get("tools", {}).get(tool, [])

    entries = [e for e in entries_of(lock) if e.get("version") == version]
    value = load_tools(config).get(tool)
    gaps = missing_platforms(value, entries, lock_platforms(config))
    if not entries:
        problem = "is not in the lock"
    elif gaps:
        problem = f"is not locked for {', '.join(gaps)}"
    elif has_platforms(entries_of(before)) and not has_platforms(entries):
        problem = "has no download for any platform"
    else:
        return 0
    print(f"ERROR: {tool} {version} {problem}", file=sys.stderr)
    return 1


def main(argv: list[str]) -> int:
    match argv:
        case ["outdated", config, *rest]:
            major = "--major" in rest
            only = [arg for arg in rest if arg != "--major"]
            return outdated(Path(config), major, only)
        case ["set", config, tool, old, new]:
            return set_version(Path(config), tool, old, new)
        case ["use", config, tool, version]:
            return use_version(Path(config), tool, version)
        case ["locked", config, lock, before, tool, version]:
            return check_locked(
                Path(config), Path(lock), Path(before), tool, version
            )
        case _:
            print(
                "usage: versions.py outdated <mise.toml> [--major] [tool...]\n"
                "       versions.py set <mise.toml> <tool> <old> <new>\n"
                "       versions.py use <mise.toml> <tool> <version>\n"
                "       versions.py locked <mise.toml> <mise.lock> "
                "<lock before> <tool> <version>",
                file=sys.stderr,
            )
            return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
