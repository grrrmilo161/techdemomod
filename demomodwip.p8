pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- [initialization]
-- evercore v2.3.1

function vector(x,y)
	return {x=x,y=y}
end

function rectangle(x,y,w,h)
	return {x=x,y=y,w=w,h=h}
end

-- global tables
objects,collected={},{}
-- global timers
freeze,delay_restart,sfx_timer,music_timer,ui_timer=0,0,0,0,-99
-- global camera values
draw_x,draw_y,cam_x,cam_y,cam_spdx,cam_spdy,cam_gain=0,0,0,0,0,0,0.25

-- [entry point]

function _init()
	frames,start_game_flash=0,0
	music(40,0,7)
	lvl_id=0
end

function begin_game()
	max_djump=1
	deaths,frames,seconds_f,minutes,music_timer,time_ticking,fruit_count,bg_col,cloud_col=0,0,0,0,0,true,0,0,1
	music(0,0,7)
	load_level(1)
end

function is_title()
	return lvl_id==0
end

-- [effects]

clouds={}
for i=0,16 do
	add(clouds,{
		x=rnd"128",
		y=rnd"128",
		spd=1+rnd"4",
	w=32+rnd"32"})
end

particles={}
for i=0,24 do
	add(particles,{
		x=rnd"128",
		y=rnd"128",
		s=flr(rnd"1.25"),
		spd=0.25+rnd"5",
		off=rnd(),
		c=6+rnd"2",
	})
end

dead_particles={}

-- [function library]

function psfx(num)
	if sfx_timer<=0 then
		sfx(num)
	end
end

function round(x)
	return flr(x+0.5)
end

function appr(val,target,amount)
	return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
	return v~=0 and sgn(v) or 0
end

function two_digit_str(x)
	return x<10 and "0"..x or x
end

function tile_at(x,y)
	return mget(lvl_x+x,lvl_y+y)
end

function spikes_at(x1,y1,x2,y2,xspd,yspd)
	for i=max(0,x1\8),min(lvl_w-1,x2/8) do
		for j=max(0,y1\8),min(lvl_h-1,y2/8) do
			if({[17]=y2%8>=6 and yspd>=0,
			[27]=y1%8<=2 and yspd<=0,
			[43]=x1%8<=2 and xspd<=0,
			[59]=x2%8>=6 and xspd>=0})[tile_at(i,j)] then
				return true
			end
		end
	end
end
-->8
-- [update loop]

function _update()
	frames+=1
	if time_ticking then
		seconds_f+=1
		minutes+=seconds_f\1800
		seconds_f%=1800
	end
	frames%=30

	if music_timer>0 then
		music_timer-=1
		if music_timer<=0 then
			music(10,0,7)
		end
	end

	if sfx_timer>0 then
		sfx_timer-=1
	end

	-- cancel if freeze
	if freeze>0 then
		freeze-=1
		return
	end

	-- restart (soon)
	if delay_restart>0 then
		cam_spdx,cam_spdy=0,0
		delay_restart-=1
		if delay_restart==0 then
			load_level(lvl_id)
		end
	end

	-- update each object
	foreach(objects,function(obj)
		obj.move(obj.spd.x,obj.spd.y,0);
		(obj.type.update or stat)(obj)
	end)

	-- move camera to player
	foreach(objects,function(obj)
		if obj.type==player or obj.type==player_spawn then
			move_camera(obj)
		end
	end)

	-- start game
	if is_title() then
		if start_game then
			start_game_flash-=1
			if start_game_flash<=-30 then
				begin_game()
			end
		elseif btn(🅾️) or btn(❎) then
			music"-1"
			start_game_flash,start_game=50,true
			sfx"38"
		end
	end
end
-->8
-- [draw loop]

function _draw()
	if freeze>0 then
		return
	end

	-- reset all palette values
	pal()

	-- start game flash
	if is_title() then
		if start_game then
			for i=1,15 do
				pal(i, start_game_flash<=10 and ceil(max(start_game_flash)/5) or frames%10<5 and 7 or i)
			end
		end

		cls()

		-- credits
		sspr(unpack(split"72,32,56,32,36,32"))
		?"🅾️/❎",55,80,5
		?"maddy thorson",40,96,5
		?"noel berry",46,102,5

		-- particles
		foreach(particles,draw_particle)

		return
	end

	-- draw bg color
	cls(flash_bg and frames/5 or bg_col)

	-- bg clouds effect
	foreach(clouds,function(c)
		c.x+=c.spd-cam_spdx
		rectfill(c.x,c.y,c.x+c.w,c.y+16-c.w*0.1875,cloud_col)
		if c.x>128 then
			c.x=-c.w
			c.y=rnd"120"
		end
	end)

	-- set cam draw position
	draw_x=round(cam_x)-64
	draw_y=round(cam_y)-64
	camera(draw_x,draw_y)

	-- draw bg terrain
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,4)
	
	-- set draw layering
	-- positive layers draw after player
	-- layer 0 draws before player, after terrain
	-- negative layers draw before terrain
	local pre_draw,post_draw={},{}
	foreach(objects,function(obj)
		local draw_grp=obj.layer<0 and pre_draw or post_draw
		for k,v in ipairs(draw_grp) do
			if obj.layer<=v.layer then
				add(draw_grp,obj,k)
				return
			end
		end
		add(draw_grp,obj)
	end)

	-- draw bg objects
	foreach(pre_draw,draw_object)
	
	-- draw terrain
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,2)
	
	-- draw fg objects
	foreach(post_draw,draw_object)

	-- draw jumpthroughs
	map(lvl_x,lvl_y,0,0,lvl_w,lvl_h,8)

	-- particles
	foreach(particles,draw_particle)

	-- dead particles
	foreach(dead_particles,function(p)
		p.x+=p.dx
		p.y+=p.dy
		p.t-=0.2
		if p.t<=0 then
			del(dead_particles,p)
		end
		rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
	end)

	-- draw level title
	camera()
	if ui_timer>=-30 then
		if ui_timer<0 then
			draw_ui()
		end
		ui_timer-=1
	end
end

function draw_particle(p)
	p.x+=p.spd-cam_spdx
	p.y+=sin(p.off)-cam_spdy
	p.off+=min(0.05,p.spd/32)
	rectfill(p.x+draw_x,p.y%128+draw_y,p.x+p.s+draw_x,p.y%128+p.s+draw_y,p.c)
	if p.x>132 then
		p.x=-4
		p.y=rnd"128"
	elseif p.x<-4 then
		p.x=128
		p.y=rnd"128"
	end
end

function draw_time(x,y)
	rectfill(x,y,x+44,y+6,0)
	?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds_f\30).."."..two_digit_str(round(seconds_f%30*100/30)),x+1,y+1,7
end

function draw_ui()
	rectfill(24,58,104,70,0)
	local title=lvl_title or lvl_id.."00 m"
	?title,64-#title*2,62,7
	draw_time(4,4)
end
-->8
-- [player class]

