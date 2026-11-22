import datetime
import json
import os
import re
import threading

import cna
import cpe
import ghapi
import webapi
from model import Component, Finding

CVES = "https://services.nvd.nist.gov/rest/json/cves/2.0"
CVE_ORG = "https://cveawg.mitre.org/api/cve/{id}"
PAGE_SIZE = 2000
RECENT_DAYS = 120
ANALYSED = ("Analyzed", "Modified", "Rejected", "Deferred")
METRICS = ("cvssMetricV40", "cvssMetricV31", "cvssMetricV30", "cvssMetricV2")
CONTAINED = ("ahead", "identical")
CVE_LIST_REPO = "CVEProject/cvelistV5"
_CVE_ORG_FAILURE: dict[str, str] = {}
_MEMO: dict[tuple, list[dict]] = {}
_MEMO_KEYS: dict[tuple, threading.Lock] = {}
_MEMO_LOCK = threading.Lock()


class SourceError(Exception):
    pass


def system() -> str:
    return os.uname().sysname.lower()


def _escape(version: str) -> str:
    return version.replace(":", "\\:")


def _pages(params: dict) -> list[dict]:
    key = tuple(sorted(params.items()))

    with _MEMO_LOCK:
        lock = _MEMO_KEYS.setdefault(key, threading.Lock())

    with lock:
        if key not in _MEMO:
            _MEMO[key] = _fetch_pages(params)

    return _MEMO[key]


def _cve_record(cve_id: str) -> dict:
    key = ("cve.org", cve_id)

    with _MEMO_LOCK:
        lock = _MEMO_KEYS.setdefault(key, threading.Lock())

    with lock:
        if key not in _MEMO:
            _MEMO[key] = _published_record(cve_id)

    return _MEMO[key]


def cve_list_path(cve_id: str) -> str:
    _, year, number = cve_id.split("-")

    return f"cves/{year}/{int(number) // 1000}xxx/{cve_id}.json"


def _published_record(cve_id: str) -> dict:
    primary = _CVE_ORG_FAILURE.get("error")

    if primary is None:
        try:
            return webapi.get_json(CVE_ORG.format(id=cve_id))
        except webapi.WebError as error:
            primary = str(error)
            _CVE_ORG_FAILURE["error"] = primary

    try:
        text = ghapi.raw_file(CVE_LIST_REPO, cve_list_path(cve_id), "main")
    except ghapi.GitHubError as mirror:
        raise SourceError(f"{cve_id}: CVE.org failed ({primary}) and {CVE_LIST_REPO} failed ({mirror})") from mirror

    record = json.loads(text)

    if record.get("cveMetadata", {}).get("cveId") != cve_id:
        raise SourceError(f"{CVE_LIST_REPO} returned another record for {cve_id}")

    return record


def _fetch_pages(params: dict) -> list[dict]:
    start = 0
    items: list[dict] = []

    while True:
        data = webapi.get_json(CVES, {**params, "resultsPerPage": PAGE_SIZE, "startIndex": start})

        if "vulnerabilities" not in data or "totalResults" not in data:
            raise SourceError(f"NVD answered without vulnerabilities for {params}")

        items.extend(entry["cve"] for entry in data["vulnerabilities"])
        start += PAGE_SIZE

        if start >= data["totalResults"]:
            return items


def _description(record: dict) -> str:
    for description in record.get("descriptions", []):
        if description.get("lang") == "en":
            return description["value"]

    return ""


def _severity(record: dict) -> str:
    metrics = record.get("metrics", {})

    for name in METRICS:
        for metric in metrics.get(name, []):
            score = metric.get("cvssData", {}).get("baseScore")

            if score is not None:
                return f"CVSS {score}"

    return "unknown"


def analysed(component: Component, base: str, version: str) -> list[Finding]:
    target = cpe.parse(base)
    query = f"{base}:{_escape(version)}"
    records = _pages({"virtualMatchString": query, "noRejected": ""})

    return [
        Finding(
            component=component,
            source=f"nvd {base}",
            id=record["id"],
            summary=_description(record),
            fixed_in=cpe.fixed_versions(record, target, version),
            severity=_severity(record),
            package=f"{target.vendor}:{target.product}@{version}",
        )
        for record in records
        if cpe.applies(record, target, version, system())
    ]


def _fix_commits(record: dict, repo: str) -> list[str]:
    pattern = re.compile(rf"github\.com/{re.escape(repo)}/commit/([0-9a-f]{{7,40}})", re.IGNORECASE)
    found: list[str] = []

    for reference in record.get("references", []):
        match = pattern.search(reference.get("url", ""))

        if match and match.group(1) not in found:
            found.append(match.group(1))

    return found


def _contains(repo: str, fix: str, commit: str) -> bool | None:
    try:
        compare = ghapi.json_get(f"repos/{repo}/compare/{fix}...{commit}")
    except ghapi.GitHubError:
        return None

    return compare.get("status") in CONTAINED


def commit_pinned(component: Component, base: str, repo: str, commit: str) -> list[Finding]:
    findings: list[Finding] = []

    for record in _pages({"virtualMatchString": base, "noRejected": ""}):
        fixes = _fix_commits(record, repo)
        answers = [_contains(repo, fix, commit) for fix in fixes]

        if answers and all(answers):
            continue

        note = ""

        if not fixes:
            note = f" (cannot verify: the CVE names no fix commit in {repo})"
        elif None in answers:
            note = f" (cannot verify: GitHub cannot compare {', '.join(fixes)} with {commit})"

        findings.append(
            Finding(
                component=component,
                source=f"nvd {base}",
                id=record["id"],
                summary=f"{_description(record)}{note}",
                fixed_in=tuple(fixes),
                severity=_severity(record),
                package=f"{repo}@{commit}",
            )
        )

    return findings


def _candidates(spec: dict, start: datetime.datetime, end: datetime.datetime) -> list[dict]:
    params = {
        "pubStartDate": start.strftime("%Y-%m-%dT%H:%M:%S.000"),
        "pubEndDate": end.strftime("%Y-%m-%dT%H:%M:%S.000"),
        "noRejected": "",
    }

    if spec.get("source"):
        params["sourceIdentifier"] = spec["source"]

    if spec.get("keyword"):
        params["keywordSearch"] = spec["keyword"]

    if "sourceIdentifier" not in params and "keywordSearch" not in params:
        raise SourceError(f"the CNA entry for {spec.get('product')} names neither a source nor a keyword")

    return _pages(params)


def awaiting(component: Component, specs: list[dict], version: str) -> list[Finding]:
    end = datetime.datetime.now(datetime.timezone.utc)
    start = end - datetime.timedelta(days=RECENT_DAYS)
    findings: list[Finding] = []
    seen: set[str] = set()

    for spec in specs:
        for record in _candidates(spec, start, end):
            if record.get("vulnStatus") in ANALYSED or record["id"] in seen:
                continue

            seen.add(record["id"])
            published = _cve_record(record["id"])

            if cna.is_affected(published, [spec], version):
                findings.append(
                    Finding(
                        component=component,
                        source="cve.org (awaiting NVD analysis)",
                        id=record["id"],
                        summary=_description(record),
                        fixed_in=cna.fixed_versions(published, [spec], version),
                        severity=_severity(record),
                        package=f"{spec['vendor']}/{spec['product']}@{version}",
                    )
                )

    return findings
