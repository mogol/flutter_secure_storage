#!/usr/bin/env bash
# Builds the example app from a sequence of git refs (tags, branches, commits)
# and installs them on an attached Android device in order, upgrading in
# place (adb install -r) so each stage's data has to survive being read by
# the next stage's code - exactly the "skip a release, land on a version
# that should recover the key" scenario reported in issue #1259 and #1237.
#
# Usage:
#   tool/migration_test/run.sh <ref> [<ref> ...]
#
# Example - reproduce the reported bug (unfixed releases):
#   tool/migration_test/run.sh v9.2.4 07ad4f4 7ee0d67
#
# Example - verify our fixes:
#   tool/migration_test/run.sh v9.2.4 \
#     fix/legacy-namespace-key-recovery-biometric \
#     fix/biometric-namespace-recovery-v11
#
# Requires: a connected/authorized device or emulator (`adb devices`), a
# working `flutter` on PATH, and JDK 17 (set JAVA_HOME before running if
# your default `java` isn't 17 - the example app's Android build needs it
# across every version tested here).
#
# Env vars:
#   MIGTEST_WORKTREES  where per-ref git worktrees are created (default:
#                       $TMPDIR/fss-migtest-worktrees, reused between runs so
#                       repeat invocations don't rebuild from scratch every
#                       time; delete it to force a clean rebuild)
#   ANDROID_SERIAL      device to target, if more than one is attached
#   MIGTEST_HARNESS_SUFFIX  set to "_nsonly" to run only the namespace-switch
#                       profile, isolated from the 'default' profile. Useful
#                       because v9.x shares one global (non-namespaced) RSA
#                       key across every FlutterSecureStorage instance in the
#                       app; if a 'default' profile's migration completes
#                       first it deletes that shared key, which can starve a
#                       still-migrating namespaced profile - a real but
#                       separate bug from the namespace-switch path itself.

set -euo pipefail

APP_ID="com.it_nomads.fluttersecurestorageexample"
ACTIVITY="$APP_ID/.MainActivity"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HARNESS_DIR="$REPO_ROOT/tool/migration_test"
WORKTREES="${MIGTEST_WORKTREES:-${TMPDIR:-/tmp}/fss-migtest-worktrees}"
RESULTS_DIR="$WORKTREES/results"

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <ref> [<ref> ...]" >&2
  exit 1
fi

mkdir -p "$WORKTREES" "$RESULTS_DIR"

log() { echo "[migtest] $*" >&2; }

sanitize() { echo "$1" | tr '/:' '__'; }

# True if the given ref's AndroidOptions has storageNamespace (v10.1+/v11.x),
# false if it predates it (v9.x, v10.0.x) - decides which harness to overlay.
ref_has_storage_namespace() {
  git -C "$REPO_ROOT" show "$1:flutter_secure_storage/lib/options/android_options.dart" 2>/dev/null \
    | grep -q "this.storageNamespace"
}

worktree_for_ref() {
  local ref="$1"
  local dir="$WORKTREES/$(sanitize "$ref")"
  if [ ! -d "$dir" ]; then
    log "Creating worktree for $ref at $dir"
    git -C "$REPO_ROOT" worktree add --detach "$dir" "$ref" >&2
  else
    log "Reusing existing worktree for $ref at $dir (resetting to $ref)"
    git -C "$dir" checkout --detach "$ref" >&2
    git -C "$dir" reset --hard "$ref" >&2
    git -C "$dir" clean -fdx >&2
  fi
  echo "$dir"
}

build_stage() {
  local ref="$1"
  local worktree
  worktree="$(worktree_for_ref "$ref")"
  local example_dir="$worktree/flutter_secure_storage/example"

  local suffix="${MIGTEST_HARNESS_SUFFIX:-}"
  local harness="$HARNESS_DIR/harness_v10plus${suffix}.dart"
  if ! ref_has_storage_namespace "$ref"; then
    harness="$HARNESS_DIR/harness_v9${suffix}.dart"
  fi
  log "Using harness $(basename "$harness") for $ref"
  cp "$harness" "$example_dir/lib/main.dart"

  # Old refs' own example/android build tooling (Gradle/AGP/Kotlin versions)
  # often predates what the currently-installed Flutter tool requires. Pin
  # known-good versions here instead - this only touches the throwaway
  # example app shell, never flutter_secure_storage/android (the plugin code
  # actually under test), so it doesn't affect what's being validated.
  cp "$HARNESS_DIR/templates/settings.gradle.kts" "$example_dir/android/settings.gradle.kts"
  cp "$HARNESS_DIR/templates/gradle-wrapper.properties" "$example_dir/android/gradle/wrapper/gradle-wrapper.properties"
  cp "$HARNESS_DIR/templates/app-build.gradle.kts" "$example_dir/android/app/build.gradle.kts"

  ( cd "$example_dir" && flutter pub get && flutter build apk --debug --target-platform android-arm64 ) >&2

  local apk="$example_dir/build/app/outputs/flutter-apk/app-debug.apk"
  if [ ! -f "$apk" ]; then
    echo "Build did not produce $apk" >&2
    exit 1
  fi
  echo "$apk"
}

install_stage() {
  local apk="$1"
  local first="$2"
  if [ "$first" = "true" ]; then
    log "Fresh install: uninstalling any existing $APP_ID first"
    adb uninstall "$APP_ID" >/dev/null 2>&1 || true
    adb install "$apk" >&2
  else
    log "Upgrading in place (adb install -r), preserving app data"
    adb install -r "$apk" >&2
  fi
}

run_and_collect() {
  local ref="$1"
  local out="$RESULTS_DIR/$(sanitize "$ref").log"
  adb logcat -c
  adb shell am start -n "$ACTIVITY" >&2
  log "Waiting for harness to finish..."
  local waited=0
  local done_line=""
  while [ "$waited" -lt 30 ]; do
    done_line="$(adb logcat -d | grep 'MIGTEST DONE' || true)"
    if [ -n "$done_line" ]; then
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  adb logcat -d | grep 'MIGTEST ' > "$out" || true
  if [ -z "$done_line" ]; then
    log "TIMED OUT waiting for harness to finish (see $out)"
  fi
  cat "$out" >&2
  echo "$out"
}

echo "=================================================================="
echo "Migration test sequence: $*"
echo "Device: $(adb devices | sed -n '2p')"
echo "=================================================================="

stage_num=0
all_results=()
for ref in "$@"; do
  stage_num=$((stage_num + 1))
  echo ""
  echo "------------------------------------------------------------------"
  echo "Stage $stage_num: $ref"
  echo "------------------------------------------------------------------"
  apk="$(build_stage "$ref")"
  if [ "$stage_num" -eq 1 ]; then
    install_stage "$apk" "true"
  else
    install_stage "$apk" "false"
  fi
  result_file="$(run_and_collect "$ref")"
  all_results+=("$result_file")
done

echo ""
echo "=================================================================="
echo "Summary"
echo "=================================================================="
fail_count=0
for f in "${all_results[@]}"; do
  stage_fail="$(grep -c 'result=FAIL\|result=ERROR' "$f" || true)"
  echo "$(basename "$f"): $stage_fail failure(s)"
  if grep -q 'result=FAIL\|result=ERROR' "$f"; then
    grep 'result=FAIL\|result=ERROR' "$f" | sed 's/^/  /'
    fail_count=$((fail_count + 1))
  fi
done

if [ "$fail_count" -eq 0 ]; then
  echo "ALL STAGES PASSED"
  exit 0
else
  echo "FAILURES DETECTED in $fail_count stage(s)"
  exit 1
fi
