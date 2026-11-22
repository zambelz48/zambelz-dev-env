import json
import re
from dataclasses import dataclass
from pathlib import Path
from xml.etree import ElementTree

import procs

MSBUILD_PROPERTY = re.compile(r"\$\(([A-Za-z_][A-Za-z0-9_.-]*)\)")
HACKAGE_ID = re.compile(rb"\b([A-Za-z][A-Za-z0-9]*(?:-[A-Za-z][A-Za-z0-9]*)*)-([0-9]+(?:\.[0-9]+)+)-(?:[0-9a-f]{64}|inplace)\b")
GHC_VERSION = re.compile(r'\("GHC version", "([0-9]+(?:\.[0-9]+)+)"\)')
DEPS_JSON_MARKER = b'"runtimeTarget"'
RUNTIME_PACK_PREFIX = "runtimepack."
PYTHON_PROBE = (
    "import ssl, sqlite3, zlib, pyexpat\n"
    "print(ssl.OPENSSL_VERSION.split()[1])\n"
    "print(sqlite3.sqlite_version)\n"
    "print(zlib.ZLIB_RUNTIME_VERSION)\n"
    "print(pyexpat.EXPAT_VERSION.removeprefix('expat_'))\n"
)
PYTHON_LIBRARIES = ("openssl", "sqlite", "zlib", "expat")
COMMAND_TIMEOUT_SECONDS = 60


class SourceError(Exception):
    pass


@dataclass(frozen=True)
class Package:
    ecosystem: str
    name: str
    version: str


def _bytes(path: str) -> bytes:
    try:
        return Path(path).read_bytes()
    except OSError as error:
        raise SourceError(f"cannot read {path}: {error}") from error


def haskell_binary(path: str) -> list[Package]:
    data = _bytes(path)
    ghc = GHC_VERSION.search(_run([path, "+RTS", "--info"]))

    if ghc is None:
        raise SourceError(f"{path} +RTS --info does not report the GHC version it was built with")

    packages = {
        (name.decode(), version.decode())
        for name, version in HACKAGE_ID.findall(data)
    }

    if not packages:
        raise SourceError(f"{path} has no Haskell package ids")

    return [
        Package("GHC", "ghc", ghc.group(1)),
        *(Package("Hackage", name, version) for name, version in sorted(packages)),
    ]


def _embedded_json(data: bytes, marker: bytes, path: str) -> dict:
    position = data.find(marker)

    if position < 0:
        raise SourceError(f"{path} has no embedded deps.json")

    start = data.rfind(b"{", 0, position)
    depth = 0

    for index in range(start, len(data)):
        match data[index]:
            case 123:
                depth += 1
            case 125:
                depth -= 1

                if depth == 0:
                    try:
                        return json.loads(data[start : index + 1])
                    except json.JSONDecodeError as error:
                        raise SourceError(f"{path} has an unreadable embedded deps.json: {error}") from error

    raise SourceError(f"{path} has a truncated embedded deps.json")


def dotnet_single_file(path: str) -> list[Package]:
    document = _embedded_json(_bytes(path), DEPS_JSON_MARKER, path)
    packages: list[Package] = []

    for key, library in document.get("libraries", {}).items():
        name, _, version = key.rpartition("/")

        match library.get("type"):
            case "package":
                packages.append(Package("NuGet", name, version))
            case "runtimepack":
                packages.append(Package("NuGet", name.removeprefix(RUNTIME_PACK_PREFIX), version))
            case "project":
                continue
            case other:
                raise SourceError(f"{path}: unknown deps.json library type '{other}' for {key}")

    if not packages:
        raise SourceError(f"{path}: the embedded deps.json lists no packages")

    return packages


def nuget_central(text: str, path: str) -> list[Package]:
    try:
        root = ElementTree.fromstring(text)
    except ElementTree.ParseError as error:
        raise SourceError(f"{path} is not valid XML: {error}") from error

    properties = {
        element.tag: (element.text or "").strip()
        for group in root.iter("PropertyGroup")
        for element in group
    }
    packages: list[Package] = []

    for element in root.iter("PackageVersion"):
        name = element.get("Include")
        version = MSBUILD_PROPERTY.sub(lambda match: properties.get(match.group(1), match.group(0)), element.get("Version", ""))

        if not name or not version or "$(" in version:
            raise SourceError(f"{path}: cannot resolve the version of {name or 'a PackageVersion'} ({element.get('Version')})")

        packages.append(Package("NuGet", name, version))

    if not packages:
        raise SourceError(f"{path} has no PackageVersion entries")

    return packages


def _run(argv: list[str]) -> str:
    try:
        done = procs.run(argv, env=procs.no_install_env(), timeout=COMMAND_TIMEOUT_SECONDS)
    except procs.CommandError as error:
        raise SourceError(str(error)) from error

    if done.code != 0:
        detail = (done.stderr or done.stdout).strip().splitlines()[-1:] or [""]
        raise SourceError(f"{argv[0]} exited {done.code}: {detail[0]}")

    return done.stdout


def python_runtime(install: str) -> dict[str, str]:
    interpreter = Path(install) / "bin/python3"
    lines = _run([str(interpreter), "-I", "-c", PYTHON_PROBE]).split()

    if len(lines) != len(PYTHON_LIBRARIES):
        raise SourceError(f"{interpreter} reported {lines}, expected versions of {', '.join(PYTHON_LIBRARIES)}")

    return dict(zip(PYTHON_LIBRARIES, lines))


def command_version(path: str, args: list[str], regex: str) -> str:
    output = _run([path, *args])
    match = re.search(regex, output)

    if match is None:
        raise SourceError(f"{path} {' '.join(args)} printed no version matching {regex}")

    return match.group(1)
