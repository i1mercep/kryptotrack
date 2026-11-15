import QtQuick
import "../../code/http.mjs" as Http
import "../../code/providerRouter.mjs" as Router

Item {
    id: root

    readonly property bool canRefresh: !loading && now >= retryAt
    property var error: null
    property bool loading: false
    property double now: Date.now()
    property var quote: null
    // Injectable transport makes the real QML/controller boundary testable offline.
    property var requestFunction: function (spec, timeout, done) {
        return Http.request(spec, timeout, done, scheduler.schedule, function () {
            return new XMLHttpRequest();
        }, scheduler.send);
    }
    property double retryAt: 0
    property var session: null
    property var settings: ({})
    readonly property bool stale: quote !== null && (error !== null || now - quote.updatedAt > Math.max(120000, (settings.refreshInterval ?? 60) * 2000))

    function configure(): void {
        if (root.session)
            root.session.configure(root.settings);
    }

    function refresh(): void {
        if (root.session)
            root.session.refresh();
    }

    visible: false

    Component.onCompleted: {
        root.session = Router.createSession({
            request: function (spec, timeout, done) {
                return root.requestFunction(spec, timeout, done);
            },
            schedule: scheduler.schedule,
            now: Date.now,
            random: Math.random,
            changed: function (state) {
                root.quote = state.quote;
                root.loading = state.loading;
                root.error = state.error;
                root.retryAt = state.retryAt;
                root.now = Date.now();
            }
        });
        Qt.callLater(root.configure);
    }
    Component.onDestruction: {
        if (root.session)
            root.session.dispose();
    }
    onSettingsChanged: Qt.callLater(root.configure)

    RequestScheduler {
        id: scheduler
    }

    Timer {
        interval: Math.max(5000, (root.settings.refreshInterval ?? 60) * 1000)
        repeat: true
        running: true

        onTriggered: root.refresh()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true

        onTriggered: root.now = Date.now()
    }
}
