pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtTest
import "../../contents/ui/config" as Config

TestCase {
    id: testCase
    name: "Settings"
    when: windowShown
    visible: true
    width: 800
    height: 800
    property var pending: []
    // Plasma supplies these translation functions. The harness uses source text.
    function i18n(text, argument) { return argument === undefined ? text : text.replace("%1", argument); }

    Component {
        id: generalComponent
        Config.ConfigGeneral {
            width: 700
            height: 700
            requestFunction: function(spec, timeout, done) {
                const pending = { done: done, cancelled: false };
                testCase.pending.push(pending);
                return function() { pending.cancelled = true; };
            }
        }
    }
    Component { id: appearanceComponent; Config.ConfigAppearance { width: 700; height: 700 } }
    Component { id: apiComponent; Config.ConfigApi { width: 700; height: 700 } }
    Component { id: supportComponent; Config.ConfigSupport { width: 700; height: 700 } }
    function init() { pending = []; }
    function test_search_preserves_selection() {
        const page = createTemporaryObject(generalComponent, testCase, { cfg_coin: "my-saved-coin", cfg_coinSymbol: "saved" });
        verify(page !== null);
        wait(30);
        compare(pending.length, 1);
        pending[0].done(null, { status: 200, body: '{"symbols":[{"status":"TRADING","baseAsset":"BTC"}]}', retryAfter: "" });
        compare(page.cfg_coin, "my-saved-coin");
        const field = findChild(page, "coinSearch");
        verify(field !== null);
        field.text = "BTC";
        wait(200);
        compare(page.cfg_coin, "my-saved-coin");
        field.forceActiveFocus();
        page.forceActiveFocus();
        compare(page.cfg_coin, "my-saved-coin");
        verify(page.visibleCoinsList.length > 0);
        field.forceActiveFocus();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        wait(30);
        compare(page.cfg_coinSymbol, "btc");
        field.popup.close();
        wait(50);
        grabImage(page).save("build/settings-general.png");
    }
    function test_settings_components_load() {
        const appearance = createTemporaryObject(appearanceComponent, testCase, {
            cfg_fontSize: 9, cfg_standardPriceThreshold: 1, cfg_largePriceThreshold: 1000,
            cfg_standardPriceDecimals: 0, cfg_minSmallPriceDecimals: 0, cfg_maxSmallPriceDecimals: 8
        });
        verify(appearance !== null);
        compare(appearance.cfg_standardPriceDecimals, 0);
        compare(appearance.cfg_minSmallPriceDecimals, 0);
        appearance.visible = false;
        const api = createTemporaryObject(apiComponent, testCase, { cfg_apiProvider: "coingecko" });
        verify(api !== null);
        compare(api.cfg_apiProvider, "coingecko");
        api.cfg_apiProvider = "binance";
        compare(api.cfg_apiProvider, "binance");
        api.visible = false;
        appearance.visible = true;
        wait(50);
        grabImage(appearance).save("build/settings-appearance.png");
        appearance.visible = false;
        const support = createTemporaryObject(supportComponent, testCase);
        verify(support !== null);
        wait(30);
        const copy = findChild(support, "copyAddress-Bitcoin");
        verify(copy !== null);
        mouseClick(copy);
        compare(support.copiedName, "Bitcoin");
        support.selectedAddress = support.addresses[0].address;
        support.selectedName = "Bitcoin";
        const dialog = findChild(support, "donationQr");
        verify(dialog !== null);
        dialog.open();
        tryCompare(dialog, "visible", true);
        verify(dialog.contentItem.minimumWidth > 0);
        dialog.close();
        wait(30);
    }
}
