import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "oma.config"
  ipcTarget: "oma.config"
  manageIpc: false

  readonly property string defaultRepoPath: (Quickshell.env("HOME") || "/home/greg") + "/Projects/omarchyGregConfig"
  readonly property string repoPath: setting("repoPath", "") !== "" ? setting("repoPath", "") : root.defaultRepoPath
  readonly property string backupScript: root.repoPath + "/backup.sh"
  readonly property string restoreScript: root.repoPath + "/restore.sh"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color barForeground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property bool hasChanges: false
  property int changedCount: 0
  property var changedFiles: []
  property string branch: "main"
  property string headHash: ""
  property string remoteUrl: ""
  property string activeTheme: ""
  property var commits: []

  property bool isPolling: false
  property bool isSaving: false
  property bool isRestoring: false
  property string restoringHash: ""
  property string confirmHash: ""
  property string statusFeedback: ""

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() {
    root.controller.show()
  }

  function toggle() {
    root.opened ? root.close() : root.open()
  }

  function refresh() {
    if (root.isPolling || statusProc.running) return
    root.isPolling = true
    statusProc.running = true
  }

  function triggerBackup() {
    if (root.isSaving || backupProc.running) return
    var msg = commitInput.text.trim()
    root.isSaving = true
    root.statusFeedback = "Guardando configuración y subiendo a GitHub..."
    backupProc.customMessage = msg
    backupProc.running = true
  }

  function requestRestore(shortHash) {
    if (root.isRestoring || restoreProc.running) return
    if (root.confirmHash !== shortHash) {
      root.confirmHash = shortHash
      confirmResetTimer.restart()
      return
    }
    root.confirmHash = ""
    root.isRestoring = true
    root.restoringHash = shortHash
    root.statusFeedback = "Restaurando versión #" + shortHash + "..."
    restoreProc.targetCommit = shortHash
    restoreProc.running = true
  }

  function launchTerminalRestore() {
    root.close()
    Quickshell.execDetached([
      "omarchy-launch-floating-terminal-with-presentation",
      root.restoreScript
    ])
  }

  Timer {
    id: confirmResetTimer
    interval: 3500
    repeat: false
    onTriggered: root.confirmHash = ""
  }

  Timer {
    id: feedbackClearTimer
    interval: 4000
    repeat: false
    onTriggered: root.statusFeedback = ""
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
    function save(): void { root.triggerBackup() }
  }

  Process {
    id: statusProc
    command: [root.backupScript, "--status-json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.isPolling = false
        try {
          var data = JSON.parse(text)
          root.hasChanges = data.hasChanges === true
          root.changedCount = data.changedCount || 0
          root.changedFiles = data.changedFiles || []
          root.branch = data.branch || "main"
          root.headHash = data.headHash || ""
          root.remoteUrl = data.remoteUrl || ""
          root.activeTheme = data.activeTheme || ""
          root.commits = data.commits || []
        } catch (e) {
          console.warn("oma.config: failed to parse status json: " + e)
        }
      }
    }
    onExited: function(code) {
      root.isPolling = false
    }
  }

  Process {
    id: backupProc
    property string customMessage: ""
    command: backupProc.customMessage !== ""
      ? [root.backupScript, "--run", backupProc.customMessage]
      : [root.backupScript, "--run"]
    onExited: function(code) {
      root.isSaving = false
      if (code === 0) {
        commitInput.text = ""
        root.statusFeedback = "✓ Guardado y sincronizado en GitHub"
      } else {
        root.statusFeedback = "⚠ Error al guardar o subir a GitHub"
      }
      feedbackClearTimer.restart()
      root.refresh()
    }
  }

  Process {
    id: restoreProc
    property string targetCommit: "HEAD"
    command: [root.restoreScript, "--commit", restoreProc.targetCommit]
    onExited: function(code) {
      root.isRestoring = false
      root.restoringHash = ""
      if (code === 0) {
        root.statusFeedback = "✓ Versión #" + restoreProc.targetCommit + " restaurada"
      } else {
        root.statusFeedback = "⚠ Error al restaurar versión"
      }
      feedbackClearTimer.restart()
      root.refresh()
    }
  }

  Timer {
    id: pollTimer
    interval: panel.open ? 5000 : 25000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    root.refresh()
  }

  // Top Bar Button
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.hasChanges && !vertical ? "󰅠 •" : "󰅠"
    slotSize: Style.bar.iconSlot * (root.hasChanges && !vertical ? 1.45 : 1.0)
    tooltipText: root.hasChanges
      ? ("Omarchy Config: " + root.changedCount + " cambio(s) sin guardar (clic para guardar o restaurar)")
      : ("Omarchy Config: Sincronizado en GitHub (#" + (root.headHash || "main") + ")")
    active: root.opened || root.hasChanges
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.triggerBackup()
      } else {
        root.toggle()
      }
    }
  }

  // Popup Panel
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(410))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight, Style.space(580))

    onOpenChanged: if (open) {
      root.confirmHash = ""
      root.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: panelColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: panelColumn
          width: panelFlick.width
          spacing: Style.space(12)

          // 1. Hero Header
          PanelHero {
            width: parent.width
            title: "Omarchy Config"
            meta: root.hasChanges
              ? (root.changedCount + " cambio(s) sin guardar • #" + (root.headHash || "main"))
              : ("Sincronizado con GitHub • #" + (root.headHash || "main"))
            detail: root.statusFeedback !== ""
              ? root.statusFeedback
              : ("Rama: " + root.branch + (root.activeTheme !== "" ? (" • Tema: " + root.activeTheme) : ""))
            foreground: root.foreground
            fontFamily: root.fontFamily

            iconComponent: Component {
              Text {
                text: root.hasChanges ? "󰅢" : "󰅠"
                color: root.hasChanges ? Color.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }

            trailingControl: Component {
              Item {
                width: Style.space(26)
                height: Style.space(26)
                Text {
                  anchors.centerIn: parent
                  text: "󰑐"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  color: refreshArea.containsMouse ? Color.accent : Qt.darker(root.foreground, 1.4)
                  rotation: (root.isPolling || root.isSaving || root.isRestoring) ? 360 : 0
                  Behavior on rotation { NumberAnimation { duration: 600 } }
                }
                MouseArea {
                  id: refreshArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.refresh()
                }
              }
            }
          }

          // Banner de archivos modificados en vivo
          Rectangle {
            width: parent.width
            visible: root.hasChanges
            implicitHeight: changedCol.implicitHeight + Style.space(14)
            radius: Style.cornerRadius
            color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)
            border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.35)
            border.width: 1

            Column {
              id: changedCol
              anchors.fill: parent
              anchors.margins: Style.space(7)
              spacing: Style.space(4)

              Text {
                text: "Cambios locales detectados (" + root.changedCount + "):"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.foreground
              }

              Text {
                width: parent.width
                text: root.changedFiles.slice(0, 4).join(", ") + (root.changedFiles.length > 4 ? " ..." : "")
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                color: Qt.darker(root.foreground, 1.25)
                wrapMode: Text.Wrap
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // 2. Guardar configuración actual
          PanelSectionHeader {
            text: "GUARDAR CONFIGURACIÓN ACTUAL"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          TextField {
            id: commitInput
            width: parent.width
            placeholderText: "Descripción opcional (ej: Ajuste de Hyprland)..."
            foreground: root.foreground
            onAccepted: root.triggerBackup()
          }

          Button {
            width: parent.width
            bordered: true
            selected: root.hasChanges
            iconText: root.isSaving ? "󰑐" : "󰅢"
            iconSpinning: root.isSaving
            text: root.isSaving
              ? "Guardando y subiendo a GitHub..."
              : (root.hasChanges ? "Guardar cambios en GitHub ahora" : "Crear nuevo punto de guardado")
            tooltipText: "Ejecuta backup.sh, crea un commit y lo sube a tu repositorio en GitHub"
            onClicked: root.triggerBackup()
          }

          PanelSeparator { foreground: root.foreground }

          // 3. Historial de versiones para restaurar
          RowLayout {
            width: parent.width
            PanelSectionHeader {
              text: "RESTAURAR VERSIÓN (" + root.commits.length + ")"
              foreground: root.foreground
              fontFamily: root.fontFamily
              Layout.fillWidth: true
            }
            Text {
              visible: root.hasChanges
              text: "Puedes volver a ACTUAL para descartar fallos"
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              color: Color.accent
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.commits

              delegate: Rectangle {
                required property var modelData
                required property int index

                width: parent.width
                implicitHeight: rowLayout.implicitHeight + Style.space(14)
                radius: Style.cornerRadius
                color: modelData.isHead
                  ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.07)
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
                border.width: 1
                border.color: modelData.isHead
                  ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.4)
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                RowLayout {
                  id: rowLayout
                  anchors.fill: parent
                  anchors.margins: Style.space(7)
                  spacing: Style.space(8)

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    RowLayout {
                      spacing: Style.space(6)
                      Rectangle {
                        radius: 4
                        color: modelData.isHead
                          ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
                          : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                        implicitWidth: hashLabel.implicitWidth + 10
                        implicitHeight: hashLabel.implicitHeight + 4
                        Text {
                          id: hashLabel
                          anchors.centerIn: parent
                          text: "#" + modelData.shortHash
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                          font.bold: true
                          color: modelData.isHead ? Color.accent : root.foreground
                        }
                      }

                      Rectangle {
                        visible: modelData.isHead
                        radius: 4
                        color: Qt.rgba(0.2, 0.8, 0.4, 0.2)
                        implicitWidth: headBadge.implicitWidth + 10
                        implicitHeight: headBadge.implicitHeight + 4
                        Text {
                          id: headBadge
                          anchors.centerIn: parent
                          text: "ÚLTIMA"
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                          color: "#4ade80"
                        }
                      }

                      Text {
                        text: modelData.relativeDate
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        color: Qt.darker(root.foreground, 1.45)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                      }
                    }

                    Text {
                      text: modelData.subject
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.bodySmall
                      font.bold: modelData.isHead
                      color: root.foreground
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                    }
                  }

                  Button {
                    bordered: true
                    selected: root.confirmHash === modelData.shortHash
                    iconText: (root.isRestoring && root.restoringHash === modelData.shortHash)
                      ? "󰑐"
                      : (root.confirmHash === modelData.shortHash ? "󰄬" : "󰦛")
                    iconSpinning: root.isRestoring && root.restoringHash === modelData.shortHash
                    text: (root.isRestoring && root.restoringHash === modelData.shortHash)
                      ? "..."
                      : (root.confirmHash === modelData.shortHash ? "¿Confirmar?" : "Restaurar")
                    tooltipText: "Sobrescribe tu configuración actual con la versión #" + modelData.shortHash
                    onClicked: root.requestRestore(modelData.shortHash)
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          // 4. Footer actions
          RowLayout {
            width: parent.width
            spacing: Style.space(8)

            Button {
              Layout.fillWidth: true
              bordered: true
              iconText: "󰆍"
              text: "Selector en Terminal"
              tooltipText: "Abrir restore.sh interactivo en una terminal flotante"
              onClicked: root.launchTerminalRestore()
            }
          }
        }
      }
    }
  }
}
