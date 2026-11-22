#!/usr/bin/env bats

setup() {
  load audit_helpers
  audit_test_setup
  printf '[mise-tool.tool]\nrepo = "o/tool"\n' >"$BATS_TEST_TMPDIR/catalog.toml"
}

engine_py() {
  "$PY" -E -s -c "
import sys
sys.path.insert(1, '$ENGINE')
from pathlib import Path
import engine, ghapi
from catalog import Catalog, Source
from model import Component, Finding, Kind, Problem, Scope
from sources import bundled, distro, github, nvd, osv, readers
catalog = Catalog(Path('$BATS_TEST_TMPDIR/catalog.toml'))
run = engine.Engine(catalog, Path('$BATS_TEST_TMPDIR'))
def tool(name='tool', version='1.0.0', kind=Kind.MISE_TOOL, **locator):
    return Component(kind, name, version, 'mise/mise.lock', Scope.DECLARED, locator)
def finding(component, id='GHSA-1', dev_only=False, package='p@1'):
    return Finding(component, 'test', id, 'summary', dev_only=dev_only, package=package)
$1
"
}

@test "a component without any source is not covered" {
  run engine_py '
result = run.run([tool("unknown")])
print([(p.component.key(), p.message) for p in result.not_covered], int(result.exit_code()))
'

  [ "$output" = "[('mise-tool:unknown@1.0.0', 'no source in catalog.toml')] 1" ]
}

@test "a source that fails is could-not-run and the exit code is 3" {
  run engine_py '
def broken(component, repo, version, product=None):
    raise github.SourceError("gh: not logged in")
github.check_version = broken
result = run.run([tool()])
print([(p.source, p.message) for p in result.could_not_run], int(result.exit_code()))
'

  [ "$output" = "[('github-advisories', 'SourceError: gh: not logged in')] 3" ]
}

@test "an unknown source kind is could-not-run, never skipped" {
  run engine_py '
answer = run._guarded(engine.Task(tool(), Source("telepathy", {})))
print(type(answer).__name__, answer.message)
'

  [ "$output" = "Problem CatalogError: no handler for source kind 'telepathy'" ]
}

@test "bundled libraries become components with their own sources, and shipped-by libraries are information" {
  run engine_py '
calls = []
nvd.analysed = lambda component, cpe, version: calls.append((component.key(), cpe, version)) or []
items = [bundled.Bundled("zlib", "1.3.1", cpe=("cpe:2.3:a:zlib:zlib",)), bundled.Bundled("uuid", "1.0", shipped_by="vendor"), bundled.Bundled("mystery", "2.0")]
run.handle = lambda task: engine._bundled_outcome(task.component, items, "origin") if task.source.kind == "github-advisories" else engine.Engine.handle(run, task)
result = run.run([tool()])
print(calls)
print([p.message for p in result.information])
print([(p.component.key(), p.message) for p in result.not_covered])
'

  [ "${lines[0]}" = "[('bundled:tool@1.0.0/zlib@1.3.1', 'cpe:2.3:a:zlib:zlib', '1.3.1')]" ]
  [ "${lines[1]}" = "['has no advisory channel of its own; covered by vendor']" ]
  [ "${lines[2]}" = "[('bundled:tool@1.0.0/mystery@2.0', 'the bundled library has no advisory source')]" ]
}

@test "upstream git pins are checked by commit, and by GitHub advisories when hosted on GitHub" {
  run engine_py '
pins = [github.Pinned("https://github.com/x/zlib", "a" * 40, "third_party/zlib"), github.Pinned("https://example.googlesource.com/icu", "b" * 40, "third_party/icu")]
outcome = engine._pinned_outcome(tool(), pins, "o/tool@1.0.0 DEPS")
print([(t.component.key(), t.source.kind) for t in outcome.tasks])
'

  [ "$output" = "[('upstream-pin:tool@1.0.0/third_party/zlib@$(printf 'a%.0s' {1..40})', 'osv-commit'), ('upstream-pin:tool@1.0.0/third_party/zlib@$(printf 'a%.0s' {1..40})', 'github-advisories'), ('upstream-pin:tool@1.0.0/third_party/icu@$(printf 'b%.0s' {1..40})', 'osv-commit')]" ]
}

@test "OS packages of one manager are checked in one batched call" {
  run engine_py '
calls = []
engine.BATCHED_DISTRO["dnf"] = lambda components: calls.append([c.name for c in components]) or []
tasks = [engine.Task(tool(name, kind=Kind.OS_PACKAGE, manager="dnf"), Source("distro", {"manager": "dnf"})) for name in ("git", "tmux")]
print(run._distro(tasks), calls)
'

  [ "$output" = "[Outcome(findings=[], information=[], not_covered=[], components=[], tasks=[])] [['git', 'tmux']]" ]
}

