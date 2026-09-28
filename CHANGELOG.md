# Changelog
All notable changes to Comelit software on Bottles (Linux). Dates are release dates (YYYY-MM-DD); authors are listed in [AUTHORS](AUTHORS).

## [Unreleased]
### Added
- Check at start for a new release on GitHub, with confirmation, update of all the files of the release (git fast forward in a clone, release files otherwise) and restart with the same arguments
- `--self-update` command and `NO_SELF_UPDATE`, `SELF_UPDATE` options
- Title, version, release date, authors, license and homepage printed at the start of every run

### Changed
- `--help` prints the same header: version, release date, authors and license are no longer repeated in the comment of the script

## [1.0.0] - 2026-09-28 - first release
### Added
- Installation and update of Comelit VIP Manager, Safe Manager and Simple Prog on Linux with Bottles (Flatpak)
- Shared bottle for all programs or one bottle per program
- Wine 11.0 runner with Windows 11
- Automatic installation of host tools, Flathub, Bottles, winetricks and Wine runner
- Windows dependencies with .NET Framework 4.8 verification
- Recovery of a bottle with a failed .NET installation
- Unattended installers
- Extracted files always owned and writable by the user, whatever permissions the archive stores
- Version check and download from Comelit Pro with progress and resume
- Reuse of already downloaded installers and offline mode
- Installation of specific versions: update, reinstall and downgrade with confirmation
- Return to the official release when a newer version is installed
- Full bottle backup before changes, manual backup and restore
- COM port mapping of USB/serial devices, stable across USB ports
- Applications menu entries with program icons
- Virtual desktop window for the programs
- GNOME and Cinnamon "not responding" timeout setting
- Status, update check, diagnostics and network report commands
- Overall progress and logs
- MIT license
