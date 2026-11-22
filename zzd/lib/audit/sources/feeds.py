import re

import ghapi
import webapi
from cpe import version_key
from model import Component, Finding

NODE_DB = "https://raw.githubusercontent.com/nodejs/security-wg/main/vuln/core/index.json"
NODE_DIST = "https://nodejs.org/dist/index.json"
DOTNET_INDEX = "https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json"
ENDOFLIFE = "https://endoflife.date/api/v1/products/{product}"
RUBYSEC = "rubysec/ruby-advisory-db"
RUBYSEC_DIR = "rubies/ruby"
RUBYSEC_QUERY = """
query($owner: String!, $name: String!, $expression: String!) {
  repository(owner: $owner, name: $name) {
    object(expression: $expression) {
      ... on Tree {
        entries {
          name
          object {
            ... on Blob {
              text
            }
          }
        }
      }
    }
  }
}
"""
COMPARATOR = re.compile(r"^(<=|>=|<|>|=|~>|~|\^)?\s*v?([0-9xX*][0-9A-Za-z.*+-]*)$")
COMPARATOR_TOKEN = re.compile(r"(?:<=|>=|<|>|=|~>|~|\^)?\s*v?[0-9xX*][0-9A-Za-z.*+-]*")
CONSTRAINT_SEPARATORS = re.compile(r"[\s,]*")
NPM = "npm"
GEM = "gem"
DIALECTS = (NPM, GEM)
YAML_KEY = re.compile(r"^([a-z_]+):\s*(.*)$")
YAML_ITEM = re.compile(r"^\s+-\s+(.*)$")


class SourceError(Exception):
    pass


def _require(record: object, fields: tuple[str, ...], what: str) -> dict:
    if not isinstance(record, dict):
        raise SourceError(f"{what}: expected an object, got {type(record).__name__}")

    missing = [name for name in fields if name not in record]

    if missing:
        raise SourceError(f"{what}: missing {', '.join(missing)}; the feed format changed")

    return record


def _parts(version: str) -> list[int]:
    return [int(part) for part in re.findall(r"[0-9]+", version)[:3]]


def _x_range(bound: str) -> tuple[str, str] | None:
    pieces = re.split(r"[.]", bound)
    numbers: list[str] = []

    for piece in pieces:
        if piece in ("x", "X", "*"):
            break

        numbers.append(piece)

    if len(numbers) == len(pieces) and len(numbers) >= 3:
        return None

    if not numbers:
        return ("0", "")

    upper = [*map(int, numbers)]
    upper[-1] += 1

    return (".".join(numbers), ".".join(map(str, upper)))


def _comparator(version: str, text: str, dialect: str) -> bool:
    match = COMPARATOR.match(text.strip())

    if match is None:
        raise SourceError(f"cannot read the version constraint '{text}'")

    operator, bound = match.group(1) or "", match.group(2)
    key = version_key(version)
    wildcard = _x_range(bound)

    if wildcard is not None and operator in ("", "="):
        lower, upper = wildcard
        return key >= version_key(lower) and (not upper or key < version_key(upper))

    if wildcard is not None and dialect == NPM and operator in ("<=", ">"):
        upper = wildcard[1]

        if operator == "<=":
            return not upper or key < version_key(upper)

        return bool(upper) and key >= version_key(upper)

    match operator:
        case "<":
            return key < version_key(bound)
        case "<=":
            return key <= version_key(bound)
        case ">":
            return key > version_key(bound)
        case ">=":
            return key >= version_key(bound)
        case "^":
            numbers = _parts(bound)
            first = next((index for index, number in enumerate(numbers) if number != 0), len(numbers) - 1)
            upper = numbers[: first + 1]
            upper[-1] += 1
            return key >= version_key(bound) and key < version_key(".".join(map(str, upper)))
        case "~" | "~>":
            numbers = _parts(bound)
            keep = max(len(bound.split(".")) - 1, 1)

            if operator == "~":
                keep = min(2, len(numbers))

            upper = numbers[:keep]
            upper[-1] += 1
            return key >= version_key(bound) and key < version_key(".".join(map(str, upper)))
        case _:
            return key == version_key(bound)


