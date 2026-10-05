import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root
  required property var feed
  required property var widget
  property real refreshSeconds: 60
  readonly property int metalIndex: Model.metalNames.indexOf(widget.preferences.chartMetal)
  readonly property int hours: widget.preferences.chartHours
  property int hoverIndex: -1
  readonly property var metal: feed.rows[metalIndex]
  readonly property var points: Model.windowSamples(feed.history[metal.symbol], feed.now, hours)
  readonly property var stats: Model.trendStats(points)
  readonly property string units: widget.preferences.currency + " / " + Model.unitName(widget.preferences.unit)
  readonly property real startTime: points.length ? Math.max(feed.now - hours * 3600000, points[0].updatedAt) : feed.now - hours * 3600000
  readonly property real span: Math.max(60000, feed.now - startTime)
  readonly property real paddingValue: stats ? Math.max((stats.high - stats.low) * 0.12, stats.last * 0.0001) : 1
  readonly property real lower: stats ? stats.low - paddingValue : 0
  readonly property real upper: stats ? stats.high + paddingValue : 1
  readonly property color lineColor: Color.accent
  readonly property color gridColor: Color.muted
  readonly property real axisWidth: Math.max(Style.space(74), axisMeasure.implicitWidth + Style.space(8))
  spacing: Style.space(12)

  Text {
    id: axisMeasure
    visible: false
    text: root.priceText(root.upper)
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
  }

  function value(price) { return Model.convertedPrice(price, feed.conversionRate, widget.preferences.unit) }
  function priceText(price) { return Model.numberText(value(price)) }
  function cycleMetal(direction) { widget.updateSettings({ chartMetal: Model.metalNames[(metalIndex + direction + 4) % 4] }) }
  function xFor(point) { return (point.updatedAt - startTime) / span * plot.width }
  function yFor(point) { return plot.height - (point.price - lower) / (upper - lower) * plot.height }
  function repaint() { if (visible) plot.requestPaint() }
  onPointsChanged: { hoverIndex = -1; repaint() }
  onLineColorChanged: repaint()
  onGridColorChanged: repaint()
  onVisibleChanged: repaint()
  onHoverIndexChanged: repaint()

  Row {
    width: parent.width
    spacing: Style.space(4)
    Repeater {
      model: ["Gold", "Silver", "Platinum", "Palladium"]
      delegate: Button {
        required property string modelData
        required property int index
        text: modelData
        width: (root.width - Style.space(12)) / 4
        horizontalPadding: Style.space(4)
        fontSize: Style.font.bodySmall
        selected: root.metalIndex === index
        focusable: true
        onClicked: root.widget.updateSettings({ chartMetal: modelData })
      }
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(4)
    Row {
      id: rangeButtons
      spacing: Style.space(4)
      Repeater {
        model: [1, 6, 24]
        delegate: Button {
          required property int modelData
          text: modelData + "h"
          selected: root.hours === modelData
          focusable: true
          onClicked: root.widget.updateSettings({ chartHours: modelData })
        }
      }
    }
    Item { width: Math.max(0, root.width - rangeButtons.width - unitButton.width - Style.space(8)); height: 1 }
    Button {
      id: unitButton
      text: root.widget.preferences.currency + "/" + root.widget.preferences.unit
      bordered: true
      focusable: true
      onClicked: root.widget.cycleUnits()
    }
  }

  Text {
    width: parent.width
    text: root.stats ? root.metal.name + "  " + root.priceText(root.stats.last) + "  " + root.units : root.metal.name + " · " + root.units
    color: Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    font.bold: true
    wrapMode: Text.Wrap
  }
  Text {
    width: parent.width
    text: root.points.length >= 2 && root.feed.conversionRate > 0
      ? (root.stats.change > 0 ? "+" : root.stats.change < 0 ? "−" : "")
        + Model.numberText(Math.abs(root.value(root.stats.change))) + " ("
        + (root.stats.percent > 0 ? "+" : "") + root.stats.percent.toFixed(2)
        + "%) since " + Qt.formatDateTime(new Date(root.points[0].updatedAt), "HH:mm")
      : root.feed.conversionRate <= 0 ? root.feed.conversionStatus : "Waiting for more quotes to draw the trend."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }

  Item {
    width: parent.width
    height: Style.space(210)
    visible: root.points.length >= 2 && root.feed.conversionRate > 0
    Item {
      width: root.axisWidth
      height: parent.height
      Repeater {
        model: 3
        delegate: Text {
          required property int index
          width: parent.width - Style.space(8)
          text: Model.numberText(root.value(root.upper - index * (root.upper - root.lower) / 2))
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
          y: index * (plot.height - implicitHeight) / 2
        }
      }
    }
    Canvas {
      id: plot
      x: root.axisWidth
      width: parent.width - x
      height: parent.height - Style.space(28)
      onWidthChanged: root.repaint()
      onHeightChanged: root.repaint()
      onPaint: {
        var ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.strokeStyle = root.gridColor
        ctx.globalAlpha = 0.25
        ctx.lineWidth = 1
        for (var grid = 0; grid < 3; grid++) {
          ctx.beginPath()
          ctx.moveTo(0, grid * (height - 1) / 2 + 0.5)
          ctx.lineTo(width, grid * (height - 1) / 2 + 0.5)
          ctx.stroke()
        }
        ctx.globalAlpha = 1
        ctx.strokeStyle = root.lineColor
        ctx.lineWidth = Style.space(2)
        ctx.lineJoin = "round"
        ctx.beginPath()
        var maxGap = Math.max(180, root.refreshSeconds * 3) * 1000
        for (var i = 0; i < root.points.length; i++) {
          var point = root.points[i]
          var x = root.xFor(point), y = root.yFor(point)
          if (i === 0 || point.updatedAt - root.points[i - 1].updatedAt > maxGap) ctx.moveTo(x, y)
          else ctx.lineTo(x, y)
        }
        ctx.stroke()
        // Dots also make isolated observations visible after an outage.
        for (var j = 0; j < root.points.length; j++) {
          if (j !== root.points.length - 1 && j !== root.hoverIndex && j !== 0
            && root.points[j].updatedAt - root.points[j - 1].updatedAt <= maxGap) continue
          ctx.fillStyle = root.lineColor
          ctx.beginPath()
          ctx.arc(root.xFor(root.points[j]), root.yFor(root.points[j]), Style.space(3), 0, Math.PI * 2)
          ctx.fill()
        }
        if (root.hoverIndex >= 0 && root.hoverIndex < root.points.length) {
          var hoverX = root.xFor(root.points[root.hoverIndex])
          ctx.strokeStyle = root.gridColor
          ctx.lineWidth = 1
          ctx.beginPath(); ctx.moveTo(hoverX, 0); ctx.lineTo(hoverX, height); ctx.stroke()
        }
      }
      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: function(mouse) {
          var time = root.startTime + mouse.x / width * root.span
          var closest = -1, distance = Infinity
          for (var i = 0; i < root.points.length; i++) {
            var delta = Math.abs(root.points[i].updatedAt - time)
            if (delta < distance) { distance = delta; closest = i }
          }
          root.hoverIndex = closest
        }
        onExited: root.hoverIndex = -1
      }
    }
    Row {
      x: plot.x
      y: plot.height + Style.space(8)
      width: plot.width
      Text {
        width: parent.width / 2
        text: Qt.formatDateTime(new Date(root.startTime), "HH:mm")
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
      Text {
        width: parent.width / 2
        text: "Now · " + Qt.formatDateTime(new Date(root.feed.now), "HH:mm")
        horizontalAlignment: Text.AlignRight
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  Text {
    width: parent.width
    visible: root.widget.preferences.currency !== "USD"
    text: root.feed.conversionStatus + ". Every chart point uses this conversion."
    color: root.feed.fxOffline ? Color.urgent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
  Text {
    width: parent.width
    visible: root.points.length < 2
    text: root.points.length ? "First quote saved. The chart will appear when the next timestamp arrives."
      : root.metal.error ? "The price feed is unreachable. Recording will resume when it reconnects."
      : "Recording begins with the first live quote. Keep the widget running to build your history."
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    wrapMode: Text.Wrap
  }
  Text {
    width: parent.width
    visible: root.points.length >= 2
    text: root.hoverIndex >= 0
      ? Qt.formatDateTime(new Date(root.points[root.hoverIndex].updatedAt), "d MMM HH:mm:ss")
        + " · " + root.priceText(root.points[root.hoverIndex].price) + " " + root.units
      : root.stats ? "Low " + root.priceText(root.stats.low) + " · High " + root.priceText(root.stats.high) + " · " + root.points.length + " quotes" : ""
    color: Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
  Text {
    width: parent.width
    text: Model.quoteStatus(root.metal.quote, root.metal.error, root.feed.now, root.refreshSeconds)
    color: root.metal.error || Model.isStale(root.metal.quote, root.feed.now, root.refreshSeconds) ? Color.urgent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
  Text {
    width: parent.width
    text: root.feed.storageError || "Quotes collected on this computer · last 24 hours saved. Gaps mark time without updates."
    color: root.feed.storageError ? Color.urgent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
}
