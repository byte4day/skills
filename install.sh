#!/usr/bin/env bash
# One clone, every byte4day agent skill.
#
#   ./install.sh                    install or update everything
#   ./install.sh nummode copycat    only these
#   ./install.sh --skip copycat     everything except these (repeatable, or comma list)
#   ./install.sh --list             show the skills and what each needs
#   ./install.sh --dry-run          show what would run, change nothing
#   ./install.sh --with-browser     also download Chromium for Copycat (~150 MB)
#
# Each skill lives in its own repository. This script clones it into ./repos/<repo>
# (or pulls it), then runs that repository's own installer. A skill whose
# requirements are missing is skipped with the reason; the rest still install.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_BASE="${SKILLS_REPO_BASE:-https://github.com/byte4day}"
REPOS_DIR="${SKILLS_REPOS_DIR:-${ROOT}/repos}"
LOG_DIR="${SKILLS_LOG_DIR:-${ROOT}/logs}"

# name | repository | commands it needs | what it is
SKILLS=(
  "nummode|nummode|git python3|Routes installed skills for big prompts; relays work to other agent CLIs"
  "deep-research|deep-research|git python3|Research skill and agent with a verified source ledger"
  "copycat|Copycat|git node npm|Inspects a UI in a real browser and rebuilds it in your stack"
  "terminal-linux|terminal-linux|git uv|A separate Linux desktop that agents can see and control"
  "devops|devops-agent|git python3|Deploy, debug and roll back apps from a coding agent"
  "quranflow|quranflow|git python3|Qur'an recitation in the background while you code"
  "product-video|claude-video-skill|claude|Claude Code plugin: product or game to a QA-gated promo video"
  "bite-watch|bite-watch|git|Gets you from \"what should I watch?\" to watching it"
  "makeup-guide|Claude-makeup-skill|git|Interview first, then researched makeup recommendations"
)

DRY_RUN=0
WITH_BROWSER=0
LIST=0
ONLY=()
SKIP=()

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; }

field() { printf '%s' "$1" | cut -d'|' -f"$2"; }

known() {
  local row
  for row in "${SKILLS[@]}"; do
    [[ "$(field "${row}" 1)" == "$1" ]] && return 0
  done
  return 1
}

add_names() { # add_names ARRAY_NAME "a,b c"
  local -n target="$1"
  local name
  for name in ${2//,/ }; do
    if ! known "${name}"; then
      echo "error: unknown skill '${name}'. Run ./install.sh --list" >&2
      exit 2
    fi
    target+=("${name}")
  done
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --list) LIST=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --with-browser) WITH_BROWSER=1 ;;
    --skip)
      [[ $# -ge 2 ]] || { echo "error: --skip needs a skill name" >&2; exit 2; }
      add_names SKIP "$2"; shift ;;
    --skip=*) add_names SKIP "${1#--skip=}" ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "error: unknown option $1" >&2; usage >&2; exit 2 ;;
    *) add_names ONLY "$1" ;;
  esac
  shift
done

in_list() { # in_list NEEDLE ITEMS...
  local needle="$1" item
  shift
  for item in "$@"; do [[ "${item}" == "${needle}" ]] && return 0; done
  return 1
}

missing_commands() {
  local cmd out=()
  for cmd in $1; do
    command -v "${cmd}" >/dev/null 2>&1 || out+=("${cmd}")
  done
  # Copycat needs Node 20 or newer.
  if [[ " $1 " == *" node "* ]] && command -v node >/dev/null 2>&1; then
    local major
    major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0)"
    [[ "${major}" -ge 20 ]] || out+=("node>=20")
  fi
  printf '%s' "${out[*]:-}"
}

if [[ "${LIST}" -eq 1 ]]; then
  printf '%-15s %-22s %s\n' "SKILL" "NEEDS" "WHAT IT DOES"
  for row in "${SKILLS[@]}"; do
    need="$(field "${row}" 3)"
    miss="$(missing_commands "${need}")"
    [[ -n "${miss}" ]] && need="${need}  (missing: ${miss})"
    printf '%-15s %-22s %s\n' "$(field "${row}" 1)" "${need}" "$(field "${row}" 4)"
  done
  exit 0
fi

# ---------------------------------------------------------------- per-skill installers
# Each runs inside its repository checkout. Output goes to logs/<skill>.log.

