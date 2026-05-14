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
DEVICE_KIND="${DEVICE_KIND:-iphone}" # iphone or ipad
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$REPO_ROOT/build/frontend/xcode-derived-data}"
SDK="${SDK:-iphonesimulator}"
APP_BUNDLE_ID="${APP_BUNDLE_ID:-}"
VCA_API_BASE_URL="${VCA_API_BASE_URL:-${API_BASE_URL:-}}"
SIMCTL_RETRY_ATTEMPTS="${SIMCTL_RETRY_ATTEMPTS:-3}"
SIMCTL_RETRY_DELAY_SECONDS="${SIMCTL_RETRY_DELAY_SECONDS:-2}"

usage() {
  cat <<USAGE
Usage: env [DEVICE_KIND=iphone|ipad] [SCHEME=VCA] [PROJECT_PATH=VCA.xcodeproj|WORKSPACE_PATH=...] ./run.sh

Defaults:
  CONFIGURATION=$CONFIGURATION
  IOS_VERSION=$IOS_VERSION
  IPADOS_VERSION=$IPADOS_VERSION
  IPHONE_DEVICE=$IPHONE_DEVICE
  IPAD_DEVICE=$IPAD_DEVICE

This script boots or creates the selected simulator, builds, installs, and launches the app.
Simulator install/launch commands retry transient CoreSimulator failures by default.
USAGE
}

fail() {
  printf 'run.sh: %s\n' "$*" >&2
  exit 1
}

validate_positive_integer() {
  local name="$1"
  local value="$2"

  case "$value" in
    ''|*[!0-9]*|0) fail "$name must be a positive integer." ;;
  esac
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

runtime_id() {
  local version="$1"
  local id="com.apple.CoreSimulator.SimRuntime.iOS-${version//./-}"
  xcrun simctl list runtimes available | grep -F "$id" >/dev/null 2>&1 || fail "iOS Simulator runtime $version is not installed. Install it in Xcode Settings > Platforms, or override IOS_VERSION/IPADOS_VERSION."
  printf '%s\n' "$id"
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

select_values() {
  case "$DEVICE_KIND" in
    iphone)
      DEVICE_NAME="$IPHONE_DEVICE"
      OS_VERSION="$(resolve_ios_version "$IOS_VERSION")"
      ;;
    ipad)
      DEVICE_NAME="$IPAD_DEVICE"
      OS_VERSION="$(resolve_ios_version "$IPADOS_VERSION")"
      ;;
    *) fail "Unknown DEVICE_KIND '$DEVICE_KIND'. Use iphone or ipad." ;;
  esac
}

simulator_udid() {
  local device="$1"
  local version="$2"
  xcrun simctl list devices available "iOS $version" 2>/dev/null | grep -F "    $device (" | sed -n '1s/.*(\([0-9A-Fa-f-][0-9A-Fa-f-]*\)).*/\1/p' || true
}

boot_simulator() {
  local udid="$1"
  local boot_error
  boot_error="$(mktemp "${TMPDIR:-/tmp}/vca-sim-boot.XXXXXX")"

  for attempt in 1 2 3; do
    if xcrun simctl boot "$udid" 2>"$boot_error"; then
      xcrun simctl bootstatus "$udid" -b
      rm -f "$boot_error"
      return
    fi

    if grep -F "current state: Booted" "$boot_error" >/dev/null 2>&1; then
      xcrun simctl bootstatus "$udid" -b
      rm -f "$boot_error"
      return
    fi

    if grep -F "current state: Shutting Down" "$boot_error" >/dev/null 2>&1 && [ "$attempt" -lt 3 ]; then
      sleep 5
      continue
    fi

    cat "$boot_error" >&2
    rm -f "$boot_error"
    fail "Could not boot simulator '$udid'."
  done

  rm -f "$boot_error"
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
    udid="$(xcrun simctl create "$device" "$device" "$runtime")" || fail "Could not create simulator '$device' for runtime '$runtime'. Override IPHONE_DEVICE/IPAD_DEVICE with an installed simulator device type."
  fi
  printf '==> Booting simulator %s (%s)\n' "$device" "$udid"
  boot_simulator "$udid"
  printf '%s\n' "$udid"
}

