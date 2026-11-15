import { qtTool } from "./qt-tool.mjs";
const files = [...new Bun.Glob("contents/**/*.qml").scanSync()].sort();
const run = Bun.spawnSync([qtTool("qmlformat"), "--settings", ".qmlformat", "--inplace", ...files], {
    stdout: "inherit",
    stderr: "inherit",
});
process.exitCode = run.exitCode;
