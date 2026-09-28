# Contributing

Main project: https://github.com/STeXE89/comelit-bottles

Forks are welcome; if you use or redistribute this project, please mention the original one. Bug reports, fixes and improvements are welcome too: contributions to the main project help everyone using these programs on Linux.

## Reporting a bug
Open an [issue](https://github.com/STeXE89/comelit-bottles/issues) with:

- What you ran (the exact command and any variables, e.g. `SEPARATE_BOTTLES=1 ./setup-comelit-bottles.sh safemanager`) and what happened instead of what you expected.
- The output of `./setup-comelit-bottles.sh --status`: bottles, runners and installed versions.
- Your distribution and version, and the desktop (GNOME, KDE Plasma, Cinnamon, XFCE, MATE).
- The relevant log from `logs/`. For a program that does not start, run `./setup-comelit-bottles.sh --diagnose <target>` first and attach that log: it contains the .NET exception, if any.
- For serial port problems, `ls -l /dev/serial/by-id/` and the COM port selected in the program. For network problems, the output of `./setup-comelit-bottles.sh --net`.

Please remove installation paths, IP addresses, serial numbers and anything else you do not want public from logs before attaching them.

Check the [known limitations](README.md#known-limitations) and [troubleshooting](README.md#troubleshooting) first: some behaviours come from Wine itself and cannot be fixed here.

## Proposing a change
1. Fork the repository and branch off `main`.
2. Keep one change per pull request, so it can be reviewed and reverted on its own.
3. Test on a real installation (see below) and say in the pull request what you tested: distribution, desktop, programs, and whether the bottle was new or existing.
4. Add an entry to [CHANGELOG.md](CHANGELOG.md) under an `## [Unreleased]` heading, in the same style as the released sections (`### Added`, `### Changed`, `### Fixed`).
5. Update [README.md](README.md) if you add or change an option, a command line flag or a behaviour a user would notice.

## Testing a change
There are no automated tests: the script installs Windows programs through Wine, so it has to be run.

- The safest check is a **new bottle**: move the existing one aside from Bottles, or use `SEPARATE_BOTTLES=1`, and run the script from scratch.
- Then check that **re-running is still safe** on an existing bottle: nothing should be reinstalled or downloaded when everything is up to date.
- `--check` and `--status` make no changes and are the quickest way to see what the script decided.
- `OFFLINE=1` with a zip in the script folder avoids downloading from Comelit Pro while testing.
- `./setup-comelit-bottles.sh --backup` before testing anything that installs or removes a program; `--restore` goes back.
- Run `shellcheck setup-comelit-bottles.sh` if you have it installed, and keep the script free of new warnings.

## Script conventions
The whole project is a single Bash script, [setup-comelit-bottles.sh](setup-comelit-bottles.sh). Match what is already there:

- `#!/usr/bin/env bash` with `set -Eeuo pipefail`: every command is expected to succeed, so handle the failures you expect (`|| true`, `if ! ...`).
- Quote expansions (`"$var"`, `"$@"`), and use `local` for variables inside functions.
- Small, single-purpose functions with lowercase underscore names, as in the existing ones (`fix_perms`, `step_begin`, `run_live`).
- User-facing messages go through `c_ok`, `c_info`, `c_warn`, `c_err` and `die`, not bare `echo`; keep them in English and on one line.
- Anything long-running goes through the step and progress helpers, so the `[ 42%] (7/20)` counter stays correct: update the step count if you add a step.
- New behaviour that changes the outcome should be reachable with an environment variable, documented in the options table in the README and in the header comment of the script.
- Destructive actions (removing a program, downgrading, restoring) ask for confirmation, back the bottle up first, and never delete a bottle: rename it aside, as the script already does.
- Keep the header comment of the script and its `--help` output in sync with what you changed.

## Versioning and releases
Versions follow [semantic versioning](https://semver.org). A release updates the version in the script header, moves the `## [Unreleased]` entries under a new `## [x.y.z] - <date>` heading in the changelog, and is tagged `vx.y.z`; the release notes on GitHub are that changelog section.

## License
This project is MIT licensed (see [LICENSE](LICENSE)). By contributing you agree that your contribution is released under the same license. The license covers this script and its documentation only, not the Comelit programs it installs.
