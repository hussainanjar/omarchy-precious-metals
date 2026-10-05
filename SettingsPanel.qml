import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root
  required property var widget
  readonly property var preferences: widget.preferences
  readonly property bool editing: rateField.activeFocus
  property string rateError: ""
  spacing: Style.space(16)

  component Choices: Column {
    id: choices
    required property string label
    required property var options
    required property var currentValue
    property int columns: 0
    signal chosen(var value)
    spacing: Style.space(6)
    Text {
      text: choices.label
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Flow {
      width: parent.width
      spacing: Style.space(4)
      Repeater {
        model: choices.options
        delegate: Button {
          required property var modelData
          readonly property var optionValue: typeof modelData === "object" ? modelData.value : modelData
          text: String(typeof modelData === "object" ? modelData.label : modelData)
          selected: optionValue === choices.currentValue
          width: choices.columns ? (choices.width - (choices.columns - 1) * Style.space(4)) / choices.columns : implicitWidth
          horizontalPadding: Style.space(6)
          fontSize: Style.font.bodySmall
          focusable: true
          Accessible.role: Accessible.Button
          Accessible.name: choices.label + ": " + text
          onClicked: choices.chosen(optionValue)
        }
      }
    }
  }

  Choices {
    width: parent.width
    label: "Currency"
    options: Model.currencies
    columns: 5
    currentValue: root.preferences.currency
    onChosen: function(value) { root.widget.updateSettings({ currency: value }) }
  }
  Choices {
    width: parent.width
    label: "Weight unit"
    options: [{ label: "Gram", value: "g" }, { label: "Troy ounce", value: "oz" }, { label: "Kilogram", value: "kg" }]
    columns: 3
    currentValue: root.preferences.unit
    onChosen: function(value) { root.widget.updateSettings({ unit: value }) }
  }
  Column {
    width: parent.width
    spacing: Style.space(6)
    visible: root.preferences.currency === "AED"
    Text {
      text: "AED per USD · fixed conversion"
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }
    Row {
      width: parent.width
      spacing: Style.space(8)
      TextField {
        id: rateField
        width: parent.width - applyRate.implicitWidth - parent.spacing
        text: String(root.preferences.usdToAed)
        placeholderText: "3.6725"
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        Accessible.name: "AED per USD"
        onAccepted: root.applyRate()
        onTextEdited: root.rateError = ""
      }
      Button {
        id: applyRate
        text: "Apply rate"
        bordered: true
        focusable: true
        enabled: rateField.text.trim() !== ""
        onClicked: root.applyRate()
      }
    }
    Text {
      width: parent.width
      visible: root.rateError !== ""
      text: root.rateError
      color: Color.urgent
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.Wrap
    }
  }
  Text {
    width: parent.width
    text: root.widget.quoteFeed.conversionStatus
    color: root.widget.quoteFeed.fxOffline ? Color.urgent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }
  Choices {
    width: parent.width
    label: "First metal in the bar"
    options: Model.metalNames
    columns: 4
    currentValue: root.preferences.primaryMetal
    onChosen: function(value) { root.widget.updateSettings({ primaryMetal: value }) }
  }
  Choices {
    width: parent.width
    label: "Second metal in the bar"
    options: ["None"].concat(Model.metalNames)
    columns: 5
    currentValue: root.preferences.secondaryMetal
    onChosen: function(value) { root.widget.updateSettings({ secondaryMetal: value }) }
  }
  Choices {
    width: parent.width
    label: "Bar prices"
    options: [{ label: "Selected currency / unit", value: "Selected" }, { label: "Also show USD / oz", value: "Both" }]
    columns: 2
    currentValue: root.preferences.barDisplay
    onChosen: function(value) { root.widget.updateSettings({ barDisplay: value }) }
  }
  Toggle {
    width: parent.width
    label: "USD reference column"
    description: "Keep USD per troy ounce beside your selected price."
    checked: root.preferences.showReference
    onClicked: root.widget.updateSettings({ showReference: !root.preferences.showReference })
  }
  Choices {
    width: parent.width
    label: "Refresh interval"
    options: [{ label: "30 sec", value: 30 }, { label: "1 min", value: 60 }, { label: "2 min", value: 120 }, { label: "5 min", value: 300 }]
    columns: 4
    currentValue: root.preferences.refreshSeconds
    onChosen: function(value) { root.widget.updateSettings({ refreshSeconds: value }) }
  }
  Choices {
    width: parent.width
    label: "Chart metal"
    options: Model.metalNames
    columns: 4
    currentValue: root.preferences.chartMetal
    onChosen: function(value) { root.widget.updateSettings({ chartMetal: value }) }
  }
  Choices {
    width: parent.width
    label: "Chart range"
    options: [{ label: "1 hour", value: 1 }, { label: "6 hours", value: 6 }, { label: "24 hours", value: 24 }]
    columns: 3
    currentValue: root.preferences.chartHours
    onChosen: function(value) { root.widget.updateSettings({ chartHours: value }) }
  }
  Text {
    width: parent.width
    text: root.widget.settingsError || "Preferences save automatically and apply to Prices, Trend and the bar. History keeps its original USD quotes."
    color: root.widget.settingsError ? Color.urgent : Color.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.Wrap
  }

  function applyRate() {
    var value = Number(rateField.text)
    if (!isFinite(value) || value <= 0 || value > 1000) {
      rateError = "Enter a positive AED rate up to 1000."
      return
    }
    if (widget.updateSettings({ usdToAed: value })) rateError = ""
  }
}
