#!/usr/bin/env bash
# POSIX counterpart to link-skills.ps1. Links by default; use -c to copy.
set -euo pipefail

target="${HOME}/.agents/skills"
copy=0
force=0

while getopts "t:cfh" opt; do
  case "$opt" in
    t) target="$OPTARG" ;;
    c) copy=1 ;;
    f) force=1 ;;
    h)
      echo "Usage: $0 [-t target-directory] [-c] [-f]"
      exit 0
      ;;
    *) exit 2 ;;
  esac
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sources=()

while IFS= read -r skill_md; do
  sources+=("$(dirname "$skill_md")")
done < <(find "$repo_root/sort-skills" -name SKILL.md -type f | sort)

maintenance="$repo_root/.agents/skills/maintain-aurora-skills/SKILL.md"
if [[ -f "$maintenance" ]]; then
  sources+=("$(dirname "$maintenance")")
fi

for ((i=0; i<${#sources[@]}; i++)); do
  for ((j=i+1; j<${#sources[@]}; j++)); do
    if [[ "$(basename "${sources[i]}")" == "$(basename "${sources[j]}")" ]]; then
      echo "Duplicate skill name: $(basename "${sources[i]}")" >&2
      exit 1
    fi
  done
done

mkdir -p "$target"
ok=0
skipped=0

for source in "${sources[@]}"; do
  name="$(basename "$source")"
  destination="$target/$name"

  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ "$force" -ne 1 ]]; then
      echo "  = $name (exists; use -f to replace)"
      skipped=$((skipped + 1))
      continue
    fi
    if [[ -L "$destination" || "$copy" -eq 1 ]]; then
      rm -rf -- "$destination"
    else
      echo "Refusing to replace non-link directory without copy mode: $destination" >&2
      exit 1
    fi
  fi

  if [[ "$copy" -eq 1 ]]; then
    cp -R -- "$source" "$destination"
  else
    ln -s -- "$source" "$destination"
  fi
  echo "  + $name"
  ok=$((ok + 1))
done

echo "Done: synchronized=$ok, skipped=$skipped -> $target"
