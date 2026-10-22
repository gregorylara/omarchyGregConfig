# Omarchy & Hyprland Config (`omarchyGregConfig`)

Repositorio de respaldo y control de versiones de mi configuración de **Omarchy**, **Hyprland**, audio (**PipeWire / EasyEffects**), terminales, temas, plugins (`oma.razer`, `oma.config`) y herramientas de desarrollo.

---

## 1. Uso desde la Barra Superior (`oma.config`)

En la barra superior de Omarchy encontrarás el icono **`󰅠`** (junto al icono de Razer):
- **Si aparece un punto (`󰅠 •`)**: significa que has modificado archivos en `~/.config` que aún no has guardado en GitHub.
- **Clic izquierdo**: abre el panel desplegable donde puedes:
  1. **Guardar versión actual en GitHub**: escribe una nota opcional (ej. `"Ajuste de blur"`) y pulsa el botón para hacer commit + push inmediato.
  2. **Restaurar cualquier versión anterior**: elige cualquier versión de la lista del historial y pulsa **Restaurar** (dos clics de confirmación) para sobrescribir tu configuración actual y volver a ese estado al instante.
- **Clic derecho en el icono de la barra**: guarda y sube un snapshot rápido a GitHub con un solo clic.

---

## 2. Uso desde la Terminal

### Guardar la configuración actual y subirla a GitHub
```bash
cd ~/Projects/omarchyGregConfig
./backup.sh "Descripción opcional del cambio"
```

### Restaurar una versión (pisar la configuración actual)
- **Selector interactivo de versiones** (elige de la lista cuál versión restaurar):
  ```bash
  ./restore.sh
  ```
- **Restaurar directamente la última versión guardada** (ideal si tocaste algo y quieres revertir al último estado bueno):
  ```bash
  ./restore.sh --latest
  ```
- **Restaurar una versión específica por su código (hash)**:
  ```bash
  ./restore.sh --commit <hash>
  ```

> **Nota de seguridad**: Antes de pisar tu configuración, `restore.sh` guarda automáticamente una copia preventiva en `~/.cache/omarchy-config-backups/pre-restore-FECHA`.

---

## 3. Instalar / Clonar en otra máquina (o compartir con un amigo)

```bash
git clone https://github.com/gregorylara/omarchyGregConfig.git ~/Projects/omarchyGregConfig
cd ~/Projects/omarchyGregConfig
./restore.sh --latest
```
`restore.sh` descargará automáticamente los 20 temas de Omarchy y los plugins definidos en `manifests/` y aplicará toda la configuración.