@test "a tag is resolved to its commit before the OSV commit query" {
  run engine_py '
ghapi.json_get = lambda endpoint, paginate=False: {"sha": "c" * 40} if endpoint == "repos/o/parser/commits/v0.23.5" else {}
print(engine._commit_sha("v0.23.5", "o/parser") == "c" * 40, engine._commit_sha("d" * 40, None) == "d" * 40)
try:
    engine._commit_sha("v1", None)
except Exception as error:
    print(error)
'

  [ "${lines[0]}" = "True True" ]
  [ "${lines[1]}" = "v1 is not a commit and no GitHub repository is known to resolve it" ]
}

@test "the same advisory reported twice for one package is one finding, failing wins over dev-only" {
  run engine_py '
c = tool()
found = engine.unique_findings([finding(c, dev_only=True), finding(c), finding(c, id="GHSA-2")])
print([(f.id, f.dev_only) for f in found])
'

  [ "$output" = "[('GHSA-1', False), ('GHSA-2', False)]" ]
}

@test "an unmaintained notice is information, an unsound notice and a vulnerability fail" {
  run engine_py '
from model import Result
record = lambda kind: {"id": "RUSTSEC-1", "affected": [{"database_specific": {"informational": kind}}]}
print(osv.notice(record("unmaintained")), osv.notice(record("unsound")), repr(osv.notice({"id": "GHSA-1", "affected": [{}]})))
c = tool()
result = Result(findings=[Finding(c, "osv", "A", "", notice="unmaintained"), Finding(c, "osv", "B", "", notice="unsound"), Finding(c, "osv", "C", "")])
print([f.id for f in result.failing_findings()], int(result.exit_code()))
result = Result(findings=[Finding(c, "osv", "A", "", notice="unmaintained")])
print(int(result.exit_code()))
'

  [ "${lines[0]}" = "unmaintained unsound ''" ]
  [ "${lines[1]}" = "['B', 'C'] 1" ]
  [ "${lines[2]}" = "0" ]
}

@test "an upstream lockfile finding the installed binary does not contain is information" {
  run engine_py '
c = tool("gopls", "0.24.0")
scan = "osv-scanner golang/tools@gopls/v0.24.0 gopls/go.mod"
findings = [
    Finding(c, scan, "GO-1", "", package="Go/golang.org/x/net@0.59.0"),
    Finding(c, scan, "GO-2", "", package="Go/golang.org/x/sys@0.35.0"),
    Finding(c, scan, "RUSTSEC-1", "", package="crates.io/zip@4.6.1"),
    Finding(c, "github golang/tools", "GHSA-1", "", package="golang/tools@0.24.0"),
]
run.install_paths = lambda: {("gopls", "0.24.0"): "/installs/gopls/0.24.0"}
osv.binary_packages = lambda path: {"Go/golang.org/x/sys@0.35.0", "Go/golang.org/x/text@0.42.0"}
for f in run.narrowed_to_binaries(findings):
    print(f.id, repr(f.notice))
run.install_paths = lambda: {}
print([repr(f.notice) for f in run.narrowed_to_binaries(findings)])
'

  [ "${lines[0]}" = "GO-1 'not compiled into the installed binary'" ]
  [ "${lines[1]}" = "GO-2 ''" ]
  [ "${lines[2]}" = "RUSTSEC-1 ''" ]
  [ "${lines[3]}" = "GHSA-1 ''" ]
  [ "${lines[4]}" = "[\"''\", \"''\", \"''\", \"''\"]" ]
}