player={
	init=function(this)
		this.upsidedown=false
		this.grace,this.jbuffer=0,0
		this.djump=max_djump
		this.dash_time,this.dash_effect_time=0,0
		this.dash_target_x,this.dash_target_y=0,0
		this.dash_accel_x,this.dash_accel_y=0,0
		this.hitbox=rectangle(1,3,6,5)
		this.spr_off=0
		this.collides=true
		create_hair(this)
		this.layer=1
	end,
	update=function(this)
		if pause_player then
			return
		end

		if this.upsidedown then		
			this.hitbox=rectangle(1,0,6,8)
		else
			this.hitbox=rectangle(1,3,6,5)
		end

		--store level exit props
		levelprops = {
			{id=0,right=true},
			{id=1,up=true},
			{id=2,right=true}
		}


		-- horizontal input
		local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0

		-- spike collision / bottom death
		if spikes_at(this.left(),this.top(),this.right(),this.bottom(),this.spd.x,this.spd.y) or this.y>lvl_ph or ((not levelprops[lvl_id].up) and this.y < -4) then
			kill_player(this)
		end

		
		-- on ground checks
		--if not this.upsidedown then
			local on_ground=this.is_solid(0,1)
		--else
		--	local on_ground=this.is_solid(0,-1)
		--end

		if this.upsidedown then
			on_ground=this.is_solid(0,-1)
		end

		-- landing smoke
		if on_ground and not this.was_on_ground then
			this.init_smoke(0,4)
		end

		-- jump and dash input
		local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
		this.p_jump,this.p_dash=btn(🅾️),btn(❎)

		-- jump buffer
		if jump then
			this.jbuffer=4
		elseif this.jbuffer>0 then
			this.jbuffer-=1
		end

		-- grace frames and dash restoration
		if on_ground then
			this.grace=6
			if this.djump<max_djump then
				psfx"54"
				this.djump=max_djump
			end
		elseif this.grace>0 then
			this.grace-=1
		end

		-- dash effect timer (for dash-triggered events, e.g., berry blocks)
		this.dash_effect_time-=1

		-- dash startup period, accel toward dash target speed
		if this.dash_time>0 then
			this.init_smoke()
			this.dash_time-=1
			this.spd=vector(appr(this.spd.x,this.dash_target_x,this.dash_accel_x),appr(this.spd.y,this.dash_target_y,this.dash_accel_y))
		else
			-- x movement
			local maxrun=1
			local accel=this.is_ice(0,1) and 0.05 or on_ground and 0.6 or 0.4
			local deccel=0.15

			-- set x speed
			this.spd.x=abs(this.spd.x)<=1 and
			appr(this.spd.x,h_input*maxrun,accel) or
			appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)

			-- facing direction
			if this.spd.x~=0 then
				this.flip.x=this.spd.x<0
			end

			-- flipping upsidedown
			this.flip.y=this.upsidedown

			-- y movement
			local maxfall=2

			-- wall slide
			if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
				maxfall=0.4
				-- wall slide smoke
				if rnd"10"<2 then
					this.init_smoke(h_input*6)
				end
			end

			-- apply gravity
			if not on_ground then
			    local grav = this.upsidedown and -1 or 1 -- flips gravity
			    this.spd.y = appr(this.spd.y, grav * maxfall, abs(this.spd.y) > 0.15 and 0.21 or 0.105)
			end

			-- jump
			if this.jbuffer > 0 then
			    if this.grace > 0 then
			        -- normal jump
			        psfx"1"
			        this.jbuffer = 0
			        this.grace = 0
			        -- flip vertical jump speed based on upside-down
			        this.spd.y = this.upsidedown and 2 or -2
			        this.init_smoke(0, 4)
			    else
			        -- wall jump
			        local wall_dir = (this.is_solid(-3, 0) and -1 or this.is_solid(3, 0) and 1 or 0)
			        if wall_dir ~= 0 then
			            psfx"2"
			            this.jbuffer = 0
			            -- wall jump, flip vertical speed based on upside-down
			            this.spd = vector(wall_dir * (-1 - maxrun), this.upsidedown and 2 or -2)
			            if not this.is_ice(wall_dir * 3, 0) then
			                -- wall jump smoke
			                this.init_smoke(wall_dir * 6)
			            end
			        end
			    end
			end

			-- dash
			local d_full = 5
			local d_half = 3.5355339059 -- 5 * sqrt(2)

			if this.djump > 0 and dash then
			    this.init_smoke()
			    this.djump -= 1
			    this.dash_time = 4
			    has_dashed = true
			    this.dash_effect_time = 10
			    -- vertical input
			    local v_input = btn(⬆️) and -1 or btn(⬇️) and  1 or 0
			    -- calculate dash speeds
			    this.spd = vector(
			        h_input ~= 0 and
			            h_input * (v_input ~= 0 and d_half or d_full) or
			            (v_input ~= 0 and 0 or (this.flip.x and -1 or 1)),
			        v_input ~= 0 and v_input * (h_input ~= 0 and d_half or d_full) or 0
			    )
			    -- effects
			    psfx"3"
			    freeze = 2
			    -- dash target speeds and accels
			    this.dash_target_x = 2 * sign(this.spd.x)
			    this.dash_target_y = (this.spd.y >= 0 and (this.upsidedown and 1.5 or 2) or (this.upsidedown and 2 or 1.5)) * sign(this.spd.y)
			    this.dash_accel_x = this.spd.y == 0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
			    this.dash_accel_y = this.spd.x == 0 and 1.5 or 1.06066017177
			elseif this.djump <= 0 and dash then
			    -- failed dash smoke
			    psfx"9"
			    this.init_smoke()
			end

		end


		-- animation
		this.spr_off+=0.25
		this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or	-- wall slide or mid air
		btn(⬇️) and 6 or -- crouch
		btn(⬆️) and 7 or -- look up
		this.spd.x~=0 and h_input~=0 and 1+this.spr_off%4 or 1 -- walk or stand


		-- exit level off the top (except summit)
		if levelprops[lvl_id].right then
			if this.x>(lvl_pw-6) and levels[lvl_id + 1] then
				next_level()
			end
		elseif levelprops[lvl_id].left then
			if this.x<0 and levels[lvl_id + 1] then
				next_level()
			end
		elseif levelprops[lvl_id].up then
			if this.y < -4 and levels[lvl_id + 1] then
				next_level()
			end
		end


		-- was on the ground
		this.was_on_ground=on_ground
		flipped = this.upsidedown
	end,

	draw=function(this)
		-- clamp in screen
		local clamped=mid(this.x,-1,lvl_pw-7)
		if this.x~=clamped then
			this.x=clamped
			this.spd.x=0
		end
		-- draw player hair and sprite
		set_hair_color(this.djump)
		set_shirt_color(this.upsidedown)
		draw_hair(this)
		draw_obj_sprite(this)
		pal()
	end
}

function create_hair(obj)
	obj.hair={}
	for i=1,5 do
		add(obj.hair,vector(obj.x,obj.y))
	end
end

function set_hair_color(djump)
	pal(8,djump==1 and 8 or djump==2 and 7+frames\3%2*4 or 12)
end

function set_shirt_color(upsidedown)
	pal(3,not upsidedown and 3 or upsidedown and 2)
