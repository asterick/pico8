var PNGReader = require('pngjs');

const CHARACTER_SET = "\n 0123456789abcdefghijklmnopqrstuvwxyz!#%(){}[]<>+=/*:;.,~_";

/*
Cartridge format:
0x0000~0x42FF: Inital ram memory map
0x4300~0x7FFF: Lua code (sometimes compressed)
0x8000:        Rom version
*/

function decompress(rom) {
	var out = [];

	var dv = new DataView(rom.buffer);

	var header = dv.getInt32(rom.byteOffset+0, true);
	var length = dv.getUint16(rom.byteOffset+4, false);

	if (header != 0x003a633a) {
		for (var i = 0; i < rom.length && rom[i]; i++)
			out.push(String.fromCharCode(rom[i]));

		return out.join("");
	}

	var index = 8;

	while (out.length < length) {
		var code = rom[index++];

		if (code == 0) {
			out.push(String.fromCharCode(rom[index++]));
		} else if (code <= 0x3B) {
			out.push(CHARACTER_SET[code - 1]);
		} else {
			var ext_code = rom[index++];

			var rcount = (ext_code >> 4) + 2;
			var roffset = (ext_code & 0xF) + (code - 0x3C) * 16;

			out.push.apply(out, out.slice(out.length - roffset, out.length - roffset + rcount));
		}
	}

	return out.join("");
}

function compress(string) {
	const maxOffset = (0xFF-0x3D)*16 + 0xF;
	const maxSize = 0x11;
	const minSize = 2;
	var bytes = [];

	var i = 0;
	while (i < string.length) {
		var bestLength = 0, bestOffset;
		
		for (var o = Math.max(i - maxOffset, 0); o != i; o++) {
			for (var l = 0; l <= maxSize && o + l < i && string[o+l] == string[i+l]; l++) ;

			if (l > bestLength) {
				bestLength = l;
				bestOffset = i - o;
			}

		}
		
		if (bestLength >= minSize) {
			bytes.push((bestOffset >> 4) + 0x3C);
			bytes.push(((bestLength - minSize) << 4) | (bestOffset & 0xF));

			console.log(bestOffset, bestLength);

			i += bestLength;
		} else {
			var char = string[i++];
			var index = CHARACTER_SET.indexOf(char);

			bytes.push(index + 1);
			if (index < 0) {
				bytes.push(char.charCodeAt(0));
			}
		}
	}
	
	var encoded = [0x3a, 0x63, 0x3a, 0x00, string.length >> 8, string.length & 0xFF, 0x00, 0x00].concat(bytes);
	return new Uint8Array(encoded);
}

export function decodePNG(buffer) {
	return new Promise(function (acc, rej) {
		var reader = new PNGReader.PNG();

		reader.parse(buffer, function(err, png){
		    if (err) {
		    	rej(err);
		    	return ;
		    }
		    
		    var sten = new Uint32Array(png.data.buffer);
			var data = new Uint8Array(sten.length);
			
			// Swizzle data around
			for (var i = 0; i < data.length; i++) {
				var clr = sten[i] & 0x03030303;

				data[i] = 
					(clr >>  0) << 4 |
					(clr >>  8) << 2 |
					(clr >> 16) << 0 |
					(clr >> 24) << 6;
			}

			var program = decompress(data.subarray(0x4300,0x8000));
			var rom = new Uint32Array(program.length + 0x4300);

			for (var i = 0; i < 0x4300; i++) {
				rom[i] = data[i];
			}

			for (var i = 0; i < program.length; i++) {
				rom[0x4300+i] = program.charCodeAt(i);
			}

		    acc({
		    	version: data[0x8000],
		    	rom: rom
		    });
		});
	});
}

export function encodePNG(data) {
	var canvas = document.createElement("canvas");
	canvas.width = 160;
	canvas.height = 205;

	var context = canvas.getContext("2d");
	var idat = context.createImageData(160,205);

	var px = new Uint32Array(idat.data.buffer);
	for (var i = 0; i < data.length; i++) {
		var byte = data[i];

		px[i] =
			(byte <<  0) >> 4 |
			(byte <<  8) >> 2 |
			(byte << 16) >> 0 |
			(byte << 24) >> 6;

		px[i] &= 0x03030303;
		px[i] = (px[i] * 0x55) | 0xFC000000;
	}

	context.putImageData(idat, 0, 0);

	return canvas.toDataURL();
}

export function loadURL (url) {
	return new Promise(function (acc, rej) {
		var xhr = new XMLHttpRequest();

		xhr.open("GET", url, true);
		xhr.responseType = "arraybuffer";
		xhr.send(null);

		xhr.onload = function () {
			const PNG_HEADER = [137, 80, 78, 71, 13, 10, 26, 10];
			var bytes = new Uint8Array(xhr.response);

			for (var i = 0; i < PNG_HEADER; i++) {
				if (PNG_HEADER[i] != byte[i]) {
					// THIS IS A TEXT STYLE CARTRIDGE
					return ;
				}
			}

			decodePNG(xhr.response).then(acc, rej);
		};
	});
}
