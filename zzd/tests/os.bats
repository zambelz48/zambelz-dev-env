#!/usr/bin/env bats

setup() {
  load helpers
  zzd_test_setup
  # shellcheck source=../lib/os.sh
  . "$ZZD_ROOT/zzd/lib/os.sh"
  # shellcheck source=../lib/paths.sh
  . "$ZZD_ROOT/zzd/lib/paths.sh"
  ZZD_OS_RELEASE="$BATS_TEST_TMPDIR/os-release"
  export ZZD_OS_RELEASE
}

linux_with() {
  zzd_stub uname 0 "Linux"
  printf '%s\n' "$@" >"$ZZD_OS_RELEASE"
}

@test "macOS is darwin" {
  zzd_stub uname 0 "Darwin"
  [ "$(zzd_os)" = "darwin" ]
}

@test "fedora is detected from ID" {
  linux_with 'NAME="Fedora Linux"' 'ID=fedora' 'VERSION_ID=44'
  [ "$(zzd_os)" = "fedora" ]
}

@test "ubuntu is detected from a quoted ID" {
  linux_with 'NAME="Ubuntu"' 'ID="ubuntu"'
  [ "$(zzd_os)" = "ubuntu" ]
}

@test "an ubuntu derivative is detected from ID_LIKE" {
  linux_with 'ID=linuxmint' 'ID_LIKE="ubuntu debian"'
  [ "$(zzd_os)" = "ubuntu" ]
}

@test "an unknown distribution is unsupported" {
  linux_with 'ID=arch'
  [ "$(zzd_os)" = "unsupported" ]
}

@test "linux without os-release is unsupported" {
  zzd_stub uname 0 "Linux"
  [ "$(zzd_os)" = "unsupported" ]
}

@test "an unknown kernel is unsupported" {
  zzd_stub uname 0 "FreeBSD"
  [ "$(zzd_os)" = "unsupported" ]
}
