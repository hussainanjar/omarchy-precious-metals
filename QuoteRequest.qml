import QtQuick
import "Model.js" as Model

Item {
  id: root
  required property string symbol
  property var quote: ({})
  property string error: ""
  property bool busy: false
  property var request: null
  property double lastAttempt: 0
  signal received(var value)

  function refresh() {
    // Respect the provider's 30-second cache even on repeated manual refresh.
    if (busy || Date.now() - lastAttempt < 30000) return
    lastAttempt = Date.now()
    busy = true
    var xhr = new XMLHttpRequest()
    request = xhr
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE || root.request !== xhr) return
      deadline.stop()
      root.request = null
      root.busy = false
      if (xhr.status !== 200) {
        root.error = xhr.status ? "Feed error (HTTP " + xhr.status + ")" : "Feed unreachable"
        return
      }
      try {
        root.quote = Model.normalizeQuote(JSON.parse(xhr.responseText), root.symbol, Date.now())
        root.error = ""
        root.received(root.quote)
      } catch (e) {
        root.error = "Invalid feed response"
      }
    }
    try {
      xhr.open("GET", "https://api.gold-api.com/price/" + symbol)
      deadline.start()
      xhr.send()
    } catch (e) {
      deadline.stop()
      request = null
      busy = false
      error = "Feed unreachable"
    }
  }

  Timer {
    id: deadline
    interval: 15000
    onTriggered: {
      var pending = root.request
      root.request = null
      if (pending) {
        pending.onreadystatechange = null
        pending.abort()
      }
      root.busy = false
      root.error = "Feed timed out"
    }
  }

  Component.onDestruction: {
    if (request) {
      request.onreadystatechange = null
      request.abort()
    }
  }
}
