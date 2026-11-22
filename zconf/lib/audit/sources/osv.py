import json
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

import ghapi
import procs
import webapi
from model import Component, Finding

QUERY_BATCH = "https://api.osv.dev/v1/querybatch"
VULN = "https://api.osv.dev/v1/vulns/{id}"
BATCH_SIZE = 1000
PARALLEL = 8
ANSWERS = (0, 1)


class SourceError(Exception):
    pass


@dataclass(frozen=True)
class PackageQuery:
    component: Component
    ecosystem: str
    name: str
    version: str


@dataclass(frozen=True)
class CommitQuery:
    component: Component
    commit: str


def scanner() -> str:
    try:
        return procs.checked(["mise", "which", "osv-scanner"], cwd=Path.home()).strip()
    except procs.CommandError as error:
        raise SourceError(f"osv-scanner is not installed by mise: {error}") from error


def _fixed(vulnerability: dict, package: dict) -> tuple[str, ...]:
    fixed: list[str] = []

    for affected in vulnerability.get("affected", []):
        affected_name = affected.get("package", {}).get("name")

        if package.get("name") and affected_name and affected_name != package.get("name"):
            continue

        for version_range in affected.get("ranges", []):
            for event in version_range.get("events", []):
                if "fixed" in event:
                    fixed.append(event["fixed"])

    return tuple(dict.fromkeys(fixed))


def _severity(entry: dict, vulnerability_id: str) -> str:
    for group in entry.get("groups", []):
        if vulnerability_id in group.get("ids", []) and group.get("max_severity"):
            return f"CVSS {group['max_severity']}"

    return "unknown"


def findings_from_scan(component: Component, output: dict) -> list[Finding]:
    findings: list[Finding] = []

    for result in output.get("results", []):
        for entry in result.get("packages", []):
            package = entry["package"]
            label = f"{package.get('ecosystem')}/{package['name']}@{package.get('version', '')}"
            dev_only = (entry.get("dependency_groups") or []) == ["dev"]

            for vulnerability in entry.get("vulnerabilities", []):
                findings.append(
                    Finding(
                        component=component,
                        source=f"osv-scanner:{result.get('source', {}).get('path', '')}",
                        id=vulnerability["id"],
                        summary=vulnerability.get("summary") or vulnerability.get("details", "")[:200],
                        aliases=tuple(vulnerability.get("aliases", [])),
                        fixed_in=_fixed(vulnerability, package),
                        severity=_severity(entry, vulnerability["id"]),
                        dev_only=dev_only,
                        package=label,
                    )
                )

    return findings


def _scan(component: Component, args: list[str]) -> list[Finding]:
    with tempfile.TemporaryDirectory() as workdir:
        config = Path(workdir) / "empty.toml"
        config.write_text("")
        done = procs.run(
            [scanner(), "scan", "source", "--config", str(config), "-f", "json", *args],
            env=procs.no_install_env(),
            cwd=Path(workdir),
        )

    if done.code not in ANSWERS:
        detail = (done.stderr.strip().splitlines() or [""])[-1]
        raise SourceError(f"osv-scanner exited {done.code} for {component.key()}: {detail}")

    if not done.stdout.strip():
        return []

    return findings_from_scan(component, json.loads(done.stdout))


def scan_lockfile(component: Component, path: str) -> list[Finding]:
    return _scan(component, ["-L", path])


def scan_artifact(component: Component, path: str) -> list[Finding]:
    plugins = ["lockfile", "sbom", "directory", "artifact"]
    args = [item for plugin in plugins for item in ("--x-plugins", plugin)]

    return _scan(component, [*args, "--allow-no-lockfiles", "-r", path])


def scan_upstream(component: Component, repo: str, tag: str, paths: list[str]) -> list[Finding]:
    findings: list[Finding] = []

    with tempfile.TemporaryDirectory() as workdir:
        for index, path in enumerate(paths):
            try:
                text = ghapi.raw_file(repo, path, tag)
            except ghapi.GitHubError as error:
                raise SourceError(f"cannot fetch {repo} {path} at {tag}: {error}") from error

            target = Path(workdir) / str(index) / Path(path).name
            target.parent.mkdir(parents=True)
            target.write_text(text)
            findings.extend(_scan(component, ["-L", str(target)]))

    return findings


def _details(vulnerability_id: str) -> dict:
    return webapi.get_json(VULN.format(id=vulnerability_id))


def _batch(entries: list[dict]) -> list[dict]:
    answer = webapi.post_json(QUERY_BATCH, {"queries": entries})
    results = answer.get("results")

    if not isinstance(results, list) or len(results) != len(entries):
        raise SourceError("OSV querybatch returned a results list that does not match the queries")

    return results


def _query(entries: list[dict]) -> list[list[str]]:
    ids: list[list[str]] = []

    for start in range(0, len(entries), BATCH_SIZE):
        chunk = entries[start : start + BATCH_SIZE]
        results = _batch(chunk)

        for entry, result in zip(chunk, results):
            found = [vuln["id"] for vuln in result.get("vulns", [])]
            token = result.get("next_page_token")

            while token:
                page = _batch([{**entry, "page_token": token}])[0]
                found.extend(vuln["id"] for vuln in page.get("vulns", []))
                token = page.get("next_page_token")

            ids.append(found)

    return ids


def _findings_for_ids(component: Component, label: str, vulnerability_ids: list[str], name: str) -> list[Finding]:
    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        details = list(pool.map(_details, vulnerability_ids))

    return [
        Finding(
            component=component,
            source="osv",
            id=vulnerability["id"],
            summary=vulnerability.get("summary") or vulnerability.get("details", "")[:200],
            aliases=tuple(vulnerability.get("aliases", [])),
            fixed_in=_fixed(vulnerability, {"name": name}),
            package=label,
        )
        for vulnerability in details
    ]


def query_packages(queries: list[PackageQuery]) -> list[Finding]:
    entries = [
        {"package": {"ecosystem": query.ecosystem, "name": query.name}, "version": query.version}
        for query in queries
    ]
    findings: list[Finding] = []

    for query, ids in zip(queries, _query(entries)):
        label = f"{query.ecosystem}/{query.name}@{query.version}"
        findings.extend(_findings_for_ids(query.component, label, ids, query.name))

    return findings


def query_commits(queries: list[CommitQuery]) -> list[Finding]:
    entries = [{"commit": query.commit} for query in queries]
    findings: list[Finding] = []

    for query, ids in zip(queries, _query(entries)):
        findings.extend(_findings_for_ids(query.component, f"commit {query.commit}", ids, ""))

    return findings
