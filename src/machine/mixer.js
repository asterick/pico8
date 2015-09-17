const AudioContext = window.AudioContext || window.webkitAudioContext;

function tri(t) {
	return Math.abs((t % 1) * 4 - 2) - 1
}

const Waveforms = [
	(t) => tri(t),
	(t) => ((t < 0.875) ? (t * 16 / 7) : ((1 - t) * 16)) - 1,
	(t) => t * 2 - 1,
	(t) => (t < 0.5) ? -1 : 1,
	(t) => (t < 0.75) ? -1 : 1,
	(_, t) => tri(t) + tri(t / 2) / 2,
	(t) => Math.random(),
	(_, t) => tri(t) + tri(t * 127 / 128) / 2,
];

const BASE_NOTE = 65.41;
const TICKS_PER_SECOND = 120;

export default class AudioMixer {
	constructor(bufferRate) {
		this.initalize(bufferRate);

		this.baseRate = BASE_NOTE / this.context.sampleRate;
		this.playbackFreq = this.baseRate * Math.pow(2,1);
		this.masterVolume = 0.20;
		this.waveIndex = 0;
		this.wave = 7;

		//setInterval(() => this.wave = (this.wave + 1) % Waveforms.length, 2500);

		this.play();
	}

	initalize(bufferRate) {
		this.context = new AudioContext();
		this.source = this.context.createBufferSource();
		
		this.node = this.context.createScriptProcessor(bufferRate || 0x1000, 0, 1);
		this.node.onaudioprocess = this.onaudioprocess.bind(this);
	}

	play() {
		this.source.connect(this.node);
		this.node.connect(this.context.destination);
		this.source.start();
	}

	onaudioprocess(e) {
	  	// The output buffer contains the samples that will be modified and played
	  	var outputData = e.outputBuffer.getChannelData(0);

	  	// Loop through the output channels (in this case there is only one)
		for (var sample = 0; sample < outputData.length; sample++) {
	    	outputData[sample] = Waveforms[this.wave](this.waveIndex % 1, this.waveIndex) * this.masterVolume;
	    	this.waveIndex = (this.waveIndex + this.playbackFreq) % 65536;
		}
	}
}
