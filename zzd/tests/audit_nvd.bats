#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup
}

audit_py() {
  local code="$1"
  shift

  "$PY" -E -s -c "
import json, sys
sys.path.insert(1, '$ENGINE')
$code
" "$@"
}

@test "a CVE for another platform's build of a product does not apply" {
  run audit_py '
import cpe
record = {"configurations": [{"nodes": [{"operator": "OR", "cpeMatch": [{"vulnerable": True, "criteria": "cpe:2.3:a:shellcheck_project:shellcheck:*:*:*:*:*:visual_studio_code:*:*", "versionEndExcluding": "0.13.4"}]}]}]}
print(cpe.applies(record, cpe.parse("cpe:2.3:a:shellcheck_project:shellcheck"), "0.11.0", "linux"))
'

  [ "$output" = "False" ]
}

@test "a product named only as a platform does not make the CVE apply" {
  run audit_py '
import cpe
record = {"configurations": [{"operator": "AND", "nodes": [
  {"operator": "OR", "cpeMatch": [{"vulnerable": True, "criteria": "cpe:2.3:a:vercel:next.js:*:*:*:*:*:node.js:*:*", "versionEndExcluding": "12.0.5"}]},
  {"operator": "OR", "cpeMatch": [{"vulnerable": False, "criteria": "cpe:2.3:a:nodejs:node.js:*:*:*:*:*:*:*:*", "versionStartExcluding": "15.0.0"}]}]}]}
print(cpe.applies(record, cpe.parse("cpe:2.3:a:nodejs:node.js"), "24.22.1", "linux"))
'

  [ "$output" = "False" ]
}

@test "a Windows-only CVE does not apply on Linux or macOS" {
  run audit_py '
import cpe
record = {"configurations": [{"operator": "AND", "nodes": [
  {"operator": "OR", "cpeMatch": [{"vulnerable": True, "criteria": "cpe:2.3:a:python:python:*:*:*:*:*:*:*:*", "versionEndIncluding": "3.14.4"}]},
  {"operator": "OR", "cpeMatch": [{"vulnerable": False, "criteria": "cpe:2.3:o:microsoft:windows:-:*:*:*:*:*:*:*"}]}]}]}
target = cpe.parse("cpe:2.3:a:python:python")
print(cpe.applies(record, target, "3.14.2", "linux"), cpe.applies(record, target, "3.14.2", "darwin"))
'

  [ "$output" = "False False" ]
}

@test "version range edges are respected" {
  run audit_py '
import cpe
def record(**bounds):
    return {"configurations": [{"nodes": [{"cpeMatch": [{"vulnerable": True, "criteria": "cpe:2.3:a:x:y:*:*:*:*:*:*:*:*", **bounds}]}]}]}
target = cpe.parse("cpe:2.3:a:x:y")
print(
    cpe.applies(record(versionEndExcluding="1.2.3"), target, "1.2.3", "linux"),
    cpe.applies(record(versionEndIncluding="1.2.3"), target, "1.2.3", "linux"),
    cpe.applies(record(versionStartIncluding="1.2.0", versionEndExcluding="1.3"), target, "1.2.10", "linux"),
    cpe.applies(record(versionStartExcluding="1.2.3"), target, "1.2.3", "linux"),
)
'

  [ "$output" = "False True True False" ]
}

@test "an exact version in the criteria matches only that version" {
  run audit_py '
import cpe
record = {"configurations": [{"nodes": [{"cpeMatch": [{"vulnerable": True, "criteria": "cpe:2.3:a:x:y:2.0.1:*:*:*:*:*:*:*"}]}]}]}
target = cpe.parse("cpe:2.3:a:x:y")
print(cpe.applies(record, target, "2.0.1", "linux"), cpe.applies(record, target, "2.0.2", "linux"))
'

  [ "$output" = "True False" ]
}

@test "a CVE.org record with version ranges is read per CVE 5 rules" {
  run audit_py '
import cna
record = {"containers": {"cna": {"affected": [{"vendor": "Python Software Foundation", "product": "CPython", "versions": [
  {"version": "0", "lessThan": "3.13.14", "status": "affected"},
  {"version": "3.14.0a1", "lessThan": "3.14.5rc1", "status": "affected"}]}]}}}
spec = [{"vendor": "Python Software Foundation", "product": "CPython"}]
print(cna.is_affected(record, spec, "3.14.2"), cna.is_affected(record, spec, "3.14.5"), cna.is_affected(record, spec, "3.12.1"))
'

  [ "$output" = "True False True" ]
}

