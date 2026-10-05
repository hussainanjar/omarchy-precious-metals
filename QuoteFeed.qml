pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root
  property real refreshSeconds: 60
  property double now: Date.now()
  property var history: ({ XAU: [], XAG: [], XPT: [], XPD: [] })
  property bool restored: false
  property string storageError: ""
  readonly property string cacheDirectory: (Quickshell.env("XDG_CACHE_HOME")
    || Quickshell.env("HOME") + "/.cache") + "/omarchy-precious-metals"
  readonly property bool busy: gold.busy || silver.busy || platinum.busy || palladium.busy
  readonly property var rows: [
    { symbol: "XAU", name: "Gold", shortName: "Au", quote: gold.quote, error: gold.error },
    { symbol: "XAG", name: "Silver", shortName: "Ag", quote: silver.quote, error: silver.error },
    { symbol: "XPT", name: "Platinum", shortName: "Pt", quote: platinum.quote, error: platinum.error },
    { symbol: "XPD", name: "Palladium", shortName: "Pd", quote: palladium.quote, error: palladium.error }
  ]

  function refresh() {
    now = Date.now()
    gold.refresh()
    silver.refresh()
    platinum.refresh()
    palladium.refresh()
  }

  function record(symbol, quote) {
    var next = Object.assign({}, history)
    next[symbol] = Model.appendSample(history[symbol], quote, Date.now())
    history = next
    if (restored) saveTimer.restart()
  }

  function restore(raw) {
    if (restored) return
    var saved = {}
    try { saved = JSON.parse(raw).history || {} } catch (e) {}
    var next = {}
    var requests = [gold, silver, platinum, palladium]
    for (var i = 0; i < requests.length; i++) {
      var request = requests[i]
      var points = Model.cleanHistory(saved[request.symbol], Date.now())
      next[request.symbol] = points
      if (points.length) {
        request.quote = points[points.length - 1]
        request.error = "Waiting for live feed"
      }
    }
    history = next
    restored = true
    refresh()
  }

  QuoteRequest { id: gold; symbol: "XAU"; onReceived: function(value) { root.record(symbol, value) } }
  QuoteRequest { id: silver; symbol: "XAG"; onReceived: function(value) { root.record(symbol, value) } }
  QuoteRequest { id: platinum; symbol: "XPT"; onReceived: function(value) { root.record(symbol, value) } }
  QuoteRequest { id: palladium; symbol: "XPD"; onReceived: function(value) { root.record(symbol, value) } }

  Process {
    id: directoryMaker
    command: ["mkdir", "-p", root.cacheDirectory]
    onExited: function(exitCode) {
      if (exitCode === 0) cache.path = root.cacheDirectory + "/history.json"
      else {
        root.storageError = "History could not be saved; this session only."
        root.restore("")
      }
    }
  }
  FileView {
    id: cache
    printErrors: false
    atomicWrites: true
    onLoaded: root.restore(text())
    onLoadFailed: root.restore("")
    onSaveFailed: root.storageError = "History could not be saved; this session only."
    onSaved: root.storageError = ""
  }
  Timer {
    id: saveTimer
    interval: 500
    onTriggered: if (cache.path) cache.setText(JSON.stringify({ version: 1, history: root.history }))
  }

  Timer {
    interval: Model.refreshSeconds(root.refreshSeconds) * 1000
    running: root.restored
    repeat: true
    onTriggered: root.refresh()
  }
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.now = Date.now()
  }
  Component.onCompleted: directoryMaker.running = true
}