end

function draw_hair(obj)
	local last=vector(obj.x+(obj.flip.x and 6 or 2),obj.y+(btn(⬇️) and 4 or 3))
	for i,h in ipairs(obj.hair) do
		h.x+=(last.x-h.x)/1.5
		h.y+=(last.y+0.5-h.y)/1.5
		circfill(h.x,h.y,mid(4-i,1,2),8)
		last=h
	end
end

function kill_player(obj)
	sfx_timer=12
	sfx"0"
	deaths+=1
	destroy_object(obj)
	for dir=0,0.875,0.125 do
		add(dead_particles,{
			x=obj.x+4,
			y=obj.y+4,
			t=2,
			dx=sin(dir)*3,
			dy=cos(dir)*3
		})
	end
	delay_restart=15
end

player_spawn={
	init=function(this)
		sfx"4"
		this.spr=3
		this.target=this.y
		this.y=min(this.y+48,lvl_ph)
		cam_x,cam_y=mid(this.x+4,64,lvl_pw-64),mid(this.y,64,lvl_ph-64)
		this.spd.y=-4
		this.state=0
		this.delay=0
		create_hair(this)
		this.djump=max_djump
		
		this.layer=1
	end,
	update=function(this)
		-- jumping up
		if this.state==0 and this.y<this.target+16 then
			this.state=1
			this.delay=3
			-- falling
		elseif this.state==1 then
			this.spd.y+=0.5
			if this.spd.y>0 then
				if this.delay>0 then
					-- stall at peak
					this.spd.y=0
					this.delay-=1
				elseif this.y>this.target then
					-- clamp at target y
					this.y=this.target
					this.spd=vector(0,0)
					this.state=2
					this.delay=5
					this.init_smoke(0,4)
					sfx"5"
				end
			end
			-- landing and spawning player object
		elseif this.state==2 then
			this.delay-=1
			this.spr=6
			if this.delay<0 then
				destroy_object(this)
				init_object(player,this.x,this.y)
			end
		end
	end,
	draw= player.draw
}
-->8
-- [objects]

greenblock={
	init=function(this)
		this.solid_obj=true
	end,
	update=function(this)
		if flipped then
			this.solid_obj=false
			this.spr=81
		else
			this.solid_obj=true
			this.spr=60
		end
	end,
	draw=function(this)
		if this.spr==60 or this.spr==81 then
			draw_obj_sprite(this)
		end
	end
}


redblock={
	init=function(this)
		this.solid_obj=false
	end,
	update=function(this)
		if not flipped then
			this.solid_obj=false
			this.spr=65
		else
			this.solid_obj=true
			this.spr=44
		end
	end,
	draw=function(this)
		if this.spr==44 or this.spr==65 then
			draw_obj_sprite(this)
		end
	end
}


flipside={
	init=function(this)
		this.show=true
		this.layer=1
		this.respawncycle=60
		this.respawncounter=0
	end,
	update=function(this)
		local hit=this.player_here()

		if not this.show then
			this.respawncounter+=1
			if this.respawncounter == this.respawncycle then
				this.show=true
				this.respawncounter=0
				this.init_smoke()
			end
		end

		if hit and this.show and not hit.upsidedown then
			hit.upsidedown=true
			this.init_smoke()
			this.show=false
		end
	end,
	draw=function(this)
		if this.spr==21 and this.show then
			draw_obj_sprite(this)
		end
	end
}

flipback={
	init=function(this)
		this.show=true
		this.layer=1
		this.respawncycle=60
		this.respawncounter=0
	end,
	update=function(this)
		local hit=this.player_here()

		if not this.show then
			this.respawncounter+=1
			if this.respawncounter == this.respawncycle then
				this.show=true
				this.respawncounter=0
				this.init_smoke()
			end
		end

		if hit and this.show and hit.upsidedown then
			hit.upsidedown=false
			this.init_smoke()
			this.show=false
		end
	end,
	draw=function(this)
		if this.spr==28 and this.show then
			draw_obj_sprite(this)
		end
	end
}


spring = {
    init = function(this)
        this.delta = 0
        this.dir = this.spr == 18 and 0 or this.is_solid(-1, 0) and 1 or -1
        this.show = true
        this.layer = -1
    end,

    update = function(this)
        this.delta = this.delta * 0.75
        local hit = this.player_here()
        
        if this.show and hit and this.delta <= 1 then
            if this.dir == 0 then
                -- For the center spring (dir == 0)
                hit.move(0, this.y - hit.y - 4, 1)
                if hit.upsidedown then
                    -- If upside down, adjust vertical trajectory
                    hit.spd.x *= 0.2
                    hit.spd.y = 3  -- Downward movement when upside down
                else
                    hit.spd.x *= 0.2
                    hit.spd.y = -3  -- Upward movement when upright
                end
            else
                -- For the side spring (dir == 1 or -1)
                hit.move(this.x + this.dir * 4 - hit.x, 0, 1)
                if hit.upsidedown then
                    -- If upside down, reverse the trajectory
                    hit.spd = vector(this.dir * 3, 1.5)  -- Downward when upside down
                else
                    hit.spd = vector(this.dir * 3, -1.5)  -- Upward when upright
                end
            end

            hit.dash_time = 0
            hit.dash_effect_time = 0
            hit.djump = max_djump
            this.delta = 8
            psfx"8"
            this.init_smoke()

            break_fall_floor(this.check(fall_floor, -this.dir, this.dir == 0 and 1 or 0))
        end
    end,

    draw = function(this)
        if this.show then
            local delta = min(flr(this.delta), 4)
            if this.dir == 0 then
                sspr(16, 8, 8, 8, this.x, this.y + delta)
            else
                spr(19, this.dir == -1 and this.x + delta or this.x, this.y, 1 - delta / 8, 1, this.dir == 1)
            end
        end
    end
}


fall_floor={
	init=function(this)
		this.solid_obj=true
		this.state=0
	end,
	update=function(this)
		-- idling
		if this.state==0 then
			for i=0,2 do
				if this.check(player,i-1,-(i%2)) then
					break_fall_floor(this)
				end
			end
		-- shaking
		elseif this.state==1 then
			this.delay-=1
			if this.delay<=0 then
				this.state=2
				this.delay=60 -- how long it hides for
				this.collideable=false
				set_springs(this,false)
			end
			-- invisible, waiting to reset
		elseif this.state==2 then
			this.delay-=1
			if this.delay<=0 and not this.player_here() then
				psfx"7"
				this.state=0
				this.collideable=true
				this.init_smoke()
				set_springs(this,true)
			end
		end
	end,
	draw=function(this)
		if this.state~=2 then
			spr(this.state==1 and 26-this.delay/5 or 23,this.x,this.y)
		end
	end,
}

function break_fall_floor(obj)
	if obj and obj.state==0 then
		psfx"15"
		obj.state=1
		obj.delay=15 -- time until it falls
		obj.init_smoke()
	end
end

function set_springs(obj,state)
	obj.hitbox=rectangle(-2,-2,12,8)
	local springs=obj.check_all(spring,0,0)
	foreach(springs,function(s) s.show=state end)
	obj.hitbox=rectangle(0,0,8,8)
