import { existsSync } from "node:fs";
import { join } from "node:path";

export function qtTool(name) {
    const candidates = [
        process.env.QT6_BIN_DIR && join(process.env.QT6_BIN_DIR, name),
        `/usr/lib/qt6/bin/${name}`,
        `/usr/lib64/qt6/bin/${name}`,
        `${name}6`,
        name,
    ].filter(Boolean);
    for (const candidate of candidates) {
        const binary = candidate.includes("/") ? (existsSync(candidate) ? candidate : null) : Bun.which(candidate);
        if (!binary) continue;
        // qmltestrunner reports the Qt runtime in -help differently; use its sibling qmllint.
        const versionTool = name === "qmltestrunner" ? binary.replace(/qmltestrunner(6)?$/, "qmllint$1") : binary;
        const version = Bun.spawnSync([versionTool, "--version"]);
        if (/\b6\.(?:1[2-9]|[2-9]\d)\./.test(version.stdout.toString() + version.stderr.toString())) return binary;
    }
    throw new Error(`Qt 6.12+ ${name} is required. Set QT6_BIN_DIR to your Qt 6 bin directory.`);
}
