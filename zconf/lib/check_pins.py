import re
import sys
import tomllib
from pathlib import Path

FLOATING = {"latest", "lts", "stable"}
RANGE_CHARS = set("^~><*")
SHA = re.compile(r"[0-9a-f]{40}")
NUMERIC = re.compile(r"\d+(\.\d+)*")
PREFIXED = re.compile(r"[a-z][a-z0-9-]*:")
WILDCARD = re.compile(r"(^|\.)x(\.|$)")
ARCH = {"aarch64": "arm64", "x86_64": "x64", "amd64": "x64"}
# Global [settings] apply in every directory, including other projects.
GLOBAL_SETTINGS_ALLOWED = {"idiomatic_version_file_enable_tools"}
GLOBAL_KEYS_ALLOWED = {"min_version", "settings", "tool_config", "tools"}


def is_exact(version: str) -> bool:
    if version.lower() in FLOATING or RANGE_CHARS & set(version):
        return False
    if PREFIXED.match(version) or WILDCARD.search(version):
        return False
    if NUMERIC.fullmatch(version):
        return version.count(".") >= 2
    return bool(version)


def tool_versions(value: object) -> list[str]:
    match value:
        case str():
            return [value]
        case list():
            return [v for item in value for v in tool_versions(item)]
        case {"version": str() as version}:
            return [version]
        case _:
            return []


def setting_keys(table: dict, prefix: str = "") -> list[str]:
    keys = []
    for key, value in table.items():
        match value:
            case dict():
                keys += setting_keys(value, f"{prefix}{key}.")
            case _:
                keys.append(f"{prefix}{key}")
    return keys


def check_global_policy(config: dict) -> list[str]:
    errors = [
        f"global [{key}] applies to every project; keep it out of "
        "the global config"
        for key in config
        if key not in GLOBAL_KEYS_ALLOWED
    ]
    errors += [
        f"global setting {key} applies to every project; "
        "keep policy in [tool_config] or zconf"
        for key in setting_keys(config.get("settings", {}))
        if key not in GLOBAL_SETTINGS_ALLOWED
    ]
    if config.get("tool_config", {}).get("locked") is not True:
        errors.append("[tool_config] locked = true is missing")
    return errors


def lock_platforms(config: Path) -> list[str]:
    text = (config.parent / "zconf" / "platforms").read_text()
    return [p for p in text.strip().split(",") if p]


def os_allows(value: object, platform: str) -> bool:
    match value:
        case {"os": list() as allowed}:
            pass
        case _:
            return True
    system, _, arch = platform.partition("-")
    for entry in allowed:
        name, _, want = entry.partition("/")
        if name == system and (not want or ARCH.get(want, want) == arch):
            return True
    return False


def missing_platforms(
    value: object, entries: list[dict], platforms: list[str]
) -> list[str]:
    locked = {
        key.removeprefix("platforms.")
        for entry in entries
        for key in entry
        if key.startswith("platforms.")
    }
    if not locked:
        return []
    return [p for p in platforms if os_allows(value, p) and p not in locked]


def check_mise(config: Path, lock: Path) -> tuple[list[str], int]:
    parsed = tomllib.loads(config.read_text())
    tools = parsed.get("tools", {})
    locked = tomllib.loads(lock.read_text()).get("tools", {})
    platforms = lock_platforms(config)
    errors = check_global_policy(parsed)
    for name, value in tools.items():
        versions = tool_versions(value)
        if not versions:
            errors.append(f"{name} has no version")
        for version in versions:
            entries = [
                e for e in locked.get(name, []) if e.get("version") == version
            ]
            if not is_exact(version):
                errors.append(f'{name} = "{version}" is not an exact version')
            elif not entries:
                errors.append(f"{name} {version} is not in the lock")
            elif gaps := missing_platforms(value, entries, platforms):
                errors.append(
                    f"{name} {version} is not locked for {', '.join(gaps)}"
                )
    return errors, len(tools)


def check_zsh(pins: Path) -> list[str]:
    values = dict(
        line.split("=", 1)
        for line in pins.read_text().splitlines()
        if "=" in line and not line.startswith("#")
    )
    if SHA.fullmatch(values.get("OHMYZSH_COMMIT", "")):
        return []
    return ["OHMYZSH_COMMIT is not a full commit sha"]


def tmux_plugins(conf: Path) -> list[str]:
    plugins = []
    for line in conf.read_text().splitlines():
        match line.split():
            case ["set" | "set-option", "-g", "@plugin", value, *_]:
                name = value.replace("'", "").replace('"', "")
                plugins.append(name.split("#", 1)[0])
            case _:
                pass
    return plugins


def check_tmux(conf: Path, pins: Path) -> list[str]:
    pinned = dict(
        line.split("\t", 1)
        for line in pins.read_text().splitlines()
        if "\t" in line and not line.startswith("#")
    )
    errors = []
    for plugin in tmux_plugins(conf):
        commit = pinned.get(plugin)
        if commit is None:
            errors.append(f"tmux plugin {plugin} is not pinned")
        elif not SHA.fullmatch(commit):
            errors.append(
                f"tmux plugin {plugin} pin {commit} is not a full commit sha"
            )
    return errors


def main(argv: list[str]) -> int:
    match argv:
        case ["--mise", config, lock]:
            errors, count = check_mise(Path(config), Path(lock))
        case [config, lock, zsh_pins, tmux_conf, tmux_pins]:
            errors, count = check_mise(Path(config), Path(lock))
            errors += check_zsh(Path(zsh_pins))
            errors += check_tmux(Path(tmux_conf), Path(tmux_pins))
        case _:
            print(
                "usage: check_pins.py <mise.toml> <mise.lock> <zsh pins> "
                "<tmux.conf> <tmux pins>\n"
                "       check_pins.py --mise <mise.toml> <mise.lock>",
                file=sys.stderr,
            )
            return 2
    for error in errors:
        print(f"ERROR: {error}")
    if errors:
        return 1
    print(f"OK: pins exact and locked ({count} mise tools)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
