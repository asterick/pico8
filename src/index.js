import Machine from "./machine";

// This is my polyfill section
var lastTime = 0;
var vendors = ['ms', 'moz', 'webkit', 'o'];
for(var x = 0; x < vendors.length && !window.requestAnimationFrame; ++x) {
    window.requestAnimationFrame = window[vendors[x]+'RequestAnimationFrame'];
    window.cancelAnimationFrame = window[vendors[x]+'CancelAnimationFrame']
                               || window[vendors[x]+'CancelRequestAnimationFrame'];
}

if (!window.requestAnimationFrame) {
    window.requestAnimationFrame = function(callback, element) {
        var currTime = new Date().getTime();
        var timeToCall = Math.max(0, 16 - (currTime - lastTime));
        var id = window.setTimeout(function() { callback(currTime + timeToCall); },
          timeToCall);
        lastTime = currTime + timeToCall;
        return id;
    };
}

if (!window.cancelAnimationFrame){
    window.cancelAnimationFrame = function(id) {
        clearTimeout(id);
    };
}

var mach = new Machine();

mach.drive.install("static/carts/picoracer.p8.png").then(function () {
    document.getElementById("root").appendChild(mach.getCanvas());
    mach.load("picoracer.p8.png");
    mach.run();
});
