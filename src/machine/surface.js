export default class Surface {
	constructor(buffer, drawPalette, clipRect, cameraPos) {
		if (buffer === undefined) {
			buffer = new Uint8Array(0x2000);
		}

		this.frame = buffer;
		this.drawPalette = drawPalette;
		this.clipRect = clipRect;
		this.cameraPos = cameraPos;
	}

	get clipX() { return this.clipRect[0]; }
	get clipY() { return this.clipRect[1]; }
	get clipW() { return this.clipRect[2]; }
	get clipH() { return this.clipRect[3]; }

	get cameraX() { return this.cameraPos[0]; }
	get cameraY() { return this.cameraPos[1]; }

	get(x, y) {
		if (x < 0 || y < 0 || x >= 128 || y >= 128) {
			return 0;
		}

		var px = this.frame[(x >> 1) + y * 64];

		return (x & 1) ? (px >> 4) : (px & 0xF);
	}

	set(x, y, col) {
		col = this.drawPalette[col & 0xF];

		if (col > 0xF) { return ; }

		var col = (col & 0xF) * 0x11
		var m = (x & 1) ? 0xF0 : 0x0F;
		var a = (x >> 1) + y * 64;

		this.frame[a] = (this.frame[a] & ~m) | (col & m);
	}

	hline(x, y, w, c) {
		var cy = this.clipY;
		var ch = this.clipH;

		if (y < cy || y >= cy+ch) {
			return ;
		}

		var cw = this.clipW;
		var cx = this.clipX;

		if (x < cx) {
			w = w - (cx - x);
			x = cx;
		}

		if (x + w > cx+cw) {
			w = cx + cw - x;
		}

		// We want to try to fill bytes
		if (x & 1) { this.set(x++, y, c); w--; }
		if (w & 1) { this.set(x+w-1, y, c); w--; }

		var loc = (x >> 1) + y * 64
		c = (c & 0xF) * 0x11;

		while (w > 0) {
			this.frame[loc++] = c;
			w -= 2;
		}
	}


	vline(x, y, h, c) {
		var cw = this.clipW;
		var cx = this.clipX;

		if (x < cx || x >= cx+cw) {
			return ;
		}

		var cy = this.clipY;
		var ch = this.clipH;

		if (y < cy) {
			h = h - (cy - y);
			y = cy;
		}

		if (y+h >= cy+ch) {
			h = (cy + ch) - y;
		}

		var c = (c & 0xF) * 0x11
		var m = (x & 1) ? 0xF0 : 0x0F;
		var a = (x >> 1) + y * 64;

		while(h-- > 0) {
			this.frame[a] = (this.frame[a] & ~m) | (c & m);
			a += 64;
		}
	}

	clipset(x, y, c) {
		var cx = this.clipX;
		var cy = this.clipY;
		var cw = this.clipW;
		var ch = this.clipH;

		if (x < cx || y < cy || x >= cx+cw || y >= cy+ch) {
			return ;
		}

		this.set(x, y, c);
	}

	point(x, y, col) {	
		col = this.drawPalette[col & 0xF];
		if (col > 0xF) { return ; }

		// Adjust to camera
		x -= this.cameraX;
		y -= this.cameraY;

		this.clipset(x, y, col);
	}

	circle(x, y, r, col) {
		col = this.drawPalette[col & 0xF];
		if (col > 0xF) { return ; }

		// Adjust to camera
		x -= this.cameraX;
		y -= this.cameraY;

		var xt = r;
		var yt = 0;
		var do2 = 1 - xt;   // Decision criterion divided by 2 evaluated at x=r, y=0

		while( yt <= xt ) {
			this.clipset( xt + x,  yt + y, col);
			this.clipset( yt + x,  xt + y, col);
			this.clipset(-xt + x,  yt + y, col);
			this.clipset(-yt + x,  xt + y, col);
			this.clipset(-xt + x, -yt + y, col);
			this.clipset(-yt + x, -xt + y, col);
			this.clipset( xt + x, -yt + y, col);
			this.clipset( yt + x, -xt + y, col);
			yt++;
			
			if (do2 <= 0) {
				do2 += 2 * yt + 1;
			} else {
				do2 += 2 * (yt - --xt) + 1;
			}
		}
	}

	circleFill(x, y, r, col) {
		col = this.drawPalette[col & 0xF];
		if (col > 0xF) { return ; }

		// Adjust to camera
		x -= this.cameraX;
		y -= this.cameraY;

	    var xoff =0;
	    var yoff = r;
	    var balance = -r;
	 
	    while (xoff <= yoff) {
			var p0 = x - xoff;
			var p1 = x - yoff;

			var w0 = xoff + xoff;
			var w1 = yoff + yoff;

			this.hline(p0, y + yoff, w0, col);
			this.hline(p0, y - yoff, w0, col);
			this.hline(p1, y + xoff, w1, col);
			this.hline(p1, y - xoff, w1, col);
	       
	       	balance += xoff++ + xoff;
	        if (balance >= 0) {	            
	            balance -= --yoff + yoff;
	        }
	    }		
	}

	line(x0, y0, x1, y1, col) {
		col = this.drawPalette[col & 0xF];
		if (col > 0xF) { return ; }

		// Adjust to camera
		x0 -= this.cameraX;
		x1 -= this.cameraX;
		y0 -= this.cameraY;
		y1 -= this.cameraY;
		
		var dx = Math.abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
		var dy = Math.abs(y1 - y0), sy = y0 < y1 ? 1 : -1; 
		var err = (dx>dy ? dx : -dy)/2;

		while (true) {
			this.clipset(x0, y0, col);

			if (x0 === x1 && y0 === y1) break;

			var e2 = err;
			if (e2 > -dx) { err -= dy; x0 += sx; }
			if (e2 < dy) { err += dx; y0 += sy; }
		}
	}

	rectangle (x0, y0, x1, y1, col) {
		col = this.drawPalette[col & 0xF];
		if (col > 0xF) { return ; }

		// Adjust to camera
		x0 -= this.cameraX;
		x1 -= this.cameraX;
		y0 -= this.cameraY;
		y1 -= this.cameraY;

		var yt = Math.min(y0,  y1) + 1;
		var h0 = Math.abs(y0 - y1) - 1;

		this.vline(x0, yt, h0, col);
		this.vline(x1, yt, h0, col);

		var xt = Math.min(x0, x1);
		var w0 = Math.abs(x0 - x1) + 1;

		this.hline(xt, y0, w0, col);
		this.hline(xt, y1, w0, col);
	}

	rectangleFill (x0, y0, x1, y1, col) {
		col = this.drawPalette[col & 0xF];
		if (col > 0xF) { return ; }

		// Adjust to camera
		x0 -= this.cameraX;
		x1 -= this.cameraX;
		y0 -= this.cameraY;
		y1 -= this.cameraY;

		var xt = Math.min(x0, x1);
		var w0 = Math.abs(x0 - x1) + 1;

		for (var y = y0; y <= y1; y++) {
			this.hline(xt, y, w0, col);
		}
	}

	draw (surf, dx, dy, sx, sy, w, h) {
		// Adjust for camera
		dx -= this.cameraX;
		dy -= this.cameraY;

		// Preclip the sprite to display area
		var cx = this.clipX;
		var cy = this.clipY;
		var cw = this.clipW;
		var ch = this.clipH;

		if (dx < cx) {
			w = w - (cx - dx);
			sx += (cx - dx);
			dx = cx;
		}

		if (dx + w > cx+cw) {
			w = cx + cw - dx;
		}

		if (dy < cy) {
			h = h - (cy - dy);
			sy += (cy - dy);
			dy = cy;
		}

		if (dy+h >= cy+ch) {
			h = (cy + ch) - dy;
		}

		// Clip sprite size
		if (sx + w > 128) {
			w = 128 - sx;
		}
		if (sy + h > 128) {
			h = 128 - sy;
		}

		// Sloppy copy
		for (; h > 0; sy++, dy++, h--) {
			for (var xo = 0; xo < w; xo++) {
				col = this.drawPalette[surf.get(sx+xo, sy)];
				if (col > 0xF) { continue ; }

				this.set(dx+xo, dy, col);
			}
		}
	}
}
