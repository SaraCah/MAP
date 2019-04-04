var Greeter = /** @class */ (function () {
    function Greeter() {
    }
    Greeter.prototype.greet = function () {
        console.log("Hello from JS too!");
    };
    return Greeter;
}());
new Greeter().greet();
