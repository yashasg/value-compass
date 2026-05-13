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
RUN_SWIFT_FORMAT_LINT="${RUN_SWIFT_FORMAT_LINT:-true}" # true, false
VCA_API_BASE_URL="${VCA_API_BASE_URL:-${API_BASE_URL:-}}"

usage() {
  cat <<USAGE
Usage: env [SCHEME=VCA] [PROJECT_PATH=VCA.xcodeproj|WORKSPACE_PATH=...] [PLATFORM_MODE=iphone|ipad|both] [RUN_ANALYZE=true|false] [RUN_SWIFT_FORMAT_LINT=true|false] [RUN_TESTS=auto|true|false] ./build.sh

Defaults:
  CONFIGURATION=$CONFIGURATION
  IOS_VERSION=$IOS_VERSION
  IPADOS_VERSION=$IPADOS_VERSION
  IPHONE_DEVICE=$IPHONE_DEVICE
  IPAD_DEVICE=$IPAD_DEVICE

This script runs Swift format lint, Xcode analyze, build, and tests on explicit simulator destinations.
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

require_swift_format() {
  xcrun --find swift-format >/dev/null 2>&1 || fail "swift-format is required. Install an Xcode toolchain that includes swift-format."
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
  local version="$1"
  local id="com.apple.CoreSimulator.SimRuntime.iOS-${version//./-}"
  xcrun simctl list runtimes available | grep -F "$id" >/dev/null 2>&1 || fail "iOS Simulator runtime $version is not installed. Install it in Xcode Settings > Platforms, or override IOS_VERSION/IPADOS_VERSION."
  printf '%s\n' "$id"
}

simulator_udid() {
  local device="$1"
  local version="$2"
  xcrun simctl list devices available "iOS $version" 2>/dev/null | grep -F "    $device (" | sed -n '1s/.*(\([0-9A-Fa-f-][0-9A-Fa-f-]*\)).*/\1/p' || true
}

ensure_simulator() {
  local device="$1"
  local version="$2"
  local runtime
  local udid

  runtime="$(runtime_id "$version")"
  udid="$(simulator_udid "$device" "$version")"

  if [ -z "$udid" ]; then
    printf '==> Creating simulator %s on iOS %s\n' "$device" "$version"
    xcrun simctl create "$device" "$device" "$runtime" >/dev/null || fail "Could not create simulator '$device' for runtime '$runtime'. Override IPHONE_DEVICE/IPAD_DEVICE with an installed simulator device type."
  fi
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

should_run_swift_format_lint() {
  case "$RUN_SWIFT_FORMAT_LINT" in
    true|1|yes) return 0 ;;
    false|0|no) return 1 ;;
    *) fail "Unknown RUN_SWIFT_FORMAT_LINT '$RUN_SWIFT_FORMAT_LINT'. Use true or false." ;;
  esac
}

run_swift_format_lint() {
  printf '\n==> Linting Swift formatting\n'
  xcrun swift-format lint --configuration "$REPO_ROOT/.swift-format" --recursive --parallel Sources Tests
}

run_xcodebuild() {
  local action="$1"
  local device="$2"
  local os_version="$3"
  local destination="platform=iOS Simulator,name=$device,OS=$os_version"

  printf '\n==> %s %s for %s on %s %s\n' "$action" "$SCHEME" "$CONFIGURATION" "$device" "$os_version"
  xcodebuild \
    $(xcode_container_args) \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    GCC_TREAT_WARNINGS_AS_ERRORS=YES \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
    VCA_API_BASE_URL="$VCA_API_BASE_URL" \
    "$action"
}

run_for_platform() {
  local kind="$1"
  case "$kind" in
    iphone)
      local os_version
      os_version="$(resolve_ios_version "$IOS_VERSION")"
      validate_runtime "$os_version"
      ensure_simulator "$IPHONE_DEVICE" "$os_version"
      if should_run_analyze; then
        run_xcodebuild analyze "$IPHONE_DEVICE" "$os_version"
      fi
      run_xcodebuild build "$IPHONE_DEVICE" "$os_version"
      if should_run_tests; then
        run_xcodebuild test "$IPHONE_DEVICE" "$os_version"
      else
        printf '\n==> Skipping tests for %s: no test target configured (set RUN_TESTS=true to require tests)\n' "$SCHEME"
      fi
      ;;
    ipad)
      local os_version
      os_version="$(resolve_ios_version "$IPADOS_VERSION")"
      validate_runtime "$os_version"
      ensure_simulator "$IPAD_DEVICE" "$os_version"
      if should_run_analyze; then
        run_xcodebuild analyze "$IPAD_DEVICE" "$os_version"
      fi
      run_xcodebuild build "$IPAD_DEVICE" "$os_version"
      if should_run_tests; then
        run_xcodebuild test "$IPAD_DEVICE" "$os_version"
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

if should_run_swift_format_lint; then
  require_swift_format
  run_swift_format_lint
fi

case "$PLATFORM_MODE" in
  iphone|ipad) run_for_platform "$PLATFORM_MODE" ;;
  both) run_for_platform iphone; run_for_platform ipad ;;
  *) fail "Unknown PLATFORM_MODE '$PLATFORM_MODE'. Use iphone, ipad, or both." ;;
esac
