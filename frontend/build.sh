#!/usr/bin/env bash
set -euo pipefail

FRONTEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$FRONTEND_DIR/.." && pwd)"
cd "$FRONTEND_DIR"

PROJECT_PATH="${PROJECT_PATH:-VCA.xcodeproj}"
WORKSPACE_PATH="${WORKSPACE_PATH:-}"
SCHEME="${SCHEME:-VCA}"
CONFIGURATION="${CONFIGURATION:-Debug}"
IOS_VERSION="${IOS_VERSION:-latest}"
IPADOS_VERSION="${IPADOS_VERSION:-$IOS_VERSION}"
IPHONE_DEVICE="${IPHONE_DEVICE:-iPhone 15}"
IPAD_DEVICE="${IPAD_DEVICE:-iPad (10th generation)}"
PLATFORM_MODE="${PLATFORM_MODE:-both}" # iphone, ipad, both
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$REPO_ROOT/build/frontend/xcode-derived-data}"
SDK="${SDK:-iphonesimulator}"
RUN_TESTS="${RUN_TESTS:-auto}" # auto, true, false
RUN_ANALYZE="${RUN_ANALYZE:-true}" # true, false
RUN_SWIFT_FORMAT="${RUN_SWIFT_FORMAT:-true}" # true, false
VCA_API_BASE_URL="${VCA_API_BASE_URL:-${API_BASE_URL:-}}"

usage() {
  cat <<USAGE
Usage: env [SCHEME=VCA] [PROJECT_PATH=VCA.xcodeproj|WORKSPACE_PATH=...] [PLATFORM_MODE=iphone|ipad|both] [RUN_SWIFT_FORMAT=true|false] [RUN_ANALYZE=true|false] [RUN_TESTS=auto|true|false] ./build.sh

Defaults:
  CONFIGURATION=$CONFIGURATION
  IOS_VERSION=$IOS_VERSION
  IPADOS_VERSION=$IPADOS_VERSION
  IPHONE_DEVICE=$IPHONE_DEVICE
  IPAD_DEVICE=$IPAD_DEVICE

This script runs Xcode analyze, build, and tests on explicit simulator destinations.
USAGE
}

fail() {
  printf 'build.sh: %s\n' "$*" >&2
  exit 1
}

require_xcode() {
  command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is required. Install Xcode and select it with xcode-select."
  command -v xcrun >/dev/null 2>&1 || fail "xcrun is required. Install Xcode command line tools."
}

validate_project() {
  if [ -n "$WORKSPACE_PATH" ]; then
    [ -d "$WORKSPACE_PATH" ] || fail "WORKSPACE_PATH '$WORKSPACE_PATH' does not exist. Set WORKSPACE_PATH to the .xcworkspace."
    return
  fi

  [ -d "$PROJECT_PATH" ] || fail "PROJECT_PATH '$PROJECT_PATH' does not exist. Set PROJECT_PATH to the frontend app .xcodeproj."
  [ -f "$PROJECT_PATH/project.pbxproj" ] || fail "PROJECT_PATH '$PROJECT_PATH' is missing project.pbxproj. Create/open the Xcode project, or set PROJECT_PATH/WORKSPACE_PATH to a valid frontend app project."
}

validate_runtime() {
  local version="$1"
  xcrun simctl list runtimes available | grep -F "iOS $version" >/dev/null 2>&1 || fail "iOS Simulator runtime $version is not installed. Install it in Xcode Settings > Platforms, or override IOS_VERSION/IPADOS_VERSION."
}

latest_ios_version() {
  xcrun simctl list runtimes available | sed -n 's/^iOS \([0-9][0-9.]*\) .*/\1/p' | tail -n 1
}

resolve_ios_version() {
  local version="$1"
  if [ "$version" = "latest" ]; then
    latest_ios_version
  else
    printf '%s\n' "$version"
  fi
}

runtime_id() {
  # Look up the SimRuntime identifier for the iOS marketing version (e.g. "26.4").
  # The build version embedded in the identifier may include an extra component
  # (e.g. iOS-26-4-1), so we resolve it from the runtime listing rather than
  # constructing the ID from the marketing version.
  local version="$1"
  local id
  id="$(xcrun simctl list runtimes available 2>/dev/null \
    | sed -n "s/^iOS ${version//./\\.} .*[[:space:]]\\(com\\.apple\\.CoreSimulator\\.SimRuntime\\.iOS-[0-9-]*\\)[[:space:]]*$/\\1/p" \
    | head -n 1)"
  [ -n "$id" ] || fail "iOS Simulator runtime $version is not installed. Install it in Xcode Settings > Platforms, or override IOS_VERSION/IPADOS_VERSION."
  printf '%s\n' "$id"
}

simulator_udid() {
  local device="$1"
  local version="$2"
  xcrun simctl list devices available "iOS $version" 2>/dev/null | grep -F "    $device (" | sed -n '1s/.*(\([0-9A-Fa-f-][0-9A-Fa-f-]*\)).*/\1/p' || true
}

