#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 1 ]] || { echo 'usage: orchestration-run.sh <exact manifest raw URL>' >&2; exit 64; }
MANIFEST_URL="$1"
[[ "$MANIFEST_URL" =~ ^https://raw\.githubusercontent\.com/jgoeppert/orchestration-downloads/[0-9a-f]{40}/runs/[A-Za-z0-9._-]+\.txt$ ]] || { echo 'TRANSPORT FAIL: manifest URL must be exact-SHA pinned in jgoeppert/orchestration-downloads' >&2; exit 65; }
for cmd in wget git bash mktemp; do command -v "$cmd" >/dev/null 2>&1 || { echo "TRANSPORT FAIL: missing command $cmd" >&2; exit 66; }; done
TMP="$(mktemp -d -t orchestration-transport.XXXXXX)"; trap 'rm -rf -- "$TMP" >/dev/null 2>&1 || true' EXIT
MANIFEST="$TMP/manifest.txt"; REPO="$TMP/repo"; HELPER="$TMP/helper.sh"
wget -qO "$MANIFEST" "$MANIFEST_URL"

declare -A V=() SEEN=()
while IFS='=' read -r key value extra || [[ -n "${key:-}" ]]; do
  [[ -z "${key:-}" || "$key" == \#* ]] && continue
  [[ -z "${extra:-}" ]] || { echo 'TRANSPORT FAIL: malformed manifest line' >&2; exit 67; }
  case "$key" in VERSION|RUN_ID|REPOSITORY|PREPARED_BRANCH|PREPARED_SHA|HELPER_PATH) ;; *) echo "TRANSPORT FAIL: unknown manifest key $key" >&2; exit 67;; esac
  [[ -z "${SEEN[$key]:-}" ]] || { echo "TRANSPORT FAIL: duplicate manifest key $key" >&2; exit 67; }
  SEEN[$key]=1; V[$key]="$value"
done < "$MANIFEST"
for key in VERSION RUN_ID REPOSITORY PREPARED_BRANCH PREPARED_SHA HELPER_PATH; do [[ -n "${V[$key]:-}" ]] || { echo "TRANSPORT FAIL: missing manifest key $key" >&2; exit 67; }; done
[[ "${V[VERSION]}" == '1' ]] || { echo 'TRANSPORT FAIL: unsupported manifest version' >&2; exit 67; }
[[ "${V[RUN_ID]}" =~ ^[A-Za-z0-9._+-]+$ ]] || { echo 'TRANSPORT FAIL: invalid Run-ID' >&2; exit 67; }
[[ "${V[REPOSITORY]}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo 'TRANSPORT FAIL: invalid repository' >&2; exit 67; }
[[ "${V[PREPARED_BRANCH]}" =~ ^[A-Za-z0-9._/-]+$ && "${V[PREPARED_BRANCH]}" != *'..'* ]] || { echo 'TRANSPORT FAIL: invalid prepared branch' >&2; exit 67; }
[[ "${V[PREPARED_SHA]}" =~ ^[0-9a-f]{40}$ ]] || { echo 'TRANSPORT FAIL: invalid prepared SHA' >&2; exit 67; }
[[ "${V[HELPER_PATH]}" =~ ^\.orchestration/btrap/[A-Za-z0-9._/-]+\.sh$ && "${V[HELPER_PATH]}" != *'..'* ]] || { echo 'TRANSPORT FAIL: invalid helper path' >&2; exit 67; }
REMOTE_URL="git@github.com:${V[REPOSITORY]}.git"
git init -q "$REPO"; git -C "$REPO" remote add github "$REMOTE_URL"
git -C "$REPO" fetch --no-tags github "+refs/heads/${V[PREPARED_BRANCH]}:refs/remotes/github/${V[PREPARED_BRANCH]}" >/dev/null 2>&1
GOT="$(git -C "$REPO" rev-parse "refs/remotes/github/${V[PREPARED_BRANCH]}^{commit}")"
[[ "$GOT" == "${V[PREPARED_SHA]}" ]] || { echo 'TRANSPORT FAIL: fetched prepared SHA mismatch' >&2; exit 68; }
LIVE="$(git ls-remote --heads "$REMOTE_URL" "refs/heads/${V[PREPARED_BRANCH]}" | awk 'NR==1{print $1}')"
[[ "$LIVE" == "${V[PREPARED_SHA]}" ]] || { echo 'TRANSPORT FAIL: live prepared ref moved' >&2; exit 69; }
git -C "$REPO" show "${V[PREPARED_SHA]}:${V[HELPER_PATH]}" > "$HELPER"
[[ -s "$HELPER" ]] || { echo 'TRANSPORT FAIL: private helper empty' >&2; exit 70; }
chmod 700 "$HELPER"
echo "transport_run_id=${V[RUN_ID]}"
echo "transport_repository=${V[REPOSITORY]}"
echo "transport_prepared_sha=${V[PREPARED_SHA]}"
set +e
bash "$HELPER" "${V[PREPARED_SHA]}"
rc=$?
set -e
exit "$rc"
