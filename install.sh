#!/usr/bin/env sh
# git-sweep-branches installer.
#
#   curl -fsSL https://raw.githubusercontent.com/Ahmed-Bitcall/git-sweep-branches/main/install.sh | sh
#
# Options (environment variables):
#   INSTALL_DIR=~/bin      where to put the executable (default: ~/.local/bin)
#   VERSION=v1.1.0         tag/branch to install (default: main)
#   GSB_NO_PATH_EDIT=1     never offer to edit your shell rc file
#
#   ... | sh -s -- --uninstall     remove the executable and print what is left
#
# POSIX sh on purpose: it runs before we know anything about the user's shell.

set -eu

REPO="Ahmed-Bitcall/git-sweep-branches"
VERSION="${VERSION:-main}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
BIN="git-sweep-branches"
RAW="https://raw.githubusercontent.com/$REPO/$VERSION/bin/$BIN"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/git-sweep-branches"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/git-sweep-branches"

if [ -t 1 ]; then
  B=$(printf '\033[1m'); D=$(printf '\033[2m'); G=$(printf '\033[32m')
  Y=$(printf '\033[33m'); R=$(printf '\033[31m'); N=$(printf '\033[0m')
else
  B=''; D=''; G=''; Y=''; R=''; N=''
fi

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '%sfatal:%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

# ------------------------------------------------------------------ uninstall
if [ "${1:-}" = "--uninstall" ]; then
  removed=0
  for dir in "$INSTALL_DIR" "$HOME/.local/bin" "$HOME/bin" /usr/local/bin; do
    if [ -f "$dir/$BIN" ]; then
      rm -f "$dir/$BIN" && ok "removed $dir/$BIN" && removed=1
    fi
  done
  [ "$removed" -eq 1 ] || warn "no installed copy found"
  say ""
  say "Left in place (delete by hand if you want them gone):"
  say "  $CONFIG_DIR   ${D}your repo list${N}"
  say "  $STATE_DIR   ${D}deletion logs — these are your restore points${N}"
  exit 0
fi

say "${B}Installing git-sweep-branches${N}"
say ""

# ---------------------------------------------------------------- dependencies
missing=""
command -v git >/dev/null 2>&1 || missing="$missing git"
command -v gh  >/dev/null 2>&1 || missing="$missing gh"
command -v awk >/dev/null 2>&1 || missing="$missing awk"

if [ -n "$missing" ]; then
  warn "missing required tool(s):$missing"
  case "$(uname -s)" in
    Darwin) say "  brew install$missing" ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        say "  sudo apt-get install$missing   ${D}(gh: https://cli.github.com)${N}"
      elif command -v dnf >/dev/null 2>&1; then
        say "  sudo dnf install$missing"
      else
        say "  install them with your package manager"
      fi ;;
    *) say "  install them with your package manager" ;;
  esac
  say ""
  die "install the missing tool(s), then re-run this installer"
fi
ok "git, gh and awk found"

# bash 3.2 is what stock macOS ships; the script is written to that floor.
if ! command -v bash >/dev/null 2>&1; then
  die "bash is required"
fi
ok "bash $(bash -c 'echo ${BASH_VERSION%%(*}')"

# -------------------------------------------------------------------- install
mkdir -p "$INSTALL_DIR"

if [ -f "$(dirname "$0")/bin/$BIN" ]; then
  # running from a clone
  cp "$(dirname "$0")/bin/$BIN" "$INSTALL_DIR/$BIN"
  ok "copied from local checkout"
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$RAW" -o "$INSTALL_DIR/$BIN.tmp" || die "download failed: $RAW"
  mv "$INSTALL_DIR/$BIN.tmp" "$INSTALL_DIR/$BIN"
  ok "downloaded $VERSION"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$INSTALL_DIR/$BIN.tmp" "$RAW" || die "download failed: $RAW"
  mv "$INSTALL_DIR/$BIN.tmp" "$INSTALL_DIR/$BIN"
  ok "downloaded $VERSION"
else
  die "need curl or wget to download the script"
fi

chmod +x "$INSTALL_DIR/$BIN"
head -1 "$INSTALL_DIR/$BIN" | grep -q '^#!' || die "downloaded file is not a script — check $RAW"
ok "installed to $INSTALL_DIR/$BIN"

# ------------------------------------------------------------------------ PATH
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ok "$INSTALL_DIR is already on your PATH" ;;
  *)
    line="export PATH=\"$INSTALL_DIR:\$PATH\""
    rc=""
    case "$(basename "${SHELL:-sh}")" in
      zsh)  rc="$HOME/.zshrc" ;;
      bash) [ -f "$HOME/.bashrc" ] && rc="$HOME/.bashrc" || rc="$HOME/.bash_profile" ;;
      fish) rc="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
            line="fish_add_path $INSTALL_DIR" ;;
    esac

    if [ -n "$rc" ] && [ -z "${GSB_NO_PATH_EDIT:-}" ] && [ -t 0 ]; then
      printf 'Add %s to your PATH in %s? [Y/n] ' "$INSTALL_DIR" "$rc"
      read -r reply < /dev/tty || reply=n
      case "$reply" in
        n*|N*) warn "skipped — add this yourself: $line" ;;
        *) printf '\n# git-sweep-branches\n%s\n' "$line" >> "$rc"
           ok "added to $rc — run: . $rc" ;;
      esac
    else
      warn "$INSTALL_DIR is not on your PATH — add this to your shell rc:"
      say "    $line"
    fi ;;
esac

# ----------------------------------------------------------------- gh + config
if gh auth status >/dev/null 2>&1; then
  ok "gh is authenticated as $(gh api user -q .login 2>/dev/null || echo '?')"
else
  warn "gh is not authenticated yet — run: gh auth login"
fi

mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/repos" ]; then
  cat > "$CONFIG_DIR/repos" <<EOF
# One repository path per line. Lines starting with # are ignored.
# Delete or empty this file to fall back to auto-discovery: every git repo
# under \$HOME, up to 2 levels deep.
#
# ~/work/api
# ~/work/web
EOF
  ok "config stub written to $CONFIG_DIR/repos ${D}(auto-discovery until you fill it in)${N}"
else
  ok "keeping existing config at $CONFIG_DIR/repos"
fi

# ------------------------------------------------------------------- smoke test
if "$INSTALL_DIR/$BIN" --version >/dev/null 2>&1; then
  ok "$("$INSTALL_DIR/$BIN" --version) is ready"
else
  die "installed, but '$BIN --version' failed"
fi

say ""
say "${B}Try it:${N}"
say "  ${D}# safe — lists only, never deletes${N}"
say "  git-sweep-branches --list"
say ""
say "  ${D}# then decide: all at once, repo by repo, or one by one${N}"
say "  git-sweep-branches"
say ""
say "Uninstall: curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh -s -- --uninstall"
