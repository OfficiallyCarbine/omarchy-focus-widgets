import QtQuick
import Qt.labs.folderlistmodel

Item {
  id: root

  required property url folder
  property int interval: 8000
  property bool canRotate: false
  property var urls: []
  property var skipped: ({})
  property int offset: 0
  property bool retriedCopy: false
  readonly property var available: urls.filter(url => !skipped[String(url)])
  readonly property url current: available.length === 0 ? ""
    : available[offset % available.length]

  function advance() {
    if (canRotate && available.length > 1)
      offset = (offset + 1) % available.length
  }

  function refresh() {
    const updated = []
    for (let i = 0; i < files.count; i++) {
      const url = files.get(i, "fileUrl")
      if (url) updated.push(url)
    }
    const first = String(current)
    offset = Math.max(0, updated.findIndex(url => String(url) === first))
    skipped = ({})
    retriedCopy = false
    urls = updated
  }

  function reject(source) {
    const key = String(source)
    if (skipped[key] || String(current) !== key) return
    const failures = Object.assign({}, skipped)
    failures[key] = true
    skipped = failures
    // A file manager can create an image before it finishes copying its data.
    if (!retriedCopy) retryCopy.restart()
  }

  FolderListModel {
    id: files
    folder: root.folder
    showDirs: false
    showHidden: false
    showOnlyReadable: true
    caseSensitive: false
    nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.tif", "*.tiff"]
    sortField: FolderListModel.Name
    onCountChanged: settle.restart()
    onStatusChanged: if (status === FolderListModel.Ready) settle.restart()
  }

  Connections {
    target: files
    function onDataChanged() { settle.restart() }
  }

  Timer {
    id: settle
    interval: 300
    onTriggered: root.refresh()
  }

  Timer {
    id: retryCopy
    interval: 2000
    onTriggered: {
      root.retriedCopy = true
      root.skipped = ({})
    }
  }

  Timer {
    id: rotation
    interval: root.interval
    repeat: true
    running: root.canRotate && root.available.length > 1
    onTriggered: root.advance()
  }
}