@test "Oracle listed versions cover that version and earlier in the same line" {
  run audit_py '
import cna
record = {"containers": {"cna": {"affected": [{"vendor": "Oracle Corporation", "product": "Oracle Java SE, Oracle GraalVM for JDK", "versions": [
  {"version": "Oracle Java SE:11.0.32", "status": "affected"},
  {"version": "Oracle Java SE:17.0.20", "status": "affected"}]}]}}}
spec = [{"vendor": "Oracle Corporation", "product": "Oracle Java SE", "product_match": "contains", "version_prefix": "Oracle Java SE:", "listed_means": "up-to-in-line"}]
print(cna.is_affected(record, spec, "17.0.20"), cna.is_affected(record, spec, "17.0.15"), cna.is_affected(record, spec, "17.0.21"), cna.is_affected(record, spec, "25.0.5"))
'

  [ "$output" = "True True False False" ]
}

@test "analysed CVEs are skipped by the awaiting-analysis check" {
  run audit_py '
from model import Component, Kind, Scope
from sources import nvd
import webapi
def get(url, params=None):
    if "cveawg" in url:
        return {"containers": {"cna": {"affected": [{"vendor": "V", "product": "P", "versions": [{"version": "0", "lessThan": "9", "status": "affected"}]}]}}}
    return {"totalResults": 2, "vulnerabilities": [
        {"cve": {"id": "CVE-A", "vulnStatus": "Analyzed", "descriptions": []}},
        {"cve": {"id": "CVE-B", "vulnStatus": "Awaiting Analysis", "descriptions": []}}]}
webapi.get_json = get
component = Component(Kind.MISE_TOOL, "p", "1.0", "x", Scope.DECLARED, {})
print([f.id for f in nvd.awaiting(component, [{"source": "s", "vendor": "V", "product": "P"}], "1.0")])
'

  [ "$output" = "['CVE-B']" ]
}

@test "a bundled version is normalized and read from the python-build-standalone release in mise.lock" {
  mkdir -p "$BATS_TEST_TMPDIR/r/mise"
  cat >"$BATS_TEST_TMPDIR/r/mise/mise.lock" <<'EOF'
[[tools.python]]
version = "3.14.2"

[tools.python."platforms.linux-x64"]
url = "https://github.com/astral-sh/python-build-standalone/releases/download/20260127/cpython.tar.gz"
EOF

  run audit_py '
from pathlib import Path
from sources import bundled
print(bundled.normalized("3500400", "^([0-9])([0-9]{2})([0-9]{2})[0-9]{2}$"))
print(bundled.pbs_release(Path(sys.argv[1]), "3.14.2", "python-build-standalone/releases/download/([0-9]+)/"))
' "$BATS_TEST_TMPDIR/r"

  [ "${lines[0]}" = "3.50.4" ]
  [ "${lines[1]}" = "20260127" ]
}

@test "a vendored version split over several defines is joined" {
  run audit_py '
from catalog import vendored_version
text = "#  define XML_MAJOR_VERSION 2\n/* x */\n#  define XML_MINOR_VERSION 7\n#  define XML_MICRO_VERSION 3\n"
print(vendored_version(text, ["XML_MAJOR_VERSION ([0-9]+)", "XML_MINOR_VERSION ([0-9]+)", "XML_MICRO_VERSION ([0-9]+)"]))
'

  [ "$output" = "2.7.3" ]
}

@test "the NVD rate limit makes a request beyond the window wait" {
  run audit_py '
import time
import webapi
window = webapi._Window(2, 1.0)
start = time.monotonic()
for _ in range(3):
    window.wait()
print(round(time.monotonic() - start, 1) >= 1.0)
'

  [ "$output" = "True" ]
}

@test "the NVD key raises the request budget" {
  run env NVD_API_KEY=x "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
import webapi
print(webapi._nvd_requests(), webapi._headers('https://services.nvd.nist.gov/rest/json/cves/2.0').get('apiKey'), webapi._headers('https://api.osv.dev/v1/query').get('apiKey'))
"

  [ "$output" = "50 x None" ]
}

real_nvd() {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" "$PY" -E -s -c "
import sys
sys.path.insert(0, '$ENGINE')
from model import Component, Kind, Scope
from sources import nvd
$1
"
}

# bats test_tags=network
@test "NVD matching finds Python CVEs and not other products' CVEs" {
  real_nvd "
component = Component(Kind.MISE_TOOL, 'python', '3.14.2', 'x', Scope.DECLARED, {})
ids = {f.id for f in nvd.analysed(component, 'cpe:2.3:a:python:python', '3.14.2')}
print(len(ids) > 0, 'CVE-2021-32052' in ids, 'CVE-2020-29396' in ids)
"

  [ "$status" -eq 0 ]
  [ "$output" = "True False False" ]
}

# bats test_tags=network
@test "the VS Code extension CVE does not apply to shellcheck" {
  real_nvd "
component = Component(Kind.MISE_TOOL, 'shellcheck', '0.11.0', 'x', Scope.DECLARED, {})
print([f.id for f in nvd.analysed(component, 'cpe:2.3:a:shellcheck_project:shellcheck', '0.11.0')])
"

  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}
