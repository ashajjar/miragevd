# MirageVD

[![Build and Release](https://github.com/ashajjar/miragevd/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/ashajjar/miragevd/actions/workflows/build-and-release.yml) [![Website](https://img.shields.io/badge/Website-miragevd.com-violet?logo=google-chrome&logoColor=white)](https://miragevd.com/)

MirageVD is a macOS application that creates virtual displays for screen sharing and recording purposes.

## Features

- Create virtual displays on macOS
- Customize display resolution and positioning
- Screen capture integration with ScreenCaptureKit
- Easy-to-use interface for managing virtual displays
- Interactive tutorial for first-time users

## System Requirements

- macOS 12.3 or later
- Screen recording permissions

## Installation

### Download Latest Release

Download the latest version from the [Releases](https://github.com/ashajjar/miragevd/releases) page.

1. Download `MirageVD-{version}.dmg`
2. Open the DMG file
3. Drag MirageVD to your Applications folder
4. Launch MirageVD from Applications

**Note:** The app is code-signed and notarized by Apple for your security.

## Building from Source

### Prerequisites

- Xcode (latest stable version)
- macOS development environment

### Build Steps

```bash
# Clone the repository
git clone https://github.com/ashajjar/miragevd.git
cd miragevd

# Build with Xcode
xcodebuild -project VirtualDisplay.xcodeproj \
  -scheme VirtualDisplay \
  -configuration Release \
  clean build
```

## Development

The project uses Swift and ScreenCaptureKit framework. Main components:

- `AppDelegate.swift` - Application lifecycle and menu management
- `MainViewController.swift` - Main interface controller
- `DisplayWindow.swift` - Virtual display window management
- `CaptureOverlayWindow.swift` - Screen capture overlay

## Releases

Releases are automated through GitHub Actions. To create a new release:

1. Update the version in `VirtualDisplay.xcodeproj/project.pbxproj`
2. Create and push a version tag:
   ```bash
   git tag v2.0.0
   git push origin v2.0.0
   ```
3. GitHub Actions will automatically build, sign, notarize, and create a release

See [RELEASE_WORKFLOW.md](RELEASE_WORKFLOW.md) for detailed release workflow documentation.

## License

Copyright © Ahmad Hajjar

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
