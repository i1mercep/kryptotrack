import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        icon: "configure"
        name: i18n("General")
        source: "config/ConfigGeneral.qml"
    }

    ConfigCategory {
        icon: "cloudstatus"
        name: i18n("API")
        source: "config/ConfigApi.qml"
    }

    ConfigCategory {
        icon: "oilpaint"
        name: i18n("Appearance")
        source: "config/ConfigAppearance.qml"
    }

    ConfigCategory {
        icon: "donate"
        name: i18n("Support")
        source: "config/ConfigSupport.qml"
    }
}
