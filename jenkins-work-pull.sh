#!/usr/bin/env bash
# jenkins-work-pull.sh - refresh every repo in the jenkins-git workspace.
#
# Invoked by the jwp shell function (modules/home/shell.nix), which also cds
# into jenkins-setup afterwards. Runnable on its own from anywhere.
#
# Pulls over SSH regardless of how "origin" is configured. Every remote in that
# workspace is HTTPS and this machine has no git credential helper, so a plain
# "git pull" prompts for a username on each repo. The SSH URL is derived from
# origin at runtime; your configured remotes are never modified.
#
# Fast-forward only: this never creates a merge commit and never rebases. A
# diverged repo is reported and left alone.
#
# Override the workspace location with JENKINS_WORK_ROOT.

set -uo pipefail

ROOT="${JENKINS_WORK_ROOT:-$HOME/Documents/cargo-partner/jenkins-git}"
REPOS=(ansible ansiblejobs jenkins-setup terraform terraformjobs tfstate)
VAULT="obsidian-vault/work"

bold=$'\033[1m'; red=$'\033[31m'; grn=$'\033[32m'; ylw=$'\033[33m'; dim=$'\033[2m'; off=$'\033[0m'
[ -t 1 ] || { bold=""; red=""; grn=""; ylw=""; dim=""; off=""; }

failed=0; updated=0; skipped=0

[ -d "$ROOT" ] || { printf '%sworkspace not found: %s%s\n' "$red" "$ROOT" "$off"; exit 1; }

report() { printf '  %-20s %-8s %s\n' "$1" "$2" "$3"; }

pull_one() {
  local dir="$1" use_origin="${2:-}"
  local path="$ROOT/$dir"

  if [ ! -d "$path/.git" ]; then
    report "$dir" "-" "${ylw}not a git repo, skipped${off}"; skipped=$((skipped+1)); return
  fi

  local branch
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [ "$branch" = "HEAD" ]; then
    report "$dir" "-" "${ylw}detached HEAD, skipped${off}"; skipped=$((skipped+1)); return
  fi

  # Derive an SSH URL from origin, unless told to use origin as-is (the vault's
  # origin already embeds credentials, so it authenticates over HTTPS).
  local remote
  remote="$(git -C "$path" remote get-url origin 2>/dev/null)"
  [ -n "$remote" ] || { report "$dir" "$branch" "${red}no origin${off}"; failed=$((failed+1)); return; }
  if [ -z "$use_origin" ]; then
    remote="$(printf '%s' "$remote" | sed -E 's#^https://([^/]+)/#git@\1:#')"
  fi

  if ! git -C "$path" fetch -q "$remote" "$branch" 2>/dev/null; then
    report "$dir" "$branch" "${red}fetch failed${off}"; failed=$((failed+1)); return
  fi

  local counts ahead behind dirty note
  counts="$(git -C "$path" rev-list --left-right --count HEAD...FETCH_HEAD 2>/dev/null)"
  ahead="$(printf '%s' "$counts" | cut -f1)"; behind="$(printf '%s' "$counts" | cut -f2)"
  dirty="$(git -C "$path" status --porcelain | wc -l | tr -d ' ')"
  note=""; [ "$dirty" != "0" ] && note=" ${dim}(${dirty} uncommitted)${off}"

  if [ "$behind" = "0" ]; then
    if [ "$ahead" = "0" ]; then
      report "$dir" "$branch" "${grn}up to date${off}$note"
    else
      report "$dir" "$branch" "${ylw}${ahead} ahead, not pushed${off}$note"
    fi
    return
  fi

  if [ "$ahead" != "0" ]; then
    report "$dir" "$branch" "${red}diverged: ${ahead} ahead / ${behind} behind${off}$note"
    failed=$((failed+1)); return
  fi

  if git -C "$path" merge --ff-only FETCH_HEAD >/dev/null 2>&1; then
    git -C "$path" fetch -q "$remote" "+refs/heads/*:refs/remotes/origin/*" 2>/dev/null
    report "$dir" "$branch" "${grn}pulled ${behind} commit(s)${off}$note"
    updated=$((updated+1))
  else
    report "$dir" "$branch" "${red}fast-forward failed${off}$note"; failed=$((failed+1))
  fi
}

printf '%sjenkins workspace%s  %s\n' "$bold" "$off" "$ROOT"
for r in "${REPOS[@]}"; do pull_one "$r"; done
pull_one "$VAULT" origin

printf '\n  %s%d updated, %d failed, %d skipped%s\n' "$bold" "$updated" "$failed" "$skipped" "$off"
[ "$failed" -eq 0 ]
