#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: open-in-rider.sh [path] [--line N]

Open a file or folder in JetBrains Rider.
If possible, open it within the nearest .sln context.

Arguments:
  path         File or directory to open (default: .)
  --line, -l   Line number when opening a file
  --help, -h   Show this help
EOF
}

launch_rider() {
  if command -v nohup >/dev/null 2>&1; then
    nohup "$rider_cmd" "$@" >/dev/null 2>&1 < /dev/null &
    return 0
  fi

  "$rider_cmd" "$@" >/dev/null 2>&1 < /dev/null &
}

get_rider_command() {
  local candidate
  for candidate in rider rider.bat rider64.exe; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

choose_best_match() {
  local dir_name="$1"
  shift
  local candidates=("$@")

  local candidate
  for candidate in "${candidates[@]}"; do
    local base
    base="$(basename "${candidate%.*}")"
    if [[ "$base" == "$dir_name" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '%s\n' "${candidates[@]}" | sort | head -n 1
}

find_nearest_project_file() {
  local start_dir="$1"
  local extension="$2"
  local dir="$start_dir"

  shopt -s nullglob
  while :; do
    local matches=("$dir"/*."$extension")
    if (( ${#matches[@]} > 0 )); then
      local dir_name
      dir_name="$(basename "$dir")"
      choose_best_match "$dir_name" "${matches[@]}"
      return 0
    fi

    if [[ "$dir" == "/" ]]; then
      break
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}

target="."
target_provided="0"
line=""

while (( $# > 0 )); do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -l|--line)
      shift
      if (( $# == 0 )); then
        echo "Error: missing value for --line" >&2
        exit 2
      fi
      line="$1"
      if [[ ! "$line" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: --line must be a positive integer" >&2
        exit 2
      fi
      ;;
    *)
      if [[ "$target_provided" == "1" ]]; then
        echo "Error: only one path argument is supported" >&2
        exit 2
      fi
      target="$1"
      target_provided="1"
      ;;
  esac
  shift
done

if ! rider_cmd="$(get_rider_command)"; then
  echo "Error: Rider CLI not found on PATH. Expected one of: rider, rider.bat, rider64.exe" >&2
  exit 127
fi

if [[ ! -e "$target" ]]; then
  echo "Error: path does not exist: $target" >&2
  exit 2
fi

target="$(realpath "$target")"

if [[ -d "$target" ]]; then
  open_mode="dir"
  search_dir="$target"
else
  open_mode="file"
  search_dir="$(dirname "$target")"
fi

solution=""
project=""

if solution="$(find_nearest_project_file "$search_dir" "sln")"; then
  :
elif project="$(find_nearest_project_file "$search_dir" "csproj")"; then
  :
fi

if [[ -n "$solution" ]]; then
  if [[ "$open_mode" == "file" ]]; then
    if [[ -n "$line" ]]; then
      launch_rider "$solution" --line "$line" "$target"
      exit 0
    fi
    launch_rider "$solution" "$target"
    exit 0
  fi
  launch_rider "$solution"
  exit 0
fi

if [[ -n "$project" ]]; then
  if [[ "$open_mode" == "file" ]]; then
    if [[ -n "$line" ]]; then
      launch_rider "$project" --line "$line" "$target"
      exit 0
    fi
    launch_rider "$project" "$target"
    exit 0
  fi
  launch_rider "$project"
  exit 0
fi

if [[ "$open_mode" == "file" && -n "$line" ]]; then
  launch_rider --line "$line" "$target"
  exit 0
fi

launch_rider "$target"
