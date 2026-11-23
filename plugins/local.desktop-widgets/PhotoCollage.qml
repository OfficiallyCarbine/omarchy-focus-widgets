import QtQuick
import QtQuick.Effects
import qs.Commons

Rectangle {
  id: root
  required property var slideshow
  readonly property bool hasPhoto: String(slideshow.current) !== ""
  radius: 23
  color: Qt.alpha(Color.background, 0.94)
  border.color: Qt.alpha(Color.foreground, 0.23)

  Rectangle {
    id: roundedMask
    anchors.fill: parent
    radius: root.radius
    visible: false
    layer.enabled: root.hasPhoto
  }

  Item {
    anchors.fill: parent
    visible: root.hasPhoto
    layer.enabled: visible
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: roundedMask
      maskThresholdMin: 0.5
      maskSpreadAtMin: 0.9
    }

    Image {
      anchors.fill: parent
      source: root.slideshow.current
      sourceSize: Qt.size(640, 640)
      asynchronous: true
      retainWhileLoading: true
      autoTransform: true
      fillMode: Image.PreserveAspectCrop
      clip: true

      onStatusChanged: {
        if (status === Image.Error) {
          const failed = source
          Qt.callLater(() => root.slideshow.reject(failed))
        }
      }
    }
  }

  Column {
    anchors.centerIn: parent
    width: parent.width - 40
    spacing: 8
    visible: !root.hasPhoto

    Text {
      width: parent.width
      text: qsTr("Photo slideshow")
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      color: Color.foreground
      font.family: Style.font.family
      font.pixelSize: 17
      font.bold: true
    }

    Text {
      width: parent.width
      text: qsTr("Drop pictures into Downloads → Slideshow")
      textFormat: Text.PlainText
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      color: Color.foreground
      opacity: 0.75
      font.family: Style.font.family
      font.pixelSize: 13
    }
  }
}
