#!/bin/bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_PATH="${PROJECT_ROOT}/Muslim5.xcodeproj"
PBXPROJ_PATH="${PROJECT_PATH}/project.pbxproj"
SCHEME="Muslim 5"
CONFIGURATION="Release"
OUTPUT_ROOT="${APP_STORE_OUTPUT_DIR:-${PROJECT_ROOT}/.build/app-store}"

DRY_RUN=false
UPLOAD=true
VERSION_BUMPED=false

usage() {
  cat <<'EOF'
Build and distribute Muslim 5 to App Store Connect.

Usage:
  ./scripts/distribute-app-store.sh [--dry-run] [--no-upload]

Options:
  --dry-run    Show the next version/build without changing or building anything.
  --no-upload  Archive and export an IPA locally without uploading it.
  -h, --help   Show this help.

Authentication:
  By default, xcodebuild uses the Apple account configured in Xcode. For CI,
  provide all three environment variables below:

    ASC_API_KEY_PATH=/absolute/path/to/AuthKey_XXXXXXXXXX.p8
    ASC_API_KEY_ID=XXXXXXXXXX
    ASC_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Optional:
  APP_STORE_OUTPUT_DIR=/absolute/path/to/output
EOF
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

on_error() {
  local status=$?
  trap - ERR

  if [[ "${VERSION_BUMPED}" == true ]]; then
    echo >&2
    echo "Distribution failed after the version bump." >&2
    echo "The bumped version is intentionally kept so this build number is not reused." >&2
  fi

  exit "${status}"
}

trap on_error ERR

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --no-upload)
      UPLOAD=false
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac
  shift
done

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is not available. Install or select Xcode first."
command -v ruby >/dev/null 2>&1 || fail "ruby is required to update Xcode build settings."
[[ -f "${PBXPROJ_PATH}" ]] || fail "Xcode project not found at ${PROJECT_PATH}"

# The project stores the same version in Debug and Release. Update every
# occurrence together and fail if they ever drift apart.
VERSION_RESULT="$({ DRY_RUN="${DRY_RUN}" ruby - "${PBXPROJ_PATH}" <<'RUBY'
path = ARGV.fetch(0)
contents = File.read(path)

marketing_versions = contents.scan(/\bMARKETING_VERSION\s*=\s*([^;]+);/).flatten.map(&:strip).uniq
build_numbers = contents.scan(/\bCURRENT_PROJECT_VERSION\s*=\s*([^;]+);/).flatten.map(&:strip).uniq

abort "Expected exactly one MARKETING_VERSION value, found: #{marketing_versions.inspect}" unless marketing_versions.length == 1
abort "Expected exactly one CURRENT_PROJECT_VERSION value, found: #{build_numbers.inspect}" unless build_numbers.length == 1

current_marketing = marketing_versions.first.delete('"')
current_build = build_numbers.first.delete('"')

match = current_marketing.match(/\A(\d+)\.(\d+)\.(\d+)\z/)
abort "MARKETING_VERSION must use major.minor.patch format, found: #{current_marketing}" unless match
abort "CURRENT_PROJECT_VERSION must be an integer, found: #{current_build}" unless current_build.match?(/\A\d+\z/)

next_marketing = "#{match[1]}.#{match[2]}.#{match[3].to_i + 1}"
next_build = (current_build.to_i + 1).to_s

unless ENV.fetch('DRY_RUN') == 'true'
  updated = contents.gsub(/(\bMARKETING_VERSION\s*=\s*)[^;]+;/, "\\1#{next_marketing};")
  updated = updated.gsub(/(\bCURRENT_PROJECT_VERSION\s*=\s*)[^;]+;/, "\\1#{next_build};")

  temp_path = "#{path}.tmp.#{$$}"
  begin
    File.write(temp_path, updated)
    File.rename(temp_path, path)
  ensure
    File.delete(temp_path) if File.exist?(temp_path)
  end
end

puts [current_marketing, next_marketing, current_build, next_build].join('|')
RUBY
} 2>&1)" || fail "Could not bump versions: ${VERSION_RESULT}"

IFS='|' read -r CURRENT_MARKETING NEXT_MARKETING CURRENT_BUILD NEXT_BUILD <<<"${VERSION_RESULT}"

