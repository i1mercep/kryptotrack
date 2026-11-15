pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: root

    // Timers belong to this instance. A long server cooldown is split into
    // supported Timer intervals without shortening the absolute deadline.
    function schedule(milliseconds: double, callback: var): var {
        let settled = false;
        const timer = timerComponent.createObject(root, {
            deadline: Date.now() + Math.max(0, milliseconds),
            interval: Math.max(1, Math.min(2147483647, milliseconds)),
            callback: function () {
                settled = true;
                callback();
            }
        });
        timer.start();
        return function () {
            if (settled)
                return;
            settled = true;
            if (timer) {
                timer.stop();
                timer.destroy();
            }
        };
    }

    // Qt captures the calling QML context in send(); ES modules have none.
    function send(xhr: var): void {
        xhr.send();
    }

    visible: false

    Component {
        id: timerComponent

        Timer {
            id: timer

            property var callback
            property double deadline

            repeat: false

            onTriggered: {
                const remaining = timer.deadline - Date.now();
                if (remaining > 0) {
                    timer.interval = Math.min(2147483647, remaining);
                    timer.restart();
                    return;
                }
                timer.callback();
                timer.destroy();
            }
        }
    }
}
