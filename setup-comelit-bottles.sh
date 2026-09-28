#!/usr/bin/env bash
# =============================================================================
#  Comelit software on Bottles (Linux)
#  setup-comelit-bottles.sh
#  Installs and updates the Comelit Windows desktop programs VIP Manager,
#  Safe Manager and Simple Prog to use them on Linux, in Bottles (Flatpak).
#  Forks and contributions are welcome (see CONTRIBUTING.md and CHANGELOG.md).
#
#  Usage:
#    ./setup-comelit-bottles.sh [targets]                # install/update (default: all)
#    ./setup-comelit-bottles.sh --check                  # compare with Comelit Pro, no changes
#    ./setup-comelit-bottles.sh --status                 # bottles, runners, versions
#    ./setup-comelit-bottles.sh --diagnose <target>      # run with Wine debug log
#    ./setup-comelit-bottles.sh --com [targets]          # map connected serial devices to COM ports
#    ./setup-comelit-bottles.sh --backup [targets]       # full backup of the bottle(s) now
#    ./setup-comelit-bottles.sh --restore <backup-file>  # restore a bottle (current one is kept aside)
#    ./setup-comelit-bottles.sh --net [target]           # network report: host interfaces and Wine adapters
#    ./setup-comelit-bottles.sh --version                # version, release date and authors
#    ./setup-comelit-bottles.sh --self-update            # check now for a new version of the script
#  Targets: vipmanager safemanager simpleprog
#
#  Default: one bottle "Comelit" (Windows 11, latest Wine runner) with all programs.
#  Re-running is safe: bottles, dependencies, data and settings are kept.
#  At start the script checks for a new release of itself on GitHub and, after
#  confirmation, updates its own files and restarts.
#  New versions are downloaded from Comelit Pro and installed in place after a full
#  backup of the bottle.
#  Specific versions: put a program's zip or installer (Setup_*.exe, Setup.msi) in
#  versions/ to install, update, reinstall (same version, different installer) or
#  downgrade (asks first) to that version; remove it to follow Comelit Pro again (an
#  installed version newer than the official release asks whether to go back to it).
#
#  Options (environment):
#    SEPARATE_BOTTLES=1    one bottle per program instead of the shared "Comelit" bottle
#    OFFLINE=1             use local zips only
#    REINSTALL=1           run the installer even if the version did not change
#    ALLOW_DOWNGRADE=1     downgrade without asking (to versions/ or to the official release)
#    DEPS_ONLY="dotnet48"  install only these winetricks verbs
#    FORCE_DEPS=1          reinstall all dependencies
#    SKIP_DEPS=1           skip dependencies
#    SKIP_UPDATE=1         do not update Bottles/Flatpak runtimes
#    NO_BACKUP=1           no backup before updates
#    KEEP_BACKUPS=2        full backups kept per bottle
#    KEEP_ZIPS=2           installer zips kept per program
#    COM_DEV=/dev/ttyACM0  devices mapped to COM1.. (comma separated) instead of auto-detection
#    NO_MENU=1             do not create host application menu entries
#    SETUP_WIZARD=1        show the installers' wizards instead of installing unattended
#    VIRTUAL_DESKTOP=1     programs inside one Wine desktop window (default; WxH, or 0 = off; remembered)
#    NOT_RESPONDING_TIMEOUT=60  seconds before GNOME/Cinnamon report a busy window as not responding (0 = never)
#    NO_SELF_UPDATE=1      do not check for new versions of the script
#    SELF_UPDATE=1         update the script without asking
# =============================================================================
set -Eeuo pipefail

TITLE="Comelit software on Bottles (Linux)"
VERSION="1.1.0"
RELEASE_DATE="2026-09-28"
AUTHORS="STeXE89 <8591354+STeXE89@users.noreply.github.com> and contributors (see AUTHORS)"
HOMEPAGE="https://github.com/STeXE89/comelit-bottles"

APP_ID="com.usebottles.bottles"
FLATHUB_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
WINETRICKS_URL="https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
PRO="https://pro.comelitgroup.com/it-it/downloads"
UA="Mozilla/5.0 (X11; Linux x86_64) setup-comelit-bottles"

DL_DIR="${DL_DIR:-$HOME/Downloads}"
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$WORK_DIR/logs"
STATE_DIR="$WORK_DIR/state"
BACKUP_DIR="$WORK_DIR/backups"
CACHE_DIR="$WORK_DIR/cache"
PIN_DIR="$WORK_DIR/versions"
BOTTLES_DATA="$HOME/.var/app/$APP_ID/data/bottles"
BOTTLES_DIR="$BOTTLES_DATA/bottles"
RUNNERS_DIR="$BOTTLES_DATA/runners"
WT_CACHE="$HOME/.var/app/$APP_ID/cache/winetricks"
WINETRICKS="$BOTTLES_DATA/winetricks"
SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/comelit-bottles"
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
KEEP_BACKUPS="${KEEP_BACKUPS:-2}"
KEEP_ZIPS="${KEEP_ZIPS:-2}"
mkdir -p "$LOG_DIR" "$STATE_DIR" "$BACKUP_DIR" "$CACHE_DIR" "$PIN_DIR"

# -----------------------------------------------------------------------------
# Profiles
# -----------------------------------------------------------------------------
# .NET Framework apps (DevExpress UI): wine-mono is not enough -> dotnet48.
DEPS_DEFAULT="corefonts tahoma vcrun2022 gdiplus dotnet48"
WIN_VERSION="win11"
LATEST_RUNNER="kron4ek-wine-11.0-staging-amd64"
SHARED_BOTTLE="Comelit"
declare -A BOTTLE TITLE PAGE ZIP SETUP SERIAL NAME_RE RUNNER
profile() {  # key bottle title page zip-glob setup-glob serial name-regex [runner]
  BOTTLE[$1]=$2; TITLE[$1]=$3; PAGE[$1]=$4; ZIP[$1]=$5; SETUP[$1]=$6; SERIAL[$1]=$7; NAME_RE[$1]=$8; RUNNER[$1]=${9:-}
}
profile vipmanager  Comelit-VIPManager  "Comelit VIP Manager"  "$PRO/vip-sistema-ip-3/software-6/vip-manager" \
        'sw-vip-manager*.zip' 'Setup_VipManager*.exe' 0 'vip.?manager'
# Safe Manager reads Win32_PnPEntity.Caption via WMI at startup: needs Wine >= 9.10.
profile safemanager Comelit-SafeManager "Comelit Safe Manager" "$PRO/antintrusione/software-4/safe-manager" \
        'safemanager*.zip' 'Setup.msi' 1 'safe.?manager' "$LATEST_RUNNER"
profile simpleprog  Comelit-SimpleProg  "Comelit Simple Prog"  "$PRO/domotica/software-3/simpleprog" \
        'sw-simpleprog*.zip' 'Setup_SimpleProg*.exe' 1 'simple.?prog'
ALL_TARGETS=(vipmanager safemanager simpleprog)
# Unattended install switches (Advanced Installer exe, Visual Studio MSI). The wizards'
# custom skins are not drawn correctly by Wine and add failure points.
declare -A SILENT_ARGS=( [vipmanager]="/exenoui /qn" [safemanager]="/qn ALLUSERS=1" [simpleprog]="/exenoui /qn" )
if [[ -z "${SEPARATE_BOTTLES:-}" ]]; then
  for t in "${ALL_TARGETS[@]}"; do BOTTLE[$t]="$SHARED_BOTTLE"; RUNNER[$t]="$LATEST_RUNNER"; done
fi

declare -A RUNNER_URL=(
  [$LATEST_RUNNER]="https://github.com/Kron4ek/Wine-Builds/releases/download/11.0/wine-11.0-staging-amd64.tar.xz"
)

# Step weights for the overall percentage (roughly proportional to duration)
declare -A WEIGHT=( [preflight]=4 [runner]=4 [create]=2 [serial]=1 [install]=6 [update]=6 [downgrade]=8 [reinstall]=8 [replace]=8
                    [backup]=6 [corefonts]=2 [tahoma]=1 [vcrun2022]=3 [gdiplus]=8 [dotnet48]=20 )

# -----------------------------------------------------------------------------
# Output and progress
# -----------------------------------------------------------------------------
c_ok()   { printf '\e[32m✔ %s\e[0m\n' "$*"; }
c_info() { printf '\e[36m➜ %s\e[0m\n' "$*"; }
c_warn() { printf '\e[33m⚠ %s\e[0m\n' "$*"; }
c_err()  { printf '\e[31m✖ %s\e[0m\n' "$*" >&2; }
die()    { c_err "$*"; exit 1; }
trap 'c_err "Error at line $LINENO (command: $BASH_COMMAND). See logs in $LOG_DIR"' ERR

is_tty()   { [[ -t 0 && -t 1 ]]; }
ask_yes()  { is_tty || return 1; local a; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[YySs]$ ]]; }
pause()    { is_tty || die "$1"; read -r -p "$1 Press Enter to continue... " _; }
mb()       { awk -v b="${1:-0}" 'BEGIN{printf "%.0f MB", b/1048576}'; }
fmt_time() { printf '%02d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }
matches() {  # case-insensitive glob match on the file name
  local f r=1; f="$(basename "$1")"
  shopt -s nocasematch; if [[ "$f" == $2 ]]; then r=0; fi; shopt -u nocasematch
  return $r
}
fix_perms() {  # <dir>: archives can store read-only folders or files writable by everyone
  chmod -R u+rwX,go-w "$1" 2>/dev/null || true
}

TOTAL_W=0; DONE_W=0; STEP=0; TOTAL_STEPS=0
w_of() { echo "${WEIGHT[$1]:-3}"; }
plan() { TOTAL_STEPS=$((TOTAL_STEPS + 1)); TOTAL_W=$((TOTAL_W + $(w_of "$1"))); }
pct()  { local p=$(( TOTAL_W > 0 ? DONE_W * 100 / TOTAL_W : 100 )); echo $(( p > 100 ? 100 : p )); }
step_begin() { STEP=$((STEP + 1)); printf '\e[1;34m[%3d%%] (%d/%d)\e[0m \e[36m%s\e[0m\n' "$(pct)" "$STEP" "$TOTAL_STEPS" "$2"; }
step_end()   { DONE_W=$((DONE_W + $(w_of "$1"))); }
progress_bar() {
  local p n j bar=""; p=$(pct); n=$(( p / 4 ))
  for ((j = 0; j < 25; j++)); do if (( j < n )); then bar+="#"; else bar+="."; fi; done
  printf '\e[1;34m[%s] %3d%%\e[0m\n' "$bar" "$p"
}

# Runs a command in background (output to <log>) with a live status line.
# WATCH_FILE/EXPECT_SIZE: show download size, %, speed and ETA of that file;
# otherwise show the file being written in the winetricks cache.
run_live() {
  local log="$1"; shift
  local wfile="${WATCH_FILE:-}" expect="${EXPECT_SIZE:-0}"
  : >"$log"
  ( trap - ERR; "$@" ) >>"$log" 2>&1 &
  local pid=$! start=$SECONDS spin='|/-\' k=0 cols last dl sz psz=0 pt=$SECONDS spd=0
  cols=$(( $(tput cols 2>/dev/null || echo 100) - 2 ))
  while kill -0 "$pid" 2>/dev/null; do
    last="$(grep -aE '^(Executing (w_do_call|load_|.*wine.* (/q|/quiet|/passive|/install))|Downloading |Saving )' "$log" \
            | tail -1 | sed -E 's#^Downloading (https?://[^ ]*/)?([^ /]+).*#download \2#; s#^Executing ##; s#/home/[^ ]*/##g' \
            | cut -c1-50)" || true
    if [[ -n "$wfile" ]]; then
      sz=$(stat -c %s "$wfile" 2>/dev/null || echo 0)
      if (( SECONDS > pt )); then spd=$(( (sz - psz) / (SECONDS - pt) )); psz=$sz; pt=$SECONDS; fi
      if (( expect > 0 )); then
        dl="$(awk -v s="$sz" -v e="$expect" -v v="$spd" 'BEGIN{ eta = v > 0 ? (e - s) / v : 0
              printf "%.0f/%.0f MB  %d%%  %.1f MB/s  ETA %02d:%02d", s/1048576, e/1048576, s*100/e, v/1048576, eta/60, eta%60 }')"
      else dl="$(mb "$sz")"; fi
    else
      dl="$(find "$WT_CACHE" -type f -newermt '5 seconds ago' -printf '%s %f\n' 2>/dev/null \
            | sort -rn | head -1 | awk '{printf "%s %.0f MB", $2, $1/1048576}')" || true
    fi
    k=$(( (k + 1) % 4 ))
    printf '\r\e[K    %s %s  %s%s' "${spin:k:1}" "$(fmt_time $((SECONDS - start)))" \
      "${last:-working...}" "${dl:+  [↓ $dl]}" | cut -c1-"$cols" | tr -d '\n'
    sleep 1
  done
  printf '\r\e[K'
  wait "$pid"
}

