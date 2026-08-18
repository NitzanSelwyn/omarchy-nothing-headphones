import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "nitzan.nothing-ear-2"
  ipcTarget: "nothing-ear-2"

  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var status: Model.deviceStatus(devices)
  readonly property string ctlPath: String(setting("ctlPath", "") || "ear2ctl")
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", false) === true
  readonly property var modes: [
    { value: "off", label: "Off" },
    { value: "transparency", label: "Transparency" },
    { value: "high", label: "High" },
    { value: "mid", label: "Mid" },
    { value: "low", label: "Low" },
    { value: "adaptive", label: "Adaptive" }
  ]

  property string ancMode: ""
  property string errorText: ""
  property int cursorIndex: 0
  property bool cursorActive: false

  function refreshAnc() {
    if (!status.connected || queryProcess.running || setProcess.running) return
    errorText = ""
    queryProcess.running = true
  }

  function setAnc(mode) {
    if (!status.connected || Model.MODES.indexOf(mode) === -1 || setProcess.running) return
    errorText = ""
    ancMode = mode
    setProcess.command = [ctlPath, "anc", mode]
    setProcess.running = true
  }

  function moveCursor(delta) {
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(modes.length - 1, cursorIndex + delta))
  }

  function activateCursor() {
    setAnc(modes[cursorIndex].value)
  }

  visible: !hideWhenDisconnected || status.connected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    cursorIndex = Math.max(0, Model.MODES.indexOf(ancMode))
    refreshAnc()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋋"
    active: root.status.connected
    dimmed: !root.status.connected
    tooltipText: root.status.connected
      ? root.status.name + " · " + Model.batteryText(root.status.battery)
      : "Nothing Ear (2) disconnected"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton && root.bar)
        root.bar.run("omarchy-shell shell toggle omarchy.bluetooth")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) { root.moveCursor(dx || dy) }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        var shortcuts = {
          o: "off", t: "transparency", n: "high", m: "mid", w: "low", a: "adaptive",
          "1": "off", "2": "transparency", "3": "high", "4": "mid", "5": "low", "6": "adaptive"
        }
        if (shortcuts[text.toLowerCase()]) root.setAnc(shortcuts[text.toLowerCase()])
        else if (text.toLowerCase() === "r") root.refreshAnc()
      }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(14)

        Row {
          width: parent.width
          spacing: Style.space(14)

          Text {
            text: "󰋋"
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: root.status.name
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: !root.status.found ? "NOT PAIRED"
                : root.status.connected ? Model.batteryText(root.status.battery).toUpperCase()
                : "DISCONNECTED"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        PanelSectionHeader {
          text: "NOISE CONTROL"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
        }

        ButtonGroup {
          id: ancButtons
          options: root.modes
          value: root.ancMode
          cursorIndex: root.cursorActive ? root.cursorIndex : -1
          focusable: false
          foreground: root.bar.foreground
          background: root.bar.background
          fontFamily: root.bar.fontFamily
          enabled: root.status.connected && !setProcess.running
          onChanged: function(value) { root.setAnc(value) }
          onHovered: function(index, hovered) {
            if (hovered) { root.cursorActive = true; root.cursorIndex = index }
          }
        }

        Text {
          visible: !root.status.connected || root.errorText !== ""
          text: root.errorText || "Connect the earbuds first. Right-click the bar icon for Bluetooth."
          color: root.errorText ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }
      }
    }
  }

  Process {
    id: queryProcess
    command: [root.ctlPath, "anc"]
    stdout: StdioCollector { id: queryOut; waitForEnd: true }
    stderr: StdioCollector { id: queryErr; waitForEnd: true }
    onExited: function(exitCode) {
      var parsed = Model.parseAnc(queryOut.text)
      if (exitCode === 0 && parsed) root.ancMode = parsed
      else root.errorText = String(queryErr.text || "Could not read ANC mode. Is ear2ctl installed?").trim()
    }
  }

  Process {
    id: setProcess
    command: []
    stderr: StdioCollector { id: setErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0)
        root.errorText = String(setErr.text || "Could not change ANC mode.").trim()
      else refreshTimer.restart()
    }
  }

  Timer {
    id: refreshTimer
    interval: 500
    onTriggered: root.refreshAnc()
  }
}
