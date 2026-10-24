#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
expected_bundle_id='com.marcelbreuer.webguard'
expected_group='group.com.marcelbreuer.webguard'

for config in Debug Release; do
  file="$root_dir/ios/WebGuard/Config/$config.xcconfig"
  bundle_id="$(awk -F ' = ' '/^PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }' "$file")"
  if [[ "$bundle_id" != "$expected_bundle_id" ]]; then
    echo "$file must use $expected_bundle_id; found '${bundle_id:-<missing>}'" >&2
    exit 1
  fi
  if ! grep -Fq 'DEVELOPMENT_TEAM = $(APPLE_DEVELOPMENT_TEAM)' "$file"; then
    echo "$file must forward the account-specific APPLE_DEVELOPMENT_TEAM build setting" >&2
    exit 1
  fi
done

if grep -R -nE 'com\.example\.webguard|group\.com\.example\.webguard' \
  "$root_dir/ios/WebGuard" "$root_dir/ios/WebGuardWidget"; then
  echo 'Release targets must not contain placeholder WebGuard identifiers.' >&2
  exit 1
fi

grep -Fq "static let appGroup = \"$expected_group\"" "$root_dir/ios/WebGuard/App/WidgetSnapshot.swift"
grep -Fq "$expected_group" "$root_dir/ios/WebGuard/WebGuard.entitlements"
grep -Fq "$expected_group" "$root_dir/ios/WebGuardWidget/WebGuardWidget.entitlements"
grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER = com.marcelbreuer.webguard.tests;' "$root_dir/ios/WebGuard.xcodeproj/project.pbxproj"
grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER = com.marcelbreuer.webguard.widget;' "$root_dir/ios/WebGuard.xcodeproj/project.pbxproj"

echo "Release identity is consistent: $expected_bundle_id"
