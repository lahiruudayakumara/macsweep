# MacSweep 1.1.0

MacSweep 1.1.0 adds App Mover and Storage Manager tools, live deletion progress reporting, and improved Gatekeeper handling for unsigned releases.

## Highlights

- **App Mover**: Seamlessly migrate large applications and their support/cache directories to external storage with automatic symbolic link management.
- **Storage Manager**: Monitor external volumes, detect free space, and manage relocatable data.
- **Live Cleanup Progress**: Watch cleaning operations stream in real time with live item paths and bytes freed.
- **Simplified Versioning**: About screen now displays clean semantic versioning without build counts.
- **Streamlined Setup**: Added installer script and automated quarantine flag stripping for Gatekeeper convenience.

> MacSweep is an open-source, ad-hoc-signed build and is not Apple-notarized. On first launch, Control-click MacSweep, choose **Open**, then confirm **Open**.

## Requirements

- macOS 14 Sonoma or later.
- Full Disk Access is recommended for complete scan results.
