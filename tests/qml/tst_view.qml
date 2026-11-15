import QtQuick
import QtTest
import "../../contents/ui"

TestCase {
    id: testCase
    function i18n(text, argument) { return argument === undefined ? text : text.replace("%1", argument); }
    name: "View"
    when: windowShown
    visible: true
    width: 500
    height: 300
    Component {
        id: viewComponent
        PriceView {
            assetText: "₿"
            priceText: "100,123.45"
            baseCurrencyText: "USDT"
            changeText: "+2.34%"
            changeValue: 2.34
            hasQuote: true
        }
    }
    function test_layouts_data() {
        return [
            { tag: "horizontal", vertical: false, width: 420, height: 48 },
            { tag: "vertical", vertical: true, width: 60, height: 160 },
            { tag: "desktop", vertical: false, width: 320, height: 180 }
        ];
    }
    function test_layouts(data) {
        const view = createTemporaryObject(viewComponent, testCase, data);
        verify(view !== null);
        wait(50);
        const label = findChild(view, "priceLabel");
        verify(label !== null);
        verify(label.paintedWidth <= view.width, "Price fits available width");
        verify(label.paintedHeight <= view.height, "Price fits available height");
        const originalText = label.text;
        view.loading = true;
        compare(label.text, originalText);
        verify(!findChild(view, "loadingIndicator").visible);
        view.warningText = "Price is out of date";
        verify(findChild(view, "warningIndicator").visible);
        wait(20);
        grabImage(view).save("build/ticker-" + data.tag + ".png");
    }
}
