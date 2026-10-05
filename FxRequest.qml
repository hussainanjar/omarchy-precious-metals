import QtQuick
import "Model.js" as Model

Item {
  id: root
  property string currency: "AED"
  property bool active: false
  property string error: ""
  property bool busy: false
  property var request: null
  property var lastAttempts: ({})
  signal received(string code, var value)

  function cancel() {
    deadline.stop()
    var xhr = request
    request = null
    busy = false
    if (xhr) { xhr.onreadystatechange = null; xhr.abort() }
  }

  function refresh() {
    if (!active || currency === "AED" || currency === "USD" || busy) return
    var remaining = 30000 - (Date.now() - (lastAttempts[currency] || 0))
    if (remaining > 0) { retry.interval = remaining; retry.restart(); return }
    retry.stop()
    var code = currency
    lastAttempts[code] = Date.now()
    var xhr = new XMLHttpRequest()
    request = xhr
    busy = true
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE || root.request !== xhr) return
      deadline.stop()
      root.request = null
      root.busy = false
      if (xhr.status !== 200) { root.error = "Currency feed unreachable"; return }
      try {
        var rate = Model.normalizeRate(JSON.parse(xhr.responseText), code, Date.now())
        root.error = ""
        root.received(code, rate)
      } catch (e) { root.error = "Invalid currency response" }
    }
    try {
      xhr.open("GET", "https://api.gold-api.com/price/XAU/" + code)
      deadline.start()
      xhr.send()
    } catch (e) { cancel(); error = "Currency feed unreachable" }
  }

  onCurrencyChanged: { retry.stop(); cancel(); error = ""; refresh() }
  onActiveChanged: if (active) refresh()
  Timer { id: retry; onTriggered: root.refresh() }
  Timer {
    id: deadline
    interval: 15000
    onTriggered: { root.cancel(); root.error = "Currency feed timed out" }
  }
  Component.onDestruction: cancel()
}
