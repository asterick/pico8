pico-8 cartridge // http://www.pico-8.com
version 4
__lua__

sfx_boost=36
sfx_boost_warning=37
sfx_boost_critical=39
sfx_boost_recover=34
sfx_boost_cooldown=33
sfx_booster=41

boost_warning_thresh=30
boost_critical_thresh=15

dark_color = {
	  1,2,3,
	4,5,5,4,
	2,5,5,3,
	1,5,2,5
}

track_colors = {
	8,9,10,11,12,3,14,15
}
dt=1/30
-- globals

local particles = {}
local mapsize = 250

function ai_controls(car)
	-- look ahead 5 segments
	local ai = {
		decisions = rnd(5)+3,
		lookahead = 5,
		target_seg = 1,
		riskiness = rnd(23)+1
	}
	ai.car = car
	function ai:update()
		self.decisions += dt*(self.skill+rnd(6))
		local car = self.car
		if not car.current_segment then return end
		local s = 5
		if self.decisions < 1 then
			return
		end
		local t = car.current_segment+s
		if t < mapsize-6 then
			local v5 = get_vec_from_vecmap(t)
			if v5 then
				local a = atan2(v5.x-car.x,v5.y-car.y)
				local diff = a-car.angle
				while diff > 0.5 do diff -= 1 end
				while diff < -0.5 do diff += 1 end
				if abs(diff) > 0.02 and rnd(50) > 40+self.skill then
					self.decisions = 0
				end
				car.controls.accel = abs(diff) < 10.02
				car.controls.right = diff < -0.015
				car.controls.left = diff > 0.015
				car.controls.brake = abs(diff) > 0.04
				car.controls.boost = car.boost > 24-self.riskiness and (abs(diff) < 0.02 or car.accel < 0.5)
				self.decisions -=1
			--break
			end
		else
			car.controls.accel = false
			car.controls.boost = false
			car.controls.brake = true
		end
	end
	return ai
end

function create_car(race)
	local car = {
		race=race,
		x=200,
		y=64,
		xv=0,
		yv=0,
		angle=0,
		trails = cbufnew(32),
		current_segment = 3,
		boost=100,
		cooldown=0,
		wrong_way=0,
		speed=0,
		accel=0,
		lost_count=0,
		last_good_x=200,
		last_good_y=64,
		color=8,
		collision=0,
	}
	car.controls = {
	}
	car.verts = {
		vec(-4,-3),
		vec(4, 0),
		vec(-4, 3)
	}
	car.get_poly = function(self)
		return fmap(self.verts,function(i) return rotate_point(self.x+i.x,self.y+i.y,self.angle,self.x,self.y) end)
	end
	car.update = function(self)
		local angle = self.angle
		local ax = cos(angle)
		local ay = sin(angle)
		local x = self.x
		local y = self.y
		local xv = self.xv
		local yv = self.yv
		local accel = self.accel
		local controls = self.controls

		if controls.accel then
			accel+=0.08*0.3
		else
			accel*=0.98
		end
		local speed = mysqrt(xv*xv+yv*yv)
		-- accelerate
		if controls.left then angle+=0.0225*0.3 end
		if controls.right then angle-=0.0225*0.3 end
		-- brake
		local sb_left
		local sb_right
		if controls.brake then
			if controls.left then
				sb_left = true
			elseif controls.right then
				sb_right = true
			else
				sb_left = true
				sb_right = true
			end
			if sb_left then
				angle += speed*0.0009
			end
			if sb_right then
				angle -= speed*0.0009
			end
			xv*=0.95
			yv*=0.95
		end
		accel=min(accel,self.boosting and 3 or 2)
		-- boosting

		if controls.boost and self.boost > 0 and self.cooldown <= 0 then
			self.boosting = true
			self.boost -= 1
			self.boost = max(self.boost,0)
			accel+=0.08*0.3

			if self.boost == 0 then -- activate cooldown
				self.cooldown = 25
				accel*=0.5
				if self.is_player then
					sfx(sfx_boost_cooldown,0)
					sc1=sfx_boost_cooldown
				end
			elseif self.is_player and (not (sc1 == sfx_booster and sc1timer > 0)) and sc1 != sfx_boost_critical and self.boost <= boost_critical_thresh then
				sfx(sfx_boost_critical,0)
				sc1=sfx_boost_critical
			elseif self.is_player and (not (sc1 == sfx_booster and sc1timer > 0)) and sc1 != sfx_boost_warning and self.boost <= boost_warning_thresh then
				sfx(sfx_boost_warning,0) -- start warning
				sc1=sfx_boost_warning
			elseif self.is_player and (not (sc1 == sfx_booster and sc1timer > 0)) and sc1 != sfx_boost and sc1 != sfx_boost_warning then
				sfx(sfx_boost,0)
				sc1=sfx_boost
			end
		else
			self.boosting = false
			if self.cooldown > 0 then
				self.cooldown -= 0.25
				self.cooldown = max(self.cooldown,0)
				if self.is_player and self.cooldown == 0 then
					sfx(sfx_boost_recover,0) -- restore power
					sc1=sfx_boost_recover
				end
				self.boost += 0.125
			else
				self.boost += 0.25
				self.boost = min(self.boost,100)
			end
			if self.is_player and (sc1==sfx_boost_warning or sc1==sfx_boost_critical or sc1==sfx_boost or ((sc1==38 or sc1==40) and self.collision <= 0) or (sc1 == sfx_boost_recover and self.boost > 10)) then
				-- engine noise
				sfx(35,0)
				sc1=35
			end
		end

		-- check collisions
		-- get a width enlarged version of this segment to help prevent losing the car
		local current_segment = self.current_segment
		local segpoly = get_segment(current_segment,true)
		local poly

		self.collision = 0
		if segpoly then
			local in_current_segment = point_in_polygon(segpoly,vec(x,y))
			if in_current_segment then
				self.last_good_x = self.x
				self.last_good_y = self.y
				self.last_good_seg = current_segment
				self.lost_count = 0
				poly = get_segment(current_segment)
			else
				-- not found in current segment, try the next
				local segnextpoly = get_segment(current_segment+1,true)
				if segnextpoly and point_in_polygon(segnextpoly,vec(x,y)) then
					poly = get_segment(current_segment+1)
					current_segment+=1
					self.wrong_way=0
				else
					-- not found in current or next, try the previous one
					local segprevpoly = get_segment(current_segment-1,true)
					if segprevpoly and point_in_polygon(segprevpoly,vec(x,y)) then
						poly = get_segment(current_segment-1)
						current_segment-=1
						self.wrong_way+=1
					else
						-- completely lost the player
						self.lost_count += 1
						current_segment+=1 -- try to find the car next frame
						if self.lost_count > 30 then
							-- lost for too long, bring them back to the last known good position
							local v = get_vec_from_vecmap(self.last_good_seg)
							self.x = v.x
							self.y = v.y
							self.current_segment = self.last_good_seg-2
							self.xv = 0
							self.yv = 0
							self.angle = v.dir
							self.wrong_way = 0
							self.accel = 1
							self.lost_count = 0
							self.trails = cbufnew(32)
							return
						end
					end
				end
			end
			-- check collisions with walls
			if poly then
				local car_poly = self:get_poly()
				local rv,p,point = check_collision(car_poly,{{poly[2],poly[3]},{poly[4],poly[1]}})
				if rv then
					if p > 5 then p = 5 end
					xv -= rv.x * p
					yv -= rv.y * p
					accel*=1.0 - (p/10)
					add(particles,{x=point.x,y=point.y,xv=-rv.x+(rnd(2)-1)/2,yv=-rv.y+(rnd(2)-1)/2,ttl=30})
					self.collision += p
					if self.is_player then
						if p > 2 then
							sfx(38,0)
							sc1=38
						else
							sfx(40,0)
							sc1=40
						end
					end
				end
			end
		end
		-- check for boosters under us
		if current_segment then
			for b in all(boosters) do
				if b.segment <= current_segment+1 and b.segment >= current_segment-1 then
					local bx = b.x
					local by = b.y
					local pa = rotate_point(bx-12,by-12,b.dir,bx,by)
					local pb = rotate_point(bx+12,by-12,b.dir,bx,by)
					local pc = rotate_point(bx+12,by+12,b.dir,bx,by)
					local pd = rotate_point(bx-12,by+12,b.dir,bx,by)
					if point_in_polygon({pa,pb,pc,pd},vec(x,y)) then
						xv*=1.25
						yv*=1.25
						if self.is_player then
							sfx(sfx_booster,0)
							sc1=sfx_booster
							sc1timer=10
						end
					end
				end
			end
		end

		xv+=ax*accel
		yv+=ay*accel

		x+=xv*0.3
		y+=yv*0.3

		-- drag
		-- check if in slipstream
