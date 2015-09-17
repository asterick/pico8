import Table from "./table.js"
import Compiler from "./compiler.js"

const PARSEABLE_NUMBER = /^[0-9]+$/;

export class RuntimeError {
	constructor(msg, loc, ast) {
		this.message = msg;
		this.location = loc;
		this.tree = ast;
	}
}

export default class Runtime {
	constructor(defines) {
		this.globals = new Table();
		this._guidIndex = 0;

		this.define(defines);
	}

	define(set = {}) {
		this.globals.define(set);
	}

	evaluate(src) {
		var comp = new Compiler();
		var ast = comp.parse(src);
		var code = comp.compile(ast);

		var func = new Function("Runtime", "Table", code).bind(this, Runtime, Table);
		func();
	}

	execute(funct) {
		var funct = this.globals.get("funct");
		
		if (typeof funct !== "function") return null ; // This is an impossible value

		var args = Array.prototype.slice.call(arguments, 1);
		return funct.apply(this, args);
	}

	// Operators
	_lt(l, r) {
		var a = this.typeOf(l), b = this.typeOf(r);

		if (a !== b) {
			throw new RuntimeError(`Cannot compare ${a} to ${b}`);
		}

		if (a !== 'string' && a !== 'number') {
			throw new RuntimeError(`Cannot compare ${a} types`);
		}

		return l < r;
	}

	_gt(l, r) {
		var a = this.typeOf(l), b = this.typeOf(r);

		if (a !== b) {
			throw new RuntimeError(`Cannot compare ${a} to ${b}`);
		}

		if (a !== 'string' && a !== 'number') {
			throw new RuntimeError(`Cannot compare ${a} types`);
		}

		return l > r;
	}

	_lte(l, r) {
		var a = this.typeOf(l), b = this.typeOf(r);

		if (a !== b) {
			throw new RuntimeError(`Cannot compare ${a} to ${b}`);
		}

		if (a !== 'string' && a !== 'number') {
			throw new RuntimeError(`Cannot compare ${a} types`);
		}

		return l <= r;
	}

	_gte(l, r) {
		var a = this.typeOf(l), b = this.typeOf(r);

		if (a !== b) {
			throw new RuntimeError(`Cannot compare ${a} to ${b}`);
		}

		if (a !== 'string' && a !== 'number') {
			throw new RuntimeError(`Cannot compare ${a} types`);
		}

		return l >= r;

	}

	_ne(l, r) {
		if (this.typeOf(l) !== this.typeOf(r)) {
			return true;
		}

		return l != r;
	}

	_eq(l, r) {
		if (this.typeOf(l) !== this.typeOf(r)) {
			return false;
		}

		return l == r;
	}

	_concat(l, r) {
		return Runtime.toString(l) + Runtime.toString(r);
	}

	_add(l, r) {
		return Runtime.toNumber(l) + Runtime.toNumber(r);
	}

	_sub(l, r) {
		return Runtime.toNumber(l) - Runtime.toNumber(r);
	}

	_mul(l, r) {
		return Runtime.toNumber(l) * Runtime.toNumber(r);
	}

	_div(l, r) {
		return Runtime.toNumber(l) / Runtime.toNumber(r);
	}

	_mod(l, r) {
		return Runtime.toNumber(l) % Runtime.toNumber(r);
	}

	_pow(l, r) {
		return Math.pow(Runtime.toNumber(l), Runtime.toNumber(r));
	}

	_not(v) {
		return !Runtime.toBool(v);
	}

	_len(v) {
		if (Table.isTable(v)) {
			return v.count();
		} else if (typeof v === "string") {
			return v.length;
		}

		throw new RuntimeError("Cannot get length of " + v);
	}

	_neg(v) {
		return -Runtime.toNumber(v);
	}

	static typeOf(v) {
		switch (typeof v) {
		case 'number':
		case 'string':
		case 'boolean':
			return typeof v;
		case 'undefined':
			return "nil";
		case 'object':
			if (Table.isTable(v)) {
				return "table";
			}
		default:
			return "unknown"
		}
	}

	static toBool(v) {
		if (v === undefined || v === false) {
			return false;
		}
		
		return true;
	}

	static toString(v) {
		switch (typeof v) {
		case 'boolean':
		case 'number':
			return String(v);
		case 'string':
			return v;
		default:
			throw new RuntimeError("Cannot coerce " + v + "to string");
		}
	}

	static toNumber(v) {
		switch (typeof v) {
		case 'number':
			return v;
		case 'string':
			if (PARSEABLE_NUMBER.test(v)) {
				return parseInt(v, 10);
			}
		default:
			throw new RuntimeError("Cannot coerce " + v + "to number");
		}
	}

	// These are simple runtime helper functions
	_pluck(args, index) {
		if (!Array.isArray(args)) {
			if (index) {
				return ;
			} else {
				return args;
			}
		} else {
			return this._pluck(args[index], 0);
		}
	}
}
