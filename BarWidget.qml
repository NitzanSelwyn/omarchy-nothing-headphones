import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.nitzanselwyn.nothing-earbuds"

  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var status: Model.deviceStatus(devices)
  readonly property string helperPath: decodeURIComponent(
    String(Qt.resolvedUrl("nothingctl.py")).replace(/^file:\/\//, ""))
  readonly property int rfcommChannel: Number(setting("rfcommChannel", 15))
  readonly property bool hideWhenDisconnected: setting("hideWhenDisconnected", false) === true
  readonly property bool busy: statusProcess.running || setProcess.running
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  property int leftBattery: -1
  property int rightBattery: -1
  property int caseBattery: -1
  property string batteryAddress: ""
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
    if (batteryAddress !== status.address) {
      leftBattery = rightBattery = caseBattery = -1
      batteryAddress = status.address
    }
    errorText = ""
    statusProcess.command = [
      "/usr/bin/python3", helperPath, status.address, "status", String(rfcommChannel)
    ]
    statusProcess.running = true
  }

  function setAnc(mode) {
    if (!status.connected || Model.MODES.indexOf(mode) === -1 || busy) return
    errorText = ""
    ancMode = mode
    setProcess.command = [
      "/usr/bin/python3", helperPath, status.address, "anc", mode, String(rfcommChannel)
    ]
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
      : "Nothing / CMF earbuds disconnected"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton && root.bar)
        root.bar.run("omarchy-shell shell toggle omarchy.bluetooth")
      else root.toggle()
    }
  }

  Process {
    id: statusProcess
    command: []
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    stderr: StdioCollector { id: statusErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var result = Model.parseStatus(statusOut.text)
        if (result.left >= 0) root.leftBattery = result.left
        if (result.right >= 0) root.rightBattery = result.right
        if (result.case >= 0) root.caseBattery = result.case
        root.ancMode = result.anc
      } else {
        root.errorText = String(statusErr.text || "Could not read earbud status.").trim()
      }
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