end

balloon={
	init=function(this)
		this.offset=rnd()
		this.start=this.y
		this.timer=0
		this.hitbox=rectangle(-1,-1,10,10)
	end,
	update=function(this)
		if this.spr==22 then
			this.offset+=0.01
			this.y=this.start+sin(this.offset)*2
			local hit=this.player_here()
			if hit and hit.djump<max_djump then
				psfx"6"
				this.init_smoke()
				hit.djump=max_djump
				this.spr=0
				this.timer=60
			end
		elseif this.timer>0 then
			this.timer-=1
		else
			psfx"7"
			this.init_smoke()
			this.spr=22
		end
	end,
	draw=function(this)
		if this.spr==22 then
			for i=7,13 do
				pset(this.x+4+sin(this.offset*2+i/10),this.y+i,6)
			end
			draw_obj_sprite(this)
		end
	end
}

smoke={
	init=function(this)
		this.spd=vector(0.3+rnd"0.2",-0.1)
		this.x+=-1+rnd"2"
		this.y+=-1+rnd"2"
		this.flip=vector(rnd()<0.5,rnd()<0.5)
		this.layer=3
	end,
	update=function(this)
		this.spr+=0.2
		if this.spr>=32 then
			destroy_object(this)
		end
	end
}

fruit={
	is_fruit=true,
	init=function(this)
		this.start=this.y
		this.off=0
	end,
	update=function(this)
		check_fruit(this)
		this.off+=0.025
		this.y=this.start+sin(this.off)*2.5
	end
}

fly_fruit={
	is_fruit=true,
	init=function(this)
		this.start=this.y
		this.step=0.5
		this.sfx_delay=8
	end,
	update=function(this)
		-- fly away
		if has_dashed then
			if this.sfx_delay>0 then
				this.sfx_delay-=1
				if this.sfx_delay<=0 then
					sfx_timer=20
					sfx"14"
				end
			end
			this.spd.y=appr(this.spd.y,-3.5,0.25)
			if this.y<-16 then
				destroy_object(this)
			end
			-- wait
		else
			this.step+=0.05
			this.spd.y=sin(this.step)*0.5
		end
		-- collect
		check_fruit(this)
	end,
	draw=function(this)
		spr(26,this.x,this.y)
		for ox=-6,6,12 do
			spr((has_dashed or sin(this.step)>=0) and 45 or this.y>this.start and 47 or 46,this.x+ox,this.y-2,1,1,ox==-6)
		end
	end
}

function check_fruit(this)
	local hit=this.player_here()
	if hit then
		hit.djump=max_djump
		sfx_timer=20
		sfx"13"
		collected[this.id]=true
		init_object(lifeup,this.x,this.y)
		destroy_object(this)
		if time_ticking then
			fruit_count+=1
		end
	end
end

lifeup={
	init=function(this)
		this.spd.y=-0.25
		this.duration=30
		this.flash=0
	end,
	update=function(this)
		this.duration-=1
		if this.duration<=0 then
			destroy_object(this)
		end
	end,
	draw=function(this)
		this.flash+=0.5
		?"1000",this.x-4,this.y-4,7+this.flash%2
	end
}

fake_wall={
	is_fruit=true,
	init=function(this)
		this.solid_obj=true
		this.hitbox=rectangle(0,0,16,16)
	end,
	update=function(this)
		this.hitbox=rectangle(-1,-1,18,18)
		local hit=this.player_here()
		if hit and hit.dash_effect_time>0 then
			hit.spd=vector(sign(hit.spd.x)*-1.5,-1.5)
			hit.dash_time=-1
			for ox=0,8,8 do
				for oy=0,8,8 do
					this.init_smoke(ox,oy)
				end
			end
			init_fruit(this,4,4)
		end
		this.hitbox=rectangle(0,0,16,16)
	end,
	draw=function(this)
		sspr(0,32,8,16,this.x,this.y)
		sspr(0,32,8,16,this.x+8,this.y,8,16,true,true)
	end
}

function init_fruit(this,ox,oy)
	sfx_timer=20
	sfx"16"
	init_object(fruit,this.x+ox,this.y+oy,26).id=this.id
	destroy_object(this)
end

key={
	update=function(this)
		this.spr=flr(9.5+sin(frames/30))
		if frames==18 then -- if spr==10 and previous spr~=10
			this.flip.x=not this.flip.x
		end
		if this.player_here() then
			sfx"23"
			sfx_timer=10
			destroy_object(this)
			has_key=true
		end
	end
}

chest={
	is_fruit=true,
	init=function(this)
		this.x-=4
		this.start=this.x
		this.timer=20
	end,
	update=function(this)
		if has_key then
			this.timer-=1
			this.x=this.start-1+rnd"3"
			if this.timer<=0 then
				init_fruit(this,0,-4)
			end
		end
	end
}

platform={
	init=function(this)
		this.x-=4
		this.hitbox.w=16
		this.dir=this.spr==11 and -1 or 1
		this.semisolid_obj=true
		
		this.layer=2
	end,
	update=function(this)
		this.spd.x=this.dir*0.65
		-- screenwrap
		if this.x<-16 then
			this.x=lvl_pw
		elseif this.x>lvl_pw then
			this.x=-16
		end
	end,
	draw=function(this)
		spr(11,this.x,this.y-1,2,1)
	end
}

message={
	init=function(this)
		this.text="-- celeste mountain --#this memorial to those#perished on the climb"
		this.hitbox.x+=4
		this.layer=4
	end,
	draw=function(this)
		if this.player_here() then
			for i,s in ipairs(split(this.text,"#")) do
				camera()
				rectfill(7,7*i,120,7*i+6,7)
				?s,64-#s*2,7*i+1,0
				camera(draw_x,draw_y)
			end
		end
	end
}

big_chest={
	init=function(this)
		this.state=max_djump>1 and 2 or 0
		this.hitbox.w=16
	end,
	update=function(this)
		if this.state==0 then
			local hit=this.check(player,0,8)
			if hit and hit.is_solid(0,1) then
				music(-1,500,7)
				sfx"37"
				pause_player=true
				hit.spd=vector(0,0)
				this.state=1
				this.init_smoke()
				this.init_smoke(8)
				this.timer=60
				this.particles={}
			end
		elseif this.state==1 then
			this.timer-=1
			flash_bg=true
			if this.timer<=45 and #this.particles<50 then
				add(this.particles,{
					x=1+rnd"14",
					y=0,
					h=32+rnd"32",
				spd=8+rnd"8"})
			end
			if this.timer<0 then
				this.state=2
				this.particles={}
				flash_bg,bg_col,cloud_col=false,2,14
				init_object(orb,this.x+4,this.y+4,102)
				pause_player=false
			end
		end
	end,
	draw=function(this)
		if this.state==0 then
			draw_obj_sprite(this)
			spr(96,this.x+8,this.y,1,1,true)
		elseif this.state==1 then
			foreach(this.particles,function(p)
				p.y+=p.spd
				line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
			end)
		end
		spr(112,this.x,this.y+8)
		spr(112,this.x+8,this.y+8,1,1,true)
	end
}

