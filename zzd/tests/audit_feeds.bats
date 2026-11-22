#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup
}

feeds_py() {
  "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
import ghapi, webapi
from model import Component, Kind, Scope
from sources import feeds
from sources.feeds import satisfies, NPM, GEM
def component(name, version):
    return Component(Kind.MISE_TOOL, name, version, 'x', Scope.DECLARED, {})
$1
"
}

@test "npm ranges read partial bounds, x-ranges, carets, tildes and hyphens" {
  run feeds_py '
print(
    satisfies("10.5.0", "<= 10", NPM), satisfies("11.0.0", "<= 10", NPM),
    satisfies("10.9.0", ">= 10.9.0", NPM), satisfies("6.2.0", ">=6.0.0 <6.2.0 || 5.x", NPM),
    satisfies("9.7.4", "9.7.x || 10.x", NPM), satisfies("9.8.0", "9.7.x || 10.x", NPM),
    satisfies("12.22.3", " ^12.22.2", NPM), satisfies("0.3.0", "^0.2.3", NPM),
    satisfies("1.2.9", "~1.2.0", NPM), satisfies("1.5.0", "1.2.0 - 1.4.0", NPM),
)
'

  [ "$output" = "True False True False True False True False True False" ]
}

@test "RubyGems requirements read pessimistic and literal bounds" {
  run feeds_py '
print(
    satisfies("3.4.12", "~> 3.4.13", GEM), satisfies("3.4.13", "~> 3.4.13", GEM),
    satisfies("3.5.0", "~> 3.4.13", GEM), satisfies("3.9.0", "~> 3.4", GEM),
    satisfies("3.4.1", "<= 3.4", GEM), satisfies("4.0.10", ">= 4.0.10", GEM),
)
'

  [ "$output" = "False True False True False True" ]
}

@test "an unreadable version constraint is an error, never a match or a miss" {
  run feeds_py 'satisfies("1.0.0", "<= banana", NPM)'

  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot read the version constraint '<= banana'"* ]]
}

@test "Node findings come from the security database and from newer security releases in the same line" {
  run feeds_py '
def get_json(url, params=None):
    if url == feeds.NODE_DB:
        return {"1": {"cve": ["CVE-OLD"], "vulnerable": "<= 10", "patched": "^10.24.0"}, "2": {"cve": ["CVE-NEW"], "vulnerable": "24.x", "patched": "^24.22.3"}}
    return [{"version": "v25.0.0", "security": True}, {"version": "v24.22.3", "security": True}, {"version": "v24.22.2", "security": False}, {"version": "v24.22.1", "security": True}, {"version": "v22.99.0", "security": True}]
webapi.get_json = get_json
print([(f.id, f.fixed_in) for f in feeds.node(component("node", "24.22.1"), "24.22.1")])
'

  [ "$output" = "[('CVE-NEW', ('^24.22.3',)), ('node-security-release-v24.22.3', ('24.22.3',))]" ]
}

@test "an empty Node security database is an error" {
  run feeds_py '
webapi.get_json = lambda url, params=None: {}
feeds.node(component("node", "24.22.1"), "24.22.1")
'

  [ "$status" -ne 0 ]
  [[ "$output" == *"the Node.js security database is empty"* ]]
}

@test "a feed record missing an expected field is an error, never clean" {
  run feeds_py '
def node_db_without_security(url, params=None):
    if url == feeds.NODE_DB:
        return {"1": {"vulnerable": "<= 10", "patched": "^10.24.0"}}
    return [{"version": "v24.22.3"}]
webapi.get_json = node_db_without_security
for check in (lambda: feeds.node(component("node", "24.22.1"), "24.22.1"),
              lambda: (setattr(webapi, "get_json", lambda url, params=None: {"result": {"releases": [{"name": "3.10"}]}}), feeds.end_of_life(component("python", "3.10.1"), "python", "3.10.1"))):
    try:
        check()
        print("clean")
    except feeds.SourceError as error:
        print(error)
'

  [ "${lines[0]}" = "Node.js release index entry: missing security; the feed format changed" ]
  [ "${lines[1]}" = "endoflife.date python cycle: missing isEol; the feed format changed" ]
}

@test "rubysec advisories are read in one request, prefixed, and skipped when patched or unaffected" {
  run feeds_py '
def blob(text):
    return {"name": text.split("\n")[0].split(": ")[1] + ".yml", "object": {"text": text}}
entries = [
    blob("cve: 2026-1\ntitle: overflow\npatched_versions:\n  - \"~> 3.3.14\"\n  - \"~> 3.4.13\"\n"),
    blob("ghsa: abcd-efgh-ijkl\ntitle: double free\npatched_versions:\n  - \">= 4.0.10\"\n"),
    blob("cve: 2020-2\ntitle: old\npatched_versions:\n  - \">= 2.7.0\"\n"),
    blob("cve: 2021-3\ntitle: other line\nunaffected_versions:\n  - \">= 3.4.0\"\n"),
]
calls = []
def graphql(query, variables):
    calls.append(variables["expression"])
    return {"repository": {"object": {"entries": entries}}}
ghapi.graphql = graphql
print([(f.id, f.fixed_in) for f in feeds.rubysec(component("ruby", "3.4.1"), "3.4.1")], calls)
'

  [ "$output" = "[('CVE-2026-1', ('~> 3.3.14', '~> 3.4.13')), ('GHSA-abcd-efgh-ijkl', ('>= 4.0.10',))] ['HEAD:rubies/ruby']" ]
}

