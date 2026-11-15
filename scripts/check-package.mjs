import { readFileSync, existsSync } from "node:fs";
import { strict as assert } from "node:assert";
import { dirname, resolve } from "node:path";

const metadata = JSON.parse(readFileSync("metadata.json", "utf8"));
assert.equal(metadata.KPlugin.Id, "com.github.i1mercep.kryptotrack");
assert.equal(metadata["X-Plasma-API-Minimum-Version"], "6.8");
const schema = readFileSync("contents/config/main.xml", "utf8");
const keys = new Set([...schema.matchAll(/<entry name="([^"]+)"/g)].map((match) => match[1]));
const files = [...new Bun.Glob("contents/**/*.{qml,mjs}").scanSync()];
for (const file of files) {
    const source = readFileSync(file, "utf8");
    if (file.endsWith(".qml")) {
        for (const match of source.matchAll(/\bproperty\s+(?:alias|string|int|bool)\s+cfg_(\w+)/g)) {
            assert(keys.has(match[1]), `${file}: cfg_${match[1]} has no schema entry`);
        }
    }
    for (const match of source.matchAll(/(?:import\s+(?:[^\n]*?from\s+)?)["'](\.[^"']+)["']/g)) {
        assert(existsSync(resolve(dirname(file), match[1])), `${file}: missing import ${match[1]}`);
    }
}
const archive = process.argv[2];
if (archive) {
    const result = Bun.spawnSync(["unzip", "-Z1", archive]);
    assert.equal(result.exitCode, 0, result.stderr.toString());
    const entries = result.stdout.toString().trim().split("\n");
    assert(entries.includes("metadata.json"));
    assert(entries.includes("contents/ui/main.qml"));
    assert(entries.includes("contents/code/providerRouter.mjs"));
    assert(
        entries.every((file) => file === "metadata.json" || /^contents\/.*\.(qml|mjs|svg|xml)$/.test(file)),
        "Archive contains non-runtime assets",
    );
    for (const file of files) assert(entries.includes(file), `Archive omits ${file}`);
}
console.log(`Package sources validated${archive ? `; archive validated: ${archive}` : ""}.`);
