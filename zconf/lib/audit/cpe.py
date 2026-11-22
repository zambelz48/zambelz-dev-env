import re
from dataclasses import dataclass

ANY = ("*", "-")
SPLIT = re.compile(r"(?<!\\):")
TOKEN = re.compile(r"\d+|[A-Za-z]+")
OS_VENDORS = {
    "linux": ("linux:linux_kernel",),
    "darwin": ("apple:macos", "apple:mac_os_x", "apple:mac_os"),
}


@dataclass(frozen=True)
class Cpe:
    part: str
    vendor: str
    product: str
    version: str
    target_sw: str

    def product_key(self) -> tuple[str, str, str]:
        return (self.part, self.vendor, self.product)


def parse(text: str) -> Cpe:
    fields = SPLIT.split(text)

    if len(fields) < 5 or fields[0] != "cpe" or fields[1] != "2.3":
        raise ValueError(f"not a CPE 2.3 name: {text}")

    padded = [*fields, *["*"] * (13 - len(fields))]

    return Cpe(part=padded[2], vendor=padded[3], product=padded[4], version=padded[5], target_sw=padded[10])


RELEASE = re.compile(r"[vV]?([0-9]+(?:[._-][0-9]+)*)(.*)$")
POST_RELEASE = ("+", "post", ".post", "-post", "p")
PRE_RELEASE = 0
FINAL = 1
POST = 2


def _tokens(text: str) -> tuple:
    return tuple((1, int(token)) if token.isdigit() else (0, token.lower()) for token in TOKEN.findall(text))


def version_key(version: str) -> tuple:
    match = RELEASE.match(version.strip())

    if match is None:
        return ((), PRE_RELEASE, _tokens(version))

    release = [int(part) for part in re.split(r"[._-]", match.group(1))]

    while release and release[-1] == 0:
        release.pop()

    rest = match.group(2)

    if not rest:
        return (tuple(release), FINAL, ())

    if rest.lower().startswith(POST_RELEASE):
        return (tuple(release), POST, _tokens(rest))

    return (tuple(release), PRE_RELEASE, _tokens(rest))


def _in_range(version: str, match: dict) -> bool:
    key = version_key(version)
    bounds = (
        ("versionStartIncluding", lambda bound: key >= version_key(bound)),
        ("versionStartExcluding", lambda bound: key > version_key(bound)),
        ("versionEndIncluding", lambda bound: key <= version_key(bound)),
        ("versionEndExcluding", lambda bound: key < version_key(bound)),
    )

    return all(check(match[name]) for name, check in bounds if name in match)


def _matches_component(match: dict, component: Cpe, version: str) -> bool:
    criteria = parse(match["criteria"])

    if criteria.product_key() != component.product_key():
        return False

    if criteria.target_sw not in ANY and criteria.target_sw != component.target_sw:
        return False

    if criteria.version not in ANY:
        return version_key(criteria.version) == version_key(version)

    return _in_range(version, match)


def _os_satisfied(match: dict, system: str) -> bool | None:
    criteria = parse(match["criteria"])

    if criteria.part != "o":
        return None

    name = f"{criteria.vendor}:{criteria.product}"

    if name in OS_VENDORS.get(system, ()):
        return True

    for vendors in OS_VENDORS.values():
        if name in vendors:
            return False

    if criteria.vendor == "microsoft":
        return False

    return None


def _node_matches(node: dict, component: Cpe, version: str, system: str) -> tuple[bool, bool]:
    hits = [_matches_component(match, component, version) for match in node.get("cpeMatch", []) if match.get("vulnerable")]
    ours = any(hits)
    platform: list[bool] = []

    for match in node.get("cpeMatch", []):
        if match.get("vulnerable"):
            continue

        satisfied = _os_satisfied(match, system)

        if satisfied is not None:
            platform.append(satisfied)

    met = ours or not platform or any(platform)

    if node.get("negate"):
        met = not met

    return ours, met


def fixed_versions(cve: dict, component: Cpe, version: str) -> tuple[str, ...]:
    found: set[str] = set()

    for configuration in cve.get("configurations", []):
        for node in configuration.get("nodes", []):
            for match in node.get("cpeMatch", []):
                end = match.get("versionEndExcluding")

                if end and _matches_component(match, component, version):
                    found.add(end)

    return tuple(sorted(found, key=version_key))


def applies(cve: dict, component: Cpe, version: str, system: str) -> bool:
    for configuration in cve.get("configurations", []):
        results = [_node_matches(node, component, version, system) for node in configuration.get("nodes", [])]

        if not results:
            continue

        ours = any(hit for hit, _ in results)

        match configuration.get("operator", "OR"):
            case "AND":
                if ours and all(met for _, met in results):
                    return True
            case _:
                if ours:
                    return True

    return False