@test "a finding is waiting when its tool is at the newest release in its line, and blocks when a newer one exists" {
  run engine_py '
import upgrades
from model import Result
newest = {
    ("biome", "2.6.8"): upgrades.Newest("biome", "2.6.8", "2.6.8", "2.6.8"),
    ("fzf", "0.74.5"): upgrades.Newest("fzf", "0.74.5", "0.75.0", "0.75.0"),
    ("java", "temurin-17.0.21.1+2"): upgrades.Newest("java", "temurin-17.0.21.1+2", "temurin-17.0.21.1+2", "temurin-27.0.1.1+4"),
}
upgrades.newest_versions = lambda pairs, config: newest
findings = [
    finding(tool("biome", "2.6.8"), id="RUSTSEC-2026-0341"),
    finding(tool("fzf", "0.74.5"), id="GO-2026-5024"),
    finding(tool("java", "temurin-17.0.21.1+2"), id="CVE-2026-114938"),
    finding(tool("lazy.nvim", "a" * 40, kind=Kind.NVIM_PLUGIN), id="GHSA-9"),
]
for f in run.with_status(findings):
    print(f.id, "|", f.status, "|", f.action, "|", f.url)
result = Result(findings=run.with_status(findings))
print(sorted(f.id for f in result.blocking_findings()), int(result.exit_code()), int(result.exit_code(gate=True)))
'

  [ "${lines[0]}" = "RUSTSEC-2026-0341 | waiting for upstream | none possible yet; biome 2.6.8 is the newest release in its pinned line | https://rustsec.org/advisories/RUSTSEC-2026-0341.html" ]
  [ "${lines[1]}" = "GO-2026-5024 | fix available | upgrade fzf 0.74.5 -> 0.75.0 (zzd upgrade fzf), then run the audit again | https://pkg.go.dev/vuln/GO-2026-5024" ]
  [ "${lines[2]}" = "CVE-2026-114938 | waiting for upstream | none possible yet; java temurin-17.0.21.1+2 is the newest release in its pinned line (a newer line exists: temurin-27.0.1.1+4, not taken without zzd upgrade --major) | https://nvd.nist.gov/vuln/detail/CVE-2026-114938" ]
  [ "${lines[3]}" = "GHSA-9 |  |  | https://github.com/advisories/GHSA-9" ]
  [ "${lines[4]}" = "['GHSA-9', 'GO-2026-5024'] 1 1" ]
}

@test "only waiting findings fail the full audit but pass the gate" {
  run engine_py '
from model import Result, WAITING
import dataclasses
result = Result(findings=[dataclasses.replace(finding(tool()), status=WAITING)])
print(int(result.exit_code()), int(result.exit_code(gate=True)))
'

  [ "$output" = "1 0" ]
}

@test "a tool whose newest version cannot be checked keeps blocking" {
  run engine_py '
import upgrades
upgrades.newest_versions = lambda pairs, config: {("biome", "2.6.8"): upgrades.Newest("biome", "2.6.8", None, None)}
print(repr(run.with_status([finding(tool("biome", "2.6.8"))])[0].status))
'

  [ "$output" = "''" ]
}

@test "the fixed version comes from the NVD configuration and the CVE.org record" {
  run engine_py '
import cpe, cna
record = {"configurations": [{"nodes": [{"cpeMatch": [
    {"vulnerable": True, "criteria": "cpe:2.3:a:sqlite:sqlite:*:*:*:*:*:*:*:*", "versionEndExcluding": "3.53.2"},
    {"vulnerable": True, "criteria": "cpe:2.3:a:other:thing:*:*:*:*:*:*:*:*", "versionEndExcluding": "9.9"}]}]}]}
print(cpe.fixed_versions(record, cpe.parse("cpe:2.3:a:sqlite:sqlite"), "3.53.1"))
published = {"containers": {"cna": {"affected": [{"vendor": "V", "product": "P", "versions": [{"version": "3.14.0", "lessThan": "3.14.11", "status": "affected"}]}]}}}
print(cna.fixed_versions(published, [{"vendor": "V", "product": "P"}], "3.14.10"))
'

  [ "${lines[0]}" = "('3.53.2',)" ]
  [ "${lines[1]}" = "('3.14.11',)" ]
}

@test "the report shows the library, the fix, the action and the link for each finding" {
  run engine_py '
import cli, dataclasses
from model import Result, WAITING
f = dataclasses.replace(
    Finding(tool("biome", "2.6.8"), "osv-scanner biomejs/biome@2.6.8 Cargo.lock", "RUSTSEC-2026-0341", "Stream reassembly memory-exhaustion guard in quinn-proto can be bypassed",
            aliases=("GHSA-qfwj-vfxf-92j2",), fixed_in=("0.11.17",), severity="CVSS 7.5", package="crates.io/quinn-proto@0.11.15"),
    status=WAITING, action="none possible yet; biome 2.6.8 is the newest release in its pinned line", url="https://rustsec.org/advisories/RUSTSEC-2026-0341.html")
cli.print_report(Result(components=[f.component], findings=[f]))
'

  [ "${lines[0]}" = "FINDING (waiting for upstream): mise-tool:biome@2.6.8 [mise/mise.lock]" ]
  [ "${lines[1]}" = "  RUSTSEC-2026-0341 / GHSA-qfwj-vfxf-92j2, high (CVSS 7.5)" ]
  [ "${lines[2]}" = "  Library: crates.io/quinn-proto@0.11.15, fixed in 0.11.17" ]
  [ "${lines[3]}" = "  What: Stream reassembly memory-exhaustion guard in quinn-proto can be bypassed" ]
  [ "${lines[4]}" = "  Action: none possible yet; biome 2.6.8 is the newest release in its pinned line" ]
  [ "${lines[5]}" = "  More: https://rustsec.org/advisories/RUSTSEC-2026-0341.html" ]
  [[ "${lines[7]}" == "Summary: 1 components, 1 findings in 1 components (0 block pushes, 1 waiting for upstream)"* ]]
}

