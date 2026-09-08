# Changelog

All notable changes to MacSweep are documented here.

## [1.0.0] - 2026-09-06

### Added

- Smart Scan, Full Scan, and Developer Cleaner workflows.
- Pause, Resume, and Stop controls for active scans.
- Secure Sparkle-based automatic update support.
- Ad-hoc application signing, DMG packaging, checksums, and GitHub Release automation without a paid Apple account.

### Changed

- Cleanup permanently removes safety-approved items after explicit confirmation.
- Large File cleanup and App Uninstaller continue to use the macOS Trash for recoverability.

### Security

- Update archives require a valid Sparkle EdDSA signature.
- Release publication fails if update signing, application verification, or packaging fails.
