#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_DIR"

TARGET_COMMIT=""
SKIP_CONFIRM=false
DO_PULL=false

while (($#)); do
  case "$1" in
    --commit|-c)
      TARGET_COMMIT="${2:?Falta el hash del commit}"
      SKIP_CONFIRM=true
      shift 2
      ;;
    --latest|-l)
      TARGET_COMMIT="HEAD"
      SKIP_CONFIRM=true
      shift
      ;;
    --pull|-p)
      DO_PULL=true
      shift
      ;;
    --yes|-y)
      SKIP_CONFIRM=true
      shift
      ;;
    -h|--help)
      echo "Uso: ./restore.sh [--latest | --commit <hash> | --pull]"
      echo "  Sin argumentos: abre un selector interactivo con el historial de versiones guardadas."
      echo "  --latest      : restaura directamente la última versión guardada."
      echo "  --commit HASH : restaura directamente la versión indicada."
      echo "  --pull        : descarga primero los últimos cambios desde GitHub."
      exit 0
      ;;
    *)
      TARGET_COMMIT="$1"
      shift
      ;;
  esac
done

if [[ "$DO_PULL" == "true" ]] && git remote get-url origin &>/dev/null; then
  echo "==> Sincronizando historial desde GitHub..."
  git fetch origin --quiet || true
fi

