#!/bin/bash
set -euo pipefail

script_directory="$(cd "$(dirname "$0")" && pwd)"
package_root="$(cd "$script_directory/.." && pwd)"
swift_executable="${SWIFT_WEB_HOST_SWIFT:-/Users/1amageek/Library/Developer/Toolchains/swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-07-17-a.xctoolchain/usr/bin/swift}"
toolchain_identifier="${SWIFT_WEB_XCODE_TOOLCHAIN:-org.swift.64202607171a}"
timeout_script="$script_directory/swift-test-timeout.sh"
workspace="$(mktemp -d "${TMPDIR:-/tmp}/swiftweb-template-verification.XXXXXX")"

cleanup() {
  if [ -n "$workspace" ] && [ -d "$workspace" ]; then
    rm -rf "$workspace"
  fi
}
trap cleanup EXIT

verify_template() {
  local app_name="$1"
  local template_flag="$2"
  local project_directory="$workspace/$app_name"
  local derived_data="$workspace/DerivedData-$app_name"

  SWIFT_WEB_PACKAGE_PATH="$package_root" \
    "$timeout_script" 600 -- \
    "$swift_executable" run --package-path "$package_root" sweb new \
      "$app_name" --output "$workspace" $template_flag

  SWIFT_WEB_PACKAGE_PATH="$package_root" \
    "$timeout_script" 300 -- \
    "$swift_executable" package --package-path "$project_directory" resolve

  (
    cd "$project_directory"
    TOOLCHAINS="$toolchain_identifier" \
      "$timeout_script" 900 -- \
      xcodebuild build \
        -quiet \
        -scheme "$app_name" \
        -destination "platform=macOS" \
        -clonedSourcePackagesDirPath "$workspace/XcodeSourcePackages" \
        -derivedDataPath "$derived_data"
  )
}

verify_template "SwiftWebTemplateSmoke" ""
verify_template "SwiftWebAITemplateSmoke" "--ai"

echo "OK: minimal and AI templates generated, resolved, and built"