@test "a crate reachable only from crates the release does not ship is not shipped" {
  cat >"$BATS_TEST_TMPDIR/Cargo.lock" <<'EOF'
version = 4

[[package]]
name = "app"
version = "1.0.0"
dependencies = ["url", "rand 0.8.5"]

[[package]]
name = "xtask"
version = "0.1.0"
dependencies = ["zip", "rand 0.7.3"]

[[package]]
name = "url"
version = "2.5.8"
source = "registry+https://github.com/rust-lang/crates.io-index"

[[package]]
name = "zip"
version = "4.6.1"
source = "registry+https://github.com/rust-lang/crates.io-index"

[[package]]
name = "rand"
version = "0.8.5"
source = "registry+https://github.com/rust-lang/crates.io-index"

[[package]]
name = "rand"
version = "0.7.3"
source = "registry+https://github.com/rust-lang/crates.io-index"
EOF

  run engine_py "
text = Path('$BATS_TEST_TMPDIR/Cargo.lock').read_text()
print(sorted(osv.cargo_unreachable(text, ['app'])))
try:
    osv.cargo_unreachable(text, ['missing-crate'])
except osv.SourceError as error:
    print(error)
"

  [ "${lines[0]}" = "['crates.io/rand@0.7.3', 'crates.io/xtask@0.1.0', 'crates.io/zip@4.6.1']" ]
  [ "${lines[1]}" = "Cargo.lock has no crate named missing-crate to start from" ]
}

@test "a binary without a dependency list narrows nothing" {
  run engine_py '
c = tool("biome", "2.6.8")
findings = [Finding(c, "osv-scanner biomejs/biome@2.6.8 Cargo.lock", "RUSTSEC-1", "", package="crates.io/quinn-proto@0.11.15")]
run.install_paths = lambda: {("biome", "2.6.8"): "/installs/biome/2.6.8"}
osv.binary_packages = lambda path: set()
print(repr(run.narrowed_to_binaries(findings)[0].notice))
'

  [ "$output" = "''" ]
}

@test "a CVE for a commit-pinned component applies unless the pin contains its fix commit" {
  run engine_py '
records = [
    {"id": "CVE-FIXED", "references": [{"url": "https://github.com/o/r/commit/aaaaaaa"}]},
    {"id": "CVE-OPEN", "references": [{"url": "https://github.com/o/r/commit/bbbbbbb"}]},
    {"id": "CVE-NOFIX", "references": [{"url": "https://example.com/report"}]},
]
nvd._pages = lambda params: records
ghapi.json_get = lambda endpoint, paginate=False: {"status": "ahead"} if "aaaaaaa..." in endpoint else {"status": "behind"}
for f in nvd.commit_pinned(tool(), "cpe:2.3:a:o:r", "o/r", "f" * 40):
    print(f.id, f.summary)
'

  [ "${lines[0]}" = "CVE-OPEN " ]
  [ "${lines[1]}" = "CVE-NOFIX  (cannot verify: the CVE names no fix commit in o/r)" ]
}

@test "GitHub ranges read channel labels, product labels, run-together ranges and explicit ORs" {
  run engine_py '
print(
    github.in_range("3.13.7", "< 3.13.7 (stable), < 3.14.0-315.3.beta (beta)"),
    github.in_range("3.13.6", "< 3.13.7 (stable), < 3.14.0-315.3.beta (beta)"),
    github.in_range("10.0.3", ">= 9.0.0, <= 9.0.13 >= 10.0.0, <= 10.0.3"),
    github.in_range("8.6.7", "<7.33.4 || >=8.0.0 <8.6.8"),
    github.in_range("8.0.3", ">= 7.0.0, < =8.0.3"),
    github.in_range("2.18.1", "Dart version prior to 2.18.2, Flutter version prior to 3.3.3", "Dart"),
    github.in_range("3.3.2", "Dart version prior to 2.18.2, Flutter version prior to 3.3.3", "Dart"),
)
'

  [ "$output" = "False True True True True True False" ]
}

