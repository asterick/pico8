var PNGReader = require('pngjs');

var palette = [
	0xFF000000,
	0xFF7B3320,
	0xFF53257E,
	0xFF318300,
	0xFF3652AB,
	0xFF454545,
	0xFFC7C3C2,
	0xFFE8F1FF,
	0xFF4D00FF,
	0xFF00A3FF,
	0xFF27E7FF,
	0xFF32E200,
	0xFFFFAD29,
	0xFF9C7683,
	0xFFA877FF,
	0xFFAACCFF
];

export default class Loader {
	constructor(url) {
		var that = this;

		this.fromRaw(url, function(sten) {
			var data = new Uint8Array(sten.length);
			
			var p = 0;
			for (var i = 0; i < data.length; i++) {
				var clr = sten[i] & 0x03030303;
				var a = (clr <<  4);
				var b = (clr >>  6);
				var c = (clr >> 16);
				var d = (clr >> 18);

				data[i] = a | b | c | d;
			}

			// THIS IS ALL TEMPORARY CODE HERE
			var hex = Array.prototype.map.call(data, function (v) {
				return String.fromCharCode(v);
			}).join("");

			console.log(hex)

			// THIS IS ALL TEMPORARY CODE HERE
			var cvs = document.createElement("canvas");
			cvs.width = 128;
			cvs.height = 128;
			cvs.style.width = "512";
			document.body.appendChild(cvs);

			var ctx = cvs.getContext("2d");
			var sten = ctx.createImageData(128, 128);
			var px = new Uint32Array(sten.data.buffer);

			p = 0;
			for (var i = 0; i < data.length; i++) {
				px[p++] = palette[data[i] & 0xF];
				px[p++] = palette[data[i] >> 4];
			}

			ctx.putImageData(sten, 0, 0);
		});
	}

	fromRaw (url, cb) {
		var xhr = new XMLHttpRequest();

		xhr.open("GET", url, true);
		xhr.responseType = "arraybuffer";
		xhr.send(null);

		xhr.onload = function () {
			var arrayBuffer = xhr.response;
			var reader = new PNGReader.PNG();

			reader.parse(arrayBuffer, function(err, png){
			    if (err) throw err;
			    cb(new Uint32Array(png.data.buffer));
			});
		};
	}
}
