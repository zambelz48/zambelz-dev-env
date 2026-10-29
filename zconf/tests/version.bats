#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/version.sh
  . "$ZC_ROOT/zconf/lib/version.sh"
}

@test "equal versions compare as at least" {
  zc_version_ge 2026.10.21 2026.10.21
}

@test "a newer year, month or day is at least the older one" {
  zc_version_ge 2027.1.1 2026.10.21
  zc_version_ge 2026.11.1 2026.10.21
  zc_version_ge 2026.10.22 2026.10.21
}

@test "components compare as numbers, not text" {
  run zc_version_ge 2026.9.30 2026.10.1
  [ "$status" -eq 1 ]
  zc_version_ge 2026.10.1 2026.9.30
}

@test "an older version is not at least the newer one" {
  run zc_version_ge 2026.4.24 2026.10.21
  [ "$status" -eq 1 ]
}

@test "missing components count as zero" {
  zc_version_ge 2026.10 2026.10.0
  run zc_version_ge 2026.10 2026.10.1
  [ "$status" -eq 1 ]
}

@test "mise min_version is read from the top level of mise.toml" {
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ZC_ROOT/mise"
  printf 'min_version = "2026.10.21"\n\n[tools]\nmin_version = "1"\n' \
    >"$ZC_ROOT/mise/mise.toml"
  run zc_mise_min_version
  [ "$status" -eq 0 ]
  [ "$output" = "2026.10.21" ]
}

@test "a mise.toml without a top-level min_version fails" {
  ZC_ROOT="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$ZC_ROOT/mise"
  printf '[tools]\nmin_version = "1"\n' >"$ZC_ROOT/mise/mise.toml"
  run zc_mise_min_version
  [ "$status" -eq 1 ]
}

@test "the repository's mise.toml has a min_version" {
  run zc_mise_min_version
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || false
}