@test "a rubysec file that cannot be read as text is an error" {
  run feeds_py '
ghapi.graphql = lambda query, variables: {"repository": {"object": {"entries": [{"name": "CVE-1.yml", "object": {"text": None}}]}}}
feeds.rubysec(component("ruby", "3.4.1"), "3.4.1")
'

  [ "$status" -ne 0 ]
  [[ "$output" == *"files could not be read as text: CVE-1.yml"* ]]
}

@test ".NET findings are the security releases after the one that ships the pinned SDK" {
  run feeds_py '
def get_json(url, params=None):
    if url == feeds.DOTNET_INDEX:
        return {"releases-index": [{"channel-version": "10.0", "releases.json": "channel"}]}
    return {"releases": [
        {"release-version": "10.0.5", "security": True, "cve-list": [{"cve-id": "CVE-B"}], "sdk": {"version": "10.0.404"}},
        {"release-version": "10.0.4", "security": False, "sdk": {"version": "10.0.403"}, "sdks": [{"version": "10.0.403"}]},
        {"release-version": "10.0.3", "security": True, "cve-list": [{"cve-id": "CVE-A"}], "sdk": {"version": "10.0.402"}},
    ]}
webapi.get_json = get_json
print([(f.id, f.fixed_in) for f in feeds.dotnet(component("dotnet", "10.0.403"), "10.0.403")])
'

  [ "$output" = "[('CVE-B', ('10.0.404',))]" ]
}

@test "a .NET SDK missing from the release metadata is an error" {
  run feeds_py '
webapi.get_json = lambda url, params=None: {"releases-index": [{"channel-version": "10.0", "releases.json": "c"}], "releases": []}
feeds.dotnet(component("dotnet", "10.0.999"), "10.0.999")
'

  [ "$status" -ne 0 ]
  [[ "$output" == *"does not list SDK 10.0.999"* ]]
}

@test "end of life uses the most specific cycle and fails for an unknown one" {
  run feeds_py '
webapi.get_json = lambda url, params=None: {"result": {"releases": [
    {"name": "3.1", "isEol": True, "eolFrom": "2012-04-09"},
    {"name": "3.10", "isEol": True, "eolFrom": "2026-10-01"},
    {"name": "3.14", "isEol": False},
]}}
print([f.summary for f in feeds.end_of_life(component("python", "3.10.19"), "python", "3.10.19")])
print(feeds.end_of_life(component("python", "3.14.2"), "python", "3.14.2"))
try:
    feeds.end_of_life(component("python", "2.7.18"), "python", "2.7.18")
except feeds.SourceError as error:
    print(error)
'

  [ "${lines[0]}" = "['python 3.10 reached end of life on 2026-10-01; it gets no more security fixes']" ]
  [ "${lines[1]}" = "[]" ]
  [ "${lines[2]}" = "endoflife.date python has no cycle for 2.7.18" ]
}

@test "gh is retried on network errors and not on answers such as 404" {
  run feeds_py '
import procs, time
time.sleep = lambda seconds: None
attempts = []
def flaky(argv, cwd=None, env=None):
    attempts.append(argv[2])
    if argv[2] == "missing":
        raise procs.CommandError("gh api missing exited 1: HTTP 404: Not Found")
    if len(attempts) < 3:
        raise procs.CommandError("gh api x exited 1: net/http: TLS handshake timeout")
    return "{\"ok\": true}"
procs.checked = flaky
print(ghapi.json_get("flaky"), len(attempts))
attempts.clear()
try:
    ghapi.json_get("missing")
except ghapi.GitHubError:
    print("error", len(attempts))
'

  [ "$output" = $'{\x27ok\x27: True} 3\nerror 1' ]
}

@test "the catalog check rejects an unknown feed and an unknown end-of-life cycle" {
  run feeds_py '
import catalog_check
from catalog import Source
webapi.get_json = lambda url, params=None: {"result": {"releases": [{"name": "3.14", "isEol": False}]}}
print(catalog_check._source_checks(Source("feed", {"name": "nodee", "version": "1"})))
print(catalog_check._source_checks(Source("feed", {"name": "node", "version": "1"})))
print(catalog_check._source_checks(Source("eol", {"product": "python", "version": "3.99.0"})))
'

  [ "${lines[0]}" = "[\"unknown feed 'nodee'; known feeds: dotnet, node, rubysec\"]" ]
  [ "${lines[1]}" = "[]" ]
  [ "${lines[2]}" = "['endoflife.date python has no cycle for 3.99.0']" ]
}

real_feeds() {
  run env HOME="$REAL_HOME" PATH="$REAL_PATH" "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
from model import Component, Kind, Scope
from sources import feeds
def component(name, version):
    return Component(Kind.MISE_TOOL, name, version, 'x', Scope.DECLARED, {})
$1
"
}

# bats test_tags=network
@test "Node 20.0.0 has security database findings and Python 3.10 is past end of life" {
  real_feeds "
print(len(feeds.node(component('node', '20.0.0'), '20.0.0')) > 0, len(feeds.end_of_life(component('python', '3.10.19'), 'python', '3.10.19')))
"

  [ "$status" -eq 0 ]
  [ "$output" = "True 1" ]
}

# bats test_tags=network
@test "rubysec and the .NET release metadata answer for an old release" {
  real_feeds "
print(len(feeds.rubysec(component('ruby', '3.2.0'), '3.2.0')) > 0, len(feeds.dotnet(component('dotnet', '10.0.100'), '10.0.100')) > 0)
"

  [ "$status" -eq 0 ]
  [ "$output" = "True True" ]
}
