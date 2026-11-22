import json
import os
import re
from pathlib import Path

import procs
from model import FIX_AVAILABLE, WAITING, Component, Finding, Kind, Scope
from sources import osv

DNF_ADVISORIES = ["dnf", "-q", "--refresh", "advisory", "list", "--security", "--available", "--json"]
DNF_FIELDS = ("name", "type", "severity", "nevra")
DNF_TIMEOUT_SECONDS = 900


class SourceError(Exception):
    pass


def os_release() -> dict[str, str]:
    path = Path(os.environ.get("ZZD_OS_RELEASE") or "/etc/os-release")
    values: dict[str, str] = {}

    for line in path.read_text().splitlines():
        key, separator, value = line.partition("=")

        if separator:
            values[key.strip()] = value.strip().strip("\"'")

    return values


def _nevra_name(nevra: str) -> str:
    return nevra.rsplit("-", 2)[0]


def _host(manager: str, release: dict[str, str]) -> Component:
    return Component(
        Kind.OS_PACKAGE,
        f"{release.get('ID', 'os')}-host",
        release.get("VERSION_ID", ""),
        f"{manager} (packages installed on this machine)",
        Scope.INSTALLED,
        {"manager": manager},
    )


def dnf_advisories() -> list[dict]:
    try:
        done = procs.run(DNF_ADVISORIES, timeout=DNF_TIMEOUT_SECONDS)
    except procs.CommandError as error:
        raise SourceError(f"dnf advisory list could not run: {error}") from error

    if done.code != 0:
        detail = (done.stderr or done.stdout).strip().splitlines()[-1:] or [""]
        raise SourceError(f"dnf advisory list exited {done.code}: {detail[0]}")

    try:
        advisories = json.loads(done.stdout or "[]")
    except json.JSONDecodeError as error:
        raise SourceError(f"dnf advisory list returned invalid JSON: {error}") from error

    if not isinstance(advisories, list):
        raise SourceError("dnf advisory list did not return a list")

    for advisory in advisories:
        missing = [name for name in DNF_FIELDS if not isinstance(advisory, dict) or name not in advisory]

        if missing:
            raise SourceError(f"dnf advisory entry is missing {', '.join(missing)}; the dnf output format changed")

    return advisories


def dnf(components: list[Component]) -> list[Finding]:
    by_name = {component.name: component for component in components}
    host = _host("dnf", os_release())
    findings: list[Finding] = []

    for advisory in dnf_advisories():
        package = _nevra_name(advisory["nevra"])
        findings.append(
            Finding(
                component=by_name.get(package, host),
                source="dnf security advisories",
                id=advisory["name"],
                summary=f"{advisory['nevra']} fixes a security issue in the installed {package}",
                fixed_in=(advisory["nevra"],),
                severity=str(advisory["severity"]).lower(),
                package=package,
            )
        )

    return findings


def apt_versions(package: str) -> tuple[str, str] | None:
    try:
        done = procs.run(["apt-cache", "policy", package])
    except procs.CommandError:
        return None

    installed = re.search(r"^\s*Installed:\s*(\S+)", done.stdout, re.MULTILINE)
    candidate = re.search(r"^\s*Candidate:\s*(\S+)", done.stdout, re.MULTILINE)

    if done.code != 0 or installed is None or candidate is None or installed.group(1) == "(none)":
        return None

    return installed.group(1), candidate.group(1)


def status(finding: Finding) -> dict[str, str]:
    manager = finding.component.locator.get("manager")

    match manager:
        case "dnf":
            return {"status": FIX_AVAILABLE, "action": f"sudo dnf upgrade --advisory={finding.id}"}
        case "apt":
            return _apt_status(finding.component.name)
        case _:
            return {}


def _apt_status(package: str) -> dict[str, str]:
    versions = apt_versions(package)

    if versions is None:
        return {}

    installed, candidate = versions

    if candidate != installed:
        return {
            "status": FIX_AVAILABLE,
            "action": f"sudo apt-get install --only-upgrade {package} ({installed} -> {candidate}), then audit again",
        }

    return {"status": WAITING, "action": f"none possible yet; {package} {installed} is the newest version the distribution ships"}


def ubuntu_ecosystem(release: dict[str, str]) -> str:
    if release.get("ID") != "ubuntu" or not release.get("VERSION_ID"):
        raise SourceError(f"not an Ubuntu release: ID={release.get('ID')} VERSION_ID={release.get('VERSION_ID')}")

    if "LTS" in release.get("VERSION", ""):
        return f"Ubuntu:{release['VERSION_ID']}:LTS"

    return f"Ubuntu:{release['VERSION_ID']}"


def apt(components: list[Component]) -> list[Finding]:
    ecosystem = ubuntu_ecosystem(os_release())
    queries: list[osv.PackageQuery] = []

    for component in components:
        source = component.locator.get("source")
        source_version = component.locator.get("source_version")

        if not source or not source_version:
            raise SourceError(f"{component.key()}: the installed package has no source package name or version")

        queries.append(osv.PackageQuery(component, ecosystem, source, source_version))

    return osv.query_packages(queries)
