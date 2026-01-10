#!/bin/bash

# Configuration
APP_NAME="MirageVD"
IDENTIFIER="me.ahmadhajjar.MirageVD"

# Extract version from app's Info.plist
VERSION=$(plutil -extract CFBundleShortVersionString raw "${APP_NAME}.app/Contents/Info.plist")
if [ -z "$VERSION" ]; then
    print_error "Could not extract version from ${APP_NAME}.app/Contents/Info.plist"
fi

OUTPUT_BASE_NAME="MirageVD"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}==> $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}==> Error: $1${NC}"
    exit 1
}

# Check if the app exists
if [ ! -d "$APP_NAME.app" ]; then
    print_error "$APP_NAME.app not found in current directory"
fi

print_status "Starting build process..."


# Staple the notarization ticket to the DMG
print_status "Stapling notarization ticket to App..."
xcrun stapler staple -v "${APP_NAME}.app" || print_error "Failed to staple notarization ticket to App"
print_status "Notarization ticket stapled successfully"

# Create PKG
print_status "Creating PKG installer..."
pkgbuild --root "$APP_NAME.app" \
    --install-location "/Applications" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    "${OUTPUT_BASE_NAME}.pkg" || print_error "Failed to create PKG"

print_status "PKG created successfully"

# Create DMG
print_status "Creating DMG..."

# Clean up any existing temporary directory
rm -rf dmg_temp

# Create temporary directory and copy app
mkdir -p dmg_temp
cp -r "$APP_NAME.app" dmg_temp/

# Create DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder dmg_temp \
    -ov -format UDZO \
    "${OUTPUT_BASE_NAME}-${VERSION}.dmg" || print_error "Failed to create DMG"

# Clean up temporary directory
rm -rf dmg_temp

print_status "DMG created successfully"

# Sign the DMG
print_status "Signing DMG..."
codesign --force --sign "Developer ID Application" --timestamp "${OUTPUT_BASE_NAME}-${VERSION}.dmg" || print_error "Failed to sign DMG"

print_status "DMG signed successfully"

# Verify signatures
print_status "Verifying signatures..."
codesign -vv "${OUTPUT_BASE_NAME}-${VERSION}.dmg" || print_error "DMG signature verification failed"

print_status "Build process completed successfully!"
print_status "Created files:"
print_status "  - ${OUTPUT_BASE_NAME}.pkg"
print_status "  - ${OUTPUT_BASE_NAME}-${VERSION}.dmg" 