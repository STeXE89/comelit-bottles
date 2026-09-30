# Comelit software on Bottles (Linux)

Version 1.1.0, released 2026-09-28.

Comelit VIP Manager, Safe Manager and Simple Prog are desktop programs developed for Windows. This script lets you install and use them on Linux:

- **VIP Manager**: VIP IP video door entry systems
- **Safe Manager**: intrusion alarm systems
- **Simple Prog**: home automation systems

It sets up Bottles (Flatpak) with Wine and the Windows components the programs need, installs the programs, keeps them updated from Comelit Pro and adds them to the applications menu, with USB/serial devices available as COM ports.

> **Note**: these are Windows programs running through Wine, not natively. Malfunctions and imperfect graphics (wrong colors or fonts, misaligned or badly drawn windows and controls) may occur. Wine is not an officially supported platform for these programs: for critical operations, or if a problem cannot be solved, use a Windows PC.

## Usage
```bash
git clone https://github.com/STeXE89/comelit-bottles.git
cd comelit-bottles
./setup-comelit-bottles.sh                           # install/update all programs
./setup-comelit-bottles.sh safemanager               # one program (vipmanager, safemanager, simpleprog)
./setup-comelit-bottles.sh --version                 # version, release date and authors
./setup-comelit-bottles.sh --check                   # compare installed versions with Comelit Pro
./setup-comelit-bottles.sh --status                  # bottles, runners, installed versions
./setup-comelit-bottles.sh --diagnose safemanager    # start with a Wine debug log
./setup-comelit-bottles.sh --com                     # map connected serial devices to COM ports
./setup-comelit-bottles.sh --desktop 0               # Wine desktop window: 0 = off, 1 = screen size, or WxH
./setup-comelit-bottles.sh --backup                  # full backup of the bottle
./setup-comelit-bottles.sh --restore backups/<file>  # restore a bottle
./setup-comelit-bottles.sh --net                     # network report: host interfaces, firewall, Wine adapters
./setup-comelit-bottles.sh --self-update             # check now for a new version of the script
```

## Bottles
- **Default**: one bottle `Comelit` with all programs, Windows 11, Wine 11.0 runner (Kron4ek).
- `SEPARATE_BOTTLES=1`: one bottle per program (`Comelit-VIPManager`, `Comelit-SafeManager`, `Comelit-SimpleProg`); Safe Manager on Wine 11.0, the others on the Bottles default runner.
- Existing bottles are never converted or deleted. Safe Manager data (`C:\ProgramData\Comelit\SafeManager`) is not copied between bottles.

## First run on a new PC
The script installs what is missing:
1. Host tools `flatpak curl unzip tar xz icoutils` (apt/dnf/pacman/zypper, sudo password).
2. Flathub and Bottles; if already installed, Bottles and its runtimes are updated, with Flatpak's own progress (`SKIP_UPDATE=1` to skip).
3. Flatpak permissions for the installers folder and USB/serial devices.
4. Bottles first-run setup, if never done: complete the wizard, close Bottles, press Enter.
5. `dialout` group for serial ports (log out/in afterwards).
6. GNOME or Cinnamon "not responding" timeout: offers to raise it from 5 s to 60 s (KDE Plasma, XFCE and MATE check only when a window is closed: nothing to change).
7. Latest winetricks and the Wine 11.0 runner.

## Downloads and updates
- Each run reads the Comelit Pro download pages (version, date, size). If the installed version is the latest, nothing is downloaded; a local zip of the same size is reused; otherwise the zip is downloaded into the script folder (e.g. `sw-vip-manager-2.18.1.zip`), with %, speed and ETA. Interrupted downloads resume.
- Local zips in the script folder or `~/Downloads` are used too; `OFFLINE=1` uses only local zips. `KEEP_ZIPS=2` zips per program are kept.
- Re-running is safe: bottles, data and settings are kept, installed dependencies are skipped.
- A new version is installed in place after a **full backup of the bottle** (`backups/<bottle>-<date>.tar.zst`, `KEEP_BACKUPS=2`). Programs share registry, users and ProgramData, so only a whole-bottle snapshot restores consistently.
- `--restore` asks for confirmation and renames the current bottle `<bottle>.before-restore-<date>`. The next online run updates the programs again; use `OFFLINE=1` to stay on the restored versions.

