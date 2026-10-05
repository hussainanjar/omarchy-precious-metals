import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "." as Metals

BarWidget {
  id: root
  moduleName: "io.github.hussainanjar.precious-metals"

  readonly property var preferences: Model.preferences(settings)
  readonly property real refreshSeconds: preferences.refreshSeconds
  readonly property real usdToAed: preferences.usdToAed
  property string settingsError: ""
  property bool opened: false
  property bool popoutSwitchClosing: false
  readonly property var quoteFeed: Metals.MetalFeed

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { popoutSwitchClosing = false; opened = true }
  function close() { opened = false }
  function closeForPopoutSwitch() { popoutSwitchClosing = true; close() }
  function refresh() { quoteFeed.refresh() }
  function updateSettings(patch) {
    try { Model.validatePatch(patch) } catch (e) { settingsError = e.message; return false }
    var changed = Object.keys(patch).some(function(name) { return root.settings[name] !== patch[name] })
    if (!changed) { settingsError = ""; return true }
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    for (var name in patch) entry[name] = patch[name]
    if (!bar || !bar.shell || typeof bar.shell.updateEntryInline !== "function"
      || bar.shell.updateEntryInline(moduleName, entry) === false) {
      settingsError = "Could not save settings. Try reopening the widget."
      return false
    }
    settings = entry
    settingsError = ""
    return true
  }
  function cycleUnits() {
    var units = ["g", "oz", "kg"]
    updateSettings({ unit: units[(units.indexOf(preferences.unit) + 1) % units.length] })
  }

  Binding {
    target: root.quoteFeed
    property: "refreshSeconds"
    value: root.refreshSeconds
  }
  Binding { target: root.quoteFeed; property: "currency"; value: root.preferences.currency }
  Binding { target: root.quoteFeed; property: "usdToAed"; value: root.usdToAed }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.selectedBarLabel(root.quoteFeed.rows, root.preferences, root.quoteFeed.conversionRate, root.quoteFeed.fxOffline, root.quoteFeed.now, root.vertical)
    fixedHeight: root.vertical ? Style.bar.iconSlot * 2 : -1
    tooltipText: "Precious metal spot prices\nClick for Prices, Trend and Settings · Right-click to cycle units\nMiddle-click to refresh · ! means stale or offline"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.cycleUnits()
      else if (mouseButton === Qt.MiddleButton) root.broadcast("refresh")
      else if (root.opened) root.close()
      else root.open()
    }
  }

  MetalsPanel {
    id: panel
    anchorItem: button
    bar: root.bar
    owner: root
    widget: root
    open: root.opened
    feed: quoteFeed
    refreshSeconds: root.refreshSeconds
  }

  IpcHandler {
    target: "io.github.hussainanjar.precious-metals"
    function refresh(): void { root.broadcast("refresh") }
    function trend(): void { panel.tabIndex = 1; root.open() }
    function prices(): void { panel.tabIndex = 0; root.open() }
    function settings(): void { panel.tabIndex = 2; root.open() }
    function configure(json: string): string {
      try {
        var ok = root.updateSettings(JSON.parse(json))
        return JSON.stringify({ saved: ok, error: root.settingsError, preferences: root.preferences })
      } catch (e) { return JSON.stringify({ saved: false, error: "Invalid settings JSON" }) }
    }
    function status(): string {
      return JSON.stringify({ preferences: root.preferences, conversionRate: root.quoteFeed.conversionRate, conversionStatus: root.quoteFeed.conversionStatus, fxOffline: root.quoteFeed.fxOffline, rows: root.quoteFeed.rows, historyCounts: Object.keys(root.quoteFeed.history).map(function(symbol) { return { symbol: symbol, count: root.quoteFeed.history[symbol].length } }), storageError: root.quoteFeed.storageError, settingsError: root.settingsError })
    }
  }
}
