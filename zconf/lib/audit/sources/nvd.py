import datetime
import os

import cna
import cpe
import webapi
from model import Component, Finding

CVES = "https://services.nvd.nist.gov/rest/json/cves/2.0"
CVE_ORG = "https://cveawg.mitre.org/api/cve/{id}"
PAGE_SIZE = 2000
RECENT_DAYS = 120
ANALYSED = ("Analyzed", "Modified", "Rejected", "Deferred")
METRICS = ("cvssMetricV40", "cvssMetricV31", "cvssMetricV30", "cvssMetricV2")


class SourceError(Exception):
    pass


def system() -> str:
    return os.uname().sysname.lower()


def _escape(version: str) -> str:
    return version.replace(":", "\\:")


def _pages(params: dict) -> list[dict]:
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
            return description["value"][:240]

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
            severity=_severity(record),
            package=f"{target.vendor}:{target.product}@{version}",
        )
        for record in records
        if cpe.applies(record, target, version, system())
    ]


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
            published = webapi.get_json(CVE_ORG.format(id=record["id"]))

            if cna.is_affected(published, [spec], version):
                findings.append(
                    Finding(
                        component=component,
                        source="cve.org (awaiting NVD analysis)",
                        id=record["id"],
                        summary=_description(record),
                        severity=_severity(record),
                        package=f"{spec['vendor']}/{spec['product']}@{version}",
                    )
                )

    return findings
