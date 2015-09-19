import { loadURL } from '../util/loader';
import guid from "../util/guid";

const PREFIX = "pico8:";
const TOP_PATH = "root";

function encode(file) {
	return Array.prototype.map.call(file, (v) => ((v < 16) ? "0" : "") + v.toString(16)).join("");
}

function decode(file) {
	return new Uint8Array(file.match(/../g).map((v) => parseInt(v, 16)));
}

export default class Storage {
	constructor() {
		// We need to create the root node
		if (!this._exists(TOP_PATH)) {
			this._save(TOP_PATH, {
				children: {},
				parent: TOP_PATH
			});
		}

		this._path = TOP_PATH;
	}

	// Private helper functions
	_load(g) {
		return JSON.parse(localStorage[PREFIX+g]);
	}

	_save(g, n) {
		localStorage[PREFIX+g] = JSON.stringify(n);
	}

	_remove(g) {
		delete localStorage[PREFIX+g];
	}

	_exists(g) {
		return localStorage[PREFIX+g] !== undefined;
	}

	_parent(g) {
		return this._exists(g) && this._load(g).parent;
	}

	_isDirectory(g) {
		return this._exists(g) && this._load(g).children !== undefined;
	}

	_isFile(g) {
		return this._exists(g) && !this._isDirectory(g);
	}

	_locate(path, cb) {
		var t = path.split("/");
		var g = this._path;

		cb || (cb = (p) => { throw new Error("Cannot locate " + p) });

		while (t.length > 0) {
			var p = t.shift();
		
			if (!this._isDirectory(g)) {
				throw new Error("Attempt to use file as path");
			}

			var node = this._load(g);

			switch (p) {
				case '':
				case '.':
					break;
				case '..':
					g = node.parent;
					break ;
				case '...':
					g = TOP_PATH;
					break ;
				default :
					if (node.children[p] === undefined) {
						var d = cb(p, g, t);
						var ng = guid();

						node.children[p] = ng;
						this._save(g, node);
						this._save(ng, d);
						g = ng;
					} else {
						g = node.children[p];
					}

					break ;
			}
		}

		return g;
	}

	// Actual workers
	format() {
		Object.keys(localStorage).forEach((k) => {
			if (!k.indexOf(PREFIX)) {
				delete localStorage[k];
			}
		});

		this.constructor.call(this);
	}

	cd (path) {
		this._path = this._locate(path, function (p) {
			throw new Error("Cannot CD into " + p);
		});
	}

	mkdir (path) {
		this._locate(path, function (p, g) {
			return {
				children: {},
				parent: g
			}
		});
	}

	_rm(handle) {
		if (handle === TOP_PATH) {
			throw new Error("Cannot remove top directory")
		}



		if (this._isDirectory(handle)) {
			var node = this._load(handle);
			
			Object.keys(node.children).forEach((v) => this._rm(node.children[v]));
		}

		this._remove(handle);
	}

	rm (path) {
		var fh = this._locate(path);
		var parent = this._parent(fh);

		this._rm(fh);

		var node = this._load(parent);
		Object.keys(node.children).forEach((k) => {
			if (node.children[k] == fh) {
				delete node.children[k];
			}
		});
		this._save(parent, node);

		if (!this._exists(this._path)) {
			this._path = TOP_PATH;
		}
	}

	dir () {
		var node = this._load(this._path);

		return Object.keys(node.children).reduce((acc, k) => {
			acc[this._isDirectory(node.children[k]) ? "folders" : "files"].push(k);
			return acc;
		}, { files:[], folders: [] });
	}

	load(path) {
		var g = this._locate(path);

		if (!this._isFile(g)) {
			throw new Error("Cannot load directory as file");
		}

		return decode(this._load(g).data);
	}

	save(fn, data) {
		if (fn.indexOf("/") >= 0) {
			throw new Error("Invalid path character");
		}

		var fh = this._locate(fn, function (p, g, t) {
			if (t.length > 0) {
				return {
					parent: g,
					children: {}
				}
			} else {
				return {
					parent: g,
					data: encode(data)
				};
			}
		});
	}

	install(url) {
		var fn = url.split("/").pop();

		return loadURL(url).then((program) => {
			this.save(fn, program.rom);
		});
	}
}