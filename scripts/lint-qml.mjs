import { readFileSync } from "node:fs";
import { qtTool } from "./qt-tool.mjs";
const files = [...new Bun.Glob("contents/**/*.qml").scanSync()].sort();
const run = Bun.spawnSync([qtTool("qmllint"), "--json", "-", ...files]);
if (!run.stdout.length) throw new Error(run.stderr.toString() || "qmllint returned no diagnostics");
const report = JSON.parse(run.stdout.toString());
let errors = 0;
for (const file of report.files) {
    const source = readFileSync(file.filename, "utf8");
    for (const warning of file.warnings) {
        // Plasma injects ki18n functions at runtime; qmllint cannot see that context.
        const name = source.slice(warning.charOffset, warning.charOffset + warning.length);
        if (warning.id === "unqualified" && ["i18n", "i18nc", "i18np"].includes(name)) continue;
        if (warning.type !== "warning" && warning.type !== "error" && warning.type !== "critical") continue;
        console.error(`${file.filename}:${warning.line}:${warning.column}: ${warning.message} [${warning.id}]`);
        errors++;
    }
}
if (errors || run.exitCode !== 0) process.exitCode = 1;
else console.log(`Qt 6 lint passed for ${files.length} QML files (Plasma translation context excluded).`);