orb={
	init=function(this)
		this.spd.y=-4
	end,
	update=function(this)
		this.spd.y=appr(this.spd.y,0,0.5)
		local hit=this.player_here()
		if this.spd.y==0 and hit then
			music_timer=45
			sfx"51"
			freeze=10
			destroy_object(this)
			max_djump=2
			hit.djump=2
		end
	end,
	draw=function(this)
		draw_obj_sprite(this)
		for i=0,0.875,0.125 do
			circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
		end
	end
}

flag={
	init=function(this)
		this.x+=5
	end,
	update=function(this)
		if not this.show and this.player_here() then
			sfx"55"
			sfx_timer,this.show,time_ticking=30,true,false
		end
	end,
	draw=function(this)
		spr(118+frames/5%3,this.x,this.y)
		if this.show then
			camera()
			rectfill(32,2,96,31,0)
			spr(26,55,6)
			?"x"..two_digit_str(fruit_count),64,9,7
			draw_time(43,16)
			?"deaths:"..two_digit_str(deaths),48,24,7
			camera(draw_x,draw_y)
		end
	end
}

-- [object class]

function init_object(type,x,y,tile)
	-- generate and check berry id
	local id=x..":"..y..":"..lvl_id
	if type.is_fruit and collected[id] then
		return
	end

	local obj={
		type=type,
		collideable=true,
		-- collides=false,
		spr=tile,
		flip=vector(),
		x=x,
		y=y,
		hitbox=rectangle(0,0,8,8),
		spd=vector(0,0),
		rem=vector(0,0),
		layer=0,
		id=id,
	}

	function obj.left() return obj.x+obj.hitbox.x end
	function obj.right() return obj.left()+obj.hitbox.w-1 end
	function obj.top() return obj.y+obj.hitbox.y end
	function obj.bottom() return obj.top()+obj.hitbox.h-1 end

	function obj.is_solid(ox,oy)
		for o in all(objects) do
			if o!=obj and (o.solid_obj or o.semisolid_obj and not obj.objcollide(o,ox,0) and oy>0) and obj.objcollide(o,ox,oy) then
				return true
			end
		end
		return oy>0 and not obj.is_flag(ox,0,3) and obj.is_flag(ox,oy,3) or -- jumpthrough or
		obj.is_flag(ox,oy,0) -- solid terrain
	end

	function obj.is_ice(ox,oy)
		return obj.is_flag(ox,oy,4)
	end

	function obj.is_flag(ox,oy,flag)
		for i=max(0,(obj.left()+ox)\8),min(lvl_w-1,(obj.right()+ox)/8) do
			for j=max(0,(obj.top()+oy)\8),min(lvl_h-1,(obj.bottom()+oy)/8) do
				if fget(tile_at(i,j),flag) then
					return true
				end
			end
		end
	end

	function obj.objcollide(other,ox,oy)
		return other.collideable and
		other.right()>=obj.left()+ox and
		other.bottom()>=obj.top()+oy and
		other.left()<=obj.right()+ox and
		other.top()<=obj.bottom()+oy
	end

	-- returns first object of type colliding with obj
	function obj.check(type,ox,oy)
		for other in all(objects) do
			if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
				return other
			end
		end
	end
	
	-- returns all objects of type colliding with obj
	function obj.check_all(type,ox,oy)
		local tbl={}
		for other in all(objects) do
			if other and other.type==type and other~=obj and obj.objcollide(other,ox,oy) then
				add(tbl,other)
			end
		end
		
		if #tbl>0 then return tbl end
	end

	function obj.player_here()
		return obj.check(player,0,0)
	end

	function obj.move(ox,oy,start)
		for axis in all{"x","y"} do
			obj.rem[axis]+=axis=="x" and ox or oy
			local amt=round(obj.rem[axis])
			obj.rem[axis]-=amt
			local upmoving=axis=="y" and amt<0
			local riding=not obj.player_here() and obj.check(player,0,upmoving and amt or -1)
			local movamt
			if obj.collides then
				local step=sign(amt)
				local d=axis=="x" and step or 0
				local p=obj[axis]
				for i=start,abs(amt) do
					if not obj.is_solid(d,step-d) then
						obj[axis]+=step
					else
						obj.spd[axis],obj.rem[axis]=0,0
						break
					end
				end
				movamt=obj[axis]-p -- save how many px moved to use later for solids
			else
				movamt=amt
				if (obj.solid_obj or obj.semisolid_obj) and upmoving and riding then
					movamt+=obj.top()-riding.bottom()-1
					local hamt=round(riding.spd.y+riding.rem.y)
					hamt+=sign(hamt)
					if movamt<hamt then
						riding.spd.y=max(riding.spd.y,0)
					else
						movamt=0
					end
				end
				obj[axis]+=amt
			end
			if (obj.solid_obj or obj.semisolid_obj) and obj.collideable then
				obj.collideable=false
				local hit=obj.player_here()
				if hit and obj.solid_obj then
					hit.move(axis=="x" and (amt>0 and obj.right()+1-hit.left() or amt<0 and obj.left()-hit.right()-1) or 0,
									axis=="y" and (amt>0 and obj.bottom()+1-hit.top() or amt<0 and obj.top()-hit.bottom()-1) or 0,
									1)
					if obj.player_here() then
						kill_player(hit)
					end
				elseif riding then
					riding.move(axis=="x" and movamt or 0, axis=="y" and movamt or 0,1)
				end
				obj.collideable=true
			end
		end
	end

	function obj.init_smoke(ox,oy)
		init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
	end

	add(objects,obj);

	(obj.type.init or stat)(obj)

	return obj
end

function destroy_object(obj)
	del(objects,obj)
end

function move_camera(obj)
	cam_spdx=cam_gain*(4+obj.x-cam_x)
	cam_spdy=cam_gain*(4+obj.y-cam_y)

	cam_x+=cam_spdx
	cam_y+=cam_spdy

	-- clamp camera to level boundaries
	local clamped=mid(cam_x,64,lvl_pw-64)
	if cam_x~=clamped then
		cam_spdx=0
		cam_x=clamped
	end
	clamped=mid(cam_y,64,lvl_ph-64)
	if cam_y~=clamped then
		cam_spdy=0
		cam_y=clamped
	end
end

function draw_object(obj)
	(obj.type.draw or draw_obj_sprite)(obj)
end

function draw_obj_sprite(obj)
	spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end
-->8
-- [level loading]

function next_level()
	local next_lvl=lvl_id+1

	-- check for music trigger
	if music_switches[next_lvl] then
		music(music_switches[next_lvl],500,7)
	end

	load_level(next_lvl)
end

