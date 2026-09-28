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
    property alias cfg_showDividers: showDividers.checked
    property alias cfg_renderMarkdown: renderMarkdown.checked
    property alias cfg_kdeNotifications: kdeNotifications.checked

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

    QQC2.CheckBox {
        id: kdeNotifications
        Kirigami.FormData.label: i18n("Plasma notifications:")
        text: i18n("Also list alerts under the notification bell")
    }

    QQC2.Label {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.smallSpacing
        text: i18n("Off, the widget works on its own. On, each overlay alert is also listed under Plasma's bell, with no popup or sound, and dismissing its card removes it there. Needs install.sh.")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        color: Kirigami.Theme.disabledTextColor
        wrapMode: Text.WordWrap
    }
}
