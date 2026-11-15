/**
 * QML implements XHR Level 1. Deadlines belong to the owning QML object's
 * scheduler, not browser-only xhr.timeout/ontimeout properties.
 * @param {import('./contracts').RequestSpec} spec
 * @param {number} timeoutMs
 * @param {(error: import('./contracts').Failure | null, response?: import('./contracts').Response) => void} done
 * @param {import('./contracts').Schedule} schedule
 * @param {() => XMLHttpRequest} createXhr
 * @param {(xhr: XMLHttpRequest) => void} [send]
 * @returns {import('./contracts').Cancel}
 */
export function request(spec, timeoutMs, done, schedule, createXhr, send = (xhr) => xhr.send()) {
    const xhr = createXhr();
    let finished = false;
    let stopDeadline = () => {};
    const cleanup = () => {
        stopDeadline();
        xhr.onreadystatechange = null;
    };
    /** @param {import('./contracts').Failure | null} error
     * @param {import('./contracts').Response} [response] */
    const finish = (error, response) => {
        if (finished) return;
        finished = true;
        cleanup();
        done(error, response);
    };
    const ready = () => {
        if (xhr.readyState !== 4 || finished) return;
        if (xhr.status === 0) {
            finish({ code: "network" });
        } else {
            finish(null, {
                status: xhr.status,
                body: xhr.responseText,
                retryAfter: xhr.getResponseHeader("Retry-After") || "",
            });
        }
    };
    try {
        xhr.open("GET", spec.url, true);
        xhr.onreadystatechange = ready;
        for (const name of Object.keys(spec.headers ?? {})) {
            xhr.setRequestHeader(name, (spec.headers ?? {})[name]);
        }
        stopDeadline = schedule(timeoutMs, () => {
            if (finished) return;
            finished = true;
            cleanup();
            xhr.abort();
            done({ code: "timeout" });
        });
        send(xhr);
    } catch (_) {
        finish({ code: "network" });
    }
    return () => {
        if (finished) return;
        finished = true;
        cleanup();
        xhr.abort();
    };
}
