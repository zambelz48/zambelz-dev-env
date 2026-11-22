#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup

  STUB_OSV="$BATS_TEST_TMPDIR/stubs/osv-scanner"
  export STUB_OSV
  zzd_stub_script mise <<EOF
printf '%s\n' "$STUB_OSV"
EOF
  cat >"$BATS_TEST_TMPDIR/scan.json" <<'EOF'
{
  "results": [
    {
      "source": {
        "path": "/x/package-lock.json"
      },
      "packages": [
        {
          "package": {
            "name": "left-pad",
            "version": "1.0.0",
            "ecosystem": "npm"
          },
          "dependency_groups": null,
          "groups": [
            {
              "ids": [
                "GHSA-aaaa"
              ],
              "max_severity": "7.5"
            }
          ],
          "vulnerabilities": [
            {
              "id": "GHSA-aaaa",
              "summary": "prod issue",
              "aliases": [
                "CVE-2026-1"
              ],
              "affected": [
                {
                  "package": {
                    "name": "left-pad"
                  },
                  "ranges": [
                    {
                      "events": [
                        {
                          "introduced": "0"
                        },
                        {
                          "fixed": "1.0.1"
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        },
        {
          "package": {
            "name": "build-tool",
            "version": "2.0.0",
            "ecosystem": "npm"
          },
          "dependency_groups": [
            "dev"
          ],
          "groups": [],
          "vulnerabilities": [
            {
              "id": "GHSA-bbbb",
              "summary": "dev issue",
              "aliases": [],
              "affected": []
            }
          ]
        }
      ]
    }
  ]
}
EOF
}

stub_scanner() {
  local code="$1"

  cat >"$STUB_OSV" <<EOF
#!/usr/bin/env bash
printf 'PATH=%s\nMISE_AUTO_INSTALL=%s\nMISE_NOT_FOUND_AUTO_INSTALL=%s\nGOTOOLCHAIN=%s\nARGS=%s\n' \
  "\$PATH" "\$MISE_AUTO_INSTALL" "\$MISE_NOT_FOUND_AUTO_INSTALL" "\$GOTOOLCHAIN" "\$*" >"$BATS_TEST_TMPDIR/env.txt"
cat "$BATS_TEST_TMPDIR/scan.json"
exit $code
EOF
  chmod +x "$STUB_OSV"
}

osv_py() {
  "$PY" -E -s -c "
import sys
sys.path.insert(0, '$ENGINE')
from model import Component, Kind, Scope
from sources import osv
component = Component(Kind.LOCKFILE, 'x', '-', 'x', Scope.DECLARED, {})
$1
"
}

@test "a lockfile scan turns every vulnerability into a finding" {
  stub_scanner 1

  run osv_py 'for f in osv.scan_lockfile(component, "/x/package-lock.json"): print(f.id, f.package, f.fixed_in, f.severity, f.dev_only, f.aliases)'

  [ "$status" -eq 0 ]
  [[ "$output" == *"GHSA-aaaa npm/left-pad@1.0.0 ('1.0.1',) CVSS 7.5 False ('CVE-2026-1',)"* ]]
  [[ "$output" == *"GHSA-bbbb npm/build-tool@2.0.0 () unknown True ()"* ]]
}

@test "osv-scanner runs without mise shims and without auto-install" {
  stub_scanner 0

  run osv_py 'osv.scan_artifact(component, "/x")'

  [ "$status" -eq 0 ]
  [[ "$(cat "$BATS_TEST_TMPDIR/env.txt")" != *"$MISE_DATA_DIR/shims"* ]]
  grep -q '^MISE_AUTO_INSTALL=false$' "$BATS_TEST_TMPDIR/env.txt"
  grep -q '^MISE_NOT_FOUND_AUTO_INSTALL=false$' "$BATS_TEST_TMPDIR/env.txt"
  grep -q '^GOTOOLCHAIN=local$' "$BATS_TEST_TMPDIR/env.txt"
  grep -q -- '--x-plugins artifact' "$BATS_TEST_TMPDIR/env.txt"
}

@test "an osv-scanner error is not an answer" {
  stub_scanner 128

  run osv_py 'osv.scan_lockfile(component, "/x/package-lock.json")'

  [ "$status" -ne 0 ]
  [[ "$output" == *"osv-scanner exited 128"* ]]
}

@test "package queries page through results and fetch each advisory" {
  run osv_py '
import webapi
calls = []
def post(url, payload):
    calls.append(payload)
    query = payload["queries"][0]
    if query.get("page_token"):
        return {"results": [{"vulns": [{"id": "GO-2"}]}]}
    return {"results": [{"vulns": [{"id": "GO-1"}], "next_page_token": "t"}]}
def get(url, params=None):
    vid = url.rsplit("/", 1)[1]
    return {"id": vid, "summary": "s", "aliases": [], "affected": [{"package": {"name": "stdlib"}, "ranges": [{"events": [{"fixed": "1.26.5"}]}]}]}
webapi.post_json = post
webapi.get_json = get
query = osv.PackageQuery(component, "Go", "stdlib", "1.26.4")
for f in osv.query_packages([query]):
    print(f.id, f.package, f.fixed_in)
print("calls", len(calls))
'

  [ "$status" -eq 0 ]
  [[ "$output" == *"GO-1 Go/stdlib@1.26.4 ('1.26.5',)"* ]]
  [[ "$output" == *"GO-2 Go/stdlib@1.26.4 ('1.26.5',)"* ]]
  [[ "$output" == *"calls 2"* ]]
}

@test "a querybatch answer that does not match the queries is an error" {
  run osv_py '
import webapi
webapi.post_json = lambda url, payload: {"results": []}
osv.query_packages([osv.PackageQuery(component, "Go", "stdlib", "1.26.4")])
'

  [ "$status" -ne 0 ]
  [[ "$output" == *"does not match the queries"* ]]
}

real_osv() {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" "$PY" -E -s -c "
import os, sys
sys.path.insert(0, '$ENGINE')
from model import Component, Kind, Scope
from sources import osv
$1
"
}

# bats test_tags=network
@test "an artifact scan of a real Go install finds stdlib advisories and installs nothing" {
  local installs="$MISE_DATA_DIR/installs" tracked="$REAL_HOME/.local/state/mise/tracked-configs" go before_dirs before_tracked

  go="$(find "$installs/go" -mindepth 1 -maxdepth 1 -type d ! -type l | sort | head -1)"
  before_dirs="$(find "$installs" -mindepth 2 -maxdepth 2 | wc -l)"
  before_tracked="$(find "$tracked" -mindepth 1 -maxdepth 1 | wc -l)"

  real_osv "
component = Component(Kind.INSTALL, 'go', '-', '$go', Scope.INSTALLED, {'path': '$go'})
findings = osv.scan_artifact(component, '$go')
print(sum(1 for f in findings if '/stdlib@' in f.package))
"

  [ "$status" -eq 0 ]
  [ "$output" -gt 0 ]
  [ "$(find "$installs" -mindepth 2 -maxdepth 2 | wc -l)" = "$before_dirs" ]
  [ "$(find "$tracked" -mindepth 1 -maxdepth 1 | wc -l)" = "$before_tracked" ]
}

# bats test_tags=network
@test "an upstream lockfile at a release tag is scanned and dev-only findings are marked" {
  real_osv "
component = Component(Kind.MISE_TOOL, 'js-debug', '1.140.0', 'x', Scope.DECLARED, {})
findings = osv.scan_upstream(component, 'microsoft/vscode-js-debug', 'v1.140.0', ['package-lock.json'])
print(len(findings), sum(1 for f in findings if f.dev_only))
"

  [ "$status" -eq 0 ]
  read -r total dev <<<"$output"
  [ "$total" -gt 0 ]
  [ "$dev" -gt 0 ]
  [ "$dev" -lt "$total" ]
}

# bats test_tags=network
@test "a commit query reaches OSV and returns an answer per commit" {
  real_osv "
component = Component(Kind.OHMYZSH, 'oh-my-zsh', 'x', 'x', Scope.DECLARED, {})
print(osv._query([{'commit': '17a2b4c3a5855524ad4772a17ada0dc474e2fdf3'}, {'commit': '0000000000000000000000000000000000000000'}]))
"

  [ "$status" -eq 0 ]
  [ "$output" = "[[], []]" ]
}

# bats test_tags=network
@test "OSV reports advisories for a known vulnerable Go toolchain" {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" "$PY" -E -s -c "
import sys
sys.path.insert(0, '$ENGINE')
from model import Component, Kind, Scope
from sources import osv
component = Component(Kind.MISE_TOOL, 'go', '1.24.3', 'x', Scope.DECLARED, {})
findings = osv.query_packages([osv.PackageQuery(component, 'Go', 'stdlib', '1.24.3')])
print(len(findings), all(f.id.startswith('GO-') for f in findings))
"

  [ "$status" -eq 0 ]
  read -r count prefixed <<<"$output"
  [ "$count" -gt 0 ]
  [ "$prefixed" = "True" ]
}
