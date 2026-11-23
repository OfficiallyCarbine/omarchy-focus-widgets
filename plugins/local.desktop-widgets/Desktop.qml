import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import "Quotes.js" as Quotes

Item {
  id: root
  property date now: new Date()
  readonly property var locale: Qt.locale(I18n.formatLocale)
  readonly property int today: now.getDate()
  readonly property int firstWeekday: new Date(now.getFullYear(), now.getMonth(), 1).getDay()
  readonly property int monthLength: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
  readonly property int weekStart: locale.firstDayOfWeek % 7
  readonly property int leadingDays: (firstWeekday - weekStart + 7) % 7

  readonly property int quoteDay: Math.floor(Date.UTC(now.getFullYear(),
    now.getMonth(), now.getDate()) / 86400000)
  readonly property string monthKey: now.getFullYear() + "-" + (now.getMonth() + 1) + "-"
  readonly property var dailyFocus: totals.dailyMilliseconds ?? ({})
  readonly property double todayFocus: dailyFocus[monthKey + today] || 0
  readonly property double monthFocus: Object.keys(dailyFocus)
    .filter(key => key.startsWith(monthKey))
    .reduce((sum, key) => sum + dailyFocus[key], 0)

  function formatFocus(milliseconds) {
    const seconds = Math.floor(Math.max(0, milliseconds) / 1000)
    return strings.t("time")
      .arg(I18n.formatNumber(Math.floor(seconds / 3600)))
      .arg(I18n.formatNumber(Math.floor(seconds / 60) % 60))
      .arg(I18n.formatNumber(seconds % 60))
  }

  Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  FileView {
    id: totalsFile
    path: Qt.resolvedUrl("../../pomodoro-totals.json")
    watchChanges: true
    onFileChanged: reload()
    Component.onCompleted: totalsFile.text()

    JsonAdapter {
      id: totals
      property var dailyMilliseconds: ({})
    }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      const current = new Date()
      if (Math.floor(current.getTime() / 60000) !== Math.floor(root.now.getTime() / 60000))
        root.now = current
    }
  }

  component Card: Rectangle {
    width: 278
    radius: 18
    color: Qt.alpha(Color.background, 0.93)
    border.width: 1
    border.color: Qt.alpha(Color.foreground, 0.23)
  }

  component Label: Text {
    color: Color.foreground
    font.family: Style.font.family
    textFormat: Text.PlainText
  }

  component FocusCard: Card {
    required property string title
    required property double milliseconds
    height: summary.height + 32

    Column {
      id: summary
      anchors.centerIn: parent
      width: parent.width - 36
      spacing: 7

      Label {
        font.pixelSize: 13
        text: summary.parent.title
      }

      Label {
        width: parent.width
        font.pixelSize: 23
        font.weight: Font.DemiBold
        text: root.formatFocus(summary.parent.milliseconds)
      }
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData
      anchors { top: true; right: true }
      margins { top: 64; right: 34 }
      implicitWidth: cards.width
      implicitHeight: cards.height
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      mask: Region {}
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "local-desktop-widgets"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      Column {
        id: cards
        spacing: 12
        LayoutMirroring.enabled: I18n.rightToLeft
        LayoutMirroring.childrenInherit: true

        Card {
          height: 117

          Column {
            anchors.centerIn: parent
            spacing: 4

            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              font.pixelSize: 46
              font.weight: Font.DemiBold
              text: root.now.toLocaleTimeString(root.locale, "HH:mm")
            }

            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              font.pixelSize: 14
              text: root.now.toLocaleDateString(root.locale, "dddd, d MMMM")
            }
          }
        }

        Card {
          height: calendar.height + 32

          Column {
            id: calendar
            anchors.centerIn: parent
            spacing: 10

            Label {
              anchors.horizontalCenter: parent.horizontalCenter
              font.pixelSize: 17
              font.weight: Font.DemiBold
              text: root.now.toLocaleDateString(root.locale, "MMMM yyyy")
            }

            Grid {
              columns: 7
              rowSpacing: 2
              columnSpacing: 3

              Repeater {
                model: 7

                Label {
                  required property int index
                  width: 32
                  height: 23
                  horizontalAlignment: Text.AlignHCenter
                  verticalAlignment: Text.AlignVCenter
                  opacity: 0.75
                  font.pixelSize: 11
                  font.weight: Font.DemiBold
                  elide: Text.ElideRight
                  text: root.locale.standaloneDayName((root.weekStart + index) % 7, Locale.ShortFormat)
                }
              }

              Repeater {
                model: 7 * Math.ceil((root.leadingDays + root.monthLength) / 7)

                Rectangle {
                  required property int index
                  readonly property int day: index - root.leadingDays + 1
                  readonly property bool isToday: day === root.today
                  width: 32
                  height: 27
                  radius: 7
                  color: isToday ? Color.accent : "transparent"

                  Label {
                    anchors.centerIn: parent
                    color: parent.isToday ? Color.background : Color.foreground
                    font.pixelSize: 13
                    font.weight: parent.isToday ? Font.Bold : Font.Normal
                    text: parent.day >= 1 && parent.day <= root.monthLength
                      ? I18n.formatNumber(parent.day) : ""
                  }
                }
              }
            }
          }
        }

        FocusCard {
          title: strings.t("today")
          milliseconds: root.todayFocus
        }

        FocusCard {
          title: strings.t("month")
          milliseconds: root.monthFocus
        }

        Card {
          height: dailyQuote.height + 32

          Column {
            id: dailyQuote
            anchors.centerIn: parent
            width: parent.width - 36
            spacing: 8

            Label {
              font.pixelSize: 13
              text: strings.t("quote")
            }

            Label {
              width: parent.width
              font.pixelSize: 16
              wrapMode: Text.WordWrap
              text: Quotes.entries[root.quoteDay % Quotes.entries.length]
            }
          }
        }
      }
    }
  }
}