## Script updates
- At start, with any command, the script checks the latest release of this repository on GitHub, compares it with its own version and says whether it is up to date or a new version is available. Only `--help` and `--version` do not check.
- A newer release is reported with its link and, **after confirmation**, installed; the script then restarts with the same arguments and continues normally.
- All the files of the release are updated, not only the script: in a clone with a fast forward to the release tag (`git fetch` + `git merge --ff-only`); outside a clone the files of the release (script, README, CHANGELOG, LICENSE and the others) replace the current ones and the previous ones are saved in `backups/script-<version>-<date>.tar.gz`.
- With changed tracked files in the clone, or if the fast forward is not possible (diverged branch), nothing is changed and the script asks you to run `git pull` yourself (log: `logs/self-update.log`).
- Bottles, programs, data, downloaded installers and `versions/` are never touched.
- `--self-update` checks and installs without restarting; `SELF_UPDATE=1` updates without asking; `NO_SELF_UPDATE=1` (and `OFFLINE=1`) skips the check.

## Specific versions
- Put a program's zip (as downloaded from Comelit Pro) or installer (`Setup_VipManager.x.y.z.exe`, `Setup_SimpleProg_x.y.z.exe`, Safe Manager `Setup.msi`, also inside a subfolder) in `versions/`: that version is installed, or the installed one is updated or downgraded to it.
- Same version as installed: nothing is done if it is the installer used last time; a different installer with the same version number (e.g. a rebuilt setup) is reinstalled: the installed version is removed first, after the full backup. `REINSTALL=1` reinstalls it anyway.
- While the file is there, that program is not updated from Comelit Pro; remove it to follow Comelit Pro again. If the installed version is newer than the official release, the script asks whether to downgrade to the official release; the answer is remembered until the installed version changes.
- The version is read from the file names (installer, zip, folder, release notes in the zip), from the MSI (`msiinfo`, package `msitools`) or from the exe version resource.
- **A downgrade, or an installer whose version is not detected, asks for confirmation** (`ALLOW_DOWNGRADE=1`: no question, also without a terminal). The installed version is removed first, after the full backup of the bottle. An older version may not read data or settings saved by a newer one: `--restore` goes back.
- One version per program: with two different versions of the same program in `versions/` the script stops.
- `--check` and `--status` show the file in `versions/` and what will happen.

## Options
| Variable | Effect |
|---|---|
| `SEPARATE_BOTTLES=1` | one bottle per program |
| `OFFLINE=1` | use local zips only |
| `REINSTALL=1` | run the installer even if the version did not change |
| `ALLOW_DOWNGRADE=1` | downgrade without asking (to the version in `versions/` or to the official release) |
| `SETUP_WIZARD=1` | show the installers' wizards instead of installing unattended |
| `DEPS_ONLY="dotnet48"` | install only these winetricks verbs |
| `FORCE_DEPS=1` / `SKIP_DEPS=1` | reinstall / skip dependencies |
| `SKIP_UPDATE=1` | do not update Bottles/Flatpak runtimes |
| `NO_BACKUP=1` / `KEEP_BACKUPS=N` | no backup before updates / backups kept per bottle |
| `KEEP_ZIPS=N` | installer zips kept per program |
| `COM_DEV=/dev/ttyACM0` | devices mapped to COM1.. (comma separated) instead of auto-detection |
| `NO_MENU=1` | no host applications menu entries |
| `VIRTUAL_DESKTOP=1` | programs inside one Wine desktop window: `0` = off (default), `1` = screen size, `WxH`; the last value given is kept, `--desktop` changes it without a full run |
| `NOT_RESPONDING_TIMEOUT=60` | seconds before GNOME/Cinnamon report a busy window as not responding (`0` = never) |
| `TAKE_FOCUS=1` | Wine takes the focus of its windows (`WM_TAKE_FOCUS`); by default the window manager does |
| `DECORATED=1` | windows framed by the window manager too; by default only the Wine theme frames them |
| `NO_SELF_UPDATE=1` | do not check for new versions of the script |
| `SELF_UPDATE=1` | update the script without asking |

## How it works
- Dependencies: corefonts, tahoma, vcrun2022, gdiplus, dotnet48 (.NET Framework apps with DevExpress UI; wine-mono is not enough).
- Dependencies and installers run with the Bottles soda runner, then the bottle switches to Wine 11: on Wine 11 the .NET installers ("ngen.exe not found") and Advanced Installer custom actions fail. Safe Manager needs Wine ≥ 9.10 at runtime (WMI `Win32_PnPEntity.Caption`).
- .NET is verified before the installers run. A bottle with a failed .NET installation and no programs can be recreated (the old one is renamed `<bottle>.broken-<date>`).
- `rundll32.exe.config` makes installer helpers use .NET 4 instead of the missing .NET 2.0.
- Installers run unattended (Advanced Installer `/exenoui /qn`, MSI `/qn ALLUSERS=1`), extracted into `installers/<program name>/`.
- By default each program runs in its own window. `VIRTUAL_DESKTOP=1` (or `--desktop 1`) puts them all inside one Wine desktop window, which keeps their windows in the right stacking order with the host windows on the window managers that need it; that window shows its own background around the programs, stays open until all of them exit and, being sized by Wine and not by the window manager, cannot be maximised or made full screen.
- Programs are added to Bottles only if not already listed, and to the host applications menu (`~/.local/share/applications/comelit-<target>.desktop`, launchers and icons in `~/.local/share/comelit-bottles/`).
- Each step shows the overall progress `[ 42%] (7/20)`; a live line shows elapsed time, activity and download progress. Logs are in `logs/`.

