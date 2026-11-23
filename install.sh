#!/usr/bin/env bash
set -euo pipefail

source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"

usage() {
  echo "Usage: ./install.sh [--bar-layout] [--no-audio-download]"
}

apply_layout=false
download_audio=true
for option in "$@"; do
  case "$option" in
    --bar-layout) apply_layout=true ;;
    --no-audio-download) download_audio=false ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

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
downloads="$HOME/Downloads"
if command -v xdg-user-dir >/dev/null; then
  configured_downloads=$(xdg-user-dir DOWNLOAD)
  if [[ -n $configured_downloads ]]; then downloads=$configured_downloads; fi
fi
mkdir -p -- "$downloads/Slideshow"
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

install_rain_audio() (
  track="$config_dir/pomodoro-rain.m4a"
  if [[ -e $track || -L $track ]]; then return 0; fi

  for tool in curl sha256sum; do
    if ! command -v "$tool" >/dev/null; then
      echo "Missing $tool. The timer will use the included rain sound." >&2
      return 0
    fi
  done

  url="https://github.com/OfficiallyCarbine/omarchy-focus-widgets/releases/download/v1.0.0/pomodoro-rain.m4a"
  checksum="7dd37cc5475cd5953503fb17b0f1cabac60d2f13d1156f5481fc68d1c47c7d12"
  temp=$(mktemp "$config_dir/.pomodoro-rain.XXXXXX")
  trap 'rm -f -- "$temp"' EXIT

  echo "Downloading the original rain track (223 MiB)..."
  if curl --fail --location --retry 2 --connect-timeout 10 --output "$temp" "$url" &&
    printf '%s  %s\n' "$checksum" "$temp" | sha256sum --check --status; then
    if ln -- "$temp" "$track"; then
      echo "Installed the original rain track."
    elif [[ ! -e $track && ! -L $track ]]; then
      echo "Could not save the rain track. The timer will use the included rain sound." >&2
    fi
  else
    echo "Could not download or verify the rain track. The timer will use the included rain sound." >&2
  fi
)

if $download_audio; then install_rain_audio; fi

for tool in mpv paplay; do
  if ! command -v "$tool" >/dev/null; then
    echo "Optional audio command $tool is missing."
  fi
done
echo "Installed Desktop Widgets and Pomodoro."
