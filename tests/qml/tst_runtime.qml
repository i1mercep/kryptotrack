import QtQuick
import QtTest
import "../../contents/ui/models"
import "../../contents/code/formatting.mjs" as Formatting
import "../../contents/code/http.mjs" as Http
import "../../build/fixture-url.mjs" as Fixture

TestCase {
    id: testCase
    name: "Runtime"
    when: windowShown
    property var pending: []
    property int completionCount: 0
    property var result: null
    width: 800
    height: 600

    RequestScheduler { id: scheduler }
    Component {
        id: controllerComponent
        PriceController {
            requestFunction: function(spec, timeout, done) {
                const request = { spec: spec, done: done, cancelled: false };
                testCase.pending.push(request);
                return function() { request.cancelled = true; };
            }
        }
    }
    function init() {
        pending = [];
        completionCount = 0;
        result = null;
    }
    function test_modules_and_locale() {
        compare(Formatting.formatPrice(1.25, { standardPriceDecimals: 0 }), "1");
        compare(Formatting.localize("1234.5", Qt.locale("de_DE").decimalPoint,
            function(n) { return n.toLocaleString(Qt.locale("de_DE"), "f", 0); }), "1.234,5");
        compare(Formatting.formatPrice(0, {}), "0");
    }
    function test_controller_coalesces_and_cancels() {
        const controller = createTemporaryObject(controllerComponent, testCase);
        verify(controller !== null);
        tryCompare(controller, "loading", true);
        compare(pending.length, 1);
        controller.settings = { coin: "ethereum", coinSymbol: "eth" };
        controller.settings = { coin: "solana", coinSymbol: "sol" };
        wait(20);
        compare(pending.length, 2);
        verify(pending[0].cancelled);
        pending[0].done(null, { status: 200, body: '{"price":"999"}', retryAfter: "" });
        compare(controller.quote, null);
        pending[1].done(null, { status: 200, body: '{"price":"12"}', retryAfter: "" });
        compare(controller.quote.price, 12);
        controller.refresh();
        compare(controller.quote.price, 12);
        verify(controller.loading);
        controller.destroy();
        wait(20);
        verify(pending[2].cancelled);
    }
    function test_instances_are_independent() {
        const a = createTemporaryObject(controllerComponent, testCase);
        const b = createTemporaryObject(controllerComponent, testCase);
        wait(20);
        compare(pending.length, 2);
        pending[0].done(null, { status: 200, body: '{"price":"1"}', retryAfter: "" });
        pending[1].done(null, { status: 200, body: '{"price":"2"}', retryAfter: "" });
        compare(a.quote.price, 1);
        compare(b.quote.price, 2);
    }
    function send(path, deadline) {
        return Http.request({ url: Fixture.url + path }, deadline, function(error, response) {
            testCase.completionCount++;
            testCase.result = { error: error, response: response };
        }, scheduler.schedule, function() { return new XMLHttpRequest(); }, scheduler.send);
    }
    function test_native_xhr_direct() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Fixture.url + "/price");
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) testCase.completionCount++;
        };
        xhr.send();
        tryCompare(testCase, "completionCount", 1);
    }
    function test_native_xhr_success() {
        send("/price", 1000);
        tryCompare(testCase, "completionCount", 1);
        verify(result.error === null, JSON.stringify(result));
        compare(JSON.parse(result.response.body).price, "42");
        wait(30);
        compare(completionCount, 1);
    }
    function test_native_xhr_deadline() {
        send("/slow", 30);
        tryCompare(testCase, "completionCount", 1);
        compare(result.error.code, "timeout");
        wait(300);
        compare(completionCount, 1);
    }
    function test_native_xhr_cancel() {
        const cancel = send("/slow", 1000);
        cancel();
        wait(300);
        compare(completionCount, 0);
    }
}