xcode_container_args() {
  if [ -n "$WORKSPACE_PATH" ]; then
    printf '%s\n' -workspace "$WORKSPACE_PATH"
  else
    printf '%s\n' -project "$PROJECT_PATH"
  fi
}

build_app() {
  local device="$1"
  local version="$2"
  local destination="platform=iOS Simulator,name=$device,OS=$version"

  printf '==> Building %s for %s %s\n' "$SCHEME" "$device" "$version"
  xcodebuild \
    $(xcode_container_args) \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -destination "$destination" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    VCA_API_BASE_URL="$VCA_API_BASE_URL" \
    build
}

built_app_path() {
  find "$DERIVED_DATA_PATH" -path "*/Build/Products/$CONFIGURATION-iphonesimulator/*.app" -type d 2>/dev/null | sort | head -n 1 || true
}

bundle_id_for_app() {
  local app_path="$1"
  if [ -n "$APP_BUNDLE_ID" ]; then
    printf '%s\n' "$APP_BUNDLE_ID"
    return
  fi

  /usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app_path/Info.plist" 2>/dev/null || fail "Could not read CFBundleIdentifier from '$app_path/Info.plist'. Set APP_BUNDLE_ID explicitly."
}

retry_simctl_command() {
  local description="$1"
  local udid="$2"
  shift 2
  local attempt=1
  local command_error
  command_error="$(mktemp "${TMPDIR:-/tmp}/vca-simctl.XXXXXX")"

  while [ "$attempt" -le "$SIMCTL_RETRY_ATTEMPTS" ]; do
    if "$@" 2>"$command_error"; then
      rm -f "$command_error"
      return
    fi

    cat "$command_error" >&2
    if [ "$attempt" -eq "$SIMCTL_RETRY_ATTEMPTS" ]; then
      rm -f "$command_error"
      fail "$description failed after $SIMCTL_RETRY_ATTEMPTS attempt(s)."
    fi

    if grep -E "current state: (Shutting Down|Shutdown)|Unable to lookup in current state|server died" "$command_error" >/dev/null 2>&1; then
      boot_simulator "$udid"
    fi

    printf '==> %s failed on attempt %s/%s; retrying in %ss\n' "$description" "$attempt" "$SIMCTL_RETRY_ATTEMPTS" "$SIMCTL_RETRY_DELAY_SECONDS"
    sleep "$SIMCTL_RETRY_DELAY_SECONDS"
    attempt=$((attempt + 1))
    : >"$command_error"
  done

  rm -f "$command_error"
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  usage
  exit 0
fi

require_xcode
validate_project
validate_positive_integer SIMCTL_RETRY_ATTEMPTS "$SIMCTL_RETRY_ATTEMPTS"
validate_positive_integer SIMCTL_RETRY_DELAY_SECONDS "$SIMCTL_RETRY_DELAY_SECONDS"
select_values
SIM_UDID="$(ensure_simulator "$DEVICE_NAME" "$OS_VERSION" | tail -n 1)"
build_app "$DEVICE_NAME" "$OS_VERSION"
APP_PATH="$(built_app_path)"
[ -n "$APP_PATH" ] || fail "No built .app found under '$DERIVED_DATA_PATH'. Check SCHEME/CONFIGURATION or set DERIVED_DATA_PATH."
BUNDLE_ID="$(bundle_id_for_app "$APP_PATH")"

printf '==> Installing %s on %s\n' "$APP_PATH" "$SIM_UDID"
retry_simctl_command "simctl install" "$SIM_UDID" xcrun simctl install "$SIM_UDID" "$APP_PATH"
printf '==> Launching %s\n' "$BUNDLE_ID"
retry_simctl_command "simctl launch" "$SIM_UDID" xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID"
