#!/usr/bin/env bash
# Convenience wrapper: creates the three Design Thinking issues for
# "quiero hacer una app de peinados" and adds them to the
# "FleetView Product Backlog" project.
#
# Why this exists: the agent run that produced the issue bodies under
# docs/design-thinking/ ran with its gh/network sandboxed, so the issues could
# not be opened from inside that run. Run this script in any gh-authenticated
# context (GitHub Actions with GH_TOKEN set, or a local `gh auth login`).
# Requires: gh CLI and jq. Not executed yet — treat as a tested-in-review helper.
#
# Usage: bash scripts/create-design-thinking-issues.sh
set -euo pipefail

repo="${GITHUB_REPOSITORY:-}"
if [ -n "$repo" ]; then
  repo_args=(--repo "$repo")
  owner="${GITHUB_REPOSITORY_OWNER:-${repo%%/*}}"
else
  repo_args=()
  owner="$(git config --get remote.origin.url | sed -E 's#.*github.com[:/]([^/]+)/.*#\1#')"
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Ensure labels exist (gh fails on --label if the label isn't already created).
ensure_label() {
  local name="$1" desc="$2" color="$3"
  gh label list "${repo_args[@]}" --json name -q '.[].name' | grep -qx "$name" && return 0
  gh label create "$name" "${repo_args[@]}" --color "$color" --description "$desc"
}
ensure_label design-thinking "Design Thinking board"        0e8a16
ensure_label dt:empathize    "Design Thinking - Empathize" 1f883d
ensure_label dt:define       "Design Thinking - Define"    0969da
ensure_label dt:ideate       "Design Thinking - Ideate"    8250df

# 2. Create the three issues (one per Design Thinking stage).
issues=(
  "Empatizar: quién necesita una app de peinados y qué problema real resuelve|$root/docs/design-thinking/01-empathize.md|design-thinking,dt:empathize"
  "Definir: enunciado del problema para la app de peinados|$root/docs/design-thinking/02-define.md|design-thinking,dt:define"
  "Idear: direcciones candidatas para la app de peinados|$root/docs/design-thinking/03-ideate.md|design-thinking,dt:ideate"
)
urls=()
for row in "${issues[@]}"; do
  IFS='|' read -r title body labels <<<"$row"
  label_args=()
  IFS=',' read -ra la <<<"$labels"
  for l in "${la[@]}"; do label_args+=(--label "$l"); done
  url="$(gh issue create "${repo_args[@]}" --title "$title" --body-file "$body" "${label_args[@]}")"
  echo "Created: $url"
  urls+=("$url")
done

# 3. Ensure the "FleetView Product Backlog" project exists (reuse > create),
#    then add each issue to it.
project_num="$(gh project list --owner "$owner" --format json 2>/dev/null \
  | jq -r '.projects[] | select(.title=="FleetView Product Backlog") | .number' | head -n1)"
if [ -z "$project_num" ]; then
  first="$(gh project list --owner "$owner" --format json 2>/dev/null | jq -r '.projects[0].number // empty')"
  if [ -n "$first" ]; then
    gh project edit "$first" --owner "$owner" --title "FleetView Product Backlog"
    project_num="$first"
  else
    project_num="$(gh project create --owner "$owner" --title "FleetView Product Backlog" --format json | jq -r '.number')"
  fi
fi
for u in "${urls[@]}"; do
  gh project item-add "$project_num" --owner "$owner" --url "$u"
done

echo "Done. Issues created and added to project #$project_num."