function load_level(id)
	has_dashed,has_key= false

	-- remove existing objects
	foreach(objects,destroy_object)

	-- reset camera speed
	cam_spdx,cam_spdy=0,0

	local diff_level=lvl_id~=id

	-- set level index
	lvl_id=id

	-- set level globals
	local tbl=split(levels[lvl_id])
	for i=1,4 do
		_ENV[split"lvl_x,lvl_y,lvl_w,lvl_h"[i]]=tbl[i]*16
	end
	lvl_title=tbl[5]
	lvl_pw,lvl_ph=lvl_w*8,lvl_h*8

	-- level title setup
	ui_timer=5

	-- reload map
	if diff_level then
		reload()
		-- check for mapdata strings
		if mapdata[lvl_id] then
			replace_mapdata(lvl_x,lvl_y,lvl_w,lvl_h,mapdata[lvl_id])
		end
	end

	-- entities
	for tx=0,lvl_w-1 do
		for ty=0,lvl_h-1 do
			local tile=tile_at(tx,ty)
			if tiles[tile] then
				init_object(tiles[tile],tx*8,ty*8,tile)
			end
		end
	end
end

-- replace mapdata with hex
function replace_mapdata(x,y,w,h,data)
	for i=1,#data,2 do
		mset(x+i\2%w,y+i\2\w,"0x"..sub(data,i,i+1))
	end
end
-->8
-- [metadata]

--@begin
-- level table
-- "x,y,w,h,title"
levels={
  "0,0,1,1,",
  "0,0,1,1,",
  "0,0,1,2,"
}

-- mapdata string table
-- assigned levels will load from here instead of the map
mapdata={
  "0031323232330000000000313232322500000000000000000000000000003b2400000000000000000000000000003b240000000000000000000000001c003b2400000000000000000000000000003b2400000000000011111111000000003b2400000000003b212222232b0000003b2400000000003b242525262b0000003b2400000000003b242525262b0000003b2400000000003b242525262b0000003b2400000000003b242525262b0000003b3100001500003b242525262b000000000000000000003b242525262b000000000000000000003b242525262b000000000000010000003b242525262b0000000000222222222222252525262b0000003b21",
  "0000000031323232323232323232322500000000000000001b0000000000002400000000111100000000001111000024353535353535353522353535230000241b1b1b1b1b000000370000003000002400000000000000001b00000030000024000000000000000000001c0030000024000000001111111111000000300000240000003b2135353536000000300000240000003b301b1b1b1b000000300000240000003b3000000000000000300000240000003b3000000034353535330000240015003b3000000000000000000000240000003b3000150000000000000000240001003b30111111000000001111112422222222252222232b00003b21222225",
  "252525323232323232322525252525252532331b1b1b1b1b1b1b313225252525330000000000000000001b1b313225250000000000000000000000001b1b312500000100000000000000000000001b24222222222222222222353600000000243232323232323232331b1b0000000024000000000000001b1b00000000000024001c00000000000000000000000000310000001111111111110000000000001b0000002122222222230000000000000000000024252525252600000000000000000000242525252526000000000000000000003132252525260000000000000000000000003125252600000000000000000000001a0024252600000000000000000000111111242526000000000000000000002122222525260000001500000000000024252525252611000000000000000000312525252525231111110000000000001b2425323232252222231111110000000024331b1b1b2425252522222200000000301b000000312525252525250000000030000000001b31323232323200000000370000000000000000000000000000001b0000160000000000000000000000000000000000000000000000000000000000000000000000000000001111000000000015000000000000001121231100000000000000111111111121252523111111111111112122222222252525252222222222222225252525252525"
}

-- list of music switch triggers
-- assigned levels will start the tracks set here
music_switches={
	[2]=20,
	[3]=30
}

local __init = _init function _init() __init() begin_game() load_level(3) music(-1) end
--@end

-- tiles stack
-- assigned objects will spawn from tiles set here
tiles={}
foreach(split([[
1,player_spawn
8,key
11,platform
12,platform
18,spring
19,spring
20,chest
21,flipside
22,balloon
23,fall_floor
26,fruit
28,flipback
44,redblock
45,fly_fruit
60,greenblock
64,fake_wall
86,message
96,big_chest
118,flag
]],"\n"),function(t)
 local tile,obj=unpack(split(t))
 tiles[tile]=_ENV[obj]
end)

--[[

short on tokens?
everything below this comment
is just for grabbing data
rather than loading it
and can be safely removed!

--]]

-- copy mapdata string to clipboard
function get_mapdata(x,y,w,h)
	local reserve=""
	for i=0,w*h-1 do
		reserve..=num2hex(mget(x+i%w,y+i\w))
	end
	printh(reserve,"@clip")
end

