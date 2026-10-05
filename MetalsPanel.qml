import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

KeyboardPanel {
  id: root
  required property var feed
  property real usdToAed: 3.6725
  property real refreshSeconds: 60
  property int tabIndex: 0

  focusTarget: keys
  contentWidth: fittedContentWidth(Style.space(520))
  contentHeight: fittedContentHeight(content.implicitHeight)

  PanelKeyCatcher {
    id: keys
    anchors.fill: parent
    onCloseRequested: root.close()
    onTabRequested: root.tabIndex = 1 - root.tabIndex
    onMoveRequested: function(dx, dy) { if (root.tabIndex === 1 && dx) trend.cycleMetal(dx) }
    onTextKey: function(text) {
      var key = text.toLowerCase()
      if (key === "r") root.feed.refresh()
      else if (key === "t") root.tabIndex = 1 - root.tabIndex
      else if (root.tabIndex === 1 && key === "u") trend.inAed = !trend.inAed
    }

    Flickable {
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: content.implicitHeight
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: content
        width: parent.width
        spacing: Style.space(16)

        Row {
          width: parent.width
          spacing: Style.space(12)
          Column {
            width: parent.width - refreshButton.width - parent.spacing
            spacing: Style.space(4)
            Text {
              text: "Precious metals"
              color: Color.popups.text
              font.family: Style.font.family
              font.pixelSize: Style.font.heading
              font.bold: true
            }
            Text {
              text: "Spot prices · every " + root.refreshSeconds + "s"
              color: Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
          Button {
            id: refreshButton
            text: root.feed.busy ? "Updating…" : "Refresh"
            enabled: !root.feed.busy
            bordered: true
            focusable: true
            onClicked: root.feed.refresh()
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)
          Button {
            text: "Prices"
            selected: root.tabIndex === 0
            focusable: true
            onClicked: root.tabIndex = 0
          }
          Button {
            text: "Trend"
            selected: root.tabIndex === 1
            focusable: true
            onClicked: root.tabIndex = 1
          }
        }

        Row {
          visible: root.tabIndex === 0
          width: parent.width
          Text {
            width: parent.width * 0.28
            text: "METAL"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            width: parent.width * 0.36
            horizontalAlignment: Text.AlignRight
            text: "USD / troy oz"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            width: parent.width * 0.36
            horizontalAlignment: Text.AlignRight
            text: "AED / gram"
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }

        Repeater {
          model: root.tabIndex === 0 ? root.feed.rows : []
          delegate: Column {
            id: metal
            required property var modelData
            readonly property var quote: modelData.quote
            readonly property bool stale: !!modelData.error || Model.isStale(quote, root.feed.now, root.refreshSeconds)
            width: content.width
            spacing: Style.space(6)

            Rectangle {
              width: parent.width
              height: 1
              color: Color.popups.text
              opacity: 0.12
            }
            Row {
              width: parent.width
              Text {
                width: parent.width * 0.28
                text: metal.modelData.name
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                width: parent.width * 0.36
                horizontalAlignment: Text.AlignRight
                text: metal.quote.price ? "$" + Model.numberText(metal.quote.price) : "—"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Text {
                width: parent.width * 0.36
                horizontalAlignment: Text.AlignRight
                text: metal.quote.price ? Model.numberText(Model.aedPerGram(metal.quote.price, root.usdToAed)) : "—"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
            }
            Text {
              width: parent.width
              wrapMode: Text.Wrap
              text: Model.quoteStatus(metal.quote, metal.modelData.error, root.feed.now, root.refreshSeconds)
                + (metal.quote.updatedAt ? " · " + Qt.formatDateTime(new Date(metal.quote.updatedAt), "d MMM HH:mm:ss") : "")
              color: metal.stale ? Color.urgent : Color.muted
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        TrendPanel {
          id: trend
          width: parent.width
          visible: root.tabIndex === 1
          feed: root.feed
          usdToAed: root.usdToAed
          refreshSeconds: root.refreshSeconds
        }

        Text {
          visible: root.tabIndex === 0
          width: parent.width
          wrapMode: Text.Wrap
          text: "1 USD = " + root.usdToAed + " AED · 1 troy oz = 31.1034768 g\nPure-metal spot value; retail premiums, taxes and making charges excluded."
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          width: parent.width
          text: root.tabIndex === 0 ? "gold-api.com · Tab trend · R refresh · Esc close"
            : "Tab prices · Left/Right metal · U units · R refresh · Esc close"
          wrapMode: Text.Wrap
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