--		local in_slipstream = false
--		for obj in all(self.race.objects) do
--			if obj != self and obj.current_segment and self.current_segment and obj.current_segment >= self.current_segment then
--				local br = normalize(vecdiff(obj,self))
--				local v = normalize(vec(obj.xv,obj.yv))
--				if distance2(obj,self) < 4096 and dot(br,v) > 0.9 then
--					in_slipstream = true
--					break
--				end
--			end
--		end
--		self.in_slipstream = in_slipstream
--		if in_slipstream then
--			xv*=0.91
--			yv*=0.91
--		else
			xv*=0.9
			yv*=0.9
--		end

		local t = rotate_point(x-6,y,angle,x,y)
		cbufpush(self.trails,t)

		-- update self attrs
		self.x = x
		self.y = y
		self.xv = xv
		self.yv = yv
		self.accel = accel
		self.speed = speed -- used for showing speedo
		self.angle = angle
		self.current_segment = current_segment
	end
	car.draw = function(self)
		local x = self.x
		local y = self.y
		local angle = self.angle
		local color = self.color
		local v = fmap(self.verts,function(i) return rotate_point(x+i.x,y+i.y,angle,x,y) end)
		local a = v[1]
		local b = v[2]
		local c = v[3]
		local boost = self.boost
		linevec(a,b,color)
		linevec(b,c,color)
		linevec(c,a,color)
		local circ = rotate_point(x-6,y,angle,x,y)
		local outc = 12
		if self.boost and self.boost < 30 then
			outc = self.boost < 15 and 8 or 9
		end
		if self.cooldown > 0 then
			circfill(circ.x,circ.y,frame%8 < 4 and 1 or 0,8)
		else
			circfill(circ.x,circ.y,self.boosting and frame%2 == 0 and 4 or 2,outc)
			circfill(circ.x,circ.y,self.boosting and frame%2 == 0 and 2 or 1,7)
		end

	end

	car.draw_trails = function(self)
		-- trails
		local lastp
		for i=0,self.trails._size-1 do
			local p = cbufget(self.trails,-i)
			if not p then break end
			if lastp then
				linevec(lastp,p,i > self.trails._size - 4 and 7 or (i < 12 and 1 or 12))
			end
			lastp = p
		end
	end

	return car
end

function set_game_mode(m)
	game_mode = m
end

function _init()
	intro:init()
	set_game_mode(intro)
end

function _draw()
	game_mode:draw()
end

function _update()
	game_mode:update()
end

-- intro

intro = {}
difficulty = 1
frame = 0

game_modes = {
	"race vs ai",
	"time attack"
}

function intro:init()
	music(0)
	self.game_mode = 1
end

