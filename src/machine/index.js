import StdLib from "./stdlib";
import Surface from "./surface";
import Palette from "./palette";
import Storage from "./storage";
import PRNG from "./prng";
import Mixer from "./mixer";
import Joysticks from "./joysticks";
import Runtime from "../runtime";

const FRAME_TICK = 1000 / 30; // 30 FPS

export default class Machine {
	constructor(scale = 1) {
		// Empty cartridge by default
		this.cartridge = new Uint8Array(0x8000);
		this.drive = new Storage();
		this.prng = new PRNG();
		this.joysticks = new Joysticks();

		this.createMemoryMap();
		this.createCanvas(scale);
		this.reset();

		this.flip();
	}

	evaluate(src) {
		this.runtime.evaluate(src);
	}

	install(url) {
		return this.drive.install(url);
	}

	load(file) {
		this.cartridge = this.drive.load(file);
	}

	save(file) {
		this.drive.save(file, this.cartridge);
	}


	tick() {
		var update = this.runtime.globals.get("_update");
		var draw = this.runtime.globals.get("_draw");
		
		update && update();
		draw && draw();

		this.flip();
	}

	run() {
		var chars = [];
		for (var i = 0x4300; i < this.cartridge.length; i++) {
			chars.push(String.fromCharCode(this.cartridge[i]));
		}
		this.evaluate(chars.join(""));

		var init = this.runtime.globals.get("_init");
		init && init();

		this._clock = +new Date();
		this._step();
	}

	_step() {
		this._raf = requestAnimationFrame(() => {
			var now = +new Date();

			if ((now - this._clock) >= FRAME_TICK) {
				this._clock = now;
				this.tick();
			}

			this._step();
		});
	}

	stop() {
		cancelAnimationFrame(this._raf);
	}

	createMemoryMap() {
		this.memory = new Uint8Array(0x8000); // 32k of system ram

		this._memoryMap = {
			sprites   : this.memory.subarray(0x0000, 0x2000),
			map 	  : this.memory.subarray(0x1000, 0x3000),
			gfx_props : this.memory.subarray(0x3000, 0x3100),
			song      : this.memory.subarray(0x3100, 0x3200),
			sfx       : this.memory.subarray(0x3200, 0x4300),
			drawState : {
				drawPalette: this.memory.subarray(0x5f00, 0x5f10),
				screenPalette: this.memory.subarray(0x5f10, 0x5f20),
				clipCoords: this.memory.subarray(0x5f20, 0x5f24),
				drawColor: this.memory.subarray(0x5f25, 0x5f26),
				cursorPos: this.memory.subarray(0x5f26, 0x5f28),
				cameraPos: new Int16Array(this.memory.buffer, 0x5f28, 2),
				screenMode: this.memory.subarray(0x5f2c, 0x5f2d),
			},
			save      : this.memory.subarray(0x5fc0, 0x6000),
			screen    : this.memory.subarray(0x6000),
		};

		this.display = new Surface(
			this._memoryMap.screen,
			this._memoryMap.drawState.drawPalette,
			this._memoryMap.drawState.clipCoords,
			this._memoryMap.drawState.cameraPos);
		
		this.sprites = new Surface(
			this._memoryMap.screen,
			this._memoryMap.drawState.drawPalette,
			this._memoryMap.drawState.clipCoords,
			new Int16Array([0, 0]));
	}

	reset() {
		this._resetDrawPalette();
		this._resetScreenPalette();
		this._resetClip();
		this._resetCursor();

		// Default draw color (white)
		this._memoryMap.drawState.drawColor[0] = 0x7;

		// Camera to top left of screen
		this._memoryMap.drawState.cameraPos[0] = 0;
		this._memoryMap.drawState.cameraPos[1] = 0;
		
		// Screen mode
		this._memoryMap.drawState.screenMode[0] = 0;

		this.runtime = new Runtime();
		this.runtime.define(this.getStdLib());
	}

	_resetCursor() {
		this._memoryMap.drawState.cursorPos[0] = 0;
		this._memoryMap.drawState.cursorPos[1] = 0;
	}

	_resetDrawPalette() {
		const def = [
			0x10, 0x01, 0x02, 0x03, 
			0x04, 0x05, 0x06, 0x07, 
			0x08, 0x09, 0x0a, 0x0b, 
			0x0c, 0x0d, 0x0e, 0x0f
		];

		for (var i = 0; i < 16; i++){
			this._memoryMap.drawState.drawPalette[i] = def[i];
		}
	}
	
	_resetScreenPalette() {
		for (var i = 0; i < 16; i++){
			this._memoryMap.drawState.screenPalette[i] = i;
		}
	}

	_resetClip () {
		// Set clipping coordinates for screen
		this._memoryMap.drawState.clipCoords[0] = 0;
		this._memoryMap.drawState.clipCoords[1] = 0;
		this._memoryMap.drawState.clipCoords[2] = 128;
		this._memoryMap.drawState.clipCoords[3] = 128;
	}

	createCanvas(scale) {
		this._canvas = document.createElement("canvas");
		this._canvas.width = 128;
		this._canvas.height = 128;

		this._context = this._canvas.getContext("2d");
		this._imgData = this._context.getImageData(0, 0, this._canvas.width, this._canvas.height);
		this._pixels = new Uint32Array(this._imgData.data.buffer);

		this.flip();
		return this._canvas;
	}

	getCanvas() {
		return this._canvas;
	}

	flip() {
		var sp = this._memoryMap.drawState.screenPalette;
		var src = this._memoryMap.screen;
		var i_idx = 0;
		var o_idx = 0;

		var x_stretch = this._memoryMap.drawState.screenMode[0] & 1;
		var y_stretch = this._memoryMap.drawState.screenMode[0] & 2 ? 1 : 0;
		
		for (var y = 0; y < 128; y++) {
			i_idx = (y >> y_stretch) * 64;

			for (var x = 0; x < 128; x += 2 << x_stretch) {
				var colors = src[i_idx++];
				var h = Palette[sp[colors >> 4] & 0xF];
				var l = Palette[sp[colors & 0xF] & 0xF];

				this._pixels[o_idx++] = l;
				if (x_stretch) this._pixels[o_idx++] = l;
				this._pixels[o_idx++] = h;
				if (x_stretch) this._pixels[o_idx++] = h;
			}
		}

		this._context.putImageData(this._imgData, 0, 0);

		this.joysticks.update();
	}

	getStdLib() {
		var out = {}
		Object.keys(StdLib).forEach((k) => out[k] = StdLib[k].bind(this));
		return out;
	}
}
