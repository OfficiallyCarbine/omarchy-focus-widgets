import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

PopupCard {
  id: panel

  required property var session
  required property string clockText
  triggerMode: "hover"
  margin: Style.space(4)
  contentWidth: fittedContentWidth(Style.space(355))
  contentHeight: fittedContentHeight(form.implicitHeight)

  property Translations translations: Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  component Label: Text {
    textFormat: Text.PlainText
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  component MinuteRow: RowLayout {
    id: row

    required property bool forBreak
    readonly property int minutes: forBreak ? panel.session.breakMinutes : panel.session.focusMinutes

    spacing: Style.space(6)

    Label {
      Layout.fillWidth: true
      text: strings.t(row.forBreak ? "breakDuration" : "focusDuration")
    }

    Button {
      text: "−"
      bordered: true
      enabled: row.minutes > 1
      Accessible.name: strings.t(row.forBreak ? "decreaseBreak" : "decreaseFocus")
      Accessible.role: Accessible.Button
      onClicked: panel.session.setMinutes(row.forBreak, row.minutes - 1)
    }

    Label {
      Layout.preferredWidth: Style.space(62)
      horizontalAlignment: Text.AlignHCenter
      text: strings.t("minutes").arg(I18n.formatNumber(row.minutes))
    }

    Button {
      text: "+"
      bordered: true
      enabled: row.minutes < panel.session.minutesLimit
      Accessible.name: strings.t(row.forBreak ? "increaseBreak" : "increaseFocus")
      Accessible.role: Accessible.Button
      onClicked: panel.session.setMinutes(row.forBreak, row.minutes + 1)
    }
  }

  component SoundRow: RowLayout {
    id: row
    required property string label
    required property bool checked
    signal toggled()

    Label {
      Layout.fillWidth: true
      text: row.label
    }

    Button {
      Layout.preferredWidth: Style.space(63)
      text: strings.t(row.checked ? "on" : "off")
      bordered: true
      selected: row.checked
      Accessible.role: Accessible.CheckBox
      Accessible.name: row.label
      Accessible.checked: row.checked
      onClicked: row.toggled()
    }
  }

  ColumnLayout {
    id: form
    width: parent.width
    spacing: Style.space(8)

    Label {
      Layout.fillWidth: true
      font.bold: true
      text: strings.t("settings")
    }

    RowLayout {
      Layout.fillWidth: true

      Label {
        Layout.fillWidth: true
        font.bold: true
        font.pixelSize: Style.font.body * 1.35
        text: strings.t(panel.session.onBreak ? "break" : "focus").arg(panel.clockText)
      }

      Label {
        visible: panel.session.started && !panel.session.running
        opacity: 0.75
        text: strings.t("paused")
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Button {
        Layout.fillWidth: true
        text: strings.t(panel.session.started && !panel.session.running ? "resume" : "start")
        bordered: true
        enabled: !panel.session.running
        onClicked: panel.session.start()
      }

      Button {
        Layout.fillWidth: true
        text: strings.t("pause")
        bordered: true
        enabled: panel.session.running
        onClicked: panel.session.pause()
      }

      Button {
        Layout.fillWidth: true
        text: strings.t("stop")
        bordered: true
        enabled: panel.session.started
        onClicked: panel.session.stop()
      }

      Button {
        Layout.fillWidth: true
        text: strings.t("reset")
        bordered: true
        enabled: panel.session.started || panel.session.secondsLeft !== panel.session.duration
        onClicked: panel.session.reset()
      }
      Button {
        Layout.fillWidth: true
        text: strings.t("skip")
        bordered: true
        enabled: !panel.session.setComplete
        onClicked: panel.session.skip()
      }
    }

    MinuteRow { Layout.fillWidth: true; forBreak: false }
    MinuteRow { Layout.fillWidth: true; forBreak: true }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Label {
        Layout.fillWidth: true
        text: strings.t("pomodoros")
      }

      Button {
        text: "−"
        bordered: true
        enabled: panel.session.pomodoroCount > 1
        Accessible.name: strings.t("fewerPomodoros")
        Accessible.role: Accessible.Button
        onClicked: panel.session.setPomodoroCount(panel.session.pomodoroCount - 1)
      }

      Label {
        Layout.preferredWidth: Style.space(62)
        horizontalAlignment: Text.AlignHCenter
        text: I18n.formatNumber(panel.session.pomodoroCount)
      }

      Button {
        text: "+"
        bordered: true
        enabled: panel.session.pomodoroCount < panel.session.pomodoroLimit
        Accessible.name: strings.t("morePomodoros")
        Accessible.role: Accessible.Button
        onClicked: panel.session.setPomodoroCount(panel.session.pomodoroCount + 1)
      }
    }

    Label {
      Layout.fillWidth: true
      opacity: 0.75
      font.pixelSize: Style.font.caption
      text: strings.t("setProgress")
        .arg(I18n.formatNumber(panel.session.completedPomodoros))
        .arg(I18n.formatNumber(panel.session.setTarget || panel.session.pomodoroCount))
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.topMargin: Style.space(3)
      implicitHeight: 1
      color: Qt.alpha(Color.popups.text, 0.2)
    }

    SoundRow {
      Layout.fillWidth: true
      label: strings.t("rain")
      checked: panel.session.rainEnabled
      onToggled: panel.session.rainEnabled = !checked
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      Label { text: strings.t("rainVolume") }

      PanelSlider {
        id: volumeSlider
        Layout.fillWidth: true
        Layout.minimumWidth: Style.space(64)
        trackColor: Qt.alpha(Color.popups.text, 0.2)
        fillColor: Color.accent
        knobColor: Color.accent
        minimum: 0
        maximum: 100
        integer: true
        value: Math.max(0, Math.min(100, panel.session.rainVolume))
        Accessible.role: Accessible.Slider
        Accessible.name: strings.t("rainVolume")
        onMoved: value => panel.session.rainVolume = value
      }

      Label {
        Layout.preferredWidth: Style.space(44)
        horizontalAlignment: Text.AlignRight
        text: strings.t("percent").arg(I18n.formatNumber(volumeSlider.liveValue))
      }
    }

    Label {
      Layout.fillWidth: true
      visible: panel.session.rainUnavailable
      wrapMode: Text.WordWrap
      text: strings.t("rainUnavailable")
    }

    SoundRow {
      Layout.fillWidth: true
      label: strings.t("alarm")
      checked: panel.session.alarmEnabled
      onToggled: panel.session.alarmEnabled = !checked
    }

    Label {
      Layout.fillWidth: true
      Layout.topMargin: Style.space(3)
      font.pixelSize: Style.font.caption
      opacity: 0.75
      wrapMode: Text.WordWrap
      text: strings.t("controls")
    }
  }
}