function intro:update()
	frame+=1
	if not btn(4) then self.ready = true end
	if self.option == 1 then
		if btnp(0) then self.game_mode -= 1 end
		if btnp(1) then self.game_mode += 1 end
	elseif self.option == 2 then
		if btnp(0) then difficulty -= 1 end
		if btnp(1) then difficulty += 1 end
	elseif self.option == 3 then
		if self.ready and btnp(4) then
			local race = race()
			race:init(difficulty,self.game_mode)
			set_game_mode(race,self)
		end
	end
	if btnp(2) then self.option -= 1 end
	if btnp(3) then self.option += 1 end
	difficulty = max(min(difficulty,5),0)
	self.game_mode = max(min(self.game_mode,2),1)
	self.option = max(min(self.option,3),1)
end

difficulty_names = {
	[0]="nano",
	"pico",
	"femto",
	"atto",
	"zepto",
	"yocto",
}

function intro:draw()
	cls()
	sspr(0,20,128,128,0,0)


	printr("z - accel",127,40,6)
	printr("x - brake",127,48,6)
	printr("up - boost",127,56,6)
	printr("< > - steer",127,64,6)
	printr("shift - menu",127,72,6)

	local c = frame%16<8 and 8 or 9
	printr("mode",127,2,self.option == 1 and c or 9)
	printr(game_modes[self.game_mode],127,8,6)
	printr("difficulty",128,16,self.option == 2 and c or 9)
	printr(difficulty_names[difficulty],128,22,6)
	printr("start",128,30,self.option == 3 and c or 9)
end