@test "an unreadable range falls back to its patched version, and fails when that is unreadable too" {
  run engine_py '
print(github.affected("7.0.10", {"vulnerable_version_range": "Some.Package.Name", "patched_versions": "7.0.11"}),
      github.affected("10.0.3", {"vulnerable_version_range": "Some.Package.Name", "patched_versions": "7.0.11"}))
try:
    github.affected("1.0.0", {"vulnerable_version_range": "all of them", "patched_versions": "soon"})
except github.SourceError as error:
    print(error)
'

  [ "${lines[0]}" = "True False" ]
  [ "${lines[1]}" = "cannot read the version range 'all of them'" ]
}

@test "the Haskell reader takes the GHC version from the runtime and the packages from the binary" {
  cat >"$BATS_TEST_TMPDIR/hs" <<'EOF'
#!/bin/sh
printf ' [("GHC RTS", "YES")\n ,("GHC version", "9.8.2")\n'
exit 0
# aeson-2.2.3.0-d5fbfb14b3895a4e880c98a07524288a36d81302d75cb24b15542b6f4b0cf055 text-2.1.1-inplace
EOF
  chmod +x "$BATS_TEST_TMPDIR/hs"

  run engine_py "print(readers.haskell_binary('$BATS_TEST_TMPDIR/hs'))"

  [ "$output" = "[Package(ecosystem='GHC', name='ghc', version='9.8.2'), Package(ecosystem='Hackage', name='aeson', version='2.2.3.0'), Package(ecosystem='Hackage', name='text', version='2.1.1')]" ]
}

@test "the .NET single-file reader reads packages and the runtime pack from the embedded deps.json" {
  printf 'MZ\0\0junk{"runtimeTarget": {"name": ".NETCoreApp,Version=v9.0/linux-x64"}, "libraries": {"Newtonsoft.Json/13.0.4": {"type": "package"}, "runtimepack.Microsoft.NETCore.App.Runtime.linux-x64/9.0.12": {"type": "runtimepack"}, "app/1.0.0": {"type": "project"}}}\0tail' >"$BATS_TEST_TMPDIR/app"

  run engine_py "print(readers.dotnet_single_file('$BATS_TEST_TMPDIR/app'))"

  [ "$output" = "[Package(ecosystem='NuGet', name='Newtonsoft.Json', version='13.0.4'), Package(ecosystem='NuGet', name='Microsoft.NETCore.App.Runtime.linux-x64', version='9.0.12')]" ]
}

@test "central NuGet versions resolve MSBuild properties and fail on an unresolved one" {
  cat >"$BATS_TEST_TMPDIR/props.xml" <<'EOF'
<Project>
  <PropertyGroup>
    <RoslynVersion>4.9.0</RoslynVersion>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="Microsoft.CodeAnalysis" Version="$(RoslynVersion)" />
    <PackageVersion Include="Newtonsoft.Json" Version="13.0.3" />
  </ItemGroup>
</Project>
EOF

  run engine_py "
text = Path('$BATS_TEST_TMPDIR/props.xml').read_text()
print(readers.nuget_central(text, 'Directory.Packages.props'))
try:
    readers.nuget_central(text.replace('RoslynVersion)', 'Missing)'), 'Directory.Packages.props')
except readers.SourceError as error:
    print(error)
"

  [ "${lines[0]}" = "[Package(ecosystem='NuGet', name='Microsoft.CodeAnalysis', version='4.9.0'), Package(ecosystem='NuGet', name='Newtonsoft.Json', version='13.0.3')]" ]
  [ "${lines[1]}" = "Directory.Packages.props: cannot resolve the version of Microsoft.CodeAnalysis (\$(Missing))" ]
}

@test "the python runtime reader reports the four bundled libraries the interpreter loads" {
  mkdir -p "$BATS_TEST_TMPDIR/py/bin"
  printf '#!/bin/sh\nprintf "3.5.5\\n3.50.4\\n1.3.1\\n2.6.3\\n"\n' >"$BATS_TEST_TMPDIR/py/bin/python3"
  chmod +x "$BATS_TEST_TMPDIR/py/bin/python3"

  run engine_py "print(readers.python_runtime('$BATS_TEST_TMPDIR/py'))"

  [ "$output" = "{'openssl': '3.5.5', 'sqlite': '3.50.4', 'zlib': '1.3.1', 'expat': '2.6.3'}" ]
}

@test "an upstream file path that leaves the checkout is rejected" {
  run engine_py "
ghapi.raw_file = lambda repo, path, ref: 'x'
try:
    osv._fetch_into(Path('$BATS_TEST_TMPDIR/checkout'), 'o/r', 'v1', '../../etc/passwd')
except osv.SourceError as error:
    print(error)
"

  [ "$output" = "o/r path ../../etc/passwd leaves the checkout" ]
}
