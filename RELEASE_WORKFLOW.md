# GitHub Release Workflow Documentation

## Overview

This repository includes a GitHub Actions workflow that automatically builds the macOS application, signs it, notarizes it with Apple, and creates releases with downloadable installers.

## Code Signing and Notarization

The workflow supports **Apple code signing and notarization** to ensure the app runs smoothly on user machines without security warnings.

### Required Secrets

To enable code signing and notarization, configure the following GitHub secrets in your repository settings:

#### For Code Signing:
- `APPLE_CERTIFICATE_BASE64` - Your Developer ID Application certificate exported as base64
  ```bash
  base64 -i certificate.p12 | pbcopy
  ```
- `APPLE_CERTIFICATE_PASSWORD` - Password for the certificate
- `KEYCHAIN_PASSWORD` - A random password for the temporary keychain (e.g., generate with `openssl rand -base64 32`)
- `APPLE_SIGNING_IDENTITY` - Your signing identity name (e.g., "Developer ID Application: Your Name (TEAM_ID)")
- `APPLE_INSTALLER_IDENTITY` - Your installer signing identity (e.g., "Developer ID Installer: Your Name (TEAM_ID)")

#### For Notarization:
- `APPLE_ID` - Your Apple ID email
- `APPLE_APP_PASSWORD` - App-specific password (create at https://appleid.apple.com)
- `APPLE_TEAM_ID` - Your Apple Developer Team ID (e.g., "KBM2NXRRG4")

### Optional: Build Without Notarization

The workflow will still build and create installers if the secrets are not configured, but:
- The app will not be code-signed
- The app will not be notarized
- Users may see security warnings when opening the app
- The app will only be suitable for development/testing

## How to Create a Release

### Method 1: Create and Push a Version Tag (Recommended)

1. Make sure your code is ready for release
2. Create a version tag:
   ```bash
   git tag v2.0.0
   git push origin v2.0.0
   ```
3. The workflow will automatically:
   - Build the app
   - Code sign the app (if secrets are configured)
   - Notarize with Apple (if secrets are configured)
   - Create DMG and PKG installers
   - Sign the DMG and PKG (if secrets are configured)
   - Create a GitHub release with the installers attached

### Method 2: Manual Trigger

1. Go to the "Actions" tab in GitHub
2. Select "Build and Release" workflow
3. Click "Run workflow"
4. The workflow will build and package the app, but won't create a release (since there's no tag)

## Version Tag Format

The workflow triggers on tags matching the pattern `v*.*.*`, for example:
- `v1.0.0`
- `v2.0.0`
- `v2.1.5`

## What Gets Released

Each release includes:
1. **DMG Installer** - Recommended for users
   - Disk image with drag-and-drop installation
   - File: `MirageVD-{version}.dmg`
   - Signed and notarized (when secrets are configured)

2. **PKG Installer** - Alternative installation method
   - Standard macOS package installer
   - File: `MirageVD-{version}.pkg`
   - Signed (when secrets are configured)

3. **Release Notes** - Generated automatically with:
   - Notarization status
   - Installation instructions
   - System requirements
   - Link to commit history

## Workflow Details

- **Trigger**: Push to version tags (`v*.*.*`) or manual workflow dispatch
- **Runner**: macOS (latest)
- **Build Tool**: Xcode (latest stable)
- **Code Signing**: Developer ID Application certificate with hardened runtime
- **Notarization**: Apple notarytool with app-specific password
- **Artifacts**: Signed and notarized DMG and PKG installers
- **Version Source**: Extracted from `MARKETING_VERSION` in `VirtualDisplay.xcodeproj/project.pbxproj`

## Files Modified

1. `.github/workflows/build-and-release.yml` - Main workflow file
2. `.gitignore` - Updated to exclude build artifacts

## Security Notes

- Signing and notarization only run on tag pushes (not manual triggers or non-tag pushes)
- Certificates are stored securely in GitHub Secrets
- Temporary keychain is created and destroyed during the build
- All signing operations use timestamp servers for long-term validity
- The workflow uses Apple's hardened runtime for enhanced security
