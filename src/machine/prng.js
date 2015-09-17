const max = 1 << 32;
const mask = max - 1;

export default class PRNG {
	constructor(seed) {
		this._w = seed | (Math.random() * max)|0;
		this._z = 987654321;
	}

	seed(seed) {
		this._w = seed | (Math.random() * max)|0;
	}

	get(s) {
	    this._z = (36969 * (this._z & 65535) + (this._z >> 16)) & mask;
	    this._w = (18000 * (this._w & 65535) + (this._w >> 16)) & mask;
	    
	    var result = ((this._z << 16) + this._w) & mask;
	    return s * (result / max);
	}
}