## Serial ports (Safe Manager, Simple Prog)
- Connected USB/serial devices are mapped to COM1, COM2, ... (Wine registry `HKLM\Software\Wine\Ports`) using the stable `/dev/serial/by-id/...` names, so moving a device to another USB port keeps its COM port. With one device connected it is always COM1.
- The menu launcher refreshes the mapping at every start when the connected devices change (with a notification). Connect the device before starting the program. `--com` applies it immediately (e.g. when starting from Bottles).
- The Windows USB driver shipped with Safe Manager cannot be installed in Wine: the panel must appear as `/dev/ttyACM*` or `/dev/ttyUSB*`.

## Known limitations
- Not all Windows functions are implemented in Wine: some features may not work or may behave differently than on Windows.
- Graphics may not match Windows: custom skins, transparent controls, fonts and colors can be drawn incorrectly.
- USB devices work only if Linux exposes them as serial ports; Windows drivers cannot be installed.
- A Bottles, runner or program update can change the behaviour: backups allow going back.

## Troubleshooting
- **Program does not start**: `./setup-comelit-bottles.sh --diagnose <target>` shows the .NET exception, if any.
- **Serial port not detected**: check `ls -l /dev/serial/by-id/` or `dmesg | tail`, run `--com`, select COM1 in the program; your user must be in `dialout`.
- **Broken windows or graphics**: bottle → Settings, disable DXVK or try another runner.
- **"Not responding" dialogs while a program loads**: the program is busy and Wine cannot answer the desktop's check (GNOME, Cinnamon) meanwhile. Raise the timeout with `NOT_RESPONDING_TIMEOUT=60` (or `0` to disable it for all applications).
- **Program windows showing through other windows**: happens with the virtual desktop off (the default); `--desktop 1` turns it back on.
- **Two frames around every window** (a title bar inside another): the Wine theme draws its own frame and the window manager adds one. The script leaves only the Wine one (`Decorated=N`, also set as the Bottles window setting); `DECORATED=1` gives the frame back to the window manager. Windows are then moved and resized from the frame Wine draws, or with the window manager shortcut (`Super` + drag on GNOME).
- **Window minimised by itself when loading finishes**: the loading window that had the focus is destroyed and the main window is left unfocused; Wine answers `WM_TAKE_FOCUS` and minimises it. The script sets `UseTakeFocus=N` so the window manager gives the focus itself; `TAKE_FOCUS=1` goes back to Wine's handling. Run `--desktop 0` (or any full run) to apply it to an existing bottle.
- **Black border around the programs, window not full screen, background still there after closing them**: they are the Wine desktop window of `VIRTUAL_DESKTOP=1`, not the programs; `--desktop 0` turns it off, `--desktop 1600x900` keeps it smaller than the screen.
- **LAN devices not found or connections failing** (cloud works): run `--net`. Check that the LAN with the devices is the default route (VPN, Docker, VirtualBox or libvirt interfaces can take broadcasts elsewhere), the host firewall (UDP broadcast and replies), and, if a program acts as a TFTP/SNMP server (firmware upload, traps), that low ports are allowed: `sudo sysctl -w net.ipv4.ip_unprivileged_port_start=69`.

## License
MIT, see [LICENSE](LICENSE): you can use, modify and redistribute this script, also in forks and derived projects, keeping the copyright notice. The license covers this script and its documentation only, not the Comelit programs it installs.

## Changelog
Changes for each version are in [CHANGELOG.md](CHANGELOG.md); the same notes are on the [releases page](https://github.com/STeXE89/comelit-bottles/releases). The version and release date of your copy: `./setup-comelit-bottles.sh --version`.

## Authors
Written and maintained by [STeXE89](https://github.com/STeXE89), with the people listed in [AUTHORS](AUTHORS).

## Contributing
Bug reports, fixes and improvements are welcome: see [CONTRIBUTING.md](CONTRIBUTING.md) for what to include in a report and how to propose a change. Forks are welcome too; if you use or redistribute this project, please mention the original one: https://github.com/STeXE89/comelit-bottles
