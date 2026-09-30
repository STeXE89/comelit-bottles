# Changelog
All notable changes to Comelit software on Bottles (Linux). Dates are release dates (YYYY-MM-DD); authors are listed in [AUTHORS](AUTHORS).

## [1.2.0] - 2026-09-30
### Added
- `--desktop <0|1|WxH>` command: turns the Wine desktop window on or off, or resizes it, without a full run

### Changed
- The Wine desktop window is off by default: it showed its own background around the programs, stayed open until all of them exited and could not be maximised or made full screen. `VIRTUAL_DESKTOP=1` or `--desktop 1` turns it back on where it is needed

### Fixed
- Two frames around every window: the window manager no longer decorates the Wine windows, which the Wine theme already frames (`DECORATED=1` restores it)
- Window minimised by itself when a program finished loading: `UseTakeFocus=N` leaves the focus to the window manager instead of letting Wine minimise a window left unfocused (`TAKE_FOCUS=1` restores Wine's handling)
- Registry changes (Windows version, COM ports, Wine desktop window) could be lost: the script now waits for wineserver to write `user.reg` instead of letting the next change read the file before it is updated

## [1.1.0] - 2026-09-28
### Added
- Check at start for a new release on GitHub, with confirmation, update of all the files of the release (git fast forward in a clone, release files otherwise) and restart with the same arguments
- `--self-update` command and `NO_SELF_UPDATE`, `SELF_UPDATE` options
- Title, version, release date, authors, license and homepage printed at the start of every run

### Changed
- `--help` prints the same header: version, release date, authors and license are no longer repeated in the comment of the script

## [1.0.0] - 2026-09-28
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
