import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "." as Metals

BarWidget {
  id: root
  moduleName: "io.github.hussainanjar.precious-metals"

  readonly property string displayMode: Model.displayMode(setting("displayMode", "AED/g"))
  readonly property real refreshSeconds: Model.refreshSeconds(setting("refreshSeconds", 60))
  readonly property real usdToAed: Model.positiveNumber(setting("usdToAed", 3.6725), 3.6725)
  property bool opened: false
  property bool popoutSwitchClosing: false
  readonly property var quoteFeed: Metals.MetalFeed

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function open() { popoutSwitchClosing = false; opened = true }
  function close() { opened = false }
  function closeForPopoutSwitch() { popoutSwitchClosing = true; close() }
  function refresh() { quoteFeed.refresh() }
  function cycleUnits() {
    var modes = ["AED/g", "USD/oz", "Both"]
    var entry = { id: moduleName }
    for (var key in settings) if (key !== "id") entry[key] = settings[key]
    entry.displayMode = modes[(modes.indexOf(displayMode) + 1) % modes.length]
    settings = entry
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }

  Binding {
    target: root.quoteFeed
    property: "refreshSeconds"
    value: root.refreshSeconds
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barLabel(quoteFeed.rows, root.displayMode, root.usdToAed, quoteFeed.now, root.refreshSeconds, root.vertical)
    fixedHeight: root.vertical ? Style.bar.iconSlot * 2 : -1
    tooltipText: "Precious metal spot prices\nClick for USD/oz and AED/g · Right-click to change bar units\nMiddle-click to refresh · ! means stale or offline"
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
    open: root.opened
    feed: quoteFeed
    usdToAed: root.usdToAed
    refreshSeconds: root.refreshSeconds
  }

  IpcHandler {
    target: "io.github.hussainanjar.precious-metals"
    function refresh(): void { root.broadcast("refresh") }
    function trend(): void { panel.tabIndex = 1; root.open() }
    function prices(): void { panel.tabIndex = 0; root.open() }
    function status(): string {
      return JSON.stringify({ displayMode: root.displayMode, refreshSeconds: root.refreshSeconds, usdToAed: root.usdToAed, rows: quoteFeed.rows, historyCounts: Object.keys(quoteFeed.history).map(function(symbol) { return { symbol: symbol, count: quoteFeed.history[symbol].length } }), storageError: quoteFeed.storageError })
    }
  }
}