-- convert mapdata to memory data
function num2hex(v)
	return sub(tostr(v,true),5,6)
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700494949494949494949494949
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770222222222222222222222222
000000008888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000420000000000000024000
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677004200000000000000002400
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000042000000000000000000240
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000420000000000000000000024
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000200000000000000000000002
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000000000000000000000000
555555550000000000000000000000000000000000777600008888004999999449999994499909940300b0b06665666500777600000000000000000070000000
55555555000000000000000000040000000000000777666008888880911111199111411991140919003b33006765676507776660007700000770070007000007
550000550000000000000000000950500aaaaaa077782666087888809111111991119119494004190288882067706770777b3666007770700777000000000000
55000055007000700499994000090505a998888a6782226508888880911111199494041900000044089888800700070067633665077777700770000000000000
55000055007000700050050000090505a988888a6662266508888880911111199114094994000000088889800700070066333365077777700000700000000000
55000055067706770005500000095050aaaaaaaa6662265508888880911111199111911991400499088988800000000066633655077777700000077000000000
55555555567656760050050000040000a980088a0666555000888800911111199114111991404119028888200000000006665550070777000007077007000070
55555555566656660005500000000000a988888a0055550000000000499999944999999444004994002882000000000000555500000000007000000000000000
57777775577777777777777777777775770000000000000000000077577777755555555555555555555555555500000056767675000000000000000000000000
77777777777777777777777777777777777000000000000000000777777777775555555555555550055555556670000077777776000777770000000000000000
77707777777700000777777000007777777000000000000000000777777777775555555555555500005555556777700067787777007766700000000000000000
77000077777000000007700000000777777700000000000000007777777007775555555555555000000555556660000077888276076777000000000000000000
77000077770000000000000000000077777700000000000000007777770000775555555555550000000055555500000067822277077660000777770000000000
77700777770077000000000000070077777000000000000000000777770000775555555555500000000005556670000077722776077770000777767007700000
77777777770077000000000000000077777000000000000000000777770700775555555555000000000000556777700067777777070000000700007707777770
57777775770000000000000000000077770000000000000000000077770000775555555550000000000000056660000057676765000000000000000000077777
77000077770000000000000000000077577777777777777777777775777000775555555550000000000000050000066656767675000000000000000000000000
777000777700000000000000000000777777777777777777777777777770077750555555550000000000005500077776777777760000000000ee0ee000000000
777000777700700000000000077000777777000777777777700077777770077755550055555000000000055500000766677b77770000000000eeeee000000030
77000777770000000000000007700077777000007077770000000777770007775555005555550000000055550000005577bbb37600000000000e8e00000000b0
77000777777000000007700000000777777000000077770700000777770000775555555555555000000555550000066667b333770000b00000eeeee000000b30
77700777777700000777777000007777777700077777777770007777770000775505555555555500005555550007777677733776000b000000ee3ee003000b00
77700777777777777777777777777777777777777777777777777777777007775555555555555550055555550000076667777777030b00300000b00000b0b300
77000077577777777777777777777775577777777777777777777775577777755555555555555555555555550000005557676765030330300000b00000303300
5777755706060600077777777777777777777770077777700000000000000000cccccccc00000000000000000000000000000000000000000000000000000000
7777777700000006700007770000777000007777700077770000000000000000c77ccccc00000000000000000000000000000000000000000000000000000000
7777cc776008000070cc777cccc777ccccc7770770c777070000000000000000c77cc7cc00000000000000000000000000000000000000000000000000000000
777ccccc0088820670c777cccc777ccccc777c0770777c070000000000000000cccccccc00000000000000000000000000000000000000000000000000000000
77cccccc60822200707770000777000007770007777700070002eeeeeeee2000cccccccc00000000000000000000000000000000000000000000000000000000
57cc77cc0002200677770000777000007770000777700007002eeeeeeeeee200cc7ccccc00000000000000000000000000000000000000000000000000000000
577c77cc600000007000000000000000000c000770000c0700eeeeeeeeeeee00ccccc7cc00000000000000000000000000000000000000000000000000000000
777ccccc006060607000000000000000000000077000000700e22222e2e22e00cccccccc00000000000000000000000000000000000000000000000000000000
777ccccc060606007000000000000000000000077000000700eeeeeeeeeeee0000000000000bbbbb30bb00000bb0bbbb30008888008808888800088888820000
577ccccc000000067000000c000000000000000770cc000700e22e2222e22e0000000000000bb33330b300000b30bb3333008222208208882220088822220000
57cc7ccc600b000070000000000cc0000000000770cc000700eeeeeeeeeeee0000000000000b300000b300000b30b30033000002208208800222088000000000
77cccccc00bbb30670c00000000cc00000000c0770000c0700eee222e22eee0000000000000b300000b300000b30b30033000022208208200022082000000000
777ccccc60b333007000000000000000000000077000000700eeeeeeeeeeee0055555555000b3bb3003300000330b3bb33000822008208200022082888200000
7777cc770003300670000000000000000000000770c0000700eeeeeeeeeeee005555555500033333003300000330333330008220002202200022022222200000
777777776000000070000000c0000000000000077000000700ee77eee7777e005555555500033000003300000330330000008200002202200222022000000000
57777577006060607000000000000000000000077000c007077777777777777055555555000330000033bbb30330330000002222202202288220022882220000
00000000000000007000000000000000000000077000000700777700500000000000000500033000003333330330330000000222202202222200022222220000
00aaaaaa00000000700000000000000000000007700c000707000070550000000000005500000000000000000000000000000000000000000000000000000000
0a99999900000000700000000000c000000000077000000770770007555000000000055500088000008888820880880000000bbb30bb0bbbb3000bbbbbb30000
a99aaaaa000000007000000cc0000000000000077000cc077077bb0755550000000055550008200000888822082088000000bb3330b30bb333300bb333330000
a9aaaaaa000000007000000cc0000000000c00077000cc07700bbb0755555555555555550008200000880000082082000000b30000b30bb003330b3000000000
a99999990000000070c00000000000000000000770c00007700bbb0755555555555555550008288800880000082082888000b33000b30b3000330b3bbb300000
a999999900000000700000000000000000000007700000070700007055555555555555550008222200880000082082222200033300b30b3000330b3333300000
a9999999000000000777777777777777777777700777777000777700555555555555555500022000008200000220820022000033303303300033033000000000
aaaaaaaa0000000007777777777777777777777007777770004bbb00004b000000400bbb00022000002200000220220022000003303303300333033000000000
a49494a10000000070007770000077700000777770007777004bbbbb004bb000004bbbbb0002288220220000022022882200bb333033033bb330033bb3330000
a494a4a10000000070c777ccccc777ccccc7770770c7770704200bbb042bbbbb042bbb0000022222202200000220222220003333003303333300033333330000
a49444aa0000000070777ccccc777ccccc777c0770777c07040000000400bbb00400000000000000000000000000000000000000000000000000000000000000
a49999aa000000007777000007770000077700077777000704000000040000000400000000000000000000000000000000000000000000000000000000000000
a49444990000000077700000777000007770000777700c0742000000420000004200000000000000000000000000000000000000000000000000000000000000
a494a444000000007000000000000000000000077000000740000000400000004000000000000000000000000000000000000000000000000000000000000000
a4949999000000000777777777777777777777700777777040000000400000004000000000000000000000000000000000000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccc775500000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccccc776670000000000000000000000000070000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc77ccc776777711111111111111110000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccc77ccc776661111111111111111110000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccccccccccc7775511111111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccccccccc77776671111111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccc77cccccccccc777777776777711111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccc77cccccccccc777777756661111111111111111110000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccc77555555551111111111111111111110000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccc777555555500000000000000000000000000000000000000000000000000000000000000000000000000000007000000000
ccccccccccccccccccccccccccccc777555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccc7777555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccc7777555500000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000
ccccccccccccccccccccccccccccc777555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccccccccccccc777550000000300b0b000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccccccccc6cccccccccc7750000000003b330000000000000000000000000000000000000000000007000000000000000000000000000000000000
cccccccccccccccccccccccccccccc77000000000288882000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccccccccccccccccccc77000000700898888000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccccccccccc77ccc77000000000888898000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccccccccccc77ccc77070000000889888000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccccc77cccccccc777000000000288882000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccccccccccccc777777ccccc7777000000000028820000000000000000000000000000000111111111111111111111111111117111111111111111110000
cccccccccccccccc7777777777777777000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111110000
cccccccccccccccc7777777777777775000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111110000
cccccccccccccc775777777566656665000006000000000000000000000000000000000000000111111111111111111111111111111111111111111111110000
ccccccc66cccc7777777777767656765000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccc66cccc777777c777767706770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccc777777cccc7707000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccc777777cccc7707000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc777777cc77700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7777777777700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccc775777777500000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111
cccccccccccccc776665666700000000000000000000000000000000000000000000000000111111111111111111111111111111111771111111111111111111
ccccccccccccc7776766676500000000000000000000000000000000000000000000000000111111111111111111111111111111111771111111111111111111
ccccccccccccc7776770677000000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111
cccccccccccc77770700070000000000000000000000000000000000000000000000000000111111111111111111111111111111111111111111111111111111
cccccccccccc77770700070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000000000000000001111111111111111111111111111111111110000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000111111111111111111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000111111111111111111111111111111111111611111111111110000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000111111111111111111111111111111111111111111111111110000000000000000000000000000000000
cccccccccccccc770000000000000000000000000000111111111111111111111111111111111111111111111111110000000000000000000000000000000000
ccccccccc77ccc770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
ccccccccc77ccc770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
ccccccccccccc7770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
cccccccccccc77770000000000000000000000000000111111111111111111111111111111111111111111111110000000000000000000000000000000000000
cccccccc777777770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccccc777777750000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
cccccc77551111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
cccccc77667111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
c77ccc77677771111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000600000000000000
c77ccc77666111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
ccccc777551111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
cccc7777667111111111111111111111111111111111111111111111111111111100000000000000000000000000000000000000000000000000000000000000
77777777677771000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77777775666111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555511111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
51555555551111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55551155555111111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55551155555511111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555551111000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55155555555555111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555555555550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
55555555500000000000000000000000000000000000000000000000000000000001111111111111111111114999999449999994499999941110000000000000
55555555550000000000000000000000000000000000000000000000000000000001111111111111111411119111111991111119911111191111100000000000
55555555555000000000000000000000000000006000000000000000000000000001111111111111111951519111111991111119911111191111100000000000
55555555555500000000000000000000000000000000000000000000000000000001111111111111111915159111111991111119911111191111100000000000
55555555555550000000000000000000000000000000000000000000000000000001111111111111111915159111111991111119911111191111100000000000
55555555555555000000000000000000000000000000000000000000000000000001111111111111111951519111111991111119911111191111100000000000
55555555555555500000000000000000000000000000000000000000000000000001111111111111111411119111111991111119911111191111100000000000
55555555555555550000000000000000000000000000000000000000000000000001111111111111111111114999999449999994499999941111100000000000
55555555555555555555555500000000077777700000000000000000000000000000000000000111111111111111111111111111111111111111100000000000
55555555555555555555555000000000777777770011111111111111111111111111111111111111111111111111111111111111111111111111100000000000
55555555555555555555550000000000777777770011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
55555555555555555555500000000000777733770011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
55555555555555555555000000000000777733770011111111111111111117711111111111111111111111111111111111000000000000000000000000000000
55555555555555555550000000000000737733370011111111111111111117711111111111111111111111111111111111000000000000000000000000000000
555555555555555555000000000000007333bb370011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
555555555555555550000000000000000333bb300011111111111111111111111111111111111111111111111111111111000000000000000000000000000000
55555555555555555000000000060000033333300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5555555555555555550000000000000003b33330000000008888888000ee0ee00000000000000000000000000000000000000000000000000000000000000000
5555555555555555555000000000003003333330000000088888888800eeeee00000000000000000000000000000000000000000000000000000000000000000
555555555555555555550000000000b00333b33000000008888ffff8000e8e000000000000000000000000000000000000000000000000000000000000000000
55555555555555555555500000000b30003333000000b00888f1ff1800eeeee00000000000000000000000000000000000000000000000000000000000000000
55555555555555555555550003000b0000044000000b000088fffff000ee3ee00000000000000000000000000000000000000000000000000000000000000000
55555555555555555555555000b0b30000044000030b0030083333000000b0000000000111111111111111111111111111888811111111110000000000000000
555555555555555555555555003033000099990003033030007007000000b0000000000111111111111111111111111118888881111111110000000000000000
55555555555555555555555557777777777777777777777557777777777777750000000111111111111111111111111118788881111111110000000000000005
55555551155555555555555577777777777777777777777777777777777777770000000111111111111111111111111118888881111111110000000000000055
5555550000555555550000557777ccccc777777ccccc77777777cccccccc77770000000111111111111111111111111118888881111111110000000000000555
555550000005555555000055777cccccccc77cccccccc777777cccccccccc7770000000111111111111111111111111118888881111111110000000000005555
55550000000055555500005577cccccccccccccccccccc7777cccccccccccc770000000111111111111111111111111111888811111111110000000000055555
55500000000005555500005577cc77ccccccccccccc7cc7777cc77ccccc7cc770000000111111111111111111111111111161111111111110000000000555555
55000000000000555555555577cc77cccccccccccccccc7777cc77cccccccc770000000111111111111111111111111111161111111111110000000005555555
50000000000000055555555577cccccccccccccccccccc7777cccccccccccc770000000111111111111111111111111111161111111111110000000055555555
00000000000000005555555577cccccccccccccccccccc7777cccccccccccc775000000000000005500000000000000000006000000000050000000055555555
000000000000000005555555777cccccccccccccccccc77777cccccccccccc775500000000000055550000000000000000006000000000550000000050555555
000000000000000000555555777cccccccccccccccccc77777cc7cccc77ccc775550000000000555555000000000000000006000000005550000000055550055
0000000000000000000555557777cccccccccccccccc777777ccccccc77ccc775555000000005555555500000000000000006000000055550600000055550055
0000000000000000000055557777cccccccccccccccc7777777cccccccccc7775555511111155555555555551111111100000000000555550000000055555555
000000000000000000000555777cccccccccccccccccc7777777cccccccc77775555551111555555555555551111111100000000005555550000000055055555
000000000000000000000055777cccccccccccccccccc77777777777777777775555555115555555555555551111111100000000055555550000000055555555
00000000000000006600000577cccccccccccccccccccc7757777777777777755555555555555555555555551111111100000000555555550000000055555555
00000000000000006600000077cccccccccccccccccccccc77777775555555555555555555555555111111111111111100000000555555555000000055555555
000000000000000000000000777ccccccccccccccccccccc77777777155555555555555555555551111111111111111100000000555555555500000055555555
000000000000000000000000777ccccccccccccccccccccccccc7777005555555555555555555511111111111111111111111111555555555551110055555555
0000000000000000007000707777ccccccccccccccccccccccccc777000555555555555555555111111111111111111111111111555555555555110055555555
0000000000000000007000707777cccccccccccccccccccccccccc77000155555555555555551111111111111111111111111111555555555555510055555555
000000000000000006770677777cccccccccccccccccccccccc7cc77000115555555555555511111111111111111111111111111555555555555550055555555
000000000000000056765676777ccccccccccccccccccccccccccc77000111555555555555111111111111111111111111111111555555555555555055555555
00000000000000005666566677cccccccccccccccccccccccccccc77000111155555555551111111111111111111111111111111555555555555555555555555
000000000000000557777777cccccccccccccccccccccccccccccc77000111155555555511111111111111111111111111111115555555555555555555555555
000000000000005577777777ccccccccccccccccccccccccccccc777000000555555555000000000000000001111111111111155555555551555555555555555
00000000000005557777ccccccccccccccccccccccccccccccccc777000005555555550000000000000000001111111111111555555555551155555555555555
0000000000005555777cccccccccccc6cccccccccccccccccccc7777000055555555500000000000000000001111111111115555555555551115555555555555
000000000005555577cccccccccccccccccccccccccccccccccc7777000555555555000000000000000000000000000000055555575555550000555555555555
000000000055555577cc77ccccccccccccccccccccccccccccccc677005555555550000000000000000000000000000000555555555555550000055555555555
000000000555555577cc77ccccccccccccccccccccccccccccccc777055555555500000000000000000000000000000005555555555555550000005555555555
000000005555555577cccccccccccccccccccccccccccccccccccc77555555555000000000000000000000000000000055555555555555550000000555555555

__gff__
0000000000000000000000000008080804020000000000000000000200000000030303030303030304040402000000000303030303030303040404020002020200001313131302020300020200020202000013131313020204020000000000000000131313130004040200000000000000001313131300000002020002020000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
__music__
01 150a5644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

