# Changelog

All notable changes to MacSweep are documented here.

## [1.0.0] - 2026-09-06

### Added

- Smart Scan, Full Scan, and Developer Cleaner workflows.
- Pause, Resume, and Stop controls for active scans.
- Secure Sparkle-based automatic update support.
- Developer ID signing, Apple notarization, DMG packaging, checksums, and GitHub Release automation.

### Changed

- Cleanup permanently removes safety-approved items after explicit confirmation.
- Large File cleanup and App Uninstaller continue to use the macOS Trash for recoverability.

### Security

- Update archives require an EdDSA signature and Developer ID validation.
- Release publication fails if signing, notarization, verification, or packaging fails.
