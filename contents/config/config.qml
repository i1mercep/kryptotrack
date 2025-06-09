import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "configure"
        source: "config/ConfigGeneral.qml"
    }
    ConfigCategory {
        name: i18n("API")
        icon: "cloudstatus"
        source: "config/ConfigApi.qml"
    }
    ConfigCategory {
        name: i18n("Appearance")
        icon: "oilpaint"
        source: "config/ConfigAppearance.qml"
    }
    ConfigCategory {
        name: i18n("Support")
        icon: "donate"
        source: "config/ConfigSupport.qml"
    }
}
