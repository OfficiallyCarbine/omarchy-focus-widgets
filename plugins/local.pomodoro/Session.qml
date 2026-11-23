pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

Item {
  id: session

  property bool onBreak: false
  readonly property int minutesLimit: 120
  readonly property int pomodoroLimit: 12
  readonly property int pomodoroCount: Math.max(1, Math.min(pomodoroLimit, preferences.pomodoroCount ?? 4))
  property int setTarget: 0
  property int completedPomodoros: 0
  readonly property bool setComplete: setTarget > 0 && completedPomodoros >= setTarget
  readonly property int focusMinutes: boundedMinutes(preferences.focusMinutes ?? 25)
  readonly property int breakMinutes: boundedMinutes(preferences.breakMinutes ?? 5)
  property alias rainEnabled: preferences.rainEnabled
  property alias rainVolume: preferences.rainVolume
  readonly property bool rainUnavailable: rainPlayer.failed
  property alias alarmEnabled: preferences.alarmEnabled
  readonly property int duration: (onBreak ? breakMinutes : focusMinutes) * 60
  property bool started: false
  property int secondsLeft: duration
  property double deadline: 0
  property double focusAccountedAt: 0
  property double pausedMilliseconds: 0
  readonly property bool running: deadline > 0
  signal finished(bool completedBreak)

  FileView {
    id: settingsFile
    blockLoading: true
    Component.onCompleted: settingsFile.text()
    path: Qt.resolvedUrl("../../pomodoro.json")
    onAdapterUpdated: savePreferences.restart()

    JsonAdapter {
      id: preferences
      property int pomodoroCount: 4
      property int focusMinutes: 25
      property int breakMinutes: 5
      property bool rainEnabled: false
      property int rainVolume: 35
      property bool alarmEnabled: true
    }
  }

  Timer {
    id: savePreferences
    interval: 160
    onTriggered: settingsFile.writeAdapter()
  }

  property double allTimeMilliseconds: 0
  property var dailyMilliseconds: ({})

  FileView {
    id: totalsFile
    path: Qt.resolvedUrl("../../pomodoro-totals.json")
    blockLoading: true
    blockWrites: true
    Component.onCompleted: {
      const content = text()
      if (!content) return
      try {
        const saved = JSON.parse(content)
        session.allTimeMilliseconds = Number(saved.focusMilliseconds) || 0
        session.dailyMilliseconds = saved.dailyMilliseconds ?? ({})
      } catch (error) {
        console.warn("Could not read Pomodoro focus totals:", error)
      }
    }
  }

  function recordFocus(now) {
    if (focusAccountedAt <= 0) return
    const through = Math.min(deadline, now)
    if (through <= focusAccountedAt) return
    const days = Object.assign({}, dailyMilliseconds)
    let cursor = focusAccountedAt
    while (cursor < through) {
      const date = new Date(cursor)
      const year = date.getFullYear()
      const month = date.getMonth()
      const day = date.getDate()
      const key = year + "-" + (month + 1) + "-" + day
      const midnight = new Date(year, month, day + 1).getTime()
      const end = Math.min(through, midnight)
      days[key] = (days[key] || 0) + end - cursor
      cursor = end
    }
    allTimeMilliseconds += through - focusAccountedAt
    dailyMilliseconds = days
    focusAccountedAt = through
    totalsFile.setText(JSON.stringify({
      focusMilliseconds: allTimeMilliseconds,
      dailyMilliseconds: dailyMilliseconds
    }) + "\n")
  }

  function boundedMinutes(value) {
    return Math.max(1, Math.min(minutesLimit, value))
  }

  function setMinutes(forBreak, value) {
    const minutes = boundedMinutes(value)
    if (forBreak)
      preferences.breakMinutes = minutes
    else
      preferences.focusMinutes = minutes
  }

  function setPomodoroCount(value) {
    preferences.pomodoroCount = Math.max(1, Math.min(pomodoroLimit, value))
  }

  onDurationChanged: if (!started) secondsLeft = duration

  function start() {
    if (running) return
    if (!onBreak && (setTarget === 0 || setComplete)) {
      completedPomodoros = 0
      setTarget = pomodoroCount
    }
    if (!started) {
      secondsLeft = duration
      pausedMilliseconds = duration * 1000
    }
    const now = Date.now()
    started = true
    focusAccountedAt = onBreak ? 0 : now
    deadline = now + pausedMilliseconds
  }

  function pause() {
    if (!running) return
    const now = Date.now()
    const remaining = Math.max(0, deadline - now)
    update(now)
    recordFocus(now)
    pausedMilliseconds = remaining
    focusAccountedAt = 0
    deadline = 0
  }

  function stop() {
    if (running) pause()
    started = false
  }

  function toggle() {
    if (running)
      pause()
    else
      start()
  }

  function reset() {
    stop()
    secondsLeft = duration
  }

  function switchPhase(now = Date.now()) {
    recordFocus(now)
    focusAccountedAt = 0
    deadline = 0
    started = false
    onBreak = !onBreak
    secondsLeft = duration
  }

  function skip() {
    if (setComplete) return
    const now = Date.now()
    if (running && now >= deadline) {
      update(now)
      return
    }
    switchPhase(now)
    start()
  }

  function update(now) {
    if (focusAccountedAt > 0 && now - focusAccountedAt >= 5000)
      recordFocus(now)
    secondsLeft = Math.max(0, Math.ceil((deadline - now) / 1000))
    if (secondsLeft === 0) {
      const completedBreak = onBreak
      if (!completedBreak) completedPomodoros += 1
      if (setComplete && !completedBreak) {
        recordFocus(now)
        focusAccountedAt = 0
        deadline = 0
        started = false
        secondsLeft = duration
      } else {
        switchPhase(now)
      }
      finished(completedBreak)
    }
  }

  Timer {
    interval: 200
    repeat: true
    running: session.running
    onTriggered: session.update(Date.now())
  }

  RainPlayer {
    id: rainPlayer
    play: session.rainEnabled && session.running && !session.onBreak
    volume: Math.max(0, Math.min(100, session.rainVolume))
  }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  onFinished: function(completedBreak) {
    if (alarmEnabled)
      Quickshell.execDetached(["paplay", "--volume=36000",
        "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"])
    Quickshell.execDetached(["notify-send", "--app-name=Pomodoro", "--hint=boolean:suppress-sound:true",
      strings.t(setComplete && !completedBreak ? "setFinished" : completedBreak ? "breakFinished" : "focusFinished"),
      strings.t(setComplete && !completedBreak ? "setReady" : completedBreak ? "focusReady" : "breakReady")])
  }
}