# Runs a command in foreground keeping its own progress output, with a copy in <log>
run_visible() {
  local log="$1"; shift
  if is_tty && command -v script >/dev/null; then script -qfec "$(printf '%q ' "$@")" "$log"
  else "$@" 2>&1 | tee "$log"; fi
}

http_head() {  # <url>: "status content-type size" of the final response
  { pro_curl -sSIL -m 30 -A "$UA" "$1" 2>/dev/null || true; } | tr -d '\r' | awk '
    /^HTTP\// { c = $2; t = "-"; s = 0 }
    tolower($1) == "content-type:" { t = $2 }
    tolower($1) == "content-length:" { s = $2 }
    END { print (c == "" ? "000" : c), (t == "" ? "-" : t), s + 0 }'
}
http_size() {  # Content-Length of a URL (0 if unknown)
  local h; h="$(http_head "$1")"
  if [[ "$h" == 2* ]]; then echo "${h##* }"; else echo 0; fi
}

# -----------------------------------------------------------------------------
# Bottles / Wine
# -----------------------------------------------------------------------------
bcli()            { flatpak run --command=bottles-cli "$APP_ID" "$@"; }
bottles_running() {  # the Bottles window is open (the script's own sandboxes do not count)
  local roots
  roots="$(flatpak ps --columns=application,pid 2>/dev/null | awk -v a="$APP_ID" '$1 == a { print $2 }')" || true
  [[ -n "$roots" ]] || return 1
  ps -eo pid=,ppid=,args= | awk -v roots="$roots" '
    BEGIN { n = split(roots, r, "\n"); for (i = 1; i <= n; i++) keep[r[i]] = 1 }
    { pid[NR] = $1; ppid[NR] = $2; $1 = $2 = ""; args[NR] = $0 }
    END { do { c = 0; for (i = 1; i <= NR; i++) if (!keep[pid[i]] && keep[ppid[i]]) { keep[pid[i]] = 1; c = 1 } } while (c)
          for (i = 1; i <= NR; i++) if (keep[pid[i]] && args[i] ~ /(^|\/)bottles( |$)/) f = 1
          exit !f }'
}
bottle_exists()   { [[ -f "$BOTTLES_DIR/$1/bottle.yml" ]]; }
runner_of()       { sed -n 's/^Runner:[[:space:]]*//p' "$BOTTLES_DIR/$1/bottle.yml" | tr -d "'\""; }

bsh() {  # bsh <bottle> <command>: bash inside the Bottles sandbox (BSH_RUNNER overrides the runner)
  local b="$1" own r pre=""; shift
  own="$(runner_of "$b")"; r="$RUNNERS_DIR/${BSH_RUNNER:-$own}/bin"
  # two Wine versions cannot share a prefix at the same time: wait for the bottle's own wineserver
  [[ -z "${BSH_RUNNER:-}" || "$BSH_RUNNER" == "$own" ]] || pre="'$RUNNERS_DIR/$own/bin/wineserver' -w 2>/dev/null; "
  flatpak run --command=bash --env=WINEPREFIX="$BOTTLES_DIR/$b" --env=WINE="$r/wine" \
    --env=WINESERVER="$r/wineserver" --env=WINEDEBUG="${WINEDEBUG:--all}" \
    --env=PATH="$r:/app/bin:/usr/bin:/bin" "$APP_ID" -c "$pre$*"
}

wine_reg() {  # wine_reg <bottle> <key> <value> <type> <data>
  bsh "$1" "wine reg add '$2' /v '$3' /t $4 /d '$5' /f >/dev/null" >>"$LOG_DIR/$1-reg.log" 2>&1 || true
}
set_winver() { wine_reg "$1" 'HKCU\Software\Wine' Version REG_SZ "$WIN_VERSION"; }

wait_bottles_closed() {
  bottles_running || return 0
  pause "Close the Bottles window so the bottle configuration can be changed."
  bottles_running && c_warn "Bottles still looks open: continuing anyway" || true
}

reg_uninstall_value() {  # <target> <DisplayVersion|key>: from the bottle's uninstall registry
  local reg="$BOTTLES_DIR/${BOTTLE[$1]}/system.reg"
  [[ -f "$reg" ]] || return 0
  awk -v re="${NAME_RE[$1]}" -v want="$2" '
    function hit() { r = (want == "key") ? k : v; if (tolower(n) ~ re && r != "") { print r; found = 1; exit } }
    /^\[/ { hit(); n = v = k = ""
            if ($0 ~ /\\\\Uninstall\\\\[{]/) { k = $0; sub(/.*\\\\Uninstall\\\\/, "", k); sub(/\].*/, "", k) } }
    /^"DisplayName"=/    { n = $0 }
    /^"DisplayVersion"=/ { v = $0; sub(/^"DisplayVersion"="/, "", v); sub(/"$/, "", v) }
    END { if (!found) hit() }' "$reg"
}
version_of()       { reg_uninstall_value "$1" DisplayVersion; }
msi_product_code() { reg_uninstall_value "$1" key; }

ver_cmp() {  # <a> <b>: -1, 0 or 1; missing parts count as 0, 3.0.0.88 (Comelit Pro) == 3.0.88 (MSI)
  awk -v a="$1" -v b="$2" 'BEGIN {
    na = split(a, x, "."); nb = split(b, y, ".")
    if (na == 4 && nb == 3 && x[3] + 0 == 0) { x[3] = x[4]; na = 3 }
    if (nb == 4 && na == 3 && y[3] + 0 == 0) { y[3] = y[4]; nb = 3 }
    n = (na > nb) ? na : nb; r = 0
    for (i = 1; i <= n && r == 0; i++) {
      p = (i <= na) ? x[i] + 0 : 0; q = (i <= nb) ? y[i] + 0 : 0
      if (p != q) r = (p < q) ? -1 : 1
    }
    print r }'
}
same_version() { [[ -n "$1" && -n "$2" && "$(ver_cmp "$1" "$2")" == 0 ]]; }

dotnet_ok() {  # real .NET Framework >= 4.7.2 (wine-mono leaves fake registry keys)
  local fw="$BOTTLES_DIR/$1/drive_c/windows/Microsoft.NET/Framework/v4.0.30319"
  [[ -f "$fw/clr.dll" && -f "$fw/ngen.exe" ]] || return 1
  awk '/^\[/ { f = ($0 ~ /^\[Software\\\\Microsoft\\\\NET Framework Setup\\\\NDP\\\\v4\\\\Full\]/) }
       f && /^"Release"=dword:/ { sub(/.*dword:/, ""); print; exit }' "$BOTTLES_DIR/$1/system.reg" 2>/dev/null \
    | { read -r h && (( 16#${h:-0} >= 461808 )); }
}

# On recent Wine, winetricks' .NET installers fail ("ngen.exe not found") and so do Advanced
# Installer custom actions (AI_AppSearchEx): dependencies and installers run with the newest
# soda/caffe runner, then the bottle moves to LATEST_RUNNER.
deps_runner() {
  local r
  r="$(ls -1d "$RUNNERS_DIR"/soda-* "$RUNNERS_DIR"/caffe-* 2>/dev/null | sort -V | tail -1)" || true
  basename "${r:-$LATEST_RUNNER}"
}

# Installer helpers hosted by rundll32 request .NET 2.0, which is not installed: use .NET 4.
dotnet_host_config() {
  local d f
  for d in system32 syswow64; do
    f="$BOTTLES_DIR/$1/drive_c/windows/$d/rundll32.exe.config"
    [[ -d "$(dirname "$f")" && ! -f "$f" ]] || continue
    printf '%s\r\n' '<?xml version="1.0" encoding="utf-8"?>' '<configuration>' \
      '  <startup useLegacyV2RuntimeActivationPolicy="true">' '    <supportedRuntime version="v4.0"/>' \
      '  </startup>' '</configuration>' >"$f"
  done
}

installed_exe() {
  local root="$BOTTLES_DIR/${BOTTLE[$1]}/drive_c"
  find "$root/Program Files" "$root/Program Files (x86)" -type f -iregex ".*${NAME_RE[$1]}[^/]*\.exe" \
       ! -iname '*unins*' ! -iname '*setup*' ! -iname '*update*' ! -iname '*crash*' ! -iname '*.vshost.exe' \
       2>/dev/null | head -1 || true
}
# One Wine desktop window keeps the programs' layered windows (DevExpress shadows) in the right
# stacking order with the host windows.
set_virtual_desktop() {  # VIRTUAL_DESKTOP, else the last value given, else 1
  local b="$1" f="$STATE_DIR/virtual-desktop" v res
  v="${VIRTUAL_DESKTOP:-$(cat "$f" 2>/dev/null || true)}"
  [[ "$v" =~ ^(0|1|[0-9]+x[0-9]+)$ ]] || { [[ -z "$v" ]] || c_warn "VIRTUAL_DESKTOP=$v not valid: using 1"; v=1; }
  [[ -z "${VIRTUAL_DESKTOP:-}" ]] || echo "$v" >"$f"
  if [[ "$v" == 0 ]]; then
    bsh "$b" "wine reg delete 'HKCU\\Software\\Wine\\Explorer' /v Desktop /f" >>"$LOG_DIR/$b-reg.log" 2>&1 || true
    c_ok "$b: virtual desktop off"; return
  fi
  res="$v"
  [[ "$res" =~ ^[0-9]+x[0-9]+$ ]] || res="$(xrandr --current 2>/dev/null | awk '/\*/ { print $1; exit }')" || true
  [[ "$res" =~ ^[0-9]+x[0-9]+$ ]] || res="1920x1080"
  wine_reg "$b" 'HKCU\Software\Wine\Explorer' Desktop REG_SZ "$b"
  wine_reg "$b" 'HKCU\Software\Wine\Explorer\Desktops' "$b" REG_SZ "$res"
  c_ok "$b: virtual desktop $res"
}

bottle_has_programs() {
  local t; for t in "${ALL_TARGETS[@]}"; do [[ "${BOTTLE[$t]}" == "$1" && -n "$(installed_exe "$t")" ]] && return 0; done; return 1
}

# -----------------------------------------------------------------------------
# Comelit Pro
# -----------------------------------------------------------------------------
# Account: email and password are asked on the terminal when needed and used for
# this run only; the session lives in a temporary folder removed at exit.
PRO_LOGIN_URL="https://apipro.comelitgroup.com/v2/auth/login"
PRO_API_KEY="comelit-pro"
PRO_CURL=(); PRO_DL_TOKEN=""; PRO_TRIED=""; PRO_EMAIL=""; PRO_TMP=""; PRO_URL=""; PRO_SIZE=0

