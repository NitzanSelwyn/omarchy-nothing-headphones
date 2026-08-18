import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.nitzanselwyn.nothing-earbuds"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property int cursorIndex: 0
  property bool cursorActive: false

  readonly property var modes: Model.modeOptions(status.name)
  readonly property var status: hostWidget ? hostWidget.status
    : ({ found: false, connected: false, name: "Nothing Earbuds" })

  function open() {
    root.controller.show()
    cursorActive = false
    cursorIndex = hostWidget ? Math.max(0, Model.MODES.indexOf(hostWidget.ancMode)) : 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() { root.controller.hide() }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function moveCursor(delta) {
    if (modes.length === 0) return
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(modes.length - 1, cursorIndex + delta))
  }

  function activateCursor() {
    if (hostWidget && modes.length > 0) hostWidget.setAnc(modes[cursorIndex].value)
  }

  function chooseMode(mode) {
    for (var i = 0; i < modes.length; i++) {
      if (modes[i].value === mode) {
        if (hostWidget) hostWidget.setAnc(mode)
        return
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
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
        if (!root.hostWidget) return
        if (shortcuts[text.toLowerCase()]) root.chooseMode(shortcuts[text.toLowerCase()])
        else if (text.toLowerCase() === "r") root.hostWidget.refresh()
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
            color: root.barForeground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: root.status.name
              color: root.barForeground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              text: !root.status.found ? "NOT PAIRED"
                : root.status.connected ? "CONNECTED" : "DISCONNECTED"
              color: Qt.darker(root.barForeground, 1.4)
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
            }
          }
        }

        PanelSeparator { foreground: root.barForeground }

        PanelSectionHeader {
          text: "BATTERY"
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        Row {
          width: parent.width
          spacing: Style.space(12)

          Repeater {
            model: [
              { label: "LEFT", value: root.status.connected && root.hostWidget ? root.hostWidget.leftBattery : -1 },
              { label: "RIGHT", value: root.status.connected && root.hostWidget ? root.hostWidget.rightBattery : -1 },
              { label: "CASE", value: root.status.connected && root.hostWidget ? root.hostWidget.caseBattery : -1 }
            ]

            Column {
              required property var modelData
              width: (parent.width - Style.space(24)) / 3
              spacing: Style.space(2)

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.value < 0 ? "--" : modelData.value + "%"
                color: modelData.value < 0
                  ? Qt.darker(root.barForeground, 1.8) : root.barForeground
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.heading
                font.bold: true
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.label
                color: Qt.darker(root.barForeground, 1.4)
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
                font.letterSpacing: 1.2
              }
            }
          }
        }

        PanelSeparator {
          visible: root.modes.length > 0
          foreground: root.barForeground
        }

        PanelSectionHeader {
          visible: root.modes.length > 0
          text: "NOISE CONTROL"
          foreground: root.barForeground
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
        }

        ButtonGroup {
          visible: root.modes.length > 0
          options: root.modes
          value: root.hostWidget ? root.hostWidget.ancMode : ""
          cursorIndex: root.cursorActive ? root.cursorIndex : -1
          focusable: false
          foreground: root.barForeground
          background: root.bar ? root.bar.background : Color.background
          fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
          enabled: root.status.connected && root.hostWidget && !root.hostWidget.busy
          onChanged: function(value) { if (root.hostWidget) root.hostWidget.setAnc(value) }
          onHovered: function(index, hovered) {
            if (hovered) { root.cursorActive = true; root.cursorIndex = index }
          }
        }

        Text {
          visible: !root.status.connected || (root.hostWidget && root.hostWidget.errorText !== "")
          text: root.hostWidget && root.hostWidget.errorText
            ? root.hostWidget.errorText
            : "Connect the earbuds first. Right-click the bar icon for Bluetooth."
          color: root.hostWidget && root.hostWidget.errorText
            ? (root.bar ? root.bar.urgent : Color.urgent)
            : Qt.darker(root.barForeground, 1.4)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
          width: parent.width
        }
      }
    }
  }
}