def satisfies(version: str, expression: str, dialect: str) -> bool:
    if dialect not in DIALECTS:
        raise SourceError(f"unknown version constraint dialect '{dialect}'")

    for alternative in expression.split("||"):
        text = alternative.strip()

        if text in ("", "*"):
            return True

        hyphen = re.match(r"^(\S+)\s+-\s+(\S+)$", text)

        if hyphen:
            if version_key(hyphen.group(1)) <= version_key(version) <= version_key(hyphen.group(2)):
                return True
            continue

        if all(_comparator(version, part, dialect) for part in _comparators(text)):
            return True

    return False


def _comparators(text: str) -> list[str]:
    parts = COMPARATOR_TOKEN.findall(text)
    leftover = CONSTRAINT_SEPARATORS.sub("", COMPARATOR_TOKEN.sub("", text))

    if leftover or not parts:
        raise SourceError(f"cannot read the version constraint '{text}'")

    return parts


def node(component: Component, version: str) -> list[Finding]:
    database = webapi.get_json(NODE_DB)
    findings: list[Finding] = []

    if not isinstance(database, dict) or not database:
        raise SourceError("the Node.js security database is empty or not an object")

    for key, entry in sorted(database.items()):
        _require(entry, ("vulnerable", "patched"), f"Node.js security database entry {key}")
        vulnerable = entry.get("vulnerable") or ""
        patched = entry.get("patched") or ""

        if vulnerable and satisfies(version, vulnerable, NPM) and not (patched and satisfies(version, patched, NPM)):
            findings.append(
                Finding(
                    component=component,
                    source="nodejs security-wg",
                    id=", ".join(entry.get("cve") or [f"nodejs-core-{key}"]),
                    summary=entry.get("overview") or entry.get("description", ""),
                    fixed_in=(patched,),
                    package=f"node@{version}",
                )
            )

    releases = webapi.get_json(NODE_DIST)
    line = _parts(version)[:1]

    if not isinstance(releases, list) or not releases:
        raise SourceError("the Node.js release index is empty or not a list")

    for release in releases:
        _require(release, ("version", "security"), "Node.js release index entry")
        number = release["version"].removeprefix("v")

        if _parts(number)[:1] == line and version_key(number) > version_key(version) and release.get("security"):
            findings.append(
                Finding(
                    component=component,
                    source="nodejs.org dist index",
                    id=f"node-security-release-{release['version']}",
                    summary=f"Node.js {release['version']} is a security release newer than {version}",
                    fixed_in=(number,),
                    package=f"node@{version}",
                )
            )

    return findings


def _yaml(text: str) -> dict:
    data: dict = {}
    current = ""

    for line in text.splitlines():
        key = YAML_KEY.match(line)

        if key:
            current = key.group(1)
            value = key.group(2).strip().strip("'\"")
            data[current] = value or []
            continue

        item = YAML_ITEM.match(line)

        if item and isinstance(data.get(current), list):
            data[current].append(item.group(1).strip().strip("'\""))

    return data


def _rubysec_files() -> list[dict]:
    owner, name = RUBYSEC.split("/")

    try:
        data = ghapi.graphql(RUBYSEC_QUERY, {"owner": owner, "name": name, "expression": f"HEAD:{RUBYSEC_DIR}"})
    except ghapi.GitHubError as error:
        raise SourceError(f"cannot read {RUBYSEC} {RUBYSEC_DIR}: {error}") from error

    tree = (data.get("repository") or {}).get("object") or {}
    entries = [entry for entry in tree.get("entries") or [] if entry["name"].endswith(".yml")]
    unreadable = [entry["name"] for entry in entries if (entry.get("object") or {}).get("text") is None]

    if unreadable:
        raise SourceError(f"{RUBYSEC} files could not be read as text: {', '.join(unreadable)}")

    return [_yaml(entry["object"]["text"]) for entry in entries]


