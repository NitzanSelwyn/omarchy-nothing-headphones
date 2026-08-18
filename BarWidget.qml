import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.nitzanselwyn.nothing-ear-2"

  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var status: Model.deviceStatus(devices)
  readonly property string ctlPath: String(setting("ctlPath", "") || "ear2ctl")
  readonly property string batteryScript: decodeURIComponent(
    String(Qt.resolvedUrl("battery.py")).replace(/^file:\/\//, ""))
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", false) === true
  readonly property bool busy: batteryProcess.running || ancProcess.running || setProcess.running
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  property int leftBattery: -1
  property int rightBattery: -1
  property int caseBattery: -1
  property string ancMode: ""
  property string errorText: ""

  function open() {
    refresh()
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (opened) close()
    else open()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function refresh() {
    if (!status.connected || busy) return
    errorText = ""
    batteryProcess.command = ["/usr/bin/python3", batteryScript, status.address]
    batteryProcess.running = true
  }

  function setAnc(mode) {
    if (!status.connected || Model.MODES.indexOf(mode) === -1 || busy) return
    errorText = ""
    ancMode = mode
    setProcess.command = [ctlPath, "anc", mode]
    setProcess.running = true
  }

  visible: !hideWhenDisconnected || status.connected
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰋋"
    active: root.status.connected
    dimmed: !root.status.connected
    tooltipText: root.status.connected
      ? root.status.name + " · " + Model.batterySummary(root.leftBattery, root.rightBattery, root.caseBattery)
      : "Nothing Ear (2) disconnected"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton && root.bar)
        root.bar.run("omarchy-shell shell toggle omarchy.bluetooth")
      else root.toggle()
    }
  }

  Process {
    id: batteryProcess
    command: []
    stdout: StdioCollector { id: batteryOut; waitForEnd: true }
    stderr: StdioCollector { id: batteryErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var levels = Model.parseBattery(batteryOut.text)
        root.leftBattery = levels.left
        root.rightBattery = levels.right
        root.caseBattery = levels.case
      } else {
        root.errorText = String(batteryErr.text || "Could not read battery levels.").trim()
      }
      if (root.status.connected) ancProcess.running = true
    }
  }

  Process {
    id: ancProcess
    command: [root.ctlPath, "anc"]
    stdout: StdioCollector { id: ancOut; waitForEnd: true }
    stderr: StdioCollector { id: ancErr; waitForEnd: true }
    onExited: function(exitCode) {
      var parsed = Model.parseAnc(ancOut.text)
      if (exitCode === 0 && parsed) root.ancMode = parsed
      else if (!root.errorText)
        root.errorText = String(ancErr.text || "Could not read ANC mode.").trim()
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
    onTriggered: root.refresh()
  }
}
