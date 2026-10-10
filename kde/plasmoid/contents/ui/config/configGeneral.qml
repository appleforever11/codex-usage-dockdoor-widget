import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_helperPort: portSpin.value
    property alias cfg_pollIntervalMs: pollSpin.value
    property alias cfg_helperRefreshSeconds: refreshSpin.value
    property alias cfg_sessionsFolder: sessionsField.text
    property alias cfg_usageStatePath: usageField.text
    property alias cfg_recentSessionCount: recentSpin.value
    property alias cfg_usageBudgetMillions: budgetSpin.value
    property alias cfg_usageWindowHours: windowSpin.value
    property alias cfg_dailyGoalMillions: goalSpin.value
    property alias cfg_chatViewerCommand: viewerField.text

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.Label {
            text: i18n("The plasmoid reads dataSource from the codex-usage-helper daemon over localhost. Keep the port identical on both sides.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Helper connection")
        }

        QQC2.SpinBox {
            id: portSpin
            Kirigami.FormData.label: i18n("Helper port:")
            from: 1024
            to: 65535
        }

        QQC2.SpinBox {
            id: pollSpin
            Kirigami.FormData.label: i18n("UI poll interval (ms):")
            from: 2000
            to: 60000
            stepSize: 1000
        }

        QQC2.SpinBox {
            id: refreshSpin
            Kirigami.FormData.label: i18n("Account refresh (seconds):")
            from: 30
            to: 600
            stepSize: 15
        }

        QQC2.Label {
            text: i18n("Local Codex dataSource (changes also apply in the helper)")
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: sessionsField
            Kirigami.FormData.label: i18n("Codex sessions folder:")
            placeholderText: "~/.codex/sessions"
        }

        QQC2.TextField {
            id: usageField
            Kirigami.FormData.label: i18n("Usage state file:")
            placeholderText: "~/.codex/usage.json"
        }

        QQC2.SpinBox {
            id: recentSpin
            Kirigami.FormData.label: i18n("Recent session count:")
            from: 3
            to: 10
        }

        QQC2.SpinBox {
            id: budgetSpin
            Kirigami.FormData.label: i18n("Usage budget (M tokens):")
            from: 25
            to: 500
            stepSize: 25
        }

        QQC2.SpinBox {
            id: windowSpin
            Kirigami.FormData.label: i18n("Usage window (hours):")
            from: 1
            to: 24
        }

        QQC2.SpinBox {
            id: goalSpin
            Kirigami.FormData.label: i18n("Daily token goal (M):")
            from: 1
            to: 20
            stepSize: 1
            value: 2
        }

        QQC2.TextField {
            id: viewerField
            Kirigami.FormData.label: i18n("Chat viewer command:")
            placeholderText: "xdg-open {file}"
        }
        QQC2.Label {
            text: i18n("Used when a recent chat is clicked. The session is rendered to Markdown and opened with this shell command; {file} is the transcript path. Examples: kitty -e nvim {file} · code {file}")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pointSize: -1
            font.pixelSize: 11
            opacity: 0.7
        }
    }
}
