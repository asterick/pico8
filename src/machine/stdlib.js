import Runtime from "../runtime";
import Table from "../runtime/table";

class LibraryError {
	constructor(msg) {
		this.message = msg;
	}
}

export default {
	// Debug functions
	"printh": function() {
		console.log(Array.prototype.map.call(arguments, (v) => Runtime.toString(v)).join(" "));
	},

	// System functions
	"load": function(path) {
		path = Runtime.toString(path);
		this.cartridge = this.drive.load(path);
	},

	"save": function(path) {
		path = Runtime.toString(path);
		this.drive.save(path, this.cartridge);
	},
	
	"cd": function(path) {
		path = Runtime.toString(path);
		this.drive.cd(path);
	},

	"rm": function(path) {
		path = Runtime.toString(path);
		this.drive.rm(path);
	},

	"del": function(path) {
		path = Runtime.toString(path);
		this.drive.rm(path);
	},

	"mkdir": function(path) {
		path = Runtime.toString(path);
		this.drive.mkdir(path);
	},

	"folder": function() {
		/* There is no easy way to do this */
	},
	
	"dir": function() {
		var print = this.runtime.globals.get("print");
		var color = this.runtime.globals.get("color");

		var dir = this.drive.dir();
		color(0xC);
		dir.folders.forEach((name) => print(name));
		color(0x7);
		dir.files.forEach((name) => print(name));
	},
	
	"run": function() {
		this.run();
	},
	
	"reboot": function() {
		throw new LibraryError("Machine has been restarted");
	},
	
	"stat": function(x) {
		throw new LibraryError("Unimplemented");
	},
	
	"info": function() {
		throw new LibraryError("Unimplemented");
	},
	
	"flip": function() {
		this.flip();
	},

	// Draw functions
	"clip": function (x, y, w, h) {
		var clip = this._memoryMap.drawState.clipCoords;

		if (x == undefined) {
			clip[0] = 0;
			clip[1] = 0;
			clip[2] = 128;
			clip[3] = 128;
		} else {
			clip[0] = Runtime.toNumber(x);
			clip[1] = Runtime.toNumber(y);
			clip[2] = Runtime.toNumber(w);
			clip[3] = Runtime.toNumber(h);
		}
	},
	
	"pget": function (x, y) {
		x = Runtime.toNumber(x) | 0;
		y = Runtime.toNumber(y) | 0;

		return this.display.get(this._memoryMap.screen, x, y);
	},

	"pset": function (x, y, col) {
		x = (Runtime.toNumber(x) | 0);
		y = (Runtime.toNumber(y) | 0);
		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0

		this.display.point(x, y, col);
	},

	"sget": function (x, y) {
		x = Runtime.toNumber(x) | 0;
		y = Runtime.toNumber(y) | 0;

		return this.sprites.get(this._memoryMap.sprites, x, y);
	},

	"sset": function (x, y, col) {
		x = Runtime.toNumber(x) | 0;
		y = Runtime.toNumber(y);
		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0

		this.sprites.set(this._memoryMap.sprites, x, y, col);
	},

	"fget": function (n, f) {
		n = Runtime.toNumber(n) | 0;

		var num = this._memoryMap.gfx_props[n] || 0;

		if (f === undefined) {
			return num;
		} else {
			return (num & (1 << (Runtime.toNumber(f) | 0))) ? true : false;
		}
	},

	"fset": function (n, f, v) {
		n = Runtime.toNumber(n) | 0;

		if (v === undefined) {
			this._memoryMap.gfx_props[n] = Runtime.toNumber(f);
		} else {
			var m = 1 << (Runtime.toNumber(f)|0);
			v = Runtime.toBool(v);


			if (Runtime.toBool(v)) {
				this._memoryMap.gfx_props[n] |= m;
			} else {
				this._memoryMap.gfx_props[n] &= ~m;
			}
		}
	},

	"print": function (str, x, y, col) {
		const TARGET_LINES = 6;

		str = Runtime.toString(str);
		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0

		var scroll = false;
		if (x == undefined || y == undefined) {
			x = this._memoryMap.drawState.cursorPos[0];
			y = this._memoryMap.drawState.cursorPos[1];

			var ny = (this._memoryMap.drawState.cursorPos[1] += 6);

			if (ny >= 128 - TARGET_LINES) {
				scroll = true;
			}
		} else {
			x = (Runtime.toNumber(x) | 0);
			y = (Runtime.toNumber(y) | 0);
		}

		this.display.print(str, x, y, col);

		if (scroll) {
			var shift = this._memoryMap.drawState.cursorPos[1] - (128 - TARGET_LINES);

			this.display.shift(shift);
			this._memoryMap.drawState.cursorPos[1] = 128 - TARGET_LINES;
		}
	},

	"cursor": function (x, y) {
		this._memoryMap.drawState.cursorPos[0] = Runtime.toNumber(x);
		this._memoryMap.drawState.cursorPos[1] = Runtime.toNumber(y);
	},

	"color": function (col) {
		this._memoryMap.drawState.drawColor[0] = Runtime.toNumber(col);
	},

	"cls": function () {
		for (var i = 0; i < 0x2000; i++) {
			this._memoryMap.screen[i] = 0;
		}

		this._resetClip();
		this._resetCursor();
	},

	"camera": function (x, y) {
		this._memoryMap.drawState.cameraPos[0] = Runtime.toNumber(x);
		this._memoryMap.drawState.cameraPos[1] = Runtime.toNumber(y);
	},

	"circ": function (x, y, r, col) {
		x = Runtime.toNumber(x) | 0;
		y = Runtime.toNumber(y) | 0;
		r = Runtime.toNumber(r) | 0;

		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0;

		this.display.circle(x, y, r, col);
	},

	"circfill": function (x, y, r, col) {
		x = Runtime.toNumber(x) | 0;
		y = Runtime.toNumber(y) | 0;
		r = Runtime.toNumber(r) | 0;

		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0

		this.display.circleFill(x, y, r, col);
	},

	"line": function (x0, y0, x1, y1, col) {
		x0 = (Runtime.toNumber(x0) | 0);
		y0 = (Runtime.toNumber(y0) | 0);
		x1 = (Runtime.toNumber(x1) | 0);
		y1 = (Runtime.toNumber(y1) | 0);

		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0;
	
		this.display.line(x0, y0, x1, y1, col);
	},

	"rect": function (x0, y0, x1, y1, col) {
		x0 = (Runtime.toNumber(x0) | 0);
		y0 = (Runtime.toNumber(y0) | 0);
		x1 = (Runtime.toNumber(x1) | 0);
		y1 = (Runtime.toNumber(y1) | 0);

		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0

		this.display.rectangle(x0, y0, x1, y1, col);
	},

	"rectfill": function (x0, y0, x1, y1, col) {
		x0 = (Runtime.toNumber(x0) | 0);
		y0 = (Runtime.toNumber(y0) | 0);
		x1 = (Runtime.toNumber(x1) | 0);
		y1 = (Runtime.toNumber(y1) | 0);

		col = (col === undefined) ? this._memoryMap.drawState.drawColor[0] : Runtime.toNumber(col) | 0

		this.display.rectangleFill(x0, y0, x1, y1, col);
	},

	"pal": function (c0, c1, p) {
		if (c0 === undefined) {
			this._resetScreenPalette();
			this._resetDrawPalette();
		} else {
			c0 = Runtime.toNumber(c0) & 0xF;
			c1 = Runtime.toNumber(c1) & 0xF;
			p = (p !== undefined) ? Runtime.toNumber(p) : 0;
			
			var pal = this._memoryMap.drawState[(p & 1) ? "screenPalette" : "drawPalette"];

			pal[c0] = (pal[c0] & 0xF0) | c1;
		}
	},

	"palt": function (c, t) {
		var pal = this._memoryMap.drawState.drawPalette;

		if (c === undefined) {
			for (var i = 0; i < 16; i++) {
				pal[i] = (pal[i] & 0x0F) | (i ? 0 : 1);
			}
		} else {
			c = Runtime.toNumber(c) & 0xF;
			t = Runtime.toBool(t);

			pal[c] = (pal[i] & 0x0F) | (t ? 0 : 0x10);
		}
	},

	"spr": function (n, x, y, w, h, flip_x, flip_y) {
		n = (Runtime.toNumber(x) | 0);
		x = (Runtime.toNumber(x) | 0);
		y = (Runtime.toNumber(y) | 0);
		w = (w === undefined) ? 1 : (Runtime.toNumber(w) | 0);
		h = (h === undefined) ? 1 : (Runtime.toNumber(h) | 0);
		flip_x = Runtime.toBool(flip_x);
		flip_x = Runtime.toBool(flip_y);

		// Unimplemented
		return ;
	},

	"sspr": function (sx, sy, sw, sh, dx, dy, dw, dh, flip_x, flip_y) {
		// Unimplemented
		return ;
	},

	// Collections functions
	"foreach": function(c, f) {
		if (!Table.isTable(c)) {
			throw new LibraryError("Argument was not a table");
		}

		var count = c.count();
		for (var i = 1; i <= count; i++) {
			f(c.get(i));
		}
	},

	"all": function(c) {
		if (!Table.isTable(c)) {
			throw new LibraryError("Argument was not a table");
		}

		var i = 1;
		return function () {
			if (i <= c.count()) return c.get(i++);
		}
	},

	"add": function(c, i) {
		if (!Table.isTable(c)) {
			throw new LibraryError("Argument was not a table");
		}

		c.set(c.count()+1, i);
	},

	"del": function(c, i) {
		if (!Table.isTable(c)) {
			throw new LibraryError("Argument was not a table");
		}

		for (var idx = 1; idx <= c.count(); idx++) {
			if (c.get(idx) === i) {
				while (idx <= c.count()) {
					c.set(idx, c.get(idx + 1));
					idx++;
				}
			}
		}
	},

	"count": function(c, v) {
		if (!Table.isTable(c)) {
			throw new LibraryError("Argument was not a table");
		}

		var values = c.values();

		if (v === undefined) {
			return values.length
		}

		return values.reduce((acc, t) => ((t === v) ? 1 : 0) + acc, 0);
	},

	// Button functions
	"btn": function (i, p) {
		if (i === undefined) {
			return this.joysticks.buttons(0) | (this.joysticks.buttons(1) << 6);
		} else {
			i = Runtime.toNumber(i);
			p = Runtime.toNumber(p) || 0;

			var buttons = this.joysticks.buttons(p);

			return (buttons & (1 << i)) ? true : false;
		}
	},

	"btnp": function (i, p) {
		if (i === undefined) {
			return this.joysticks.buttons_previous(0) | (this.joysticks.buttons_previous(1) << 6);
		} else {
			i = Runtime.toNumber(i);
			p = Runtime.toNumber(p) || 0;

			var buttons = this.joysticks.buttons_previous(p);

			return (buttons & (1 << i)) ? true : false;
		}
	},

	// Audio
	"sfx": function (n, channel, offset) {
		// Unimplemented
		return ;
	},

	"music": function (n, fade_len, channel_mask) {
		// Unimplemented
		return ;
	},

	// Map
	"mget": function (x, y) {
		var x = Runtime.toNumber(x) | 0;
		var y = Runtime.toNumber(y) | 0;
		
		if (x >= 128 || y >= 64) {
			return 0;
		}

		return this._memoryMap.map[(y ^ 32) * 128 + x];
	},

	"mset": function (x, y, v) {
		var x = Runtime.toNumber(x) | 0;
		var y = Runtime.toNumber(y) | 0;
		var v = Runtime.toNumber(v) | 0;

		this._memoryMap.map[(y ^ 32) * 128 + x] = v;
	},

	"map": function (cel_x, cel_y, sx, sy, cel_w, cel_h, layer) {
		// Unimplemented
		return ;
	},

	// Memory
	"peek": function (addr) {
		addr = Runtime.toNumber(addr) | 0;
		
		if (addr >= 0x8000) {
			throw new LibraryError("Cannot access memory beyond 32k boundary");
		}

		return this.memory[addr];
	},

	"poke": function (addr, val) {
		addr = Runtime.toNumber(addr) | 0;
		val = Runtime.toNumber(val) | 0;

		if (addr >= 0x8000) {
			throw new LibraryError("Cannot access memory beyond 32k boundary");
		}

		this.memory[addr] = val;
	},

	"memcpy": function (dest_addr, source_addr, len) {
		dest_addr = Runtime.toNumber(dest_addr) | 0;
		source_addr = Runtime.toNumber(source_addr) | 0;
		len = Runtime.toNumber(len) | 0;

		if (dest_addr + len >= 0x8000 || (source_addr + len) >= 0x8000) {
			throw new LibraryError("Cannot access memory beyond 32k boundary");
		}

		while(len-- > 0) {
			this.memory[dest_addr++] = this.memory[source_addr++];
		}
	},

	"reload": function (dest_addr, source_addr, len) {
		dest_addr = Runtime.toNumber(dest_addr) | 0;
		source_addr = Runtime.toNumber(source_addr) | 0;
		len = Runtime.toNumber(len) | 0;

		if (dest_addr + len >= 0x8000 || (source_addr + len) >= 0x8000) {
			throw new LibraryError("Cannot access memory beyond 32k boundary");
		}

		while(len-- > 0) {
			this.memory[dest_addr++] = this.cartridge[source_addr++];
		}
	},

	"cstore": function (dest_addr, source_addr, len) {
		dest_addr = Runtime.toNumber(dest_addr) | 0;
		source_addr = Runtime.toNumber(source_addr) | 0;
		len = Runtime.toNumber(len) | 0;

		if (dest_addr + len >= 0x8000 || (source_addr + len) >= 0x8000) {
			throw new LibraryError("Cannot access memory beyond 32k boundary");
		}

		while(len-- > 0) {
			this.cartridge[dest_addr++] = this.memory[source_addr++];
		}
	},

	"memset": function (dest_addr, val, len) {
		dest_addr = Runtime.toNumber(dest_addr) | 0;
		val = Runtime.toNumber(val) | 0;
		len = Runtime.toNumber(len) | 0;

		if (dest_addr + len >= 0x8000) {
			throw new LibraryError("Cannot access memory beyond 32k boundary");
		}

		while (len-- > 0) {
			this.memory[dest_addr++] = val;
		}
	},

	// Math
	"max": function (x, y) {
		x = Runtime.toNumber(x);
		y = Runtime.toNumber(y);

		return Math.max(x, y);
	},

	"min": function (x, y) {
		x = Runtime.toNumber(x);
		y = Runtime.toNumber(y);

		return Math.min(x, y);
	},

	"mid": function (x, y, z) {
		x = Runtime.toNumber(x);
		y = Runtime.toNumber(y);
		z = Runtime.toNumber(z);
		var t;

		// sort values
		if (y < x) { t = y; y = x; x = t; }
		if (z < x) { t = z; z = x; x = t; }
		if (z < y) { t = y; y = z; z = t; }

		return y;
	},
	
	"flr": function (x) {
		x = Runtime.toNumber(x);
		return Math.floor(x);
	},

	"cos": function (x) {
		x = Runtime.toNumber(x * 2 * Math.PI);
		return Math.cos(x);		
	},

	"sin": function (x) {
		x = Runtime.toNumber(x * 2 * Math.PI);
		return Math.sin(x);
	},

	"atan2": function (dx, dy) {
		return Math.atan2(Runtime.toNumber(dx), -Runtime.toNumber(dy)) / (Math.PI * 2);
	},

	"sqrt": function (x) {
		x = Runtime.toNumber(x);
		return Math.sqrt(x);
	},

	"abs": function (x) {
		x = Runtime.toNumber(x);
		return Math.abs(x);
	},

	"rnd": function (x) {
		x = Runtime.toNumber(x);
		return this.prng(x);
	},

	"srand": function (x) {
		x = Runtime.toNumber(x);
		this.prng(x);
	},

	// Binary Math
	"band": function (x, y) {
		x = Runtime.toNumber(x) * 0x10000;
		y = Runtime.toNumber(y) * 0x10000;

		return (x & y) / 0x10000;
	},

	"bor": function  (x, y) {
		x = Runtime.toNumber(x) * 0x10000;
		y = Runtime.toNumber(y) * 0x10000;

		return (x | y) / 0x10000;
	},

	"bxor": function (x, y) {
		x = Runtime.toNumber(x) * 0x10000;
		y = Runtime.toNumber(y) * 0x10000;

		return (x ^ y) / 0x10000;
	},

	"bnot": function (x) {
		x = Runtime.toNumber(x) * 0x10000;
		
		return ~x / 0x10000;
	},

	"shl": function  (x, y) {
		x = Runtime.toNumber(x) * 0x10000;
		y = Runtime.toNumber(y) * 0x10000;

		return (x << y) / 0x10000;
	},

	"shr": function  (x, y) {
		x = Runtime.toNumber(x) * 0x10000;
		y = Runtime.toNumber(y) * 0x10000;

		return (x >> y) / 0x10000;
	},

	// Strings
	"sub": function (s, start, end) {
		s = Runtime.toString(s);
		start = Runtime.toNumber(start);

		if (end !== undefined) {
			end = Runtime.toNumber(end);
			return s.substr(start - 1, end - start + 1);
		} else {
			return s.substr(start - 1);
		}		
	}
};
