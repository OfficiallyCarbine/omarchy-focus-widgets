import QtQuick
import qs.Commons
import qs.Ui
import "." as Local

BarWidget {
  id: root
  moduleName: "local.pomodoro"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  readonly property var session: Local.Session
  readonly property string clockText: "%1:%2"
    .arg(I18n.formatNumber(Math.floor(session.secondsLeft / 60)))
    .arg(session.secondsLeft % 60 < 10
      ? I18n.formatNumber(0) + I18n.formatNumber(session.secondsLeft % 60)
      : I18n.formatNumber(session.secondsLeft % 60))

  property bool panelOpen: false

  function close() {
    showPanel.stop()
    hidePanel.stop()
    panelOpen = false
  }

  function syncHover() {
    if (button.tooltipHovered || settingsPanel.containsMouse) {
      hidePanel.stop()
      if (!panelOpen && button.tooltipHovered)
        showPanel.restart()
    } else {
      showPanel.stop()
      if (panelOpen)
        hidePanel.restart()
    }
  }

  Timer {
    id: showPanel
    interval: 180
    onTriggered: if (root.bar && button.tooltipHovered) root.panelOpen = true
  }

  Timer {
    id: hidePanel
    interval: 340
    onTriggered: root.close()
  }

  Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? root.clockText
      : strings.t(root.session.onBreak ? "break" : "focus").arg(root.clockText)
    active: root.session.running
    onTooltipHoveredChanged: root.syncHover()

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.LeftButton)
        root.session.toggle()
      else if (mouseButton === Qt.RightButton)
        root.session.switchPhase()
      else if (mouseButton === Qt.MiddleButton)
        root.session.reset()
    }
  }

  SettingsPanel {
    id: settingsPanel
    owner: root
    anchorItem: button
    bar: root.bar
    open: root.panelOpen
    session: root.session
    clockText: root.clockText
    onContainsMouseChanged: root.syncHover()
  }
}