plain_skill() { # a repository that is just a SKILL.md
  local name="$1" dest="${HOME}/.agents/skills/$1" link="${HOME}/.claude/skills/$1"
  mkdir -p "${dest}" "${HOME}/.claude/skills"
  cp SKILL.md "${dest}/SKILL.md"
  if [[ -d "${link}" && ! -L "${link}" ]]; then
    cp SKILL.md "${link}/SKILL.md"       # a real folder is already there: refresh it in place
  else
    ln -sfn "${dest}" "${link}"
  fi
}

install_nummode() { ./install.sh all; }
install_deep-research() { ./install.sh all; }
install_copycat() {
  npm install --no-audit --no-fund || return 1
  if [[ "${WITH_BROWSER}" -eq 1 ]]; then
    node scripts/install.mjs --all --global --with-browser
  else
    node scripts/install.mjs --all --global
  fi
}
install_terminal-linux() {
  uv tool install --force . || return 1
  local bin
  bin="$(command -v terminal-linux || echo "${HOME}/.local/bin/terminal-linux")"
  "${bin}" plugins install --all
}
install_devops() { python3 installers/install.py --all --global --update || python3 installers/install.py --all --global; }
install_quranflow() { ./install.sh; }
install_product-video() {
  claude plugin marketplace add byte4day/claude-video-skill || true   # already added is fine
  claude plugin install product-video@product-video
}
install_bite-watch() { plain_skill bite-watch; }
install_makeup-guide() { plain_skill makeup-guide; }

# ---------------------------------------------------------------- run

fetch_repo() { # fetch_repo REPO -> 0 when the checkout is ready
  local repo="$1" dir="${REPOS_DIR}/$1"
  if [[ -d "${dir}/.git" ]]; then
    if [[ -n "$(git -C "${dir}" status --porcelain 2>/dev/null)" ]]; then
      echo "local changes in ${dir}: not pulling, installing what is there"
      return 0
    fi
    git -C "${dir}" pull --ff-only --quiet || echo "could not pull ${repo}: installing the checked-out version"
    return 0
  fi
  mkdir -p "${REPOS_DIR}"
  git clone --quiet "${REPO_BASE}/${repo}" "${dir}"
}

mkdir -p "${LOG_DIR}"
ok=() skipped=() failed=()

for row in "${SKILLS[@]}"; do
  name="$(field "${row}" 1)"
  repo="$(field "${row}" 2)"
  need="$(field "${row}" 3)"
  if [[ "${#ONLY[@]}" -gt 0 ]] && ! in_list "${name}" "${ONLY[@]}"; then continue; fi
  if [[ "${#SKIP[@]}" -gt 0 ]] && in_list "${name}" "${SKIP[@]}"; then
    skipped+=("${name} (--skip)")
    continue
  fi
  miss="$(missing_commands "${need}")"
  if [[ -n "${miss}" ]]; then
    echo "skip  ${name}: missing ${miss}"
    skipped+=("${name} (missing: ${miss})")
    continue
  fi
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    if [[ " ${need} " == *" git "* ]]; then
      echo "would install ${name}: clone or pull ${REPO_BASE}/${repo}, then run its installer"
    else
      echo "would install ${name}: run its installer"
    fi
    ok+=("${name}")
    continue
  fi
  log="${LOG_DIR}/${name}.log"
  printf 'install %-15s ' "${name}"
  (
    set -e
    if [[ " ${need} " == *" git "* ]]; then
      fetch_repo "${repo}"
      cd "${REPOS_DIR}/${repo}"
    fi
    "install_${name}"
  ) >"${log}" 2>&1
  code=$?
  if [[ "${code}" -eq 0 ]]; then
    echo "ok"
    ok+=("${name}")
  else
    echo "FAILED (exit ${code})"
    echo "        $(grep -v '^[[:space:]]*$' "${log}" | tail -n 1)"
    echo "        full log: ${log}"
    failed+=("${name}")
  fi
done

echo
verb="installed"
[[ "${DRY_RUN}" -eq 1 ]] && verb="would install"
echo "${verb}: ${#ok[@]}   skipped: ${#skipped[@]}   failed: ${#failed[@]}"
for s in "${skipped[@]:-}"; do [[ -n "${s}" ]] && echo "  skipped  ${s}"; done
for s in "${failed[@]:-}"; do [[ -n "${s}" ]] && echo "  failed   ${s}  (${LOG_DIR}/${s}.log)"; done
if [[ "${DRY_RUN}" -eq 0 && "${#ok[@]}" -gt 0 ]]; then
  echo "Restart your agent (Claude Code, Cursor, Codex) so it loads the new skills."
fi
[[ "${#failed[@]}" -eq 0 ]]
