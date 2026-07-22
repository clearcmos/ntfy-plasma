import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root

    property alias cfg_serverUrl: serverUrl.text
    property alias cfg_topics: topics.text
    property alias cfg_maxMessages: maxMessages.value
    property alias cfg_historySince: historySince.text
    property alias cfg_textScale: textScale.value
    property alias cfg_showDividers: showDividers.checked
    property alias cfg_renderMarkdown: renderMarkdown.checked

    QQC2.TextField {
        id: serverUrl
        Kirigami.FormData.label: i18n("Server URL:")
        Layout.fillWidth: true
        placeholderText: "https://ntfy.sh"
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        text: i18n("Public ntfy.sh works without an account. For private alerts, self-host: docs.ntfy.sh")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }

    QQC2.TextField {
        id: topics
        Kirigami.FormData.label: i18n("Topics:")
        Layout.fillWidth: true
        placeholderText: "my-alerts,backups"
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        text: i18n("Comma-separated. On public ntfy.sh, anyone who knows the topic name can read it - pick something hard to guess.")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }

    QQC2.TextField {
        id: historySince
        Kirigami.FormData.label: i18n("Backfill on reconnect:")
        Layout.fillWidth: true
        placeholderText: "1h"
    }

    QQC2.SpinBox {
        id: maxMessages
        Kirigami.FormData.label: i18n("Keep last:")
        from: 10
        to: 1000
        stepSize: 10
    }

    QQC2.ComboBox {
        id: textScaleCombo
        Kirigami.FormData.label: i18n("Text size:")
        Layout.fillWidth: true

        readonly property var presets: [
            { label: i18n("Compact"),      value: 0.90 },
            { label: i18n("Default"),      value: 1.00 },
            { label: i18n("Comfortable"),  value: 1.15 },
            { label: i18n("Large"),        value: 1.30 },
            { label: i18n("Largest"),      value: 1.50 }
        ]

        textRole: "label"
        valueRole: "value"
        model: presets

        // Bind selection to the underlying numeric config value. We pick the
        // closest preset on first load so a hand-edited config still maps
        // somewhere sensible.
        Component.onCompleted: {
            const v = textScale.value
            let bestIdx = 1
            let bestDiff = Math.abs(presets[1].value - v)
            for (let i = 0; i < presets.length; i++) {
                const d = Math.abs(presets[i].value - v)
                if (d < bestDiff) { bestDiff = d; bestIdx = i }
            }
            currentIndex = bestIdx
        }

        onActivated: textScale.value = presets[currentIndex].value
    }

    // Real numeric backing for cfg_textScale -- the ComboBox is a UI shell.
    Item {
        visible: false
        QtObject {
            id: textScale
            property real value: 1.0
        }
    }

    QQC2.CheckBox {
        id: showDividers
        Kirigami.FormData.label: i18n("Separator between messages:")
        text: i18n("Show divider line")
    }

    QQC2.CheckBox {
        id: renderMarkdown
        Kirigami.FormData.label: i18n("Rich rendering:")
        text: i18n("Render Markdown and emoji tags")
    }
}
