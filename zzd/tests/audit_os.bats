#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup

  ZZD_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZZD_OS_RELEASE
  printf 'ID=fedora\nVERSION_ID=45\n' >"$ZZD_OS_RELEASE"
}

distro_py() {
  "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
from model import Component, Kind, Scope
from sources import distro, osv
def package(name, version, **locator):
    return Component(Kind.OS_PACKAGE, name, version, 'packages/x.txt', Scope.INSTALLED, locator)
$1
"
}

@test "each pending dnf security advisory is a finding on its package, or on the host for other packages" {
  zzd_stub_script dnf <<'EOF'
cat <<'JSON'
[
  {
    "name": "FEDORA-2026-1",
    "type": "security",
    "severity": "Important",
    "nevra": "tmux-3.6a-1.fc45.x86_64",
    "buildtime": 1
  },
  {
    "name": "FEDORA-2026-2",
    "type": "security",
    "severity": "Moderate",
    "nevra": "openssl-libs-1:3.5.6-1.fc45.x86_64",
    "buildtime": 1
  }
]
JSON
EOF

  run distro_py '
for f in distro.dnf([package("tmux", "0:3.6-1.fc45", manager="dnf")]):
    print(f.component.name, f.id, f.severity, f.package, f.fixed_in)
'

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "tmux FEDORA-2026-1 important tmux ('tmux-3.6a-1.fc45.x86_64',)" ]
  [ "${lines[1]}" = "fedora-host FEDORA-2026-2 moderate openssl-libs ('openssl-libs-1:3.5.6-1.fc45.x86_64',)" ]
  [ "$(cat "$BATS_TEST_TMPDIR/calls/dnf")" = "-q --refresh advisory list --security --available --json" ]
}

@test "no pending dnf security advisories is clean" {
  zzd_stub dnf 0 "[]"

  run distro_py 'print(distro.dnf([]))'

  [ "$output" = "[]" ]
}

@test "a dnf failure, invalid JSON or a changed format is an error" {
  zzd_stub dnf 1 "Failed to download metadata"
  run distro_py 'distro.dnf([])'
  [ "$status" -ne 0 ]
  [[ "$output" == *"dnf advisory list exited 1"* ]]

  zzd_stub dnf 0 "not json"
  run distro_py 'distro.dnf([])'
  [ "$status" -ne 0 ]
  [[ "$output" == *"returned invalid JSON"* ]]

  zzd_stub dnf 0 '[{"name": "FEDORA-1", "type": "security"}]'
  run distro_py 'distro.dnf([])'
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing severity, nevra; the dnf output format changed"* ]]
}

@test "the Ubuntu OSV ecosystem follows the release, with the LTS suffix only for LTS releases" {
  run distro_py '
print(distro.ubuntu_ecosystem({"ID": "ubuntu", "VERSION_ID": "26.04", "VERSION": "26.04 LTS (Resolute Raccoon)"}))
print(distro.ubuntu_ecosystem({"ID": "ubuntu", "VERSION_ID": "25.10", "VERSION": "25.10 (Questing Quokka)"}))
try:
    distro.ubuntu_ecosystem({"ID": "debian", "VERSION_ID": "13"})
except distro.SourceError as error:
    print(error)
'

  [ "${lines[0]}" = "Ubuntu:26.04:LTS" ]
  [ "${lines[1]}" = "Ubuntu:25.10" ]
  [ "${lines[2]}" = "not an Ubuntu release: ID=debian VERSION_ID=13" ]
}

@test "Ubuntu packages are queried in OSV by source package name and source version" {
  printf 'ID=ubuntu\nVERSION_ID="26.04"\nVERSION="26.04 LTS (Resolute Raccoon)"\n' >"$ZZD_OS_RELEASE"

  run distro_py '
sent = []
def query(entries):
    sent.extend(entries)
    return [["UBUNTU-CVE-1"] for _ in entries]
osv._query = query
osv._details = lambda vulnerability_id: {"id": vulnerability_id, "summary": "s", "affected": []}
found = distro.apt([package("fd-find", "10.2.0-1", manager="apt", source="rust-fd-find", source_version="10.2.0-1")])
print(sent)
print([(f.component.name, f.id) for f in found])
'

  [ "${lines[0]}" = "[{'package': {'ecosystem': 'Ubuntu:26.04:LTS', 'name': 'rust-fd-find'}, 'version': '10.2.0-1'}]" ]
  [ "${lines[1]}" = "[('fd-find', 'UBUNTU-CVE-1')]" ]
}

@test "an Ubuntu package without its source package is an error, never a clean query" {
  printf 'ID=ubuntu\nVERSION_ID=26.04\nVERSION="26.04 LTS"\n' >"$ZZD_OS_RELEASE"

  run distro_py 'distro.apt([package("fd-find", "10.2.0-1", manager="apt")])'

  [ "$status" -ne 0 ]
  [[ "$output" == *"has no source package name or version"* ]]
}

@test "the apt inventory records each package's source package" {
  zzd_stub_script dpkg-query <<'EOF'
case "$*" in
  *source:Package*) printf 'rust-fd-find\t10.2.0-1' ;;
  *) printf '10.2.0-1' ;;
esac
EOF

  run "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
import inventory
print(inventory._package_version('apt', 'fd-find'), inventory._package_details('apt', 'fd-find'))
"

  [ "$output" = "10.2.0-1 {'source': 'rust-fd-find', 'source_version': '10.2.0-1'}" ]
}

@test "an apt package whose source package cannot be read is an error" {
  zzd_stub dpkg-query 1 ""

  run "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
import inventory
inventory._package_details('apt', 'fd-find')
"

  [ "$status" -ne 0 ]
  [[ "$output" == *"dpkg-query cannot tell the source package of the installed fd-find"* ]]
}

# bats test_tags=network
@test "on a Fedora host the dnf path answers" {
  if ! PATH="$REAL_PATH" command -v dnf >/dev/null 2>&1; then
    skip "dnf is not installed on this machine"
  fi

  run env HOME="$REAL_HOME" PATH="$REAL_PATH" ZZD_OS_RELEASE=/etc/os-release "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
from sources import distro
print(type(distro.dnf_advisories()).__name__)
"

  [ "$status" -eq 0 ]
  [ "$output" = "list" ]
}

# bats test_tags=network
@test "OSV knows Ubuntu source packages and not binary package names" {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
import webapi
def count(name):
    answer = webapi.post_json('https://api.osv.dev/v1/query', {'package': {'name': name, 'ecosystem': 'Ubuntu:24.04:LTS'}, 'version': '3.0.13-0ubuntu3'})
    return len(answer.get('vulns', []))
print(count('openssl') > 0, count('libssl3'))
"

  [ "$status" -eq 0 ]
  [ "$output" = "True 0" ]
}
