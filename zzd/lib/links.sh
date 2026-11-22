# shellcheck shell=bash

_zc_backup_dir=""

_zc_backup() {
  local target="$1" rel="$2" stamp dest destdir
  if [ -z "$_zc_backup_dir" ]; then
    mkdir -p "${ZZD_STATE_DIR:?}/backup"
    stamp="$(date +%Y%m%d-%H%M%S)"
    _zc_backup_dir="$(mktemp -d "$ZZD_STATE_DIR/backup/$stamp-$$.XXXXXX")"
  fi
  dest="$_zc_backup_dir/$rel"
  destdir="$(dirname "$dest")"
  mkdir -p "$destdir"
  mv "$target" "$dest"
  printf '%s\n' "$dest"
}

zzd_links_apply() {
  local file="$1" src rel source target current parent backup status=0
  _zc_backup_dir=""
  while IFS=$'\t' read -r src rel || [ -n "$src" ]; do
    zzd_is_data_line "$src" || continue
    source="${ZZD_ROOT:?}/$src"
    target="${ZZD_HOME:?}/$rel"
    if [ ! -e "$source" ]; then
      zzd_error "missing link source: $src"
      status=1
      continue
    fi
    backup=""
    if [ -L "$target" ]; then
      current="$(readlink "$target")"
      if [ "$current" = "$source" ]; then
        zzd_ok "linked $rel"
        continue
      fi
      if _zc_dry_run; then
        printf 'DRY-RUN: relink %s -> %s\n' "$rel" "$source"
        continue
      fi
      rm "$target"
    elif [ -e "$target" ]; then
      if _zc_dry_run; then
        printf 'DRY-RUN: back up %s, link -> %s\n' "$rel" "$source"
        continue
      fi
      backup="$(_zc_backup "$target" "$rel")"
    elif _zc_dry_run; then
      printf 'DRY-RUN: link %s -> %s\n' "$rel" "$source"
      continue
    fi
    parent="$(dirname "$target")"
    mkdir -p "$parent"
    ln -s "$source" "$target"
    if [ -n "$backup" ]; then
      zzd_changed "linked $rel (backup: $backup)"
    else
      zzd_changed "linked $rel"
    fi
  done <"$file"
  return "$status"
}

zzd_links_check() {
  local file="$1" src rel source target current status=0
  while IFS=$'\t' read -r src rel || [ -n "$src" ]; do
    zzd_is_data_line "$src" || continue
    source="${ZZD_ROOT:?}/$src"
    target="${ZZD_HOME:?}/$rel"
    current=""
    if [ -L "$target" ]; then
      current="$(readlink "$target")"
    fi
    if [ "$current" = "$source" ]; then
      zzd_ok "linked $rel"
    else
      zzd_error "not linked: $rel" "zzd apply ${ZZD_MODULE:-}"
      status=1
    fi
  done <"$file"
  return "$status"
}
