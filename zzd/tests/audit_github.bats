#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup
}

github_py() {
  "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
import ghapi
from model import Component, Kind, Scope
from sources import github
component = Component(Kind.NVIM_PLUGIN, 'p', 'abc123', 'x', Scope.DECLARED, {})
ADVISORIES = [[{'ghsa_id': 'GHSA-1', 'summary': 'bug', 'cve_id': 'CVE-1', 'severity': 'high', 'vulnerabilities': [{'vulnerable_version_range': '>= 1.2.0, < 1.4.0', 'patched_versions': '1.4.0'}]}]]
COMPARE = {}
def json_get(endpoint, paginate=False):
    if 'security-advisories' in endpoint:
        return ADVISORIES
    for tag, status in COMPARE.items():
        if '/compare/' + tag + '...' in endpoint:
            return {'status': status}
    raise ghapi.GitHubError('404 ' + endpoint)
ghapi.json_get = json_get
$1
"
}

@test "version ranges with several constraints are evaluated" {
  run github_py '
print(github.in_range("1.3.5", ">= 1.2.0, < 1.4.0"), github.in_range("1.4.0", ">= 1.2.0, < 1.4.0"), github.in_range("1.1.9", ">= 1.2.0, < 1.4.0"), github.in_range("0.8.2", "<= 0.8.2"), github.in_range("2.0.0", "= v2.0.0"))
'

  [ "$output" = "True False False True True" ]
}

@test "a released version inside a vulnerable range is a finding" {
  run github_py '
for f in github.check_version(component, "o/r", "1.3.0"):
    print(f.id, f.fixed_in, f.severity, f.aliases)
print(len(github.check_version(component, "o/r", "1.4.0")))
'

  [ "${lines[0]}" = "GHSA-1 ('1.4.0',) high ('CVE-1',)" ]
  [ "${lines[1]}" = "0" ]
}

@test "a pinned commit that contains the patched tag is not affected" {
  run github_py '
COMPARE.update({"v1.2.0": "ahead", "v1.4.0": "ahead"})
print(len(github.check_commit(component, "o/r", "abc123")))
COMPARE.update({"v1.4.0": "identical"})
print(len(github.check_commit(component, "o/r", "abc123")))
'

  [ "$output" = $'0\n0' ]
}

@test "a pinned commit behind or diverged from the patched tag is a finding" {
  run github_py '
COMPARE.update({"v1.2.0": "ahead", "v1.4.0": "behind"})
print([f.id for f in github.check_commit(component, "o/r", "abc123")])
COMPARE.update({"v1.4.0": "diverged"})
print([f.id for f in github.check_commit(component, "o/r", "abc123")])
'

  [ "$output" = $'[\x27GHSA-1\x27]\n[\x27GHSA-1\x27]' ]
}

@test "a pinned commit older than the vulnerable range is not affected" {
  run github_py '
COMPARE.update({"v1.2.0": "behind", "v1.4.0": "behind"})
print(len(github.check_commit(component, "o/r", "abc123")))
'

  [ "$output" = "0" ]
}

@test "a patched version without a tag cannot be verified and is a finding" {
  run github_py '
COMPARE.update({"v1.2.0": "ahead"})
print([f.summary for f in github.check_commit(component, "o/r", "abc123")])
'

  [[ "$output" == *"cannot verify: no tag for 1.4.0"* ]]
}

@test "an advisory without a patched release always applies to a commit pin" {
  run github_py '
ADVISORIES[0][0]["vulnerabilities"][0] = {"vulnerable_version_range": "", "patched_versions": None}
print([f.summary for f in github.check_commit(component, "o/r", "abc123")])
'

  [[ "$output" == *"no patched release"* ]]
}

@test "unreadable advisories are an error, never an empty answer" {
  run github_py '
def broken(endpoint, paginate=False):
    raise ghapi.GitHubError("gh: not logged in")
ghapi.json_get = broken
github.check_version(component, "o/r", "1.0.0")
'

  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot read o/r security advisories"* ]]
}

