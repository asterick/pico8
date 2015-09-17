var inc = 0;
function guid() {
	return "_" + inc++;
}

export default class Table {
	constructor() {
		this._values = {};
		this._keys = {};
		this._top = 0;
		this._id = guid();
	}

	static fromArray(a) {
		var t = new Table();

		a.forEach((v, i) => {
			t.set(i+1, v);
		})
		
		return t;
	}

	static isTable(a) {
		return typeof a === "object" && a instanceof Table;
	}

	define(set) {
		Object.keys(set).forEach((idx) => this.set(idx, set[idx]));
	}

	// This is a very cheap hashing algorithm for keying tables as strings
	_index(i) {
		switch(typeof i) {
			case "undefined":
				return "u";
			case "number":
				return "n" + ((i * 0x10000)|0);
			case 'boolean':
				return i ? "t" : "f";
			case 'string':
				return 's' + i;
			case 'object':
				return 'o' + i._id;
			case 'function':
				i._id || (i._id = guid());
				return 'f' + i._id;
			default:
				throw Error("FFFF");
		}
	}

	values () {
		return Object.keys(this._values).map((v) => this._values[v]);
	}

	count () {
		return this._top;
	}

	get (i) {
		return this._values[this._index(i)];
	}

	set (i, v) {
		var idx = this._index(i);
		
		if (v === undefined) {
			delete this._keys[idx];
			delete this._values[idx];
		} else {
			this._keys[idx] = i;
			this._values[idx] = v;
		}

		// Countable index
		if (typeof i === 'number' && i|0 == i && i >= 1) {
			if (typeof v === 'undefined') {
				this._top = i - 1;
			} else {
				while (this._values[this._index(this._top+1)] !== undefined) this._top++;
			}
		}
	}

	toString() {
		return `table: ${this._id}`
	}
}
