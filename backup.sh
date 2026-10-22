#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

CONFIG_DIRS=(
  alacritty
  autostart
  btop
  easyeffects
  environment.d
  fcitx5
  fish
  foot
  ghostty
  git
  gtk-3.0
  gtk-4.0
  hypr
  imv
  kitty
  lazygit
  lsfg-vk
  MangoHud
  mise
  nvim
  pipewire
  tmux
  uwsm
  vkBasalt
  vkSumi
  voxtype
  wireplumber
)

CONFIG_FILES=(
  starship.toml
  brave-origin-flags.conf
  chromium-flags.conf
  hyprland-mimeapps.list
  mimeapps.list
  xdg-terminals.list
)

HOME_FILES=(
  .bashrc
  .bash_profile
  .zshrc
)

LOCAL_BIN_SCRIPTS=(
  audio-reset-defaults
  launch-easyeffects
  omarchy
  omarchy-agent
  omarchy-default-agent
)

sync_live_to_repo_unlocked() {
    mkdir -p "$REPO_DIR/config" "$REPO_DIR/home" "$REPO_DIR/local/bin" "$REPO_DIR/local/state/omarchy" "$REPO_DIR/manifests"

    # 1. Copy ~/.config directories
    for dir in "${CONFIG_DIRS[@]}"; do
      if [[ -d "$HOME/.config/$dir" ]]; then
        rm -rf "$REPO_DIR/config/$dir"
        mkdir -p "$REPO_DIR/config/$dir"
        cp -a "$HOME/.config/$dir/." "$REPO_DIR/config/$dir/"
        # Remove backup/cache files that shouldn't be tracked
        find "$REPO_DIR/config/$dir" \( -name "*.bak" -o -name "*.bak.*" -o -name "cached_layouts" -o -name "__pycache__" \) -exec rm -rf {} + 2>/dev/null || true
      fi
    done

    # 2. Copy ~/.config top-level files
    for f in "${CONFIG_FILES[@]}"; do
      if [[ -f "$HOME/.config/$f" ]]; then
        cp -a "$HOME/.config/$f" "$REPO_DIR/config/$f"
      fi
    done

    # 3. Copy ~/.config/omarchy (separating git-cloned themes/plugins into manifests)
    rm -rf "$REPO_DIR/config/omarchy"
    mkdir -p "$REPO_DIR/config/omarchy/themes" "$REPO_DIR/config/omarchy/plugins"

    for item in branding defaults extensions hooks themed shell.json shell.toml; do
      if [[ -e "$HOME/.config/omarchy/$item" ]]; then
        cp -a "$HOME/.config/omarchy/$item" "$REPO_DIR/config/omarchy/$item"
      fi
    done

    # Themes: record git-cloned themes in manifests/themes.txt, copy custom local themes directly
    : > "$REPO_DIR/manifests/themes.txt"
    if [[ -d "$HOME/.config/omarchy/themes" ]]; then
      for tdir in "$HOME/.config/omarchy/themes"/*; do
        [[ -d "$tdir" ]] || continue
        tname="$(basename "$tdir")"
        if [[ -d "$tdir/.git" ]]; then
          turl="$(git -C "$tdir" remote get-url origin 2>/dev/null || true)"
          if [[ -n "$turl" ]]; then
            echo "${tname}|${turl}" >> "$REPO_DIR/manifests/themes.txt"
          fi
        else
          rm -rf "$REPO_DIR/config/omarchy/themes/$tname"
          mkdir -p "$REPO_DIR/config/omarchy/themes/$tname"
          cp -a "$tdir/." "$REPO_DIR/config/omarchy/themes/$tname/"
        fi
      done
      sort -o "$REPO_DIR/manifests/themes.txt" "$REPO_DIR/manifests/themes.txt"
    fi

    # Plugins: record git-cloned plugins in manifests/plugins.txt, copy local plugins (like oma.config) directly
    : > "$REPO_DIR/manifests/plugins.txt"
    if [[ -d "$HOME/.config/omarchy/plugins" ]]; then
      for pdir in "$HOME/.config/omarchy/plugins"/*; do
        [[ -d "$pdir" ]] || continue
        pname="$(basename "$pdir")"
        if [[ -d "$pdir/.git" ]]; then
          purl="$(git -C "$pdir" remote get-url origin 2>/dev/null || true)"
          if [[ -n "$purl" ]]; then
            echo "${pname}|${purl}" >> "$REPO_DIR/manifests/plugins.txt"
          fi
        else
          rm -rf "$REPO_DIR/config/omarchy/plugins/$pname"
          mkdir -p "$REPO_DIR/config/omarchy/plugins/$pname"
          cp -a "$pdir/." "$REPO_DIR/config/omarchy/plugins/$pname/"
          find "$REPO_DIR/config/omarchy/plugins/$pname" -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
        fi
      done
      sort -o "$REPO_DIR/manifests/plugins.txt" "$REPO_DIR/manifests/plugins.txt"
    fi

    # 4. Copy Home dotfiles
    for f in "${HOME_FILES[@]}"; do
      if [[ -f "$HOME/$f" ]]; then
        cp -a "$HOME/$f" "$REPO_DIR/home/$f"
      fi
    done

    # 5. Copy custom scripts from ~/.local/bin
    for s in "${LOCAL_BIN_SCRIPTS[@]}"; do
      if [[ -f "$HOME/.local/bin/$s" && ! -L "$HOME/.local/bin/$s" ]]; then
        cp -a "$HOME/.local/bin/$s" "$REPO_DIR/local/bin/$s"
      fi
    done

    # 6. Copy Omarchy state (active theme, background, Razer profiles, workspace layouts)
    if [[ -f "$HOME/.local/state/omarchy/current/theme.name" ]]; then
      cp -a "$HOME/.local/state/omarchy/current/theme.name" "$REPO_DIR/manifests/active-theme.txt"
    fi
    if [[ -L "$HOME/.local/state/omarchy/current/background" ]]; then
      basename "$(readlink "$HOME/.local/state/omarchy/current/background")" > "$REPO_DIR/manifests/active-background.txt"
    fi
    if [[ -f "$HOME/.local/state/omarchy/razer/profiles.json" ]]; then
      mkdir -p "$REPO_DIR/local/state/omarchy/razer"
      cp -a "$HOME/.local/state/omarchy/razer/profiles.json" "$REPO_DIR/local/state/omarchy/razer/profiles.json"
    fi
    if [[ -d "$HOME/.local/state/omarchy/workspace-layouts" ]]; then
      rm -rf "$REPO_DIR/local/state/omarchy/workspace-layouts"
      mkdir -p "$REPO_DIR/local/state/omarchy/workspace-layouts"
      cp -a "$HOME/.local/state/omarchy/workspace-layouts/." "$REPO_DIR/local/state/omarchy/workspace-layouts/"
    fi
}

sync_live_to_repo() {
  (
    flock -x 200
    sync_live_to_repo_unlocked
  ) 200>"${XDG_RUNTIME_DIR:-/tmp}/omarchy-greg-config.lock"
}

status_json() {
  (
    flock -x 200
    sync_live_to_repo_unlocked
    python3 - "$REPO_DIR" <<'PY'
import json
import subprocess
import sys

repo = sys.argv[1]

def run(cmd):
    r = subprocess.run(cmd, cwd=repo, capture_output=True, text=True)
    return r.stdout.rstrip("\r\n") if r.returncode == 0 else ""

porcelain = run(["git", "status", "--porcelain"])
changed_files = []
if porcelain:
    for line in porcelain.splitlines():
        if len(line) > 3:
            changed_files.append(line[3:].strip())

head_hash = run(["git", "rev-parse", "--short", "HEAD"]).strip()
branch = run(["git", "branch", "--show-current"]).strip() or "main"
remote_url = run(["git", "remote", "get-url", "origin"]).strip()
active_theme = ""
try:
    with open(f"{repo}/manifests/active-theme.txt") as f:
        active_theme = f.read().strip()
except Exception:
    pass

log_raw = run([
    "git", "log", "-n", "25",
    "--pretty=format:%H%x1f%h%x1f%s%x1f%ad%x1f%ar",
    "--date=format:%Y-%m-%d %H:%M"
])
commits = []
if log_raw:
    for idx, line in enumerate(log_raw.splitlines()):
        parts = line.split("\x1f")
        if len(parts) >= 5:
            commits.append({
                "hash": parts[0],
                "shortHash": parts[1],
                "subject": parts[2],
                "date": parts[3],
                "relativeDate": parts[4],
                "isHead": idx == 0
            })

print(json.dumps({
    "hasChanges": len(changed_files) > 0,
    "changedCount": len(changed_files),
    "changedFiles": changed_files[:15],
    "branch": branch,
    "headHash": head_hash,
    "remoteUrl": remote_url,
    "activeTheme": active_theme,
    "commits": commits
}))
PY
  ) 200>"${XDG_RUNTIME_DIR:-/tmp}/omarchy-greg-config.lock"
}

if [[ "${1:-}" == "--status-json" ]]; then
  status_json
  exit 0
fi

if [[ "${1:-}" == "--sync-only" ]]; then
  sync_live_to_repo
  exit 0
fi

if [[ "${1:-}" == "--run" ]]; then
  shift
fi

CUSTOM_MSG="${*:-}"

echo "==> Copiando configuración actual de Omarchy y Hyprland al repositorio..."
sync_live_to_repo

# Save package lists on full backup
if command -v pacman &>/dev/null; then
  pacman -Qqen > "$REPO_DIR/manifests/packages-native.txt" 2>/dev/null || true
  pacman -Qqem > "$REPO_DIR/manifests/packages-aur.txt" 2>/dev/null || true
fi

git add -A

TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
if [[ -n "$CUSTOM_MSG" ]]; then
  COMMIT_MSG="$CUSTOM_MSG ($TIMESTAMP)"
else
  COMMIT_MSG="Snapshot Omarchy ($TIMESTAMP)"
fi

if git diff --cached --quiet; then
  if [[ -n "$CUSTOM_MSG" ]]; then
    git commit --allow-empty -m "$COMMIT_MSG"
  else
    echo "==> No hay cambios nuevos respecto a la última versión guardada."
  fi
else
  git commit -m "$COMMIT_MSG"
fi

SHORT_HASH="$(git rev-parse --short HEAD)"

if git remote get-url origin &>/dev/null; then
  echo "==> Subiendo versión $SHORT_HASH a GitHub..."
  git push -u origin "$(git branch --show-current)"
  if command -v omarchy-notification-send &>/dev/null; then
    omarchy-notification-send --app-name "oma.config" -g "󰅠" -t 3500 \
      "Configuración guardada en GitHub" \
      "Versión $SHORT_HASH • ${CUSTOM_MSG:-Snapshot $TIMESTAMP}"
  fi
  echo "==> ¡Listo! Configuración guardada y sincronizada en GitHub ($SHORT_HASH)."
else
  echo "==> ¡Listo! Configuración guardada localmente ($SHORT_HASH)."
fi
