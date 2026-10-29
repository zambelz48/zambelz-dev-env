#!/usr/bin/env bats

setup() {
  load helpers
  zc_test_setup
  # shellcheck source=../lib/os.sh
  . "$ZC_ROOT/zconf/lib/os.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZC_ROOT/zconf/lib/paths.sh"
  ZC_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZC_OS_RELEASE
}

linux_with() {
  zc_stub uname 0 "Linux"
  printf '%s\n' "$@" >"$ZC_OS_RELEASE"
}

@test "macOS is darwin" {
  zc_stub uname 0 "Darwin"
  [ "$(zc_os)" = "darwin" ]
}

@test "fedora is detected from ID" {
  linux_with 'NAME="Fedora Linux"' 'ID=fedora' 'VERSION_ID=44'
  [ "$(zc_os)" = "fedora" ]
}

@test "ubuntu is detected from a quoted ID" {
  linux_with 'NAME="Ubuntu"' 'ID="ubuntu"'
  [ "$(zc_os)" = "ubuntu" ]
}

@test "an ubuntu derivative is detected from ID_LIKE" {
  linux_with 'ID=linuxmint' 'ID_LIKE="ubuntu debian"'
  [ "$(zc_os)" = "ubuntu" ]
}

@test "an unknown distribution is unsupported" {
  linux_with 'ID=arch'
  [ "$(zc_os)" = "unsupported" ]
}

@test "linux without os-release is unsupported" {
  zc_stub uname 0 "Linux"
  [ "$(zc_os)" = "unsupported" ]
}

@test "an unknown kernel is unsupported" {
  zc_stub uname 0 "FreeBSD"
  [ "$(zc_os)" = "unsupported" ]
}
