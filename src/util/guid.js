var inc = 0;
var s = +new Date();
var r = (Math.random() * 0x80000000) | 0;

function guid() {
	var q = [inc++,(Math.random() * 0x80000000) | 0,s,r,+new Date()];
	return q.map((v) => v.toString(36)).join("-");
}

export default guid;