ensure_simulator() {
  # Returns the UDID of an available simulator for the given device/version,
  # creating one if necessary. Status messages are written to stderr so the
  # UDID can be captured from stdout by the caller.
  local device="$1"
  local version="$2"
  local runtime
  local udid

  runtime="$(runtime_id "$version")"
  udid="$(simulator_udid "$device" "$version")"

  if [ -z "$udid" ]; then
    printf '==> Creating simulator %s on iOS %s\n' "$device" "$version" >&2
    udid="$(xcrun simctl create "$device" "$device" "$runtime")" \
      || fail "Could not create simulator '$device' for runtime '$runtime'. Override IPHONE_DEVICE/IPAD_DEVICE with an installed simulator device type."
  fi

  [ -n "$udid" ] || fail "Could not resolve UDID for simulator '$device' on iOS $version."
  printf '%s\n' "$udid"
}

xcode_container_args() {
  if [ -n "$WORKSPACE_PATH" ]; then
    printf '%s\n' -workspace "$WORKSPACE_PATH"
  else
    printf '%s\n' -project "$PROJECT_PATH"
  fi
}

scheme_has_testables() {
  local scheme_path=""

  if [ -n "$WORKSPACE_PATH" ]; then
    scheme_path="$WORKSPACE_PATH/xcshareddata/xcschemes/$SCHEME.xcscheme"
  else
    scheme_path="$PROJECT_PATH/xcshareddata/xcschemes/$SCHEME.xcscheme"
  fi

  [ -f "$scheme_path" ] && grep -F "<TestableReference" "$scheme_path" >/dev/null 2>&1
}

should_run_tests() {
  case "$RUN_TESTS" in
    true|1|yes) return 0 ;;
    false|0|no) return 1 ;;
    auto) scheme_has_testables ;;
    *) fail "Unknown RUN_TESTS '$RUN_TESTS'. Use auto, true, or false." ;;
  esac
}

should_run_analyze() {
  case "$RUN_ANALYZE" in
    true|1|yes) return 0 ;;
    false|0|no) return 1 ;;
    *) fail "Unknown RUN_ANALYZE '$RUN_ANALYZE'. Use true or false." ;;
  esac
}

should_run_swift_format() {
  case "$RUN_SWIFT_FORMAT" in
    true|1|yes) return 0 ;;
    false|0|no) return 1 ;;
    *) fail "Unknown RUN_SWIFT_FORMAT '$RUN_SWIFT_FORMAT'. Use true or false." ;;
  esac
}

lint_swift_format() {
  command -v xcrun >/dev/null 2>&1 || fail "xcrun is required. Install Xcode command line tools."
  xcrun --find swift-format >/dev/null 2>&1 || fail "swift-format is required for Swift style lint. Install a recent Xcode toolchain or set RUN_SWIFT_FORMAT_LINT=false."

  printf '\n==> Linting Swift style\n'
  xcrun swift-format lint \
    --configuration "$REPO_ROOT/.swift-format" \
    --recursive \
    --parallel \
    --strict \
    "$FRONTEND_DIR/Sources" \
    "$FRONTEND_DIR/Tests"
}

run_xcodebuild() {
  local action="$1"
  local device="$2"
  local os_version="$3"
  local udid="$4"
  # Use the simulator UDID rather than name+OS to avoid mismatches between the
  # marketing version reported by simctl (e.g. "26.4") and the build version
  # used by xcodebuild's destination matcher (e.g. "26.4.1").
  local destination="platform=iOS Simulator,id=$udid"

  printf '\n==> %s %s for %s on %s %s\n' "$action" "$SCHEME" "$CONFIGURATION" "$device" "$os_version"
  xcodebuild \
    $(xcode_container_args) \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    VCA_API_BASE_URL="$VCA_API_BASE_URL" \
    "$action"
}

run_for_platform() {
  local kind="$1"
  case "$kind" in
    iphone)
      local os_version udid
      os_version="$(resolve_ios_version "$IOS_VERSION")"
      validate_runtime "$os_version"
      udid="$(ensure_simulator "$IPHONE_DEVICE" "$os_version")"
      if should_run_analyze; then
        run_xcodebuild analyze "$IPHONE_DEVICE" "$os_version" "$udid"
      fi
      run_xcodebuild build "$IPHONE_DEVICE" "$os_version" "$udid"
      if should_run_tests; then
        run_xcodebuild test "$IPHONE_DEVICE" "$os_version" "$udid"
      else
        printf '\n==> Skipping tests for %s: no test target configured (set RUN_TESTS=true to require tests)\n' "$SCHEME"
      fi
      ;;
    ipad)
      local os_version udid
      os_version="$(resolve_ios_version "$IPADOS_VERSION")"
      validate_runtime "$os_version"
      udid="$(ensure_simulator "$IPAD_DEVICE" "$os_version")"
      if should_run_analyze; then
        run_xcodebuild analyze "$IPAD_DEVICE" "$os_version" "$udid"
      fi
      run_xcodebuild build "$IPAD_DEVICE" "$os_version" "$udid"
      if should_run_tests; then
        run_xcodebuild test "$IPAD_DEVICE" "$os_version" "$udid"
      else
        printf '\n==> Skipping tests for %s: no test target configured (set RUN_TESTS=true to require tests)\n' "$SCHEME"
      fi
      ;;
    *) fail "Unknown platform '$kind'. Use PLATFORM_MODE=iphone, ipad, or both." ;;
  esac
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

require_xcode
validate_project
if should_run_swift_format; then
  lint_swift_format
fi

case "$PLATFORM_MODE" in
  iphone|ipad) run_for_platform "$PLATFORM_MODE" ;;
  both) run_for_platform iphone; run_for_platform ipad ;;
  *) fail "Unknown PLATFORM_MODE '$PLATFORM_MODE'. Use iphone, ipad, or both." ;;
esac