function race()
	local race = {}
	function race:init(difficulty,race_mode)
		self.race_mode = race_mode
		sc1=nil
		sc1timer=0
		maxwidth = 64
		maxlength = 20
		if difficulty == 0 then
			modes = "111223345"
			minwidth = 48
			minlength = 10
			maxlength = 30
		elseif difficulty == 1 then
			modes = "111234567"
			minwidth = 32
			minlength = 7
			maxlength = 25
		elseif difficulty == 2 then
			modes = "112233456789"
			minwidth = 24
			maxwidth = 48
			minlength = 5
		elseif difficulty == 3 then
			modes = "1123456789ab"
			minwidth = 16
			maxwidth = 32
			minlength = 3
		elseif difficulty == 4 then
			modes = "16789ab"
			minwidth = 12
			maxwidth = 32
			minlength = 2
			maxlength = 15
		elseif difficulty == 5 then
			modes = "189aabb"
			minwidth = 8
			maxwidth = 32
			minlength = 1
			maxlength = 10
		end

		vecmap = {}
		boosters = {}
		local dir,mx,my=0,64,64
		local w = 32
		local mode = "1"
		local length = 10
		local lastdir = 0
		-- generate map
		for i=1,mapsize do

			if mode == "2" then
				dir += 0.01
			elseif mode == "3" then
				dir += 0.02
			elseif mode == "4" then
				dir += 0.03
			elseif mode == "5" then
				dir += 0.06
			elseif mode == "6" then
				dir -= 0.01
			elseif mode == "7" then
				dir -= 0.02
			elseif mode == "8" then
				dir -= 0.03
			elseif mode == "9" then
				dir -= 0.06
			elseif mode == "a" then
				dir += 0.1
			elseif mode == "b" then
				dir -= 0.1
			end

			if abs(dir-lastdir) > 0.09 then
				dir = lerp(lastdir,dir,0.5)
				segment_length = 16
				length -= 0.5
			else
				segment_length = 32
				length -= 1
			end

			if i > 10 and i < mapsize-10 and abs(dir-lastdir) < 0.02 then
				local r=rnd(100)
				if r > 90 then
					local w = w-16
					-- place a booster
					local perp = perpendicular(vec(cos(dir),sin(dir)))
					-- either on left, middle or right of track
					local r = flr(rnd(2))+1
					if w < 20 then r = 2
					elseif w < 32 and r == 2 then r = 1 end
					local b
					if r == 1 then -- left
						b = vec(mx+perp.x*(w-8/2),my+perp.y*(w/2))
					elseif r == 2 then -- mid
						b = vec(mx,my)
					else -- right
						b = vec(mx-perp.x*(w/2),my-perp.y*(w/2))
					end
					b.segment = i
					b.dir = dir
					add(boosters,b)
				end
			end

			mx+=cos(dir)*segment_length
			my+=sin(dir)*segment_length
			add(vecmap,mx)
			add(vecmap,my)
			add(vecmap,w)
			add(vecmap,dir)

			lastdir = dir

			if length <= 0 then
				local r = rnd(#modes-1)+1
				mode = sub(modes,r,r)
				if mode == chicanel or mode == chicaner then
				else
					w = rnd(32)+16
				end
				length = rnd(maxlength-minlength)+minlength
				w = max(min(w,maxwidth),minwidth)
			end
		end
		-- finish off the track to look like the start
		for i=1,30 do
			mx+=cos(dir)*segment_length
			my+=sin(dir)*segment_length

			add(vecmap,mx)
			add(vecmap,my)
			add(vecmap,w)
			add(vecmap,dir)

			lastdir = dir
			mapsize += 1
			segment_length+=1
		end

		self:restart()
	end

	function race:restart()
		self.completed = false
		self.time = self.race_mode == 1 and -3 or 0
		self.previous_best = nil
		self.lastcx=64
		self.lastcy=64
		self.start_timer = self.race_mode == 1
		self.record_replay = nil
		self.play_replay_step = 1
		-- spawn cars

		self.objects = {}

		if self.race_mode == 2 and self.play_replay then
			local replay_car = create_car(self)
			add(self.objects,replay_car)
			replay_car.color = 1
			self.replay_car = replay_car
		end

		local p = create_car(self)
		add(self.objects,p)
		self.player = p
		p.is_player = true

		if self.race_mode == 1 then
			for i=1,3 do
				local ai_car = create_car(self)
				ai_car.color = rnd(6)+9
				ai_car.y -= (i%2!=0 and 16 or 0)
				ai_car.x -= i*16
				local oldupdate = ai_car.update
				ai_car.ai = ai_controls(ai_car)
				global_ai = ai_car.ai
				global_ai.skill = i+1
				ai_car.update = function(self)
					self.ai:update()
					oldupdate(self)
				end
				add(self.objects,ai_car)
			end
		end


	end

	function race:update()
		frame+=1
		if sc1timer > 0 then
			sc1timer-=1
		end

		if self.completed then
			self.completed_countdown -= dt
			if self.completed_countdown < 4 then
				set_game_mode(completed_menu(self))
				return
			end
		end

		if btn(4,1) then
			set_game_mode(paused_menu(self))
			return
		end

		-- enter input
		local player = self.player
		if player then
			player.controls.left = btn(0)
			player.controls.right = btn(1)
			player.controls.boost = btn(2)
			player.controls.accel = btn(4)
			player.controls.brake = btn(5)
		end

		-- replay playback
		if self.play_replay and self.replay_car then
			if self.play_replay_step == 1 then
				self.replay_car.x = self.play_replay[1].x
				self.replay_car.y = self.play_replay[1].y
				self.replay_car.angle = self.play_replay[1].angle
				self.play_replay_step=2
			end
			if self.start_timer then
				if self.play_replay_step == 2 then
					local rc = self.replay_car
					rc.xv = self.play_replay[1].xv
					rc.yv = self.play_replay[1].yv
					rc.accel = self.play_replay[1].accel
					rc.boost = self.play_replay[1].boost
				end
				local v = self.play_replay[self.play_replay_step]
				if v then
					local c = self.replay_car.controls
					c.left  = band(v,1) != 0
					c.right = band(v,2) != 0
					c.accel = band(v,4) != 0
					c.brake = band(v,8) != 0
					c.boost = band(v,16) != 0
					self.play_replay_step+=1
				end
			end
		end

		if player.current_segment == 6 and not self.start_timer and self.race_mode == 2 then
			self.start_timer = true
			self.record_replay = {}
			add(self.record_replay,{x=player.x,y=player.y,xv=player.xv,yv=player.yv,angle=player.angle,accel=player.accel,boost=player.boost})
		end
		if self.start_timer then
			self.time += dt
		end

		-- record replay
		if self.record_replay then
			local c = player.controls
			local v = (c.left  and 1  or 0)
					+ (c.right and 2  or 0)
					+ (c.accel and 4  or 0)
					+ (c.brake and 8  or 0)
					+ (c.boost and 16 or 0)
			add(self.record_replay,v)
		end

		if self.race_mode == 2 or self.time > 0 then
		for obj in all(self.objects) do
			obj:update()
		end
		end

		-- car to car collision
		for obj in all(self.objects) do
			for obj2 in all(self.objects) do
				if obj != obj2 and obj != self.replay_car and obj2 != self.replay_car then
					if abs(obj.current_segment-obj2.current_segment) <= 1 then
						local p1 = obj:get_poly()
						local p2 = obj2:get_poly()
						for point in all(p1) do
							if point_in_polygon(p2,point) then
								local rv,p,point = check_collision(p1,{{p2[2],p2[1]},{p2[3],p2[2]},{p2[1],p2[3]}})
								if rv then
									if p > 5 then p = 5 end
									p*=1.5
									obj.xv += rv.x * p
									obj.yv += rv.y * p
									obj2.xv -= rv.x * p
									obj2.yv -= rv.y * p
									add(particles,{x=point.x,y=point.y,xv=-rv.x+(rnd(2)-1)/2,yv=-rv.y+(rnd(2)-1)/2,ttl=30})
									obj.collision += flr(p)
									obj2.collision += flr(p)
									if obj.is_player or obj2.is_player then
										if p > 2 then
											sfx(38,0)
											sc1=38
										else
											sfx(40,0)
											sc1=40
										end
									end
								end
							end
						end
					end
				end
			end
		end

		if player.current_segment == mapsize-10 then
			-- completed
			self.completed = true
			self.completed_countdown = 5
			self.start_timer = false
			if (not self.best_time) or self.time < self.best_time then
				if self.best_time then
					self.previous_best = self.best_time
				end
				self.best_time = self.time
				self.play_replay = self.record_replay
			end
		end


		-- particles
		for p in all(particles) do
			p.x += p.xv
			p.y += p.yv
			p.xv *= 0.95
			p.yv *= 0.95
			p.ttl -= 1
			if p.ttl < 0 then
				del(particles,p)
			end
		end

	end

	function race:draw()
		--local player = global_ai.car
		local player = self.player
		local time = self.time
		cls()

		local tp = cbufget(player.trails,player.trails._size-8)
		local cx,cy
		if tp then
			cx=player.x+(player.x-tp.x)-64
			cy=player.y+(player.y-tp.y)-64
		else
			cx=player.x-64
			cy=player.y-64
		end
		if player.collision > 0 then
			camera(cx+rnd(3)-2,cy+rnd(3)-2)
		else
			camera(lerp(self.lastcx,cx,0.5),lerp(self.lastcy,cy,0.5))
		end

		self.lastcx = cx
		self.lastcy = cy

		local current_segment = player.current_segment
		-- draw track
		local lastv
		for seg=1,#vecmap/4 do
			local v = get_vec_from_vecmap(seg)
			if v.x then
			if not lastv then lastv = {x=nil,y=nil} end
			local diff = normalize(vec(v.x-(lastv.x or 0),v.y-(lastv.y or 0)))
			local w = v.w
			up = vec(v.x-diff.y*w,v.y+diff.x*w)
			down = vec(v.x+diff.y*w,v.y-diff.x*w)
			w = v.w-8
			up2 = vec(v.x-diff.y*w,v.y+diff.x*w)
			down2 = vec(v.x+diff.y*w,v.y-diff.x*w)
			w = v.w+4
			up3 = vec(v.x-diff.y*w,v.y+diff.x*w)
			down3 = vec(v.x+diff.y*w,v.y-diff.x*w)

			if lastv.x != nil then
				if onscreen(v,cx,cy) or onscreen(lastv,cx,cy) or onscreen(up,cx,cy) or onscreen(down,cx,cy) then

					-- inner track
					local track_color = (seg < current_segment-10 or seg > current_segment+10) and 1 or (seg%2==0 and 13 or 5)
					if seg > current_segment-5 and seg < current_segment+7 then
						if seg >= current_segment-2 and seg < current_segment+7 then
							linevec(lastup2,up2,track_color) -- mid upper
							linevec(lastdown2,down2,track_color) -- mid lower
						end

						-- look for upcoming turns and draw arrows
						-- scan foward until we find a turn sharper than 2/100
						for j=seg+2,seg+7 do
							local v1 = get_vec_from_vecmap(j)
							local v2 = get_vec_from_vecmap(j+1)
							if v1 and v2 then
								-- find the difference in angle between v and v2
								local diff = v2.dir - v1.dir
								while diff > 0.5 do diff -= 1 end
								while diff < -0.5 do diff += 1 end
								if diff > 0.03 then
									-- arrow left
									draw_arrow(lastup2,4,v.dir+0.25,9)
									break
								elseif diff < -0.03 then
									-- arrow right
									draw_arrow(lastdown2,4,v.dir-0.25,9)
									--linevec(lastv,lastdown3,8)
									break
								elseif v2.w < v1.w*0.75 then
									draw_arrow(lastup2,4,v.dir+0.25,8)
									draw_arrow(lastdown2,4,v.dir-0.25,8)
									break
								end
							end
						end
					end

					-- edges
					local track_color = (seg < current_segment-10) and 1 or track_colors[flr((seg/((mapsize+16)/8)))%8+1]
					if seg > current_segment+5 then
						track_color = dark_color[track_color]
						local segdiff = (seg - (current_segment+5)) * 0.01
						displace_line(lastup,up,cx,cy,segdiff,track_color)
						displace_line(lastdown,down,cx,cy,segdiff,track_color)
						--displace_line(lastup3,up3,cx,cy,segdiff,track_color)
						--displace_line(lastdown3,down3,cx,cy,segdiff,track_color)
					else
						linevec(lastup,up,track_color)
						linevec(lastdown,down,track_color)

						linevec(lastup3,up3,track_color)
						linevec(lastdown3,down3,track_color)
					end

					-- diagonals
					if seg >= current_segment-2 and seg < current_segment+7 then
						if seg == 6 or seg == mapsize-10 then
							linevec(lastup2,lastdown2,time < -1 and 8 or time < 0 and 9 or 11) -- start/end markers
						--else
							--linevec(lastup2,lastdown2,1) -- normal verticals
						end
						linevec(lastdown2,down,4)
						linevec(lastup2,up,4)
					end


				end
			end
			lastup = up
			lastdown = down
			lastup2 = up2
			lastdown2 = down2
			lastup3 = up3
			lastdown3 = down3
			lastv = v
			end
		end

		for b in all(boosters) do
			if b.segment >= current_segment-5 and b.segment <= current_segment+5 then
				draw_arrow(b,8,b.dir,12)
			end
		end

		-- draw objects
		for obj in all(self.objects) do
			if abs(obj.current_segment-player.current_segment) <= 10 then
				if obj.trails then obj:draw_trails() end
			end
		end
		for obj in all(self.objects) do
			if abs(obj.current_segment-player.current_segment) <= 10 then
				obj:draw()
			end
		end

		for p in all(particles) do
			line(p.x,p.y,p.x-p.xv,p.y-p.yv,p.ttl > 20 and 10 or (p.ttl > 10 and 9 or 8))
		end

		camera()

		--print("mem:"..stat(0),0,0,7)
		--print("cpu:"..stat(1),0,8,7)

		-- get placing
		local placing = 1
		local nplaces = 1
		for obj in all(self.objects) do
			if obj != player then
				nplaces+=1
				if obj.current_segment > player.current_segment then
					placing+=1
				end
			end
		end
		if self.start_timer then
			player.placing = placing
		end

		print((player.placing or '?')..'/'..nplaces,0,0,9)
		print("speed "..flr(player.speed*10),124-12*3,120,9)
		rectfill(128,124,128-40*(player.speed/15),126,9)
		rectfill(128,127,128-20*(player.accel),128,11)
		if player.cooldown > 0 then
			print("overheat ",0,120,8)
			rectfill(0,124,40*(player.cooldown/30),126,8)
		else
			local c = 12
			if player.boost < boost_warning_thresh then
				c = player.boost < boost_critical_thresh and (frame%4<2 and 8 or 7) or 8
			end
			print("boost ",0,120,c)
			rectfill(0,124,40*(player.boost/100),126,c)
		end
		print("time: "..format_time(time > 0 and time or 0),80,9,7)
		if self.best_time then
			print("best: "..format_time(self.best_time),80,3,7)
		end
		--if player.lost_count > 10 and not self.completed then
		--	print("off course",54,60,8)
		--end
		if player.wrong_way > 4 then
			print("wrong way!",54,60,8)
		end
		if time < 0 then
			print(-flr(time),60,20,8)
		end
		if player.collision > 0 or self.completed then
			-- corrupt screen
			for i=1,(completed and 100-((completed_countdown/5)*100) or 10) do
				local source = rnd(flr(0x6000+8192))
				local range = flr(rnd(64))
				local dest = 0x6000 + rnd(8192-range)-2
				memcpy(dest,source,range)
			end
			player.collision -= 0.1
		end
	end

	return race
end


function mysqrt(x)
	if x <= 0 then return 0 end
	local r = sqrt(x)
	if r < 0 then return 32768 end
	return r
end

function copyv(v)
	return {x=v.x,y=v.y}
end

function vec(x,y)
	return { x=x,y=y }
end

function rotate_point(x,y,angle,ox,oy)
	ox = ox or 0
	oy = oy or 0
	return vec(cos(angle) * (x-ox) - sin(angle) * (y-oy) + ox,sin(angle) * (x-ox) + cos(angle) * (y-oy) + oy)
end

function cbufnew(size)
	return {_start=0,_end=0,_size=size}
end

function cbufpush(cb,v)
	-- add a value to the end of a circular buffer
	cb[cb._end] = v
	cb._end = (cb._end+1)%cb._size
	if cb._end == cb._start then
		cb._start = (cb._start+1)%cb._size
	end
end

function cbufpop(cb)
	-- remove a value from the start of the circular buffer, and return it
	local v = cb[cb._start]
	cb._start = cb._start+1%cb._size
	return v
end

function cbufget(cb,i)
	-- return a value from the circular buffer by index. 0 = start, -1 = end
	if i <= 0 then
		return cb[(cb._end - i)%cb._size]
	else
		return cb[(cb._start + i)%cb._size]
	end
end

function _update()
	game_mode:update()
end

function paused_menu(game)
	local selected = 1
	local m = {
	}
	function m:update()
		frame+=1
		if btnp(2) then selected -= 1 end
		if btnp(3) then selected += 1 end
		selected = max(min(selected,3),1)
		if btnp(4) then
			if selected == 1 then
				set_game_mode(game)
			elseif selected == 2 then
				set_game_mode(game)
				game:restart()
			elseif selected == 3 then
				set_game_mode(intro)
			end
		end
	end
	function m:draw()
		game:draw()
		rectfill(35,40,93,88,1)
		print("paused",40,44,7)
		print("continue",40,56,selected == 1 and frame%4<2 and 7 or 6)
		print("restart race",40,62,selected == 2 and frame%4<2 and 7 or 6)
		print("exit",40,70,selected == 3 and frame%4<2 and 7 or 6)
	end
	return m
end

function completed_menu(game)
	local m = {
		selected=1
	}
	function m:update()
		frame+=1
		if not btn(4) then self.ready = true end
		if btnp(2) then self.selected -= 1 end
		if btnp(3) then self.selected += 1 end
		self.selected = clamp(self.selected,1,2)
		if self.ready and btnp(4) then
			if self.selected == 1 then
				set_game_mode(game)
				game:restart()
			else
				set_game_mode(intro)
			end
		end
	end
	function m:draw()
		game:draw()
		print("race complete!",40,44,7)

		print("time: "..format_time(game.time),35,70,7)
		print("best: "..format_time(game.best_time),35,78,game.best_time == game.time and frame%4<2 and 8 or 7)
		if game.previous_best then
			print("previous: "..format_time(game.previous_best),30,86,7)
		end

		print("retry",44,102,self.selected == 1 and frame%16<8 and 8 or 6)
		print("exit",44,110,self.selected == 2 and frame%16<8 and 8 or 6)
	end
	return m
end


function displace_point(p,ox,oy,factor)
	return vec(p.x+(p.x-ox)*factor,p.y+(p.y-oy)*factor)
end

function displace_line(a,b,ox,oy,factor,col)
	a = displace_point(a,ox,oy,factor)
	b = displace_point(b,ox,oy,factor)
	line(a.x,a.y,b.x,b.y,col)
end

function linevec(a,b,col)
	line(a.x,a.y,b.x,b.y,col)
end

-- util

function fmap(objs,func)
	local ret = {}
	for i in all(objs) do
		add(ret,func(i))
	end
	return ret
end

function clamp(val,lower,upper)
	return max(lower,min(upper,val))
end

function format_number(n)
	if n < 10 then return "0"..flr(n) end
	return n
end

function format_time(t)
	return format_number(flr(t))..":"..format_number(flr((t-flr(t))*60))
end

function printr(text,x,y,c)
	local l = #text
	print(text,x-l*4,y,c)
end

function dot(a,b)
	return a.x*b.x + a.y*b.y
end

function onscreen(p,cx,cy)
	local x = p.x
	local y = p.y
	return x >= cx - 20 and x <= cx+128+20 and y >= cy-20 and y <= cy+128+20
end

function length(v)
	return mysqrt(v.x*v.x+v.y*v.y)
end

function scalev(v,s)
	return vec(v.x*s,v.y*s)
end

function normalize(v)
	local len = length(v)
	return vec(v.x/len,v.y/len)
end

function side_of_line(v1,v2,px,py)
	return (px - v1.x) * (v2.y - v1.y) - (py - v1.y)*(v2.x - v1.x)
end

function get_vec_from_vecmap(seg)
	if seg > mapsize-1 then
		seg = mapsize-1
	end
	local i = ((seg-1)*4)+1
	local v = {x=vecmap[i],y=vecmap[i+1],w=vecmap[i+2],dir=vecmap[i+3]}
	return v
end

function get_segment(seg,enlarge)
	-- returns the 4 points of the segment
	if seg == nil or seg < 1 or seg > 999 then return nil end
	local lastlastv = get_vec_from_vecmap(seg-1)
	lastlastv = lastlastv or {}
	local v = get_vec_from_vecmap(seg+1)
	if not v then return nil end
	local lastv = get_vec_from_vecmap(seg) or v

	local perp = normalize({x=v.x-(lastv.x or 0),y=v.y-(lastv.y or 0)})
	local lastperp = normalize({x=lastv.x-(lastlastv.x or 0),y=lastv.y-(lastlastv.y or 0)})
	local lastw = enlarge and lastv.w*2.5 or lastv.w
	local w = enlarge and v.w*2.5 or v.w
	local a = vec(v.x-perp.y*w,v.y+perp.x*w)
	local b = vec(v.x+perp.y*w,v.y-perp.x*w)
	local c = vec(lastv.x+lastperp.y*lastw,lastv.y-lastperp.x*lastw)
	local d = vec(lastv.x-lastperp.y*lastw,lastv.y+lastperp.x*lastw)
	return {a,b,c,d}
end

function perpendicular(v)
	return { x=v.y,y=-v.x }
end

function vecdiff(a,b)
	return { x=a.x-b.x, y=a.y-b.y }
end

function midpoint(a,b)
	return { x=(a.x+b.x)/2, y=(a.y+b.y)/2 }
end

function get_normal(a,b)
	return normalize(perpendicular(vecdiff(a,b)))
end

function distance(a,b)
	return mysqrt(distance2(a,b))
end

function distance2(a,b)
	local d = vecdiff(a,b)
	return d.x*d.x+d.y*d.y
end

function distance_from_line2(p,v,w)
	local l2 = distance2(v,w)
	if (l2 == 0) then return distance2(p, v) end
	local t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
	if t < 0 then return distance2(p, v)
	elseif t > 1 then return distance2(p, w)
	end
	return distance2(p, { x=v.x + t * (w.x - v.x),
	                  y=v.y + t * (w.y - v.y) })
end

function distance_from_line(p,v,w)
	return mysqrt(distance_from_line2(p,v,w))
end

function vecinv(v)
	return { x=-v.x, y=-v.y }
end

function point_in_polygon(pgon, t)
	local tx,ty = t.x,t.y
	local i, yflag0, yflag1, inside_flag
	local vtx0, vtx1

	local numverts = #pgon

	vtx0 = pgon[numverts]
	vtx1 = pgon[1]

	-- get test bit for above/below x axis
	yflag0 = ( vtx0.y >= ty )
	inside_flag = false

	for i=2,numverts+1 do
		yflag1=(vtx1.y>=ty)

		if yflag0 != yflag1 then
			if ((vtx1.y - ty) * (vtx0.x - vtx1.x) >= (vtx1.x - tx) * (vtx0.y - vtx1.y)) == yflag1 then
				inside_flag = not inside_flag
			end
		end

		-- move to the next pair of vertices, retaining info as possible.
		yflag0  = yflag1
		vtx0    = vtx1
		vtx1    = pgon[i]
	end

	return  inside_flag
end

function check_collision(points,lines)
	for point in all(points) do
		for line in all(lines) do
			if side_of_line(line[1],line[2],point.x,point.y) < 0 then
				local rvec = get_normal(line[1],line[2])
				local penetration = distance_from_line(point,line[1],line[2])
				return rvec,penetration,point
			end
		end
	end
	return nil
end

function lerp(a,b,t)
	return (1-t)*a+t*b
end
function lerpv(a,b,t)
	return vec(lerp(a.x,b.x,t),lerp(a.y,b.y,t))
end

function draw_arrow(p,size,dir,col)
	local x,y = p.x,p.y
	local v = {rotate_point(x,y-size,dir,x,y),rotate_point(x,y+size,dir,x,y),rotate_point(x+size,y,dir,x,y)}
	for i=1,3 do
		linevec(v[i],v[(i%3)+1],col)
	end
	--line(pb.x,pb.y,pc.x,pc.y,col)
	--line(pc.x,pc.y,pa.x,pa.y,col)
end

__gfx__
00000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
00080000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
0097f000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
0a777e00dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
00b7d000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
000c0000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
00000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
00000000dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000800000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00097f0000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d00a777e000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d000b7d0000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000c00000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d0000000000ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d666666d666d66666d666666d66ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d666666d666d66666d666666d66ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66dd66d666d66dddd66dd66dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d666666d666d66dddd66dd66dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d666666d666d66666d666666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d66ddddd666d66666d666666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d888888d888888d88888d88888d888888d99999d999999d99ddddd99999d99dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d888888d888888d88888d88888d888888d99999d999999d99ddddd99999d99dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88dd88d88dd88d88dddd88dddd88dd88dddd99d99dd99d99ddddd99d99ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88dd88d888888d88dddd8888dd88dd88d99999d99dd99d99999d999999ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88888dd888888d88dddd8888dd88888dd99999d99dd99d99999d999999ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88888dd88dd88d88dddd88dddd88888dd99dddd99dd99ddd99dd999d99ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88dd88d88dd88d88888d88888d88dd88d999999999999ddd99dd999999ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d88dd88d88dd88d88888d88888d88dd88d999999999999ddd99dd999999ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
d666666666666666666666666666666666666666666666666666666ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddd6ddddddd6ddddddddddddd6ddddddd6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddd6ddddddd6ddddddddddddddd6ddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddd6dddddd6ddddddddddddddddd6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddd6dddddd6ddddddddddddddddd6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddd6dddddd6ddddddddddddddddd6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
66666666666666666666666666666666ddd6d6666666d6d6d6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddd66dd6d6ddddd6d6d6d6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddddd666d6ddddd6d6d6d6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddddddd6d6ddddd6666666666666666666666666666666666666666666666666666666666666666666666666666666666666
dddddddddddddddddd6dddddddddddddddd6d6ddddd6d6d6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddddddd6d6666666d6d6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddddddd66dddddddd6d6dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddddddd66666666666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddddddddddddd6ddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddddd6dddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddddddddddd6ddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddddd6dddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddddddddd6ddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddddd6dddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddddddd6ddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddddd6dddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddddd6ddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddddd6dddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddd6ddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dddd6dddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddd6ddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6dd6dddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6d6ddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd66dddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddd6ddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
666666666666666666666666666666666666666666666666666666dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddd6dddddddddddddddddddddddddddddddddddddddddddd9999999999999999999999999999999999999999999
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddddd99999979999999777999999999999999999999999999
dddddddddddddddddddddddddddddddddddddddd6dddddddddddddddddddddddddddddddddddddddddd999979799777799799799999999999999999999999999
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddddd9999977999999799799799999999999999999999999999
dddddddddddddddddddddddddddddddddddddddd6dddddddddddddddddddddddddddddddddddddddd99999979999999797999979999999999999999999999999
dddddddddddddddddddddddddddddddddddddddd6ddddddddddddddddddddddddddddddddddddddd999999977779777797999979999999999999999999999999
999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999a999999999a9a999999999aa999a99999a999a
999999999999999999999999999999999999999999999999999999999999999999999999999999999999999a9a99aaaa9a9a99a9999999999aa999a9999aaaa9
989888889888988998889898989888889988888888999999999999999999999999999999999999999999999aa999999a9aa999a99a9aaaa9999a9999aa9a9a99
989898989898988898989898999888889986666668999999999999999999999999999999999999999999999a9999999a9a9999a9a999999999a9999a99999a99
989899989888989898989989999888889986666688999999999999999999999999999999999999999999999aaaa9aaaa9aaaa9aa99999999aa999aa9999aa999
98989998989998889888989899988888998888888899999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999998666668899999999999999999999999999999999999999999999999999999999999999999999999999999999999999
95599555955595559599595599559955998666686899999999999999999999999999999999999999999999999999999999999999999999999999999999999999
95559595955999599599595959595955998888888899999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99959595959999599595595559559959998888888899999999999999999999999999999999999999999999999999999999999999999999999999999999999999
95559555959999599555595959595955598888888899999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888866668866666666888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888888868888888866888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002525252525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002525252525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002525252525250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002525252525252502000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000002525252525252525252525252500250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000025252525250000000000000000002525002500252525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000250025000000000000000000000000000000000000252525252525252525252525252525252500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252525000000000000000000000000000000000000000000000000000000000000000000002525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000000000000000000000000000000000000000025250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000250000000000000000000000000000000000000000000000000000000000000000000000000000250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000250000000000000000000000000000000000000000000000000000000000000000000000000000002525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000250000000000000000000000000000000000000000000000000000000000000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000250000000000000000000000000000000000000000000000000000000000000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000000000000000000000000000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000000000000000000000000000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002500000000000000000000000000000000000000000000002525252500000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000000000000250000000025000000000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002500000000000000000000000000000000000000000025000000000000250000000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000000252500000000000000250000000000000000250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000025250000000000000000250000000000000000250000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000252500000000000000000000000000000000000025000000000000000000250000000000002525000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000002500000000000000000000000000000000002525000000000000000000250000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000025250000000000000000000000000000002500000000000000000025000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000250000000000000000000000000000002500000000000000002500000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000002525000000000000000000000000002500000000000000250000000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000025250000000000000000000000002500000000002525000000000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000252500000000000000000000002500000000252500000000000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000025252525000000000000002500000000250000000000000000000000002500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000250025000000000000250000000000250000000000000000000000000025000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000025000000000000250000000000002500000000000000000000000000252500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010c00080e3433e6153e6253e6150e3433e6153e6253e6150e373326030e6033e6430e373326033e6433e6430e373326030e6033e6430e373326033e6433e6430e37332603326033e6430e3730e3033e6433e643
01180020021750215502125021150e3050e3050e1550e125051750515505125051150e3050e305151551512513175131551312513115131051310511175111551112511115266050c60516175161551612516115
011800200e040020400e042020420e040020400e0420204211040050401104205042100400404010042040421304007040130420704215040090401504209042160400a04016042150420e040020400e04202042
013000200e5471d53715527135170e5472153711527135170e5472253713527115170e5471c53711527155170e5471d5371552713517135471c537115270e5170e54721537165271151715547225370e5270c517
011800201a302000001d302000001a302000001c302000001d302000001a302000001c302000001f302000001a30200000183021a302183021530221302183021a3011a3021d30221302213021f3011a30100000
010c00201a7551d75521755227551a7551d7552175526755267552475526755297552d7552b7552d75526755267551a75524755187551c7551d755217551f755267551a755267552b755297552d7552e7552d755
010c0020267751a775267751a775267751a775267751a775267751a775267751a77526775267752677526775287751c775287751c775267751a775267751a775297751f7752b7751d775267751c7752677518775
010c00201a7751a7050e7751d705117751d705117751d7051d7750000011775000001577500000157750000022775000001577500000137750000011775000001c7750000010775000000e775000000c77500000
011800100277402772027720277202772027720277202772020220202202022020220202202022020220202200000000000000000000000000000000000000000000000000000000000000000000000000000004
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000026170221701d1701917014170111700f1700c1700a1700817006170051700417003170021700117001170011000110001100051000510005100051000510005100051000410004100000000000000000
000300000117001170031700417005170061700617007170091700a1700b1700d1700f170121701517016170191701b1701d1701e17021170221701f1001f1001f1001f1001f1001f1001f1001f1001f10020100
010600080e6100e6100e6100e6100e6100e6100e6100e6100e6050e700320001a1001a100027000270002702027020270202702027020270200002000020c0020c0020c0020c002000020000200002000023c002
010600082162021620216202162021620216202162021620046020460204702047020470204702047020470200000000000000000000000000000000000000000000000000000000000000000000000000000003
0106000821120216202162021620216202162021620216203e6003e6003e6003e6003e6003e6003e6003e6003c6003c6003c6003c6003c6003c6003c6003c6003c60000600006000060000600006000060000700
000300003c67037670336603064028630196201262008610196100131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01060008211302162021130216202162021620216202162000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003c000
000300003f6603c610276100e41312600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000086000221005210092200b2300e240112401334016350132501b3601f3601826023360283601c2602d360383603e3602a250223502b340373403e3402530012300103000e3000d300243002330025600
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 41424108
01 41024001
01 41030001
01 41030001
02 63020001
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344