if [[ -z "$TARGET_COMMIT" ]]; then
  echo "================================================================"
  echo "   Restaurar Configuración de Omarchy (Selector de Versiones)   "
  echo "================================================================"
  echo ""

  mapfile -t COMMIT_LINES < <(git log -n 30 --pretty=format:"%h | %ad | %s (%ar)" --date=format:"%Y-%m-%d %H:%M")

  if [[ ${#COMMIT_LINES[@]} -eq 0 ]]; then
    echo "No hay versiones guardadas en el repositorio todavía."
    exit 1
  fi

  if command -v gum &>/dev/null && [[ -t 0 ]]; then
    echo "Selecciona qué versión deseas restaurar encima de tu configuración actual:"
    CHOICE="$(printf '%s\n' "${COMMIT_LINES[@]}" | gum choose --height 15 --header "Historial de versiones (Enter para seleccionar, Esc para cancelar)")" || exit 0
    TARGET_COMMIT="${CHOICE%% |*}"
  else
    echo "Versiones disponibles:"
    for i in "${!COMMIT_LINES[@]}"; do
      printf "  [%2d] %s\n" $((i + 1)) "${COMMIT_LINES[$i]}"
    done
    echo ""
    read -rp "Elige el número de versión a restaurar (1-${#COMMIT_LINES[@]}, o 'q' para cancelar) [1]: " NUM
    [[ "${NUM:-1}" == "q" || "${NUM:-1}" == "Q" ]] && exit 0
    IDX=$(( ${NUM:-1} - 1 ))
    if (( IDX < 0 || IDX >= ${#COMMIT_LINES[@]} )); then
      echo "Selección inválida."
      exit 1
    fi
    TARGET_COMMIT="${COMMIT_LINES[$IDX]%% |*}"
  fi
fi

FULL_HASH="$(git rev-parse --verify "${TARGET_COMMIT}^{commit}" 2>/dev/null || true)"
if [[ -z "$FULL_HASH" ]]; then
  echo "Error: No se encontró la versión '$TARGET_COMMIT' en el repositorio."
  exit 1
fi

SHORT_HASH="$(git rev-parse --short "$FULL_HASH")"
COMMIT_DESC="$(git log -1 --pretty=format:"%s (%ad)" --date=format:"%Y-%m-%d %H:%M" "$FULL_HASH")"

if [[ "$SKIP_CONFIRM" != "true" && -t 0 ]]; then
  echo ""
  echo "Vas a restaurar la versión: [$SHORT_HASH] $COMMIT_DESC"
  echo "Esto sobrescribirá tu configuración actual de Omarchy/Hyprland (se creará un respaldo automático previo)."
  read -rp "¿Continuar? [s/N]: " CONFIRM
  if [[ ! "${CONFIRM:-n}" =~ ^[sSyY]$ ]]; then
    echo "Restauración cancelada."
    exit 0
  fi
fi

# 1. Create a local safety backup before overwriting
SAFETY_DIR="$HOME/.cache/omarchy-config-backups/pre-restore-$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$SAFETY_DIR"
echo "==> Creando copia de seguridad preventiva en: $SAFETY_DIR"
cp -a "$HOME/.config/hypr" "$SAFETY_DIR/" 2>/dev/null || true
cp -a "$HOME/.config/omarchy/shell.json" "$HOME/.config/omarchy/shell.toml" "$SAFETY_DIR/" 2>/dev/null || true

# 2. Extract the chosen commit snapshot to a temporary directory
TMP_EXTRACT="$(mktemp -d)"
trap 'rm -rf "$TMP_EXTRACT"' EXIT
git archive "$FULL_HASH" | tar -x -C "$TMP_EXTRACT"

# 3. Restore ~/.config files and directories
echo "==> Aplicando archivos de configuración de la versión $SHORT_HASH..."
if [[ -d "$TMP_EXTRACT/config" ]]; then
  mkdir -p "$HOME/.config"
  for item in "$TMP_EXTRACT/config"/*; do
    [[ -e "$item" ]] || continue
    name="$(basename "$item")"
    if [[ "$name" == "git" && "${USER:-}" != "greg" ]]; then
      continue
    fi
    if [[ "$name" == "omarchy" ]]; then
      mkdir -p "$HOME/.config/omarchy"
      for oitem in "$item"/*; do
        [[ -e "$oitem" ]] || continue
        oname="$(basename "$oitem")"
        if [[ "$oname" == "themes" || "$oname" == "plugins" ]]; then
          mkdir -p "$HOME/.config/omarchy/$oname"
          for sub in "$oitem"/*; do
            [[ -e "$sub" ]] || continue
            subname="$(basename "$sub")"
            rm -rf "$HOME/.config/omarchy/$oname/$subname"
            cp -a "$sub" "$HOME/.config/omarchy/$oname/$subname"
          done
        else
          rm -rf "$HOME/.config/omarchy/$oname"
          cp -a "$oitem" "$HOME/.config/omarchy/$oname"
        fi
      done
    elif [[ -d "$item" ]]; then
      rm -rf "$HOME/.config/$name"
      cp -a "$item" "$HOME/.config/$name"
    else
      cp -a "$item" "$HOME/.config/$name"
    fi
  done
fi

# 4. Restore Home dotfiles (.bashrc, .bash_profile, .zshrc)
if [[ -d "$TMP_EXTRACT/home" ]]; then
  shopt -s dotglob
  for f in "$TMP_EXTRACT/home"/*; do
    [[ -f "$f" ]] || continue
    cp -a "$f" "$HOME/$(basename "$f")"
  done
  shopt -u dotglob
fi

# 5. Restore custom scripts in ~/.local/bin
if [[ -d "$TMP_EXTRACT/local/bin" ]]; then
  mkdir -p "$HOME/.local/bin"
  for s in "$TMP_EXTRACT/local/bin"/*; do
    [[ -f "$s" ]] || continue
    cp -a "$s" "$HOME/.local/bin/$(basename "$s")"
    chmod +x "$HOME/.local/bin/$(basename "$s")"
  done
fi

# 6. Restore Omarchy state (Razer profiles, workspace layouts)
if [[ -d "$TMP_EXTRACT/local/state/omarchy" ]]; then
  mkdir -p "$HOME/.local/state/omarchy"
  cp -a "$TMP_EXTRACT/local/state/omarchy/." "$HOME/.local/state/omarchy/"
fi

# 7. Ensure git-cloned themes & plugins from manifests are installed
if [[ -f "$TMP_EXTRACT/manifests/themes.txt" ]]; then
  mkdir -p "$HOME/.config/omarchy/themes"
  while IFS='|' read -r tname turl; do
    [[ -n "$tname" && -n "$turl" ]] || continue
    if [[ ! -d "$HOME/.config/omarchy/themes/$tname" ]]; then
      echo "==> Descargando tema faltante: $tname..."
      git clone --depth 1 "$turl" "$HOME/.config/omarchy/themes/$tname" 2>/dev/null || true
    fi
  done < "$TMP_EXTRACT/manifests/themes.txt"
fi

if [[ -f "$TMP_EXTRACT/manifests/plugins.txt" ]]; then
  mkdir -p "$HOME/.config/omarchy/plugins"
  while IFS='|' read -r pname purl; do
    [[ -n "$pname" && -n "$purl" ]] || continue
    if [[ ! -d "$HOME/.config/omarchy/plugins/$pname" ]]; then
      echo "==> Descargando plugin faltante: $pname..."
      git clone --depth 1 "$purl" "$HOME/.config/omarchy/plugins/$pname" 2>/dev/null || true
    fi
  done < "$TMP_EXTRACT/manifests/plugins.txt"
fi

# 8. Restore active theme if changed
if [[ -f "$TMP_EXTRACT/manifests/active-theme.txt" ]]; then
  WANT_THEME="$(tr -d '[:space:]' < "$TMP_EXTRACT/manifests/active-theme.txt")"
  CURR_THEME="$(tr -d '[:space:]' < "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)"
  if [[ -n "$WANT_THEME" && "$WANT_THEME" != "$CURR_THEME" ]] && command -v omarchy-theme-set &>/dev/null; then
    echo "==> Aplicando tema activo: $WANT_THEME..."
    omarchy-theme-set "$WANT_THEME" || true
  fi
fi

# 9. Sync repo working copy with current state
"$REPO_DIR/backup.sh" --sync-only || true

# 10. Reload Hyprland and notify user
if command -v hyprctl &>/dev/null; then
  hyprctl reload >/dev/null 2>&1 || true
fi

if command -v omarchy-notification-send &>/dev/null; then
  omarchy-notification-send --app-name "oma.config" -g "󰅠" -t 4000 \
    "Configuración restaurada ($SHORT_HASH)" \
    "$COMMIT_DESC"
fi

echo "==> ¡Restauración completada con éxito! (Versión $SHORT_HASH: $COMMIT_DESC)"
