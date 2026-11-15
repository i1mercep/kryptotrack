import { mkdirSync } from "node:fs";
import { qtTool } from "./qt-tool.mjs";

const binary = qtTool("qmltestrunner");
const server = Bun.serve({
    hostname: "127.0.0.1",
    port: 0,
    async fetch(request) {
        if (new URL(request.url).pathname === "/slow") await Bun.sleep(250);
        return Response.json({ price: "42" });
    },
});
mkdirSync("build", { recursive: true });
await Bun.write("build/fixture-url.mjs", `export const url = ${JSON.stringify(server.url.origin)};\n`);
try {
    const child = Bun.spawn([binary, "-input", "tests/qml", "-o", "-,txt"], {
        env: {
            ...process.env,
            QT_QPA_PLATFORM: "offscreen",
            QT_QUICK_BACKEND: "software",
            http_proxy: "",
            https_proxy: "",
            HTTP_PROXY: "",
            HTTPS_PROXY: "",
            ALL_PROXY: "",
            all_proxy: "",
            NO_PROXY: "127.0.0.1,localhost",
        },
        stdout: "inherit",
        stderr: "inherit",
    });
    const watchdog = setTimeout(() => child.kill(), 60000);
    try {
        process.exitCode = await child.exited;
    } finally {
        clearTimeout(watchdog);
    }
} finally {
    server.stop(true);
}
