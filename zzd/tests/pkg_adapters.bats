#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  zc_stub id 0 "501"
  zc_stub sudo 0
  ADAPTERS="$ZC_ROOT/zconf/adapters/pkg"
}

in_adapter() {
  local adapter="$1"
  shift
  (
    for lib in log exec; do
      # shellcheck source=/dev/null
      . "$ZC_ROOT/zconf/lib/$lib.sh"
    done
    # shellcheck source=/dev/null
    . "$ADAPTERS/$adapter.sh"
    "$@"
  )
}

@test "brew outdated turns brew's verbose format into name current latest" {
  zc_stub brew 0 "aws-c-s3 (1.4.0) < 1.4.1"
  run in_adapter brew pkg_outdated aws-c-s3
  [ "$output" = "aws-c-s3 1.4.0 1.4.1" ]
  [ "$(zc_calls brew)" = "outdated --formula --verbose aws-c-s3" ]
}

@test "brew cask outdated parses the != form" {
  zc_stub brew 0 "reqable (3.3.5) != 3.3.6"
  run in_adapter brew-cask pkg_outdated reqable
  [ "$output" = "reqable 3.3.5 3.3.6" ]
}

@test "brew version prints the newest installed version" {
  zc_stub brew 0 "gmp 6.3.0 6.2.1"
  run in_adapter brew pkg_version gmp
  [ "$output" = "6.3.0" ]
}

@test "brew install installs all packages in one call" {
  zc_stub brew 0
  run in_adapter brew pkg_install gmp chafa
  [ "$status" -eq 0 ]
  [ "$(zc_calls brew)" = "install --formula gmp chafa" ]
}

@test "dnf install goes through sudo" {
  zc_stub dnf 0
  run in_adapter dnf pkg_install zsh gmp-devel </dev/null
  [ "$status" -eq 0 ]
  [ "$(zc_calls sudo | tail -1)" = "-n dnf install -y zsh gmp-devel" ]
}

@test "dnf installed check queries the capability, not the name" {
  zc_stub rpm 0 "zlib-ng-compat-devel-2.2.5-2.fc44.x86_64"
  run in_adapter dnf pkg_is_installed zlib-devel
  [ "$status" -eq 0 ]
  [ "$(zc_calls rpm)" = "-q --whatprovides zlib-devel" ]
  zc_stub rpm 1
  run in_adapter dnf pkg_is_installed zlib-devel
  [ "$status" -eq 1 ]
}

@test "dnf version reports the first provider" {
  zc_stub_script rpm 'printf "2.2.5-2.fc44\n2.2.5-2.fc44\n"'
  run in_adapter dnf pkg_version zlib-devel
  [ "$status" -eq 0 ]
  [ "$output" = "2.2.5-2.fc44" ]
}

@test "dnf outdated pairs the installed and upgrade versions" {
  zc_stub_script rpm 'printf "0.32.2-1.fc44\n"'
  zc_stub dnf 0 "kitty 0.35.1-1.fc44"
  run in_adapter dnf pkg_outdated kitty
  [ "$output" = "kitty 0.32.2-1.fc44 0.35.1-1.fc44" ]
}

@test "apt installed check reads dpkg status" {
  zc_stub dpkg-query 0 "install ok installed"
  run in_adapter apt pkg_is_installed zsh
  [ "$status" -eq 0 ]
  zc_stub dpkg-query 1 "unknown ok not-installed"
  run in_adapter apt pkg_is_installed zsh
  [ "$status" -eq 1 ]
}

@test "apt outdated compares apt-cache policy Installed and Candidate" {
  zc_stub_script apt-cache 'cat <<EOF
kitty:
  Installed: 0.32.2-1
  Candidate: 0.35.1-1
  Version table:
EOF'
  run in_adapter apt pkg_outdated kitty
  [ "$output" = "kitty 0.32.2-1 0.35.1-1" ]
}

@test "apt outdated prints nothing when up to date" {
  zc_stub_script apt-cache 'cat <<EOF
zsh:
  Installed: 5.9-6
  Candidate: 5.9-6
EOF'
  run in_adapter apt pkg_outdated zsh
  [ -z "$output" ]
}
