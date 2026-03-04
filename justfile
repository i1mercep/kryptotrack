name     := "kryptotrack"
plugin   := "com.github.i1mercep." + name
package  := name + ".plasmoid"
install_dir := "~/.local/share/plasma/plasmoids/" + plugin

# Build the plasmoid package (default)
[group('build')]
build:
    zip -r {{package}} contents metadata.json

# Run the widget in plasmoidviewer
[group('dev')]
run:
    plasmoidviewer -a .

# Build and install (or upgrade) the plasmoid
[group('build')]
install: build
    kpackagetool6 -t Plasma/Applet -i {{package}} || kpackagetool6 -t Plasma/Applet -u {{package}}

# Uninstall and clean
[group('build')]
uninstall: clean
    kpackagetool6 -t Plasma/Applet -r {{plugin}} || rm -rf {{install_dir}}

# Format all QML and JS files in-place
[group('dev')]
format:
    find contents -name "*.qml" | xargs qmlformat -i
    find contents -name "*.js" | xargs prettier --write

# Remove build artifacts
[group('build')]
clean:
    rm -f {{package}}