if [[ "${DRY_RUN}" == true ]]; then
  echo "Marketing version: ${CURRENT_MARKETING} -> ${NEXT_MARKETING}"
  echo "Build number:      ${CURRENT_BUILD} -> ${NEXT_BUILD}"
  exit 0
fi

VERSION_BUMPED=true
echo "Version bumped: ${CURRENT_MARKETING} (${CURRENT_BUILD}) -> ${NEXT_MARKETING} (${NEXT_BUILD})"

KEY_PATH="${ASC_API_KEY_PATH:-}"
KEY_ID="${ASC_API_KEY_ID:-}"
ISSUER_ID="${ASC_API_ISSUER_ID:-}"
AUTH_VALUE_COUNT=0
[[ -n "${KEY_PATH}" ]] && AUTH_VALUE_COUNT=$((AUTH_VALUE_COUNT + 1))
[[ -n "${KEY_ID}" ]] && AUTH_VALUE_COUNT=$((AUTH_VALUE_COUNT + 1))
[[ -n "${ISSUER_ID}" ]] && AUTH_VALUE_COUNT=$((AUTH_VALUE_COUNT + 1))

if [[ ${AUTH_VALUE_COUNT} -ne 0 && ${AUTH_VALUE_COUNT} -ne 3 ]]; then
  fail "Set ASC_API_KEY_PATH, ASC_API_KEY_ID, and ASC_API_ISSUER_ID together, or leave all three unset to use Xcode's account."
fi

AUTH_ARGS=()
if [[ ${AUTH_VALUE_COUNT} -eq 3 ]]; then
  [[ -f "${KEY_PATH}" ]] || fail "App Store Connect API key not found: ${KEY_PATH}"
  KEY_PATH="$(cd "$(dirname "${KEY_PATH}")" && pwd)/$(basename "${KEY_PATH}")"
  AUTH_ARGS=(
    -authenticationKeyPath "${KEY_PATH}"
    -authenticationKeyID "${KEY_ID}"
    -authenticationKeyIssuerID "${ISSUER_ID}"
  )
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BUILD_DIR="${OUTPUT_ROOT}/${NEXT_MARKETING}-${NEXT_BUILD}-${TIMESTAMP}"
ARCHIVE_PATH="${BUILD_DIR}/Muslim5.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_OPTIONS_PATH="${BUILD_DIR}/ExportOptions.plist"

mkdir -p "${BUILD_DIR}" "${EXPORT_PATH}"

echo "Archiving ${SCHEME} for generic iOS device..."
xcodebuild \
  -project "${PROJECT_PATH}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -destination "generic/platform=iOS" \
  -archivePath "${ARCHIVE_PATH}" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
  clean archive

EXPORT_DESTINATION="upload"
if [[ "${UPLOAD}" == false ]]; then
  EXPORT_DESTINATION="export"
fi

/usr/bin/plutil -create xml1 "${EXPORT_OPTIONS_PATH}"
/usr/bin/plutil -insert method -string app-store-connect "${EXPORT_OPTIONS_PATH}"
/usr/bin/plutil -insert destination -string "${EXPORT_DESTINATION}" "${EXPORT_OPTIONS_PATH}"
/usr/bin/plutil -insert signingStyle -string automatic "${EXPORT_OPTIONS_PATH}"
/usr/bin/plutil -insert manageAppVersionAndBuildNumber -bool false "${EXPORT_OPTIONS_PATH}"
/usr/bin/plutil -insert uploadSymbols -bool true "${EXPORT_OPTIONS_PATH}"

if [[ "${UPLOAD}" == true ]]; then
  echo "Uploading ${NEXT_MARKETING} (${NEXT_BUILD}) to App Store Connect..."
else
  echo "Exporting ${NEXT_MARKETING} (${NEXT_BUILD}) without uploading..."
fi

xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_PATH}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PATH}" \
  -allowProvisioningUpdates \
  "${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}"

if [[ "${UPLOAD}" == true ]]; then
  echo "Upload complete: ${NEXT_MARKETING} (${NEXT_BUILD})"
  echo "Archive and distribution logs: ${BUILD_DIR}"
else
  echo "Export complete: ${EXPORT_PATH}"
fi
