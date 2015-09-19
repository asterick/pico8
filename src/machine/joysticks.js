import KeyCodes from "./keycodes";

const TOTAL_JOYSTICKS = 8;

var gamepads = [];
var keyboard = [];

// -- GLOBAL KEYBOARD CODE
const JOYSTICK_CONFIG = [
	[ KeyCodes.LEFT, KeyCodes.RIGHT, KeyCodes.UP, KeyCodes.DOWN, KeyCodes.N, KeyCodes.M ],
	[ KeyCodes.S, KeyCodes.F, KeyCodes.E, KeyCodes.D, KeyCodes.SHIFT, KeyCodes.TAB ]
];

window.addEventListener("keydown", function(e) {
	keyboard[e.keyCode] = true;
	e.preventDefault();
});

window.addEventListener("keyup", function(e) {
	keyboard[e.keyCode] = false;
});

// --- GLOBAL GAMEPAD CODE
var pads = navigator.getGamepads ? navigator.getGamepads() : (navigator.webkitGetGamepads ? navigator.webkitGetGamepads : []);

for (var i = 0; i < pads.length; i++) {
	if (pads[i])
		gamepads[i] = pads[i];
}

window.addEventListener("gamepadconnected", (e) => {
	var gamepad = event.gamepad;
	gamepads[gamepad.index] = gamepad;
	console.log(`Gamepad ${gamepad.index} connected`);
});

window.addEventListener("gamepaddisconnected", (e) => {
	var gamepad = event.gamepad;
	delete gamepads[gamepad.index];
	console.log(`Gamepad ${gamepad.index} disconnected`);
});

export default class Joysticks {
	constructor() {
		// Fill out our variable
		this.update();
		this.update();
	}

	update() {
		this._previous = this._state;
		this._state = [];

		for (var i = 0; i < 8; i++) {
			var keyCfg = JOYSTICK_CONFIG[i] || [];
			var output = 0;

			keyCfg.forEach((k, i) => {
				if (keyboard[k]) output |= 1 << i;
			})

			// TODO: GAMEPADS!

			this._state.push(output);
		}
	}

	buttons(player) {
		if (player >= 8) {
			return false;
		}

		return this._state[player];
	}

	buttons_previous(player, button) {
		if (player >= 8) {
			return false;
		}

		return this._state[player] & ~this._previous[player];
	}
}
