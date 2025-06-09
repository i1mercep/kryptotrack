NAME = kryptotrack
PLUGIN_ID = com.github.i1mercep.$(NAME)
INSTALL_DIR = ~/.local/share/plasma/plasmoids/$(PLUGIN_ID)
PACKAGE = $(NAME).plasmoid

# Default target: Build the plasmoid package
all:
	zip -r $(PACKAGE) contents metadata.json

run:
	plasmoidviewer -a .

install: all
	kpackagetool6 -t Plasma/Applet -i $(PACKAGE) || kpackagetool6 -t Plasma/Applet -u $(PACKAGE)

uninstall: clean
	kpackagetool6 -t Plasma/Applet -r $(PLUGIN_ID) || rm -rf $(INSTALL_DIR)

clean:
	rm -f $(PACKAGE)

.PHONY: all run install uninstall clean
