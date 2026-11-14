#!/usr/bin/env bash
# Runs the installer in a throwaway $HOME against local repositories (no network).
# Usage: tests/test_install.sh DIR_WITH_REPOS
#   DIR_WITH_REPOS holds checkouts named like the GitHub repos:
#   nummode, deep-research, bite-watch, Claude-makeup-skill
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BASE="${1:?give a directory that holds the skill repositories}"
FAKE="$(mktemp -d)"
trap 'rm -rf "${FAKE}"' EXIT
export HOME="${FAKE}/home" SKILLS_REPO_BASE="${BASE}" SKILLS_REPOS_DIR="${FAKE}/repos" SKILLS_LOG_DIR="${FAKE}/logs"
mkdir -p "${HOME}"
pass=0
ok() { echo "ok  $*"; pass=$((pass + 1)); }
die() { echo "FAIL $*" >&2; exit 1; }
I="${ROOT}/install.sh"

out="$(bash "${I}" --list)" || die "--list failed"
[[ "$(echo "${out}" | wc -l)" -eq 10 ]] || die "--list should print a header and 9 skills"
ok "--list"

out="$(bash "${I}" --dry-run)" || die "--dry-run failed"
[[ ! -e "${FAKE}/repos" && ! -e "${HOME}/.agents" ]] || die "--dry-run changed the disk"
echo "${out}" | grep -q "would install nummode" || die "--dry-run did not list nummode"
ok "--dry-run changes nothing"

if bash "${I}" nope >/dev/null 2>&1; then die "unknown skill accepted"; fi
if bash "${I}" --frobnicate >/dev/null 2>&1; then die "unknown option accepted"; fi
ok "bad arguments rejected"

out="$(bash "${I}" nummode deep-research bite-watch makeup-guide)" || { echo "${out}"; cat "${FAKE}"/logs/*.log; die "install failed"; }
echo "${out}" | grep -q "installed: 4   skipped: 0   failed: 0" || { echo "${out}"; die "wrong summary"; }
for f in .nummode/scripts/route.py .agents/skills/nummode/SKILL.md .claude/agents/nummode.md \
         .agents/skills/deep-research/scripts/research.py .claude/agents/researcher.md \
         .agents/skills/bite-watch/SKILL.md .agents/skills/makeup-guide/SKILL.md; do
  [[ -f "${HOME}/${f}" ]] || die "missing ${f}"
done
[[ -L "${HOME}/.claude/skills/bite-watch" && -f "${HOME}/.claude/skills/makeup-guide/SKILL.md" ]] || die "claude links missing"
ok "four skills installed from one command"

out="$(bash "${I}" nummode bite-watch)" || die "second run failed"
echo "${out}" | grep -q "installed: 2" || die "second run summary"
ok "re-run updates in place"

out="$(bash "${I}" --skip nummode,deep-research --skip bite-watch makeup-guide nummode)" || die "--skip run failed"
echo "${out}" | grep -q "installed: 1   skipped: 1" || { echo "${out}"; die "--skip summary"; }
ok "--skip"

# A skill whose tool is missing is skipped; a broken repository fails without stopping the others.
out="$(PATH="/usr/bin:/bin" SKILLS_REPO_BASE="${FAKE}/nowhere" SKILLS_REPOS_DIR="${FAKE}/repos2" bash "${I}" product-video quranflow bite-watch 2>&1)" && die "expected a failure exit"
echo "${out}" | grep -q "skip  product-video: missing claude" || { echo "${out}"; die "missing tool not reported"; }
echo "${out}" | grep -q "failed: 2" || { echo "${out}"; die "clone failures not counted"; }
ok "missing tools are skipped, failures are reported, exit code is 1"
echo "${pass} checks passed"