@test "submodules at a tag are read with their exact commits" {
  run github_py '
ghapi.raw_file = lambda repo, path, ref: "[submodule \"a\"]\n\tpath = 3rd/a\n\turl = https://github.com/x/a\n"
ghapi.json_get = lambda endpoint, paginate=False: {"type": "submodule", "sha": "deadbeef"}
print([(p.path, p.url, p.revision) for p in github.submodules("o/r", "1.0")])
'

  [ "$output" = "[('3rd/a', 'https://github.com/x/a', 'deadbeef')]" ]
}

@test "a DEPS file is parsed without running it, and unpinned entries are returned" {
  run github_py '
DEPS = """
vars = {
  \"git\": \"https://example.googlesource.com\",
  \"zlib_rev\": \"1234abcd\",
}
deps = {
  \"src/third_party/zlib\": Var(\"git\") + \"/zlib.git\" + \"@\" + Var(\"zlib_rev\"),
  \"src/third_party/icu\": {\"url\": Var(\"git\") + \"/icu.git@5678\", \"condition\": \"host_os == \\\"linux\\\"\"},
  \"src/buildtools/tool\": {\"packages\": [{\"package\": \"x/y\", \"version\": \"v1\"}], \"dep_type\": \"cipd\"},
}
"""
ghapi.raw_file = lambda repo, path, ref: DEPS
pinned, unpinned = github.deps("o/r", "1.0", "DEPS")
print([(p.path, p.url, p.revision) for p in pinned])
print(unpinned)
'

  [ "${lines[0]}" = "[('src/third_party/zlib', 'https://example.googlesource.com/zlib.git', '1234abcd'), ('src/third_party/icu', 'https://example.googlesource.com/icu.git', '5678')]" ]
  [ "${lines[1]}" = "['src/buildtools/tool']" ]
}

# bats test_tags=network
@test "neovim 0.12.6 is not affected by its own advisory fixed in 0.8.3" {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
from model import Component, Kind, Scope
from sources import github
component = Component(Kind.MISE_TOOL, 'neovim', '0.12.6', 'x', Scope.DECLARED, {})
print(len(github.advisories('neovim/neovim')) > 0, [f.id for f in github.check_version(component, 'neovim/neovim', '0.12.6')], [f.id for f in github.check_version(component, 'neovim/neovim', '0.8.2')])
"

  [ "$status" -eq 0 ]
  [ "$output" = "True [] ['GHSA-6f9m-hj8h-xjgj']" ]
}

@test "a dropped GitHub stream is retried, a missing file is not, and three drops still fail" {
  run github_py '
import procs, time
time.sleep = lambda seconds: None
calls = []
def answers(*errors):
    def checked(argv, cwd=None, env=None):
        calls.append(argv)
        if len(calls) <= len(errors):
            raise procs.CommandError(errors[len(calls) - 1])
        return "body"
    return checked
dropped = "gh api repos/o/r/contents/package-lock.json?ref=v1 -H exited 1: stream error: stream ID 1; CANCEL; received from peer"
procs.checked = answers(dropped)
print(ghapi.raw_file("o/r", "package-lock.json", "v1"), len(calls))
calls.clear()
procs.checked = answers("gh api repos/o/r/contents/x exited 1: HTTP 404: Not Found")
try:
    ghapi.raw_file("o/r", "x", "v1")
except ghapi.GitHubError as error:
    print("404", len(calls))
calls.clear()
procs.checked = answers(dropped, dropped, dropped)
try:
    ghapi.raw_file("o/r", "package-lock.json", "v1")
except ghapi.GitHubError as error:
    print("CANCEL", len(calls))
'

  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "body 2" ]
  [ "${lines[1]}" = "404 1" ]
  [ "${lines[2]}" = "CANCEL 3" ]
}
