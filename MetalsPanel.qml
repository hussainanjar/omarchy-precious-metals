import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

KeyboardPanel {
  id: root
  required property var feed
  required property var widget
  property real refreshSeconds: 60
  property int tabIndex: 0

  focusTarget: keys
  contentWidth: fittedContentWidth(Style.space(520))
  contentHeight: fittedContentHeight(content.implicitHeight, Style.space(900))

  Item {
    id: keys
    anchors.fill: parent
    focus: true
    Keys.priority: Keys.AfterItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true; return }
      if (root.tabIndex === 2 && settingsPanel.editing) return
      var key = event.text.toLowerCase()
      if (key === "r") { root.feed.refresh(); event.accepted = true }
      else if (key === "t") { root.tabIndex = (root.tabIndex + 1) % 3; event.accepted = true }
      else if (root.tabIndex === 1 && key === "u") { root.widget.cycleUnits(); event.accepted = true }
      else if (root.tabIndex === 1 && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
        trend.cycleMetal(event.key === Qt.Key_Left ? -1 : 1); event.accepted = true
      }
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
          Button {
            text: "Settings"
            selected: root.tabIndex === 2
            focusable: true
            onClicked: root.tabIndex = 2
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
            width: parent.width * (root.widget.preferences.showReference ? 0.36 : 0.72)
            horizontalAlignment: Text.AlignRight
            text: root.widget.preferences.currency + " / " + Model.unitName(root.widget.preferences.unit)
            color: Color.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
          Text {
            width: parent.width * 0.36
            horizontalAlignment: Text.AlignRight
            visible: root.widget.preferences.showReference
            text: "USD / troy oz"
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
                width: parent.width * (root.widget.preferences.showReference ? 0.36 : 0.72)
                horizontalAlignment: Text.AlignRight
                text: metal.quote.price ? Model.numberText(Model.convertedPrice(metal.quote.price, root.feed.conversionRate, root.widget.preferences.unit)) : "—"
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Text {
                visible: root.widget.preferences.showReference
                width: parent.width * 0.36
                horizontalAlignment: Text.AlignRight
                text: metal.quote.price ? "$" + Model.numberText(metal.quote.price) : "—"
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
          widget: root.widget
          refreshSeconds: root.refreshSeconds
        }

        SettingsPanel {
          id: settingsPanel
          width: parent.width
          visible: root.tabIndex === 2
          widget: root.widget
        }

        Text {
          visible: root.tabIndex === 0
          width: parent.width
          wrapMode: Text.Wrap
          text: root.feed.conversionStatus + " · 1 troy oz = 31.1034768 g\nPure-metal spot value; retail premiums, taxes and making charges excluded."
          color: root.feed.fxOffline ? Color.urgent : Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          width: parent.width
          text: root.tabIndex === 1 ? "T tabs · Left/Right metal · U units · R refresh · Esc close"
            : "T tabs · Tab controls · R refresh · Esc close"
          wrapMode: Text.Wrap
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }
    }
  }
}