pro_curl() {  # curl, with the session only towards comelitgroup.com
  local a u=""
  for a in "$@"; do [[ "$a" != http* ]] || u="$a"; done
  if (( ${#PRO_CURL[@]} )) && [[ "$u" =~ ^https://([^/?#]+\.)?comelitgroup\.com([/?#:]|$) ]]; then
    curl "${PRO_CURL[@]}" "$@"
  else curl "$@"; fi
}

json_str() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }
json_get() {  # <key> <json>: first string or number value of the key
  { grep -oE "\"$1\"[[:space:]]*:[[:space:]]*(\"[^\"]*\"|[0-9]+)" <<<"$2" || true; } | head -1 \
    | sed -E 's/^[^:]*:[[:space:]]*"?//; s/"$//'
}

pro_session() {  # <access token> <download token>: curl options kept off the command line
  if [[ -z "$PRO_TMP" ]]; then PRO_TMP="$(mktemp -d)"; trap 'rm -rf "$PRO_TMP"' EXIT; fi
  ( umask 077
    printf '.comelitgroup.com\tTRUE\t/\tTRUE\t0\tjwt_token_prod\t%s\n' "$1" >"$PRO_TMP/cookies"
    printf 'header = %s\ncookie = %s\n' "$(json_str "Authorization: Bearer $1")" "$(json_str "$PRO_TMP/cookies")" >"$PRO_TMP/curlrc" )
  PRO_CURL=(-K "$PRO_TMP/curlrc"); PRO_DL_TOKEN="$2"
}

pro_login() {  # once per run (again if the session expires)
  local pass e hint resp tok msg n
  [[ -z "$PRO_TRIED" ]] || return 1
  PRO_TRIED=1
  is_tty || { c_warn "Comelit Pro sign-in needed: run the script from a terminal"; return 1; }
  c_info "Comelit Pro sign-in"
  for n in 1 2 3; do
    if [[ -n "$PRO_EMAIL" ]]; then hint="[$PRO_EMAIL]"; else hint="(Enter to skip)"; fi
    read -r -p "  Email $hint: " e || { echo; return 1; }
    PRO_EMAIL="${e:-$PRO_EMAIL}"
    [[ -n "$PRO_EMAIL" ]] || { c_warn "Comelit Pro sign-in skipped"; return 1; }
    read -r -s -p "  Password: " pass || { echo; return 1; }
    echo
    [[ -n "$pass" ]] || continue
    resp="$(printf '{"email":%s,"password":%s}' "$(json_str "$PRO_EMAIL")" "$(json_str "$pass")" \
      | curl -sS -m 30 -A "$UA" -H "Api-Key: $PRO_API_KEY" -H 'Content-Type: application/json' \
             -H 'Accept: application/json' --data-binary @- "$PRO_LOGIN_URL" 2>&1)" || true
    pass=""
    tok="$(json_get access_token "$resp")"
    if [[ -n "$tok" ]]; then
      pro_session "$tok" "$(json_get ccstoken "$resp")"
      c_ok "Signed in to Comelit Pro as $PRO_EMAIL"
      return 0
    fi
    [[ "$resp" == *"{"* ]] || { c_warn "Comelit Pro sign-in: server not reachable"; return 1; }
    msg="$(json_get message "$resp")"
    c_warn "Comelit Pro sign-in failed${msg:+: $msg}"
  done
  return 1
}

fetch_page() {  # <url> <file>: prints the HTTP status (000 = not reachable)
  pro_curl -sSL -m 60 -A "$UA" -o "$2" -w '%{http_code}' "$1" 2>/dev/null || true
}
needs_auth() {  # <http_head output> of a file: refused, or a login page instead of the file
  [[ "$1" =~ ^40[13]\  || "$1" =~ ^2[0-9][0-9]\ text/html ]]
}
pro_file_url() {  # <url>: sets PRO_URL (URL to download the file with) and PRO_SIZE
  local u="$1" h
  h="$(http_head "$u")"
  if needs_auth "$h" && pro_login; then h="$(http_head "$u")"; fi
  if needs_auth "$h" && [[ -n "$PRO_DL_TOKEN" ]]; then
    if [[ "$u" == *\?* ]]; then u+="&token=$PRO_DL_TOKEN"; else u+="?token=$PRO_DL_TOKEN"; fi
    h="$(http_head "$u")"
  fi
  PRO_URL="$u"; PRO_SIZE=0
  if [[ "$h" == 2* ]] && ! needs_auth "$h"; then PRO_SIZE="${h##* }"; fi
}
pro_download() {  # <target> <file>: resumable download, signing in again if the session expired
  local t="$1" log="$LOG_DIR/download-$1.log" n
  for n in 1 2; do
    WATCH_FILE="$2" EXPECT_SIZE="${R_SIZE[$t]}" \
      run_live "$log" pro_curl -fL --retry 3 -A "$UA" -C - -o "$2" "${R_URL[$t]}" && return 0
    (( n == 1 )) && grep -qE 'returned error: 40[13]' "$log" || return 1
    (( ${#PRO_CURL[@]} )) || [[ -z "$PRO_TRIED" ]] || return 1   # signed in before: session expired
    PRO_TRIED=""; pro_login || return 1
    pro_file_url "${R_HREF[$t]}"; R_URL[$t]="$PRO_URL"; R_SIZE[$t]="$PRO_SIZE"
  done
  return 1
}

# R_STATUS: offline | unreachable | not-found | current | newer | downloaded | new | pinned
declare -A R_URL R_HREF R_FILE R_VER R_DATE R_SIZE R_LOCAL R_STATUS
remote_check() {
  local t="$1" html="$CACHE_DIR/page-$1.html" raw="" href h meta z inst code try
  R_STATUS[$t]=offline; R_LOCAL[$t]=""; R_SIZE[$t]=0
  if [[ -n "${PIN_FILE[$t]:-}" ]]; then R_STATUS[$t]=pinned; return 0; fi
  [[ -z "${OFFLINE:-}" ]] && command -v curl >/dev/null || return 0
  for try in 1 2; do
    code="$(fetch_page "${PAGE[$t]}" "$html")"
    [[ "$code" != 000 ]] || { R_STATUS[$t]=unreachable; return 0; }
    while IFS= read -r h; do
      if matches "${h%%\?*}" "${ZIP[$t]}"; then raw="$h"; break; fi
    done < <([[ "$code" != 200 ]] || { grep -oE "https://[^\"'<> ]+\.zip(\?[^\"'<> ]*)?" "$html" || true; } | awk '!s[$0]++')
    [[ -z "$raw" && $try == 1 && "$code" =~ ^(200|401|403)$ ]] && pro_login || break
  done
  if [[ -z "$raw" ]]; then
    if [[ "$code" == 200 ]]; then R_STATUS[$t]=not-found; else R_STATUS[$t]=unreachable; fi
    return 0
  fi

  href="${raw//&amp;/&}"; R_HREF[$t]="$href"; R_FILE[$t]="$(basename "${href%%\?*}")"
  pro_file_url "$href"; R_URL[$t]="$PRO_URL"
  meta="$(awk -v h="$raw" 'BEGIN { RS = "\001" } { i = index($0, h); if (i) print substr($0, i, 4000) }' "$html" \
          | tr '\n' ' ' | grep -oE 'rel\. *[0-9][0-9.]*[0-9] *dat\. *[0-9]{8}' | head -1)" || true
  R_VER[$t]="$(sed -nE 's/^rel\. *([0-9.]+) .*/\1/p' <<<"$meta")"
  R_DATE[$t]="$(grep -oE '[0-9]{8}$' <<<"$meta")" || R_DATE[$t]=""
  R_SIZE[$t]="$PRO_SIZE"

  inst="$(version_of "$t")"
  for z in "$WORK_DIR"/*.zip "$DL_DIR"/*.zip; do   # already downloaded: version in the name or same size
    [[ -f "$z" ]] && matches "$z" "${ZIP[$t]}" || continue
    if [[ -n "${R_VER[$t]}" && "$z" == *"-${R_VER[$t]}.zip" ]]; then R_LOCAL[$t]="$z"; break; fi
    (( R_SIZE[$t] > 0 )) && [[ "$(stat -Lc %s "$z")" == "${R_SIZE[$t]}" ]] || continue
    # same size as the installed zip but a different version: not the same file
    if [[ -n "$inst" && "$(cat "$STATE_DIR/$t.state" 2>/dev/null)" == "$(fingerprint "$z")" ]] \
       && ! same_version "$inst" "${R_VER[$t]:-x}"; then continue; fi
    R_LOCAL[$t]="$z"; break
  done
  if [[ -z "${REINSTALL:-}" ]] && same_version "$inst" "${R_VER[$t]:-x}"; then R_STATUS[$t]=current
  elif [[ -n "$inst" && -n "${R_VER[$t]}" && "$(ver_cmp "$inst" "${R_VER[$t]}")" == 1 ]]; then R_STATUS[$t]=newer
  elif [[ -n "${R_LOCAL[$t]}" ]]; then R_STATUS[$t]=downloaded
  elif (( R_SIZE[$t] == 0 )) && find_zip "$t" >/dev/null; then R_STATUS[$t]=downloaded
  else R_STATUS[$t]=new; fi
}

download_zip() {
  local t="$1" key="download_$1" dest part got
  dest="$WORK_DIR/${R_FILE[$t]%.zip}-${R_VER[$t]:-${R_DATE[$t]:-$(date +%Y%m%d)}}.zip"
  [[ -e "$dest" ]] && dest="${dest%.zip}-$(date +%H%M%S).zip"
  part="$dest.part"
  step_begin "$key" "Download ${R_FILE[$t]} ${R_VER[$t]:+rel. ${R_VER[$t]} }from Comelit Pro ($(mb "${R_SIZE[$t]}"))"
  if ! pro_download "$t" "$part"; then
    c_warn "Download failed (log: $LOG_DIR/download-$t.log): run again to resume. Using local zips if any."
  else
    got="$(stat -c %s "$part")"
    if { (( R_SIZE[$t] > 0 )) && [[ "$got" != "${R_SIZE[$t]}" ]]; } || ! unzip -l "$part" >/dev/null 2>&1; then
      rm -f "$part"; c_warn "Downloaded file is corrupted: removed, run again to retry"
    else
      mv -f "$part" "$dest"; R_LOCAL[$t]="$dest"; c_ok "Downloaded $(basename "$dest") ($(mb "$got"))"
    fi
  fi
  step_end "$key"
}

cleanup_zips() {  # keep the newest KEEP_ZIPS zips of a program in the script folder
  local t="$1" z n=0
  while IFS= read -r z; do
    matches "$z" "${ZIP[$t]}" || continue
    if (( ++n > KEEP_ZIPS )); then rm -f "$z"; c_info "Removed old installer $(basename "$z")"; fi
  done < <(ls -1t "$WORK_DIR"/*.zip 2>/dev/null)
}

# -----------------------------------------------------------------------------
# Script updates (GitHub)
# -----------------------------------------------------------------------------
# The latest release of the repository is checked at every run (NO_SELF_UPDATE=1
# skips it). A newer version is reported and, after confirmation, installed: a clone is fast
# forwarded to the release tag, otherwise the files are replaced with those of the
# release (the previous ones are saved in backups/). The script then restarts with
# the same arguments.
GH_REPO="${HOMEPAGE#*://github.com/}"
GH_API="https://api.github.com/repos/$GH_REPO"
SELF="$WORK_DIR/$(basename "${BASH_SOURCE[0]}")"
SELF_TAG=""; SELF_VER=""; SELF_TARBALL=""

self_release() {  # latest release: sets SELF_TAG, SELF_VER and SELF_TARBALL
  local json
  json="$(curl -fsSL -m 30 -A "$UA" -H 'Accept: application/vnd.github+json' \
          "$GH_API/releases/latest" 2>/dev/null)" || return 1
  SELF_TAG="$(json_get tag_name "$json")"
  SELF_TARBALL="$(json_get tarball_url "$json")"
  SELF_VER="$(name_version "$SELF_TAG")"
  [[ -n "$SELF_TAG" && -n "$SELF_VER" ]]
}

self_git_update() {  # clone: fast forward to the release tag
  local log="$LOG_DIR/self-update.log" g=(git -C "$WORK_DIR")
  if [[ -n "$("${g[@]}" status --porcelain --untracked-files=no 2>/dev/null)" ]]; then
    c_warn "Changed files in $WORK_DIR: update the clone yourself (git pull). Nothing changed."; return 1
  fi
  "${g[@]}" fetch --quiet --tags origin >"$log" 2>&1 \
    && "${g[@]}" merge --quiet --ff-only "$SELF_TAG" >>"$log" 2>&1 && return 0
  c_warn "git could not update the clone (log: $log): update it yourself (git pull). Nothing changed."
  return 1
}

self_files_update() {  # not a clone: files of the release, the previous ones saved in backups/
  local tmp top f b r=0 saved="" new=() old=() bak="$BACKUP_DIR/script-$VERSION-$(date +%Y%m%d-%H%M%S).tar.gz"
  [[ -n "$SELF_TARBALL" ]] || { c_warn "Release $SELF_TAG without source archive: download it from $HOMEPAGE"; return 1; }
  tmp="$(mktemp -d)"; top=""
  if curl -fsSL -m 600 -A "$UA" -o "$tmp/src.tar.gz" "$SELF_TARBALL" && tar -xzf "$tmp/src.tar.gz" -C "$tmp"; then
    top="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -1)"
  fi
  if [[ -z "$top" || ! -f "$top/$(basename "$SELF")" ]]; then
    rm -rf "$tmp"; c_warn "Download of $SELF_TAG failed: nothing changed"; return 1
  fi
  while IFS= read -r f; do
    new+=("$f"); b="$(basename "$f")"; [[ ! -f "$WORK_DIR/$b" ]] || old+=("$b")
  done < <(find "$top" -maxdepth 1 -type f | sort)
  (( ${#old[@]} == 0 )) || tar -czf "$bak" -C "$WORK_DIR" "${old[@]}" 2>/dev/null || true
  [[ ! -f "$bak" ]] || saved=" (previous files: ${bak#"$WORK_DIR"/})"
  for f in "${new[@]}"; do   # replaced by rename: bash keeps reading the file of the running script
    b="$(basename "$f")"
    cp -p "$f" "$WORK_DIR/.$b.new" && mv -f "$WORK_DIR/.$b.new" "$WORK_DIR/$b" || { rm -f "$WORK_DIR/.$b.new"; r=1; }
  done
  rm -rf "$tmp"
  (( r == 0 )) || { c_warn "Some files could not be replaced in $WORK_DIR$saved"; return 1; }
  chmod u+x "$SELF"
  [[ -z "$saved" ]] || c_info "Files of $VERSION saved in ${bak#"$WORK_DIR"/}"
}

self_update() {  # <arguments to restart with>: check, ask, replace the files, restart
  local force="${FORCE_SELF_UPDATE:-}"
  [[ -z "${SELF_UPDATED:-}" ]] || return 0                       # already updated in this run
  [[ -n "$force" || ( -z "${NO_SELF_UPDATE:-}" && -z "${OFFLINE:-}" ) ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  if ! self_release; then
    [[ -z "$force" ]] || c_warn "No release found for $GH_REPO on GitHub, or GitHub is not reachable"
    return 0
  fi
  if [[ "$(ver_cmp "$SELF_VER" "$VERSION")" != 1 ]]; then
    c_ok "The script is up to date (version $VERSION, latest release: $SELF_VER)"
    return 0
  fi
  c_warn "New version of the script: $SELF_VER (installed: $VERSION)"
  c_info "  $HOMEPAGE/releases/tag/$SELF_TAG"
  if [[ -z "${SELF_UPDATE:-}" ]] && ! ask_yes "Download and install it now?"; then
    c_info "Update skipped (SELF_UPDATE=1 installs it without asking, NO_SELF_UPDATE=1 stops the check)"
    return 0
  fi
  c_info "Updating the script to $SELF_VER"
  if git -C "$WORK_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    self_git_update || return 0
  else
    self_files_update || return 0
  fi
  c_ok "Script updated to $SELF_VER"
  [[ -z "${SELF_NO_RESTART:-}" ]] || { c_info "Run the script again to use the new version"; return 0; }
  c_info "Restarting$([[ $# -eq 0 ]] || echo ": $(basename "$SELF") $*")"
  echo
  export SELF_UPDATED=1
  exec "$SELF" "$@"
}

# -----------------------------------------------------------------------------
# Host prerequisites
# -----------------------------------------------------------------------------
pkg_install() {
  local pkgs=("$@") mgr
  for mgr in apt-get dnf pacman zypper ""; do command -v "$mgr" >/dev/null 2>&1 && break; done
  [[ -n "$mgr" ]] || die "No supported package manager found. Install manually: ${pkgs[*]}"
  [[ "$mgr" == apt-get ]] && pkgs=("${pkgs[@]/#xz/xz-utils}")
  c_info "Installing host packages with $mgr (sudo password may be asked): ${pkgs[*]}"
  case "$mgr" in
    apt-get) sudo apt-get update -qq && sudo apt-get install -y "${pkgs[@]}" ;;
    dnf)     sudo dnf install -y "${pkgs[@]}" ;;
    pacman)  sudo pacman -S --needed --noconfirm "${pkgs[@]}" ;;
    zypper)  sudo zypper --non-interactive install "${pkgs[@]}" ;;
  esac
}

ensure_host_tools() {
  local missing=() c
  for c in flatpak curl unzip tar xz; do command -v "$c" >/dev/null || missing+=("$c"); done
  command -v icotool >/dev/null && command -v wrestool >/dev/null || missing+=(icoutils)   # menu icons
  (( ${#missing[@]} == 0 )) || pkg_install "${missing[@]}"
  c_ok "Host tools: flatpak curl unzip tar xz icoutils"
}

ensure_bottles() {
  flatpak remotes --columns=name 2>/dev/null | grep -qx flathub \
    || flatpak remote-add --user --if-not-exists flathub "$FLATHUB_URL"
  if ! flatpak info "$APP_ID" >/dev/null 2>&1; then
    c_info "Installing Bottles and its runtimes from Flathub"
    run_visible "$LOG_DIR/bottles-install.log" flatpak install -y --user flathub "$APP_ID"
  elif [[ -z "${SKIP_UPDATE:-}" ]]; then
    c_info "Updating Bottles and its runtimes"
    run_visible "$LOG_DIR/bottles-update.log" flatpak update -y "$APP_ID" \
      || c_warn "Bottles update failed (log: $LOG_DIR/bottles-update.log), continuing"
  fi
  c_ok "Bottles $(flatpak info "$APP_ID" | sed -n 's/.*Version: //p')"

  flatpak override --user --filesystem="$DL_DIR" --filesystem="$WORK_DIR" --device=all "$APP_ID"
  c_ok "Flatpak permissions: $DL_DIR, USB/serial devices"

  if [[ -z "$(ls -A "$RUNNERS_DIR" 2>/dev/null)" || -z "$(ls -A "$BOTTLES_DATA/dxvk" 2>/dev/null)" ]]; then
    c_warn "Bottles first-run setup not done: complete the welcome wizard, then close Bottles."
    flatpak run "$APP_ID" >/dev/null 2>&1 &
    pause "Bottles first-run setup required."
    [[ -n "$(ls -A "$RUNNERS_DIR" 2>/dev/null)" ]] || die "No Wine runner in Bottles: complete its first-run setup."
  fi
}

ensure_dialout() {
  id -nG | tr ' ' '\n' | grep -qxE 'dialout|uucp' && return 0
  if getent group dialout | cut -d: -f4 | tr ',' '\n' | grep -qxF "$USER"; then
    c_warn "Added to 'dialout': log out and back in to use serial devices."
  elif ask_yes "Add $USER to the 'dialout' group (needed for USB/serial devices)?"; then
    sudo gpasswd -a "$USER" dialout || sudo usermod -aG dialout "$USER"
    c_ok "Added to 'dialout': log out and back in to use serial devices."
  else
    c_warn "Not in 'dialout': serial devices unavailable. Fix: sudo gpasswd -a \"$USER\" dialout"
  fi
}

# GNOME (Mutter) and Cinnamon (Muffin) report "not responding" after 5 s; Wine windows stay
# silent while the program is busy loading. KDE Plasma, XFCE and MATE check only on close.
tune_not_responding() {
  local want=$(( ${NOT_RESPONDING_TIMEOUT:-60} * 1000 )) de schema name cur
  de="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-${DESKTOP_SESSION:-}}}"; de="${de,,}"
  case "$de" in
    *cinnamon*)      schema=org.cinnamon.muffin; name=Cinnamon ;;
    *gnome*|ubuntu*) schema=org.gnome.mutter;    name=GNOME ;;
    *) return 0 ;;
  esac
  command -v gsettings >/dev/null && gsettings writable "$schema" check-alive-timeout >/dev/null 2>&1 || return 0
  cur="$(gsettings get "$schema" check-alive-timeout | awk '{ print $NF }')"
  [[ "$cur" != "$want" ]] && { (( want == 0 )) || (( cur != 0 && cur < want )); } || return 0
  [[ ! -f "$STATE_DIR/not-responding.declined" || -n "${NOT_RESPONDING_TIMEOUT:-}" ]] || return 0
  if ask_yes "Set $name's 'not responding' timeout to $(( want / 1000 )) s (now $(( cur / 1000 )) s; 0 = never)?"; then
    gsettings set "$schema" check-alive-timeout "$want"; c_ok "$name 'not responding' timeout: $(( want / 1000 )) s"
  elif is_tty; then
    touch "$STATE_DIR/not-responding.declined"
  fi
}

update_winetricks() {
  [[ -z "${SKIP_DEPS:-}" ]] || return 0
  if curl -fsSL -o "$WINETRICKS.new" "$WINETRICKS_URL"; then
    mv -f "$WINETRICKS.new" "$WINETRICKS"; chmod +x "$WINETRICKS"; c_ok "winetricks updated"
  elif [[ -x "$WINETRICKS" ]]; then c_warn "winetricks download failed, using the existing copy"
  else die "winetricks download failed"; fi
}

preflight() {
  step_begin preflight "Host prerequisites and Bottles"
  ensure_host_tools
  ensure_bottles
  ensure_dialout
  tune_not_responding
  update_winetricks
  step_end preflight
}

# -----------------------------------------------------------------------------
# Bottle setup
# -----------------------------------------------------------------------------
ensure_runner() {
  local name="$1" url="${RUNNER_URL[$1]:-}" tarball tmp top size
  [[ -x "$RUNNERS_DIR/$name/bin/wine" ]] && return 0
  [[ -n "$url" ]] || die "Runner $name missing: install it from Bottles → Preferences → Runners."
  tarball="$CACHE_DIR/$(basename "$url")"
  if [[ ! -s "$tarball" ]]; then
    size="$(http_size "$url")"
    c_info "Downloading runner $name ($(mb "$size"))"
    WATCH_FILE="$tarball.part" EXPECT_SIZE="$size" \
      run_live "$LOG_DIR/runner-$name.log" curl -fL --retry 3 -C - -o "$tarball.part" "$url"
    mv -f "$tarball.part" "$tarball"
  fi
  mkdir -p "$RUNNERS_DIR"; tmp="$(mktemp -d "$RUNNERS_DIR/.extract.XXXXXX")"
  run_live "$LOG_DIR/runner-$name.log" tar -xJf "$tarball" -C "$tmp"
  fix_perms "$tmp"
  top="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [[ -n "$top" ]] || { rm -rf "$tmp"; die "Runner $name: unexpected archive layout"; }
  [[ ! -e "$RUNNERS_DIR/$name" ]] || fix_perms "$RUNNERS_DIR/$name"
  rm -rf "${RUNNERS_DIR:?}/$name"; mv "$top" "$RUNNERS_DIR/$name"; rm -rf "$tmp"
  [[ -x "$RUNNERS_DIR/$name/bin/wine" ]] || die "Runner $name: bin/wine not found"
  c_ok "Runner $name installed"
}

apply_runner() {  # switch runner, keeping the prefix and its data
  local t="$1" b="${BOTTLE[$1]}" want="${RUNNER[$1]}" cur
  step_begin runner "$b: Wine runner $want"
  ensure_runner "$want"
  cur="$(runner_of "$b")"
  if [[ "$cur" == "$want" ]]; then
    c_ok "$b already uses $want"
  else
    wait_bottles_closed
    bcli edit -b "$b" --runner "$want" >>"$LOG_DIR/$b-edit.log" 2>&1 || true
    [[ "$(runner_of "$b")" == "$want" ]] || sed -i "s|^Runner:.*|Runner: $want|" "$BOTTLES_DIR/$b/bottle.yml"
    c_ok "$b: runner $cur → $want"
    run_live "$LOG_DIR/$b-wineboot.log" bsh "$b" 'wineboot -u; wineserver -w' || c_warn "wineboot reported errors"
    set_winver "$b"
  fi
  step_end runner
}

create_bottle() {
  local b="$1"
  step_begin create "$b: bottle"
  if bottle_exists "$b"; then
    c_ok "Bottle $b exists: reusing it"
  else
    if [[ -e "$BOTTLES_DIR/$b" ]]; then   # folder without bottle.yml: Bottles would create "$b__NNN"
      mv "$BOTTLES_DIR/$b" "$BOTTLES_DIR/$b.leftover-$(date +%Y%m%d-%H%M%S)"
      c_warn "$BOTTLES_DIR/$b was not a valid bottle: moved to $b.leftover-*"
    fi
    run_live "$LOG_DIR/$b-new.log" bcli new --bottle-name "$b" --environment application --arch win64
    bottle_exists "$b" || die "Bottles did not create $b (log: $LOG_DIR/$b-new.log)"
    wine_reg "$b" 'HKCU\Software\Wine\WineDbg' ShowCrashDialog REG_DWORD 0
    c_ok "Bottle $b created (Application, win64)"
  fi
  bcli edit -b "$b" --win "$WIN_VERSION" >>"$LOG_DIR/$b-edit.log" 2>&1 || true
  grep -q "^Windows: $WIN_VERSION" "$BOTTLES_DIR/$b/bottle.yml" || bottles_running \
    || sed -i "s/^Windows:.*/Windows: $WIN_VERSION/" "$BOTTLES_DIR/$b/bottle.yml"
  set_winver "$b"
  step_end create
}

pending_deps() {  # winetricks verbs still to install
  local b="${BOTTLE[$1]}" v out=()
  [[ -z "${SKIP_DEPS:-}" ]] || return 0
  [[ -z "${DEPS_ONLY:-}" ]] || { echo "$DEPS_ONLY"; return 0; }
  for v in $DEPS_DEFAULT; do
    if [[ -n "${FORCE_DEPS:-}" ]] || ! grep -qxF "$v" "$BOTTLES_DIR/$b/winetricks.log" 2>/dev/null \
       || { [[ "$v" == dotnet48 ]] && ! dotnet_ok "$b"; }; then out+=("$v"); fi
  done
  echo "${out[*]:-}"
}

install_deps() {  # one winetricks run per verb
  local b="$1" v failed=() force="" runner
  [[ -z "${FORCE_DEPS:-}${DEPS_ONLY:-}" ]] || force="--force"
  runner="$(deps_runner)"
  for v in $2; do
    step_begin "$v" "$b: dependency $v ($runner)"
    if BSH_RUNNER="$runner" run_live "$LOG_DIR/$b-winetricks-$v.log" bsh "$b" "\"$WINETRICKS\" --unattended $force $v" \
       && { [[ "$v" != dotnet48 ]] || dotnet_ok "$b"; }; then
      c_ok "$v installed"
    else
      c_warn "$v failed (log: $LOG_DIR/$b-winetricks-$v.log)"; failed+=("$v")
    fi
    step_end "$v"
  done
  set_winver "$b"   # winetricks may switch the Windows version
  (( ${#failed[@]} == 0 )) || c_warn "$b: failed: ${failed[*]}. Retry: DEPS_ONLY=\"${failed[*]}\" $0 <target>"
}

# COM ports: connected devices are mapped to COM1.. in HKLM\Software\Wine\Ports.
# /dev/serial/by-id names do not change with the USB port. The menu launcher
# repeats the mapping at every start, so the functions below must be self-contained.
com_devices() {  # connected serial devices, stable by-id names first
  local d r seen=" "
  if [[ -n "${COM_DEV:-}" ]]; then tr ',' '\n' <<<"$COM_DEV"; return; fi
  for d in /dev/serial/by-id/* /dev/ttyACM* /dev/ttyUSB*; do
    [[ -e "$d" ]] || continue
    r="$(readlink -f "$d")"; [[ "$seen" == *" $r "* ]] && continue
    seen+="$r "; echo "$d"
  done
}

com_sync() {  # <app> <prefix> <runners-dir> <state-file> <force>: prints the mapping if applied
  local devs=() runner reg="$2/comelit-ports.reg" i
  mapfile -t devs < <(com_devices)
  (( ${#devs[@]} )) || return 0
  [[ "$5" == 1 || "$(cat "$4" 2>/dev/null)" != "${devs[*]}" ]] || return 0
  {
    printf 'REGEDIT4\n\n[HKEY_LOCAL_MACHINE\\Software\\Wine\\Ports]\n'
    for i in 1 2 3 4 5 6 7 8; do
      if (( i <= ${#devs[@]} )); then printf '"COM%d"="%s"\n' "$i" "${devs[i-1]}"; else printf '"COM%d"=-\n' "$i"; fi
    done
  } >"$reg"
  runner="$(sed -n 's/^Runner:[[:space:]]*//p' "$2/bottle.yml" | tr -d "'\"")"
  # Wine reads the ports when it starts: wait for the session to end
  flatpak run --command=sh --env=WINEPREFIX="$2" --env=WINEDEBUG=-all "$1" \
    -c '"$1/wine" regedit /S "Z:$2"; "$1/wineserver" -w' sh "$3/$runner/bin" "$reg" >/dev/null 2>&1 || return 0
  echo "${devs[*]}" >"$4"
  for i in "${!devs[@]}"; do echo "COM$((i + 1)) → ${devs[i]}"; done
}

com_setup() {  # <bottle>: map the connected devices now
  local b="$1" l d out
  mkdir -p "$SHARE_DIR"
  out="$(com_sync "$APP_ID" "$BOTTLES_DIR/$b" "$RUNNERS_DIR" "$SHARE_DIR/$b.com" 1)"
  if [[ -n "$out" ]]; then
    while IFS= read -r l; do c_ok "$b: $l"; done <<<"$out"
    while IFS= read -r d; do
      [[ -r "$d" && -w "$d" ]] || c_warn "$b: no access to $d (dialout group, log out/in)"
    done < <(com_devices)
  else
    c_info "$b: no serial device connected: mapped automatically when started from the menu"
  fi
}
setup_serial() { step_begin serial "$1: COM ports"; com_setup "$1"; step_end serial; }

# -----------------------------------------------------------------------------
# Install / update
# -----------------------------------------------------------------------------
find_zip() {  # newest local zip: script folder, then ~/Downloads
  local d z
  for d in "$WORK_DIR" "$DL_DIR"; do
    z="$(find "$d" -maxdepth 1 \( -type f -o -type l \) -iname "${ZIP[$1]}" -printf '%T@ %p\n' 2>/dev/null \
         | sort -rn | head -1 | cut -d' ' -f2-)" || true
    [[ -n "$z" ]] && { echo "$z"; return 0; }
  done
  return 1
}
fingerprint() { stat -Lc '%n|%s|%Y' "$1" | sed 's#.*/##'; }

prepare_installer() {  # extract to installers/<program name>/, print the setup path
  local t="$1" zip="$2" dest="$WORK_DIR/installers/${TITLE[$1]}"
  if ! matches "$zip" '*.zip'; then echo "$zip"; return; fi   # an installer in versions/
  if [[ "$(cat "$dest/.from" 2>/dev/null)" != "$(fingerprint "$zip")" ]]; then
    [[ ! -e "$dest" ]] || fix_perms "$dest"
    rm -rf "$dest"; mkdir -p "$dest"
    c_info "Extracting $(basename "$zip")" >&2
    unzip -q -o "$zip" -d "$dest"
    fix_perms "$dest"
    fingerprint "$zip" >"$dest/.from"
  fi
  find "$dest" -type f -iname "${SETUP[$t]}" | head -1
}

# Specific versions: the zip or installer of a program in versions/ is the version to have
declare -A PIN_FILE PIN_VER PIN_OK PIN_ID
name_version() { grep -oE '[0-9]+(\.[0-9]+)+' <<<"$1" | head -1 || true; }
pe_version() {  # ProductVersion in the version resource of a Windows executable
  local h ms ls
  h="$(wrestool -x -t 16 "$1" 2>/dev/null | od -An -tx1 -v | tr -d ' \n')" || true
  [[ "$h" == *bd04effe* ]] || return 0
  h="${h#*bd04effe}"; (( ${#h} >= 40 )) || return 0
  ms=$(( 16#${h:30:2}${h:28:2}${h:26:2}${h:24:2} )); ls=$(( 16#${h:38:2}${h:36:2}${h:34:2}${h:32:2} ))
  echo "$(( ms >> 16 )).$(( ms & 65535 )).$(( ls >> 16 )).$(( ls & 65535 ))"
}
msi_version() {  # ProductVersion of an MSI (needs msiinfo, package msitools)
  command -v msiinfo >/dev/null || return 0
  { msiinfo export "$1" Property 2>/dev/null || true; } | tr -d '\r' | awk -F'\t' '$1 == "ProductVersion" { print $2; exit }'
}
zip_list() { unzip -Z1 "$1" 2>/dev/null | grep -v '/$' || true; }
pin_version() {  # <target> <zip or installer>: version from the names, the MSI or the exe (empty if unknown)
  local t="$1" f="$2" v="" e setup=""
  if matches "$f" '*.zip'; then
    while IFS= read -r e; do matches "$e" "${SETUP[$t]}" && { setup="$e"; break; }; done < <(zip_list "$f")
    v="$(name_version "$(basename "$setup")")"
    [[ -n "$v" ]] || v="$(name_version "$(basename "$f")")"
    [[ -n "$v" ]] || v="$(name_version "$(zip_list "$f" | sed 's#.*/##')")"   # e.g. the release notes
  else
    v="$(name_version "$(basename "$f")")"
    if [[ -z "$v" ]]; then if matches "$f" '*.msi'; then v="$(msi_version "$f")"; else v="$(pe_version "$f")"; fi; fi
    [[ -n "$v" ]] || v="$(name_version "${f#"$PIN_DIR"/}")"   # folder names
  fi
  echo "$v"
}
pin_scan() {  # <targets>: find each program's zip or installer in versions/ (one version only)
  local t f e i hit list vers
  for t in "$@"; do
    PIN_FILE[$t]=""; PIN_VER[$t]=""; PIN_ID[$t]=""; list=(); vers=()
    while IFS= read -r -d '' f; do
      hit=""
      if matches "$f" "${SETUP[$t]}"; then hit=1
      elif matches "$f" '*.zip'; then
        if matches "$f" "${ZIP[$t]}"; then hit=1
        else while IFS= read -r e; do matches "$e" "${SETUP[$t]}" && { hit=1; break; }; done < <(zip_list "$f"); fi
      fi
      [[ -z "$hit" ]] || { list+=("$f"); vers+=("$(pin_version "$t" "$f")"); }
    done < <(find "$PIN_DIR" -maxdepth 3 -type f \( -iname '*.zip' -o -iname '*.exe' -o -iname '*.msi' \) -print0 2>/dev/null | sort -z)
    (( ${#list[@]} )) || continue
    for i in "${!list[@]}"; do
      (( ${#list[@]} == 1 )) || { [[ -n "${vers[$i]}" ]] && same_version "${vers[$i]}" "${vers[0]}"; } \
        || die "${TITLE[$t]}: more than one version in $PIN_DIR, keep only one:$(printf '\n  %s' "${list[@]#"$PIN_DIR"/}")"
    done
    PIN_FILE[$t]="${list[0]}"; PIN_VER[$t]="${vers[0]}"
    for i in "${!list[@]}"; do   # the same version as zip and installer: use the installer
      matches "${list[$i]}" '*.zip' || { PIN_FILE[$t]="${list[$i]}"; PIN_VER[$t]="${vers[$i]}"; break; }
    done
  done
}
pin_hash() {  # <target>: sets PIN_ID, the checksum of the file in versions/
  [[ -n "${PIN_ID[$1]:-}" ]] || PIN_ID[$1]="$(sha256sum "${PIN_FILE[$1]}" | cut -d' ' -f1)"
}
pin_same_file() {  # <target>: the file in versions/ is the one installed last
  local t="$1" s f
  if [[ -f "$STATE_DIR/$t.pin" ]]; then pin_hash "$t"; [[ "$(cat "$STATE_DIR/$t.pin")" == "${PIN_ID[$t]}" ]]; return; fi
  s="$(cat "$STATE_DIR/$t.state" 2>/dev/null)"; f="$(fingerprint "${PIN_FILE[$t]}")"
  [[ -n "$s" && "${s%|*}" == "${f%|*}" ]]   # same zip as installed from Comelit Pro: name and size
}
pin_action() {  # <target>: install | update | downgrade | reinstall | replace | none | declined
  local t="$1" inst
  ZIPFILE[$t]="${PIN_FILE[$t]}"
  inst="$(version_of "$t")"
  if ! bottle_exists "${BOTTLE[$t]}" || [[ -z "$(installed_exe "$t")" ]]; then ACTION[$t]=install
  elif [[ -n "${PIN_VER[$t]}" && -n "$inst" ]]; then
    case "$(ver_cmp "${PIN_VER[$t]}" "$inst")" in
      0) if pin_same_file "$t"; then ACTION[$t]=none; else ACTION[$t]=reinstall; fi ;;   # e.g. a rebuilt setup
      1) ACTION[$t]=update ;;
      *) ACTION[$t]=downgrade ;;
    esac
  elif pin_same_file "$t"; then ACTION[$t]=none
  else ACTION[$t]=replace; fi   # version unknown
  [[ "${ACTION[$t]}" != none || -z "${REINSTALL:-}" ]] || ACTION[$t]=reinstall
  [[ ! "${ACTION[$t]}" =~ ^(downgrade|replace)$ || "${PIN_OK[$t]:-}" != no ]] || ACTION[$t]=declined
}
pin_msg() {  # <target>: what happens with the version in versions/
  local t="$1" inst; inst="$(version_of "$t")"
  pin_action "$t"
  printf 'versions/%s (%s): ' "${PIN_FILE[$t]#"$PIN_DIR"/}" "${PIN_VER[$t]:-version not detected}"
  case "${ACTION[$t]}" in
    install)   echo "to install" ;;
    none)      echo "installed" ;;
    update)    echo "UPDATE from $inst" ;;
    downgrade) echo "DOWNGRADE from $inst (asks first)" ;;
    reinstall) if [[ -n "${REINSTALL:-}" ]]; then echo "REINSTALL of $inst"
               else echo "REINSTALL of $inst (different installer, same version)"; fi ;;
    replace)   echo "replaces $inst (asks first)" ;;
    declined)  echo "$inst kept" ;;
  esac
}
pin_confirm() {  # <target>: a downgrade, or an installer of unknown version, asks first
  local t="$1" inst rel
  [[ -n "${PIN_FILE[$t]:-}" ]] || return 0
  pin_action "$t"
  [[ "${ACTION[$t]}" == downgrade || "${ACTION[$t]}" == replace ]] || return 0
  inst="$(version_of "$t")"; rel="versions/${PIN_FILE[$t]#"$PIN_DIR"/}"
  echo
  if [[ "${ACTION[$t]}" == downgrade ]]; then
    c_warn "${TITLE[$t]}: DOWNGRADE from $inst to ${PIN_VER[$t]} ($rel)"
  else
    c_warn "${TITLE[$t]}: version of $rel not detected: it replaces $inst"
    if matches "$rel" '*.msi' && ! command -v msiinfo >/dev/null; then c_warn "  (install msitools to read MSI versions)"; fi
  fi
  c_warn "  $inst is removed first; an older version may not read data saved by a newer one."
  if [[ -n "${NO_BACKUP:-}" ]]; then c_warn "  NO_BACKUP is set: no backup of the bottle."
  else c_warn "  The bottle is backed up first: --restore goes back."; fi
  if [[ -n "${ALLOW_DOWNGRADE:-}" ]] || ask_yes "  Continue?"; then PIN_OK[$t]=yes
  else
    PIN_OK[$t]=no
    if is_tty; then c_info "${TITLE[$t]}: $inst kept"; else c_info "${TITLE[$t]}: $inst kept (ALLOW_DOWNGRADE=1 to allow it)"; fi
  fi
}
declare -A OFFICIAL
newer_confirm() {  # <target>: installed version newer than the official release
  local t="$1" inst keep="$STATE_DIR/$1.keep"
  [[ "${R_STATUS[$t]}" == newer ]] || return 0
  inst="$(version_of "$t")"
  if [[ -z "${ALLOW_DOWNGRADE:-}" ]]; then
    is_tty && [[ "$(cat "$keep" 2>/dev/null)" != "$inst" ]] || return 0   # asked once per installed version
  fi
  echo
  c_warn "${TITLE[$t]}: installed $inst is newer than the official release ${R_VER[$t]} on Comelit Pro"
  c_warn "  Downgrading removes $inst first; an older version may not read data saved by a newer one."
  if [[ -n "${NO_BACKUP:-}" ]]; then c_warn "  NO_BACKUP is set: no backup of the bottle."
  else c_warn "  The bottle is backed up first: --restore goes back."; fi
  if [[ -n "${ALLOW_DOWNGRADE:-}" ]] || ask_yes "  Downgrade to the official ${R_VER[$t]}?"; then
    OFFICIAL[$t]=1; rm -f "$keep"
    if [[ -n "${R_LOCAL[$t]}" ]]; then R_STATUS[$t]=downloaded; else R_STATUS[$t]=new; fi
  else
    echo "$inst" >"$keep"
    c_info "${TITLE[$t]}: $inst kept (asked again when the installed version changes; ALLOW_DOWNGRADE=1 to downgrade)"
  fi
}
uninstall_program() {  # <target>: remove the installed version (msiexec /x <ProductCode>)
  local t="$1" code; code="$(msi_product_code "$t")"
  if [[ -z "$code" ]]; then c_warn "${TITLE[$t]}: product code not found, installing over the current version"; return 0; fi
  c_info "${TITLE[$t]}: removing $(version_of "$t") ($code)"
  BSH_RUNNER="$(deps_runner)" run_live "$LOG_DIR/$t-uninstall.log" bsh "${BOTTLE[$t]}" "wine msiexec /x \"$code\" /qn; wineserver -w" \
    || c_warn "${TITLE[$t]}: uninstaller error (log: $LOG_DIR/$t-uninstall.log)"
}

declare -A ACTION ZIPFILE
decide_action() {  # install | update | downgrade | reinstall | replace | none | declined | missing
  local t="$1" state="$STATE_DIR/$1.state" zip zv=""
  if [[ -n "${PIN_FILE[$t]:-}" ]]; then pin_action "$t"; return; fi
  if [[ -n "${OFFICIAL[$t]:-}" ]]; then   # confirmed downgrade to the official release
    ZIPFILE[$t]="${R_LOCAL[$t]}"
    if [[ -n "${ZIPFILE[$t]}" ]]; then ACTION[$t]=downgrade; else ACTION[$t]=declined; fi
    return
  fi
  zip="$(find_zip "$t")" || zip=""
  ZIPFILE[$t]="$zip"
  if ! bottle_exists "${BOTTLE[$t]}" || [[ -z "$(installed_exe "$t")" ]]; then
    ACTION[$t]=$([[ -n "$zip" ]] && echo install || echo missing); return
  fi
  [[ -z "$zip" ]] || zv="$(pin_version "$t" "$zip")"
  if [[ -z "$zip" ]]; then ACTION[$t]=none
  elif [[ -n "${REINSTALL:-}" ]]; then ACTION[$t]=update
  elif [[ -n "$zv" ]] && [[ "$(ver_cmp "$zv" "$(version_of "$t")")" != 1 ]]; then   # not newer (e.g. after versions/)
    [[ -f "$state" ]] || fingerprint "$zip" >"$state"; ACTION[$t]=none
  elif [[ ! -f "$state" ]]; then   # untracked install (older script, restore): compare versions
    if [[ -n "${R_VER[$t]:-}" ]] && ! same_version "$(version_of "$t")" "${R_VER[$t]}"; then ACTION[$t]=update
    else fingerprint "$zip" >"$state"; ACTION[$t]=none; fi
  elif [[ "$(cat "$state")" != "$(fingerprint "$zip")" ]]; then ACTION[$t]=update
  else ACTION[$t]=none; fi
}

# Full bottle backup: programs share registry, users and ProgramData, so only
# a snapshot of the whole bottle can be restored consistently.
backup_bottle() {
  local b="$1" file comp="gzip" ext="gz"
  if command -v zstd >/dev/null; then comp="zstd -T0 -3"; ext="zst"; fi
  file="$BACKUP_DIR/$b-$(date +%Y%m%d-%H%M%S).tar.$ext"
  wait_bottles_closed
  WATCH_FILE="$file" run_live "$LOG_DIR/$b-backup.log" tar --use-compress-program="$comp" -cf "$file" \
    -C "$BOTTLES_DIR" --exclude="$b/drive_c/users/*/AppData/Local/Temp" --exclude="$b/drive_c/windows/temp" \
    --exclude="$b/drive_c/ProgramData/Package Cache" "$b"
  c_ok "$b: backup → $(basename "$file") ($(du -h "$file" | cut -f1))"
  ls -1t "$BACKUP_DIR/$b-"[0-9]*.tar.* 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f || true
}

backup_before_update() {  # once per bottle and run
  local b="$1"
  [[ -z "${BACKED_UP[$b]:-}" ]] || return 0
  BACKED_UP[$b]=1
  step_begin backup "$b: backup before update"
  if [[ -n "${NO_BACKUP:-}" ]]; then c_warn "NO_BACKUP: skipped"; else backup_bottle "$b"; fi
  step_end backup
}

restore_bottle() {  # <backup-file>: the current bottle is renamed, not deleted
  local file="$1" b old t
  [[ -f "$file" ]] || die "Backup not found: $file"
  b="$(tar -tf "$file" 2>/dev/null | head -1 | cut -d/ -f1)" || true
  [[ -n "$b" ]] || die "Not a bottle backup: $file"
  ask_yes "Restore bottle $b from $(basename "$file")?" || die "Restore cancelled"
  wait_bottles_closed
  if bottle_exists "$b"; then
    old="$BOTTLES_DIR/$b.before-restore-$(date +%Y%m%d-%H%M%S)"
    mv "$BOTTLES_DIR/$b" "$old"; c_info "Current bottle kept in $old"
  fi
  run_live "$LOG_DIR/$b-restore.log" tar -xaf "$file" -C "$BOTTLES_DIR"
  for t in "${ALL_TARGETS[@]}"; do [[ "${BOTTLE[$t]}" != "$b" ]] || rm -f "$STATE_DIR/$t.state" "$STATE_DIR/$t.pin"; done
  c_ok "$b restored from $(basename "$file")"
}

setup_args() { [[ -n "${SETUP_WIZARD:-}" ]] || echo "${SILENT_ARGS[$1]:-}"; }

msi_install() {  # <target> <msi> <mode>
  local t="$1" b="${BOTTLE[$1]}" msi="$2" code
  local cmd="wine msiexec /i \"$msi\" $(setup_args "$t") /l*v \"Z:$LOG_DIR/$t-msi.log\"; wineserver -w"
  BSH_RUNNER="$(deps_runner)" run_live "$LOG_DIR/$t-install.log" bsh "$b" "$cmd" || true
  # Same ProductCode already installed (1638): remove it, then install again
  [[ "$3" == update ]] && tr -d '\0' <"$LOG_DIR/$t-msi.log" 2>/dev/null | grep -qE 'Error 1638|returning 1638' || return 0
  code="$(msi_product_code "$t")"; [[ -n "$code" ]] || return 0
  c_info "${TITLE[$t]}: removing previous version $code"
  BSH_RUNNER="$(deps_runner)" run_live "$LOG_DIR/$t-uninstall.log" bsh "$b" "wine msiexec /x \"$code\" /qb; wineserver -w" || true
  BSH_RUNNER="$(deps_runner)" run_live "$LOG_DIR/$t-install.log" bsh "$b" "$cmd" || true
}

run_installer() {  # <target> <install|update|downgrade|reinstall|replace>
  local t="$1" mode="$2" b="${BOTTLE[$1]}" setup old
  step_begin "$mode" "${TITLE[$t]}: $mode program"
  setup="$(prepare_installer "$t" "${ZIPFILE[$t]}")"
  if [[ -z "$setup" ]]; then
    c_warn "${TITLE[$t]}: ${SETUP[$t]} not found in $(basename "${ZIPFILE[$t]}")"; step_end "$mode"; return
  fi
  old="$(version_of "$t")"
  if [[ "$mode" =~ ^(downgrade|reinstall|replace)$ ]]; then uninstall_program "$t"; fi
  if [[ -n "${SETUP_WIZARD:-}" ]]; then c_info "${TITLE[$t]}: running $(basename "$setup")${old:+ (installed: $old)}: complete the wizard"
  else c_info "${TITLE[$t]}: installing $(basename "$setup") unattended${old:+ (installed: $old)}"; fi
  if matches "$setup" '*.msi'; then msi_install "$t" "$setup" "$mode"
  else BSH_RUNNER="$(deps_runner)" run_live "$LOG_DIR/$t-install.log" \
         bsh "$b" "cd \"$(dirname "$setup")\" && wine \"$(basename "$setup")\" $(setup_args "$t"); wineserver -w" \
         || c_warn "${TITLE[$t]}: installer error (log: $LOG_DIR/$t-install.log)"; fi
  c_info "${TITLE[$t]}: waiting for Wine to exit (close the program if it opened)"
  BSH_RUNNER="$(deps_runner)" run_live "$LOG_DIR/$t-wait.log" bsh "$b" 'wineserver -w' || true
  if [[ -n "$(installed_exe "$t")" ]]; then
    fingerprint "${ZIPFILE[$t]}" >"$STATE_DIR/$t.state"
    if [[ -n "${PIN_FILE[$t]:-}" ]]; then pin_hash "$t"; echo "${PIN_ID[$t]}" >"$STATE_DIR/$t.pin"
    else rm -f "$STATE_DIR/$t.pin"; fi
    rm -f "$STATE_DIR/$t.keep"
    c_ok "${TITLE[$t]}: $(version_of "$t") installed"
    cleanup_zips "$t"
  else
    c_warn "${TITLE[$t]}: program not found after the installer (log: $LOG_DIR/$t-install.log)"
  fi
  register_program "$t"
  step_end "$mode"
}

lnk_points_to() {  # a Start Menu .lnk targets <exe name> (ASCII or UTF-16)
  local root="$1" base="$2" u16 l
  u16="$(printf '%s' "$base" | sed 's/[.]/\\./g; s/\(\\\?.\)/\1\\x00/g')"
  while IFS= read -r -d '' l; do
    if grep -aqiF "$base" "$l" || LC_ALL=C grep -aqiP "$u16" "$l"; then return 0; fi
  done < <(find "$root/ProgramData/Microsoft/Windows/Start Menu" \
                "$root"/users/*/AppData/Roaming/Microsoft/Windows/Start\ Menu -iname '*.lnk' -print0 2>/dev/null || true)
  return 1
}

register_program() {  # only if Bottles does not list it already
  local t="$1" b="${BOTTLE[$1]}" bdir="$BOTTLES_DIR/${BOTTLE[$1]}" exe name
  exe="$(installed_exe "$t")"
  [[ -n "$exe" ]] || { c_warn "${TITLE[$t]}: executable not found: add it from Bottles → Programs"; return; }
  name="$(basename "$exe" .exe)"
  if grep -qiF "executable: $name.exe" "$bdir/bottle.yml" || lnk_points_to "$bdir/drive_c" "$name.exe"; then
    c_ok "${TITLE[$t]}: $name listed in Bottles"
  elif bcli add -b "$b" -n "$name" -p "$exe" >>"$LOG_DIR/$t-add.log" 2>&1; then
    c_ok "${TITLE[$t]}: $name added to Bottles"
  fi
  [[ -n "${NO_MENU:-}" ]] || menu_entry "$t" "$exe"
}

menu_icon() {  # <target> <exe>: PNG from the exe icon (or an .ico next to it), else Bottles icon
  local t="$1" exe="$2" out="$SHARE_DIR/icons/$1.png" tmp ico png
  command -v icotool >/dev/null || { echo "$APP_ID"; return; }
  mkdir -p "$SHARE_DIR/icons"; tmp="$(mktemp -d)"
  command -v wrestool >/dev/null && wrestool -x -t 14 -o "$tmp" "$exe" 2>/dev/null || true
  ico="$(ls -S "$tmp"/*.ico 2>/dev/null | head -1)" || true
  [[ -n "$ico" ]] || ico="$(find "$(dirname "$exe")" -maxdepth 1 -iname '*.ico' | head -1)" || true
  if [[ -n "$ico" ]] && icotool -x -o "$tmp" "$ico" 2>/dev/null; then
    # largest image up to 256 px (some menus do not show bigger icons)
    png="$(ls "$tmp"/*.png 2>/dev/null | awk -F_ '{ split($NF, a, "x"); w = a[1] + 0
             print (w <= 256 ? 100000000 : 0) + w * 1000 + a[3], $0 }' | sort -n | tail -1 | cut -d' ' -f2-)" || true
  fi
  if [[ -n "${png:-}" ]]; then cp -f "$png" "$out"; echo "$out"; else echo "$APP_ID"; fi
  rm -rf "$tmp"
}

menu_entry() {  # <target> <exe>: launcher + .desktop in the host applications menu
  local t="$1" exe="$2" b="${BOTTLE[$1]}" launcher desktop
  launcher="$SHARE_DIR/comelit-$t.sh"; desktop="$APPS_DIR/comelit-$t.desktop"
  mkdir -p "$SHARE_DIR" "$APPS_DIR"
  {
    echo '#!/bin/bash'
    echo '# Generated by setup-comelit-bottles.sh'
    printf 'app=%q\nbottle=%q\ntitle=%q\ndir=%q\nexe=%q\n' "$APP_ID" "$b" "${TITLE[$t]}" "$(dirname "$exe")" "$exe"
    if (( SERIAL[$t] )); then
      declare -f com_devices com_sync
      printf 'msg="$(com_sync "$app" %q %q %q 0)"\n' "$BOTTLES_DIR/$b" "$RUNNERS_DIR" "$SHARE_DIR/$b.com"
      echo '[[ -z "$msg" ]] || ! command -v notify-send >/dev/null || notify-send "$title" "$msg"'
    fi
    # start from the program folder (relative paths), through Bottles
    echo 'exec flatpak run --command=sh "$app" -c '\''cd "$1" && exec bottles-cli run -b "$2" -e "$3"'\'' sh "$dir" "$bottle" "$exe"'
  } >"$launcher"
  chmod +x "$launcher"
  cat >"$desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=${TITLE[$t]}
Comment=${TITLE[$t]} (Bottles: $b)
Exec="$launcher"
Icon=$(menu_icon "$t" "$exe")
Terminal=false
Categories=Utility;
StartupWMClass=$(basename "$exe" | tr '[:upper:]' '[:lower:]')
DESKTOP
  command -v update-desktop-database >/dev/null && update-desktop-database "$APPS_DIR" 2>/dev/null || true
  c_ok "${TITLE[$t]}: menu entry \"${TITLE[$t]}\""
}

# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------
diagnose() {
  local t="$1" b="${BOTTLE[$1]}" exe log
  exe="$(installed_exe "$t")"; [[ -n "$exe" ]] || die "${TITLE[$t]}: program not installed"
  log="$LOG_DIR/$t-diagnose-$(date +%Y%m%d-%H%M%S).log"
  c_info "${TITLE[$t]}: starting $(basename "$exe") with debug log (close it to finish)"
  WINEDEBUG="+seh,err+all" run_live "$log" \
    bsh "$b" "cd \"$(dirname "$exe")\" && wine \"$(basename "$exe")\"; wineserver -w" || true
  c_ok "Log: $log"
  if grep -q '^Unhandled Exception' "$log"; then
    c_warn "Unhandled .NET exception:"; grep -A14 '^Unhandled Exception' "$log" | head -16 || true
  else c_ok "No unhandled .NET exception"; fi
}

net_report() {  # <target>
  local b="${BOTTLE[$1]}" v
  echo "== Host IPv4 interfaces"; { ip -4 -br addr 2>/dev/null || true; } | grep -v '^lo ' || true
  echo "== Default route"; ip route show default 2>/dev/null || true
  echo "== Firewall services"
  for v in ufw firewalld nftables iptables; do
    systemctl is-active --quiet "$v" 2>/dev/null && echo "$v: active"
  done
  echo "== Lowest port usable without root (TFTP/SNMP servers need <= 69; Linux default 1024)"
  sysctl -n net.ipv4.ip_unprivileged_port_start 2>/dev/null || cat /proc/sys/net/ipv4/ip_unprivileged_port_start 2>/dev/null || true
  bottle_exists "$b" || return 0
  echo "== Adapters seen by Wine ($b)"
  bsh "$b" 'wine ipconfig /all' 2>/dev/null | tr -d '\r' | grep -E 'adapter|IPv4|IP address|Subnet|Gateway|Description' || true
}

status() {
  local t b
  pin_scan "${ALL_TARGETS[@]}"
  printf '%-12s %-20s %-33s %-10s %s\n' TARGET BOTTLE RUNNER INSTALLED "LOCAL ZIP"
  for t in "${ALL_TARGETS[@]}"; do
    b="${BOTTLE[$t]}"
    printf '%-12s %-20s %-33s %-10s %s\n' "$t" "$b" "$(bottle_exists "$b" && runner_of "$b" || echo -)" \
      "$(version_of "$t")" "${PIN_FILE[$t]:+versions/${PIN_FILE[$t]#"$PIN_DIR"/}}$([[ -n "${PIN_FILE[$t]}" ]] || basename "$(find_zip "$t" || echo -)")"
  done
}

remote_msg() {  # one-line status of remote_check for <target>
  local t="$1" inst; inst="$(version_of "$t")"
  case "${R_STATUS[$t]}" in
    pinned)      pin_msg "$t" ;;
    offline)     echo "online check disabled" ;;
    unreachable) echo "Comelit Pro not reachable" ;;
    not-found)   echo "zip not found on ${PAGE[$t]}" ;;
    current)     echo "up to date" ;;
    newer)       if [[ "$(cat "$STATE_DIR/$t.keep" 2>/dev/null)" == "$inst" ]]; then echo "newer than the official release: kept"
                 else echo "NEWER than the official release (asks to downgrade)"; fi ;;
    downloaded)  [[ -n "$inst" ]] && echo "downloaded, ready to install" || echo "downloaded, not installed" ;;
    new)         [[ -n "$inst" ]] && echo "UPDATE AVAILABLE" || echo "available, not installed" ;;
  esac
}

check_updates() {
  local t
  pin_scan "${ALL_TARGETS[@]}"
  printf '%-12s %-10s %-22s %-8s %s\n' TARGET INSTALLED "COMELIT PRO" SIZE STATUS
  for t in "${ALL_TARGETS[@]}"; do
    remote_check "$t"
    printf '%-12s %-10s %-22s %-8s %s\n' "$t" "$(version_of "$t" | grep . || echo -)" \
      "${R_VER[$t]:+${R_VER[$t]} (${R_DATE[$t]})}" "$( (( R_SIZE[$t] > 0 )) && mb "${R_SIZE[$t]}")" "$(remote_msg "$t")"
  done
}

# Title, version, authors and license come from version(): the header comment has the
# description and the usage, from the line after the title and the file name.
usage() { version; echo; sed -n '5,/^# ====/p' "$0" | sed '$d' | sed -E 's/^#( {1,2}|$)//'; }

version() {  # header of the script: also the banner of every run
  printf '\e[1m%s %s (%s)\e[0m\n' "$TITLE" "$VERSION" "$RELEASE_DATE"
  printf 'Script: %s\n' "$(basename "${BASH_SOURCE[0]}")"
  printf 'Authors: %s\n' "$AUTHORS"
  printf 'License: MIT (see LICENSE)\n'
  printf 'Homepage: %s\n' "$HOMEPAGE"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
# Bottle-level steps (create, dependencies, COM ports, runner) run once per bottle
declare -A TDEPS PLANNED READY BACKUP_PLANNED BACKED_UP BROKEN SWITCHED
bottle_serial() {  # any program of the bottle uses serial ports
  local t; for t in "${ALL_TARGETS[@]}"; do [[ "${BOTTLE[$t]}" == "$1" ]] && (( SERIAL[$t] )) && return 0; done; return 1
}

plan_target() {
  local t="$1" b="${BOTTLE[$1]}" v
  decide_action "$t"
  if [[ "${R_STATUS[$t]}" == new ]]; then
    WEIGHT[download_$t]=$(( R_SIZE[$t] / 52428800 + 1 )); plan "download_$t"
    if [[ -n "${OFFICIAL[$t]:-}" ]]; then ACTION[$t]=downgrade
    else ACTION[$t]=$([[ -n "$(installed_exe "$t")" ]] && echo update || echo install); fi
  fi
  if [[ -z "${PLANNED[$b]:-}" ]]; then
    PLANNED[$b]=1; TDEPS[$b]="$(pending_deps "$t")"
    plan create
    [[ -z "${RUNNER[$t]}" ]] || plan runner
    for v in ${TDEPS[$b]}; do plan "$v"; done
    ! bottle_serial "$b" || plan serial
  fi
  if [[ "${ACTION[$t]}" =~ ^(update|downgrade|reinstall|replace)$ && -z "${BACKUP_PLANNED[$b]:-}" ]]; then
    BACKUP_PLANNED[$b]=1; plan backup
  fi
  case "${ACTION[$t]}" in install|update|downgrade|reinstall|replace) plan "${ACTION[$t]}" ;; esac
}

prepare_bottle() {  # create, dependencies (deps runner), COM ports; the Wine runner is set at the end
  local t="$1" b="${BOTTLE[$1]}" old v
  [[ -z "${READY[$b]:-}" ]] || return 0
  READY[$b]=1
  if bottle_exists "$b" && [[ " $DEPS_DEFAULT " == *" dotnet48 "* ]] && ! dotnet_ok "$b" && ! bottle_has_programs "$b" \
     && [[ -f "$BOTTLES_DIR/$b/winetricks.log" ]] && ask_yes "Bottle $b has a failed .NET installation and no programs: recreate it?"; then
    old="$BOTTLES_DIR/$b.broken-$(date +%Y%m%d-%H%M%S)"; wait_bottles_closed; mv "$BOTTLES_DIR/$b" "$old"
    c_info "$b moved to $old (delete it when no longer needed)"
    for v in $(pending_deps "$t"); do [[ " ${TDEPS[$b]} " == *" $v "* ]] || plan "$v"; done
    TDEPS[$b]="$(pending_deps "$t")"
  fi
  create_bottle "$b"
  if [[ -n "${TDEPS[$b]}" ]]; then install_deps "$b" "${TDEPS[$b]}"; else c_ok "$b: dependencies installed"; fi
  ! dotnet_ok "$b" || dotnet_host_config "$b"
  set_virtual_desktop "$b"
  ! bottle_serial "$b" || setup_serial "$b"
  if [[ " $DEPS_DEFAULT " == *" dotnet48 "* ]] && ! dotnet_ok "$b"; then
    BROKEN[$b]=1
    c_err "$b: .NET Framework 4.8 is not installed (log: $LOG_DIR/$b-winetricks-dotnet48.log): programs skipped."
    c_err "Delete the bottle $b in Bottles and run the script again."
  fi
}

run_target() {
  local t="$1" b="${BOTTLE[$1]}"
  echo; c_info "===== ${TITLE[$t]} ====="; progress_bar
  [[ "${R_STATUS[$t]}" != new ]] || download_zip "$t"
  decide_action "$t"
  if [[ "${ACTION[$t]}" == missing ]]; then
    c_warn "${TITLE[$t]}: no installer (Comelit Pro unavailable, no ${ZIP[$t]} in $WORK_DIR or $DL_DIR): skipped"; return
  fi
  prepare_bottle "$t"
  [[ -z "${BROKEN[$b]:-}" ]] || return 0
  case "${ACTION[$t]}" in
    install) run_installer "$t" install ;;
    update|downgrade|reinstall|replace) backup_before_update "$b"; run_installer "$t" "${ACTION[$t]}" ;;
    declined) c_warn "${TITLE[$t]}: $(version_of "$t") kept"; register_program "$t" ;;
    none)
      if [[ -n "${PIN_FILE[$t]:-}" ]]; then
        c_ok "${TITLE[$t]}: $(version_of "$t") installed, as in versions/"
        [[ -f "$STATE_DIR/$t.pin" ]] || { pin_hash "$t"; echo "${PIN_ID[$t]}" >"$STATE_DIR/$t.pin"; }
      elif [[ "${R_STATUS[$t]}" == newer ]]; then c_ok "${TITLE[$t]}: $(version_of "$t") kept (official release: ${R_VER[$t]})"
      else c_ok "${TITLE[$t]}: $(version_of "$t") is up to date"; fi
      register_program "$t" ;;
  esac
}

main() {
  local cmd=install targets=() t t0
  if [[ ! "${1:-}" =~ ^(-h|--help|-V|--version)$ ]]; then   # --help and --version print their own
    version; echo
    case "${1:-}" in
      --self-update) FORCE_SELF_UPDATE=1 SELF_NO_RESTART=1 self_update; exit 0 ;;
      *) self_update "$@" ;;
    esac
  fi
  while (( $# )); do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      -V|--version) version; exit 0 ;;
      --status)  status; exit 0 ;;
      --check)   check_updates; exit 0 ;;
      --diagnose) cmd=diagnose ;;
      --com)     cmd=com ;;
      --backup)  cmd=backup ;;
      --net)     cmd=net ;;
      --restore) shift; (( $# )) || die "Usage: --restore <backup-file>"; restore_bottle "$1"; exit 0 ;;
      --self-update) FORCE_SELF_UPDATE=1 SELF_NO_RESTART=1 self_update; exit 0 ;;
      *) targets+=("$1") ;;
    esac
    shift
  done
  (( ${#targets[@]} )) || targets=("${ALL_TARGETS[@]}")
  for t in "${targets[@]}"; do
    [[ -n "${BOTTLE[$t]:-}" ]] || die "Unknown target: $t (vipmanager, safemanager, simpleprog)"
  done
  if [[ "$cmd" == diagnose ]]; then for t in "${targets[@]}"; do diagnose "$t"; done; exit 0; fi
  if [[ "$cmd" == com ]]; then
    for t in "${targets[@]}"; do
      (( SERIAL[$t] )) && bottle_exists "${BOTTLE[$t]}" && [[ -z "${READY[${BOTTLE[$t]}]:-}" ]] || continue
      READY[${BOTTLE[$t]}]=1; com_setup "${BOTTLE[$t]}"
    done
    exit 0
  fi
  if [[ "$cmd" == net ]]; then net_report "${targets[0]}"; exit 0; fi
  if [[ "$cmd" == backup ]]; then
    for t in "${targets[@]}"; do
      bottle_exists "${BOTTLE[$t]}" && [[ -z "${BACKED_UP[${BOTTLE[$t]}]:-}" ]] || continue
      BACKED_UP[${BOTTLE[$t]}]=1; backup_bottle "${BOTTLE[$t]}"
    done
    exit 0
  fi

  pin_scan "${targets[@]}"
  for t in "${targets[@]}"; do
    [[ -n "${PIN_FILE[$t]}" || -n "${OFFLINE:-}" ]] || { c_info "Checking Comelit Pro"; break; }
  done
  for t in "${targets[@]}"; do
    remote_check "$t"
    [[ "${R_STATUS[$t]}" == offline ]] || c_info "  $t: ${R_VER[$t]:+rel. ${R_VER[$t]} (${R_DATE[$t]}) }$(remote_msg "$t")"
  done
  for t in "${targets[@]}"; do pin_confirm "$t"; newer_confirm "$t"; done

  plan preflight
  for t in "${targets[@]}"; do plan_target "$t"; done
  t0=$SECONDS
  preflight
  for t in "${targets[@]}"; do run_target "$t"; done
  for t in "${targets[@]}"; do   # switch to the runtime runner once the programs are installed
    if [[ -n "${READY[${BOTTLE[$t]}]:-}" && -z "${BROKEN[${BOTTLE[$t]}]:-}" && -n "${RUNNER[$t]}" \
          && -z "${SWITCHED[${BOTTLE[$t]}]:-}" ]]; then
      SWITCHED[${BOTTLE[$t]}]=1; echo; apply_runner "$t"
    fi
  done
  DONE_W=$TOTAL_W; echo; progress_bar
  c_ok "Done in $(fmt_time $((SECONDS - t0))). Logs in $LOG_DIR"
  echo; status
}
main "$@"
