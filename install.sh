#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"

case "${1:-}" in
  "") apply_layout=false ;;
  --bar-layout) apply_layout=true ;;
  --help|-h) echo "Usage: ./install.sh [--bar-layout]"; exit 0 ;;
  *) echo "Usage: ./install.sh [--bar-layout]" >&2; exit 2 ;;
esac
(( $# <= 1 )) || exit 2

for tool in omarchy omarchy-shell jq; do
  command -v "$tool" >/dev/null || { echo "Missing required command $tool" >&2; exit 1; }
done
omarchy-shell shell ping >/dev/null || {
  echo "Run the installer from your Omarchy desktop session." >&2
  exit 1
}

plugins=(local.desktop-widgets local.pomodoro)
for id in "${plugins[@]}"; do
  omarchy plugin validate "$source_dir/plugins/$id"
  target="$config_dir/plugins/$id"
  if [[ -e $target || -L $target ]] && ! diff -qr "$source_dir/plugins/$id" "$target" >/dev/null; then
    echo "A different version of $id is already installed. Back it up and move it out of the plugins folder before continuing." >&2
    exit 1
  fi
done

mkdir -p "$config_dir/plugins"
if [[ -f $config_dir/shell.json ]]; then
  backup=$(mktemp "$config_dir/shell.json.focus-widgets.XXXXXX")
  cp -p -- "$config_dir/shell.json" "$backup"
  echo "Saved previous shell settings to $backup"
fi
for id in "${plugins[@]}"; do
  if [[ ! -e $config_dir/plugins/$id ]]; then
    cp -a -- "$source_dir/plugins/$id" "$config_dir/plugins/"
  fi
done
(
  set -o noclobber
  for file in pomodoro.json pomodoro-totals.json; do
    if [[ ! -e $config_dir/$file ]]; then
      printf '{}\n' > "$config_dir/$file"
    fi
  done
)

catalog_ready=false
for attempt in {1..15}; do
  catalog=$(omarchy-shell shell listPlugins)
  if jq -e 'any(.[]; .id == "local.desktop-widgets") and any(.[]; .id == "local.pomodoro")'     <<<"$catalog" >/dev/null; then
    catalog_ready=true
    break
  fi
  omarchy-shell -q shell rescanPlugins
  sleep 0.3
done
if ! $catalog_ready; then
  echo "Omarchy has not discovered the widgets. Restart the shell, then rerun the installer." >&2
  exit 1
fi

if ! jq -e 'any(.[]; .id == "local.desktop-widgets" and .enabled)' <<<"$catalog" >/dev/null; then
  omarchy plugin enable local.desktop-widgets
fi

if ! jq -e 'any(.[]; .id == "local.pomodoro" and .enabled)' <<<"$catalog" >/dev/null; then
  if [[ -f $config_dir/shell.json ]] && jq -e 'any(.bar.layout.center[]?; .id == "omarchy.clock")'     "$config_dir/shell.json" >/dev/null; then
    omarchy plugin enable local.pomodoro --section centerEnd --index 0
  elif [[ -f $config_dir/shell.json ]] && jq -e '
    any(.bar.layout[]?[]?; .id == "omarchy.clock")' "$config_dir/shell.json" >/dev/null; then
    omarchy plugin enable local.pomodoro --after omarchy.clock
  else
    omarchy plugin enable local.pomodoro --section centerEnd --index 0
  fi
fi

if $apply_layout; then
  layout="$source_dir/bar-layout.json"
  omarchy bar position "$(jq -r .position "$layout")"
  omarchy bar background "$(jq -r .background "$layout")"
  while IFS=$'\t' read -r section index id; do
    if jq -e --arg id "$id" 'any(.[]; .id == $id)' <<<"$catalog" >/dev/null; then
      omarchy bar put "$id" --section "$section" --index "$index"
      omarchy bar move "$id" --section "$section" --index "$index"
    else
      echo "This version of Omarchy does not include $id. Skipping it."
    fi
  done < <(jq -r '.layout | to_entries[] | .key as $section |
    .value | to_entries[] | [$section, .key, .value] | @tsv' "$layout")
fi

for tool in mpv paplay; do
  if ! command -v "$tool" >/dev/null; then
    echo "Optional audio command $tool is missing."
  fi
done
echo "Installed Desktop Widgets and Pomodoro."
