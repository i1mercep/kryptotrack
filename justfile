name := "kryptotrack"
plugin := "com.github.i1mercep." + name
package := name + ".plasmoid"

# Build a directly installable package containing runtime files only.
[group('build')]
build: clean
    rg --files contents -g '*.qml' -g '*.mjs' -g '*.svg' -g '*.xml' | LC_ALL=C sort | zip -X {{package}} metadata.json -@

[group('dev')]
run:
    plasmoidviewer -a .

# Installing does not interrupt the current desktop session.
[group('build')]
install: build
    kpackagetool6 -t Plasma/Applet -i {{package}} || kpackagetool6 -t Plasma/Applet -u {{package}}

[group('dev')]
restart-plasma:
    plasmashell --replace > /dev/null 2>&1 &

[group('build')]
uninstall: clean
    kpackagetool6 -t Plasma/Applet -r {{plugin}}

[group('dev')]
lint:
    bun run lint
    bun scripts/lint-qml.mjs

[group('dev')]
typecheck:
    bun run typecheck

[group('dev')]
test:
    bun run test
    bun scripts/test-qml.mjs

[group('dev')]
check: lint typecheck test build
    bun scripts/check-package.mjs {{package}}

[group('dev')]
format:
    bun scripts/format-qml.mjs
    bunx --no-install prettier --write 'contents/code/*.mjs' 'tests/*.mjs' 'scripts/*.mjs' package.json tsconfig.json

[group('build')]
clean:
    rm -f {{package}}