def _rubysec_id(advisory: dict) -> str:
    match advisory:
        case {"cve": str(cve)} if cve:
            return f"CVE-{cve.removeprefix('CVE-')}"
        case {"ghsa": str(ghsa)} if ghsa:
            return f"GHSA-{ghsa.removeprefix('GHSA-')}"
        case {"osvdb": str(osvdb)} if osvdb:
            return f"OSVDB-{osvdb}"
        case _:
            raise SourceError(f"{RUBYSEC} advisory '{advisory.get('title', '')}' has no identifier")


def rubysec(component: Component, version: str) -> list[Finding]:
    findings: list[Finding] = []
    advisories = _rubysec_files()

    if not advisories:
        raise SourceError(f"{RUBYSEC} {RUBYSEC_DIR} has no advisories")

    for advisory in advisories:
        patched = advisory.get("patched_versions") or []
        unaffected = advisory.get("unaffected_versions") or []

        if any(satisfies(version, item, GEM) for item in [*patched, *unaffected]):
            continue

        findings.append(
            Finding(
                component=component,
                source="rubysec ruby-advisory-db",
                id=_rubysec_id(advisory),
                summary=str(advisory.get("title", "")),
                fixed_in=tuple(patched),
                package=f"ruby@{version}",
            )
        )

    return findings


def dotnet_runtime(sdk_version: str) -> str:
    return _dotnet_release(sdk_version)[1]["release-version"]


def dotnet(component: Component, sdk_version: str) -> list[Finding]:
    releases, pinned = _dotnet_release(sdk_version)
    pinned_runtime = pinned["release-version"]

    return [
        Finding(
            component=component,
            source=".NET release metadata",
            id=", ".join(cve.get("cve-id", "") for cve in release.get("cve-list", [])) or f"dotnet-security-{release['release-version']}",
            summary=f".NET {release['release-version']} is a security release newer than the pinned SDK {sdk_version}",
            fixed_in=(release.get("sdk", {}).get("version", release["release-version"]),),
            package=f"dotnet-sdk@{sdk_version}",
        )
        for release in releases
        if release.get("security") and version_key(release["release-version"]) > version_key(pinned_runtime)
    ]


def _dotnet_release(sdk_version: str) -> tuple[list[dict], dict]:
    channel = ".".join(sdk_version.split(".")[:2])
    index = webapi.get_json(DOTNET_INDEX)
    entry = next((item for item in index.get("releases-index", []) if item.get("channel-version") == channel), None)

    if entry is None:
        raise SourceError(f".NET release metadata has no channel {channel}")

    releases = webapi.get_json(entry["releases.json"]).get("releases", [])

    for release in releases:
        _require(release, ("release-version", "security"), f".NET {channel} release")

    pinned = next(
        (
            release
            for release in releases
            if sdk_version in [sdk.get("version") for sdk in release.get("sdks", [])]
            or release.get("sdk", {}).get("version") == sdk_version
        ),
        None,
    )

    if pinned is None:
        raise SourceError(f".NET {channel} release metadata does not list SDK {sdk_version}")

    return releases, pinned


def eol_cycle(product: str, version: str) -> dict:
    try:
        releases = webapi.get_json(ENDOFLIFE.format(product=product)).get("result", {}).get("releases", [])
    except webapi.WebError as error:
        raise SourceError(f"endoflife.date {product} cannot be read: {error}") from error

    cycles = sorted(
        (release for release in releases if version == release["name"] or version.startswith(f"{release['name']}.")),
        key=lambda release: len(release["name"]),
        reverse=True,
    )

    if not cycles:
        raise SourceError(f"endoflife.date {product} has no cycle for {version}")

    return _require(cycles[0], ("name", "isEol"), f"endoflife.date {product} cycle")


def end_of_life(component: Component, product: str, version: str) -> list[Finding]:
    cycle = eol_cycle(product, version)

    if not cycle.get("isEol"):
        return []

    return [
        Finding(
            component=component,
            source="endoflife.date",
            id=f"end-of-life-{product}-{cycle['name']}",
            summary=f"{product} {cycle['name']} reached end of life on {cycle.get('eolFrom')}; it gets no more security fixes",
            fixed_in=("a supported cycle",),
            package=f"{product}@{version}",
        )
    ]


FEEDS = {
    "node": node,
    "rubysec": rubysec,
    "dotnet": dotnet,
}
