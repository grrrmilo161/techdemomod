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
		?"original game by:",33,90,5
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
    -- Adjust movement direction based on flipped state
    local direction = (flipped and flipped == true) and -1 or 1

    p.x += p.spd - cam_spdx
    p.y += direction * (sin(p.off) + p.spd - cam_spdy)
    p.off += min(0.05, p.spd / 32)

    -- Define color sets
    local green_shades = {3, 11, 3}
    local red_shades = {2, 8, 2}

    -- Assign colors based on flipped state
    local color_pool = (flipped and flipped == true) and red_shades or green_shades
    local particle_color = color_pool[flr(rnd(#color_pool)) + 1] -- Pick a random color from the selected pool

    rectfill(p.x + draw_x, p.y % 128 + draw_y, p.x + p.s + draw_x, p.y % 128 + p.s + draw_y, particle_color)

    -- Handle screen wrapping
    if p.x > 132 then
        p.x = -4
        p.y = rnd(128)
    elseif p.x < -4 then
        p.x = 128
        p.y = rnd(128)
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
			{id=0,right=1},
			{id=1,right=1},
			{id=2,right=1},
			{id=3,right=1},
			{id=4,right=1},
			{id=5,right=1},
			{id=6,right=1},
			{id=7,right=1},
			{id=8,right=1},
			{id=9,right=1},
			{id=10,right=1},
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
	flipped=false
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
  "0,0,4,1,",
  "0,0,2,2,",
  "0,0,3,2,",
  "0,0,2.3125,2,",
  "0,0,2,3,",
  "0,0,3,1,",
  "0,0,3,2,",
  "0,0,1,1,",
  "0,0,1,1,",
  "0,0,1,2,"
}

-- mapdata string table
-- assigned levels will load from here instead of the map
mapdata={
  "282828281028282828243e26686868686868306868686868686824266868686868686868686868686868686868686868686868686868686868686868686868682828686868686868212525260000000000212600000000000021253e22360000000000000000000000000000000000000000000000000000000000000000000038280000000000003132323236000000002426000000000034323232330000000000000000000000000000000000000000000000000000000000000000000000282900000000000000000000000000343532323600000000000000000000000000000000000000000000000000000000000000000000000000000000000000002800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000029000000000000000000000000000000000000000000000000000000000000001c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000595a5b5c5d5e5f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000696a6b6c6d6e6f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015000000000000000000797a7b7c7d7e7f000000000000002122222222222222360000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000031253e252525253300000000342222222222222222360000003422222222222222222222222223000000000000000000000000000000000000000000000000000031252525252600000000000031252525252532330000000000242525252532252525253e323300000000000000000000000000000000000000000000000000000024253e2533000000000000003125252526000000000000003132252526003e25253233000000000000000000000000000000000000000000000000000000000031252526000000000000000000242525330000000000000000002425330025252667676767676767676767676767676767676767676767676767676767676767672425266767676767676767672425266767676767676767676724266767",
  "6868686868686868301168686868686868686868686868686868686868686824000000000000001124231100000000000021230000000027000000000000002400000000000000212525231100000000212526000000212523000000000000240000000000001124252525230000000031252523000024252522360000000024000000000011212525252526110000001b3125260021252532331b000000002400000000003432323232323236000000001b2425222525331b1b00000000002400000000000000000000000000000000000031252525261b00000000000011240000000000000000000000000000000000003b242525252300000000000021250000000000000000000000000000001c00003b242532252536000000000024250000000000000000000000000000000000003b24331b31331b000000000024250000000000000000000000000000000000003b301b001b1b00000000000024250000000000000000000000110000000000003b37000000001100000000002425000000000000000000003b272b00000000000000000000002700000000002425000000000000000000003b302b00000000000000000000003000000000002425000000000000000000003b301100000000000000000000113000000000002425000000000000000000003b242311111111000000000000212600000000002425000000000000000000003b242522222223110000000000242600000000112425000000000000000000003b242532323225231100000011242600000000212525000000000000000000003b24331b1b1b2425232b003b21252600000000242525000000000000000000003b371b0000002425262b003b2425260000000024252500000000000000000000001b000000002425262b003b2425260000000024252500000000000000000000000000001a002425262b003b24252600000011242525000000000000000000001100000000002425262b163b242526000000212525250000000000000000003b2700000000212525262b003b242526000000242525250000000000000000003b2422222222252525262b003b313233000000242525250000000000000000003b2425253232323232332b00001b1b1b000000313232320000000000000015003b24252600000000000000000000000000000000000000000000000000000000112425330000000000000000000000000000000000000000000100000000003b2125260000150000000000000000000000000000000000222222222236000011242526000000000000000000000000000000000000000032252525333911112125252600000000000000000000000000000000000000002824252628282122252525252222222367676767676767676767676767676767",
  "6868686868686868686868683132252525253368686868683068686868306868686868686868686868686868686868680000000000000000000000001b1b312525331b000000000030000011212523110000000000000000000000000000000000000000000000000000000000001b24261b0000000000003000112125252523110000000000000000000000000000000000000000000000001c00000000002426000000000000003000343232323232360000000000000000000000000000000000000000000000000000001600002426110000000000003700000000000000000000000000000000000000000000000000000000000000001100000000002425231100000000001b0000000000000000000000000000000000000000000000000000000000000000271b1b1b1b1b2425252300001c0000000000000000000000000000000000000000000000000000000000000000000000371b1b1b1b1b2425252611000000001100000000000000000000000000000000000000000000000000000000000000001b000000000024252525230016001127000000000000000000000000000000000000000000000000000011000000000000000000000024252525260000002126110000000000000000000000000000000000000000000000001127000000000000000000000024252525260000002425230000000000000000000000000000000000000000000000002126110000000000000000000024252525261b1b1b2425260000000000000000000000110000000000000000000000002425231111000000000000000031323232331b1b1b242526000000000000111111111127000000000000000000000000312525222311110000000000001b1b00000000003b2425260000000000112122222222261100000000000000000000001b312525252223110000000000000000000000003b242526000000000021252525252525231111000000000000000000001b3132252525232b00000000111111111100003b24252600000000003132323232252525222311110000000000000000001b1b312525262b0000003b213535353600003b24252600000000001b1b0000002425252525222311111100000000000000001b3125262b0000003b301b1b1b1b00003b24252600000000000000001c00242532322525252222231100000000000000001b24262b0000003b300000000000003b2425260000000000111100000024331b1b3132323225252311000000000000000024262b0000003b3000001c0000003b242533000000000034361b1b1b371b00001b1b000031252522000000000000000031262b0000003b300000000000003b24331b00000000001b1b0000001b000000000000000031252500000000000000001b302b0000003b300000000000003b301b0000000000000000000000000000001111000000002425000000000000000000302b0000003b300000000000003b30000000000000000000000000000000002123000000002425000000000000000000302b0000003b300000000000003b37000000000000003422222222360000002426000000002425000000000000000000302b0000003b30000000000000001b000000000000001b312532331b0000002426000000003125000001000000000000302b0000003b30000000000000000000000000000000001b301b1b000000002426110000000031222222222236000000372b0000003b3000000000000000000000000000000000003700000000000024252300000000002525253233000000001b000000003b3000000000000000150000000000000000001b000000000011242526000000000025253300000000000000000015003b30000000000000000000000000000000000000000000001121252526000000000025260000000000000000000000003b3700000000000000000000000000000000000000000011212525252600000000003233000000000000000000000000001b0000000000000000000000000000000000000000112125252525330000000000676767676767676767676767676767676767676767676767676767676767676767676767212525252526676767676767",
  "252525336868686868686868686868686868686868686868686868686868686868686868682525331b0000000000003b272b00000000000000111100000034230000000000000000000025261b000000000000003b302b0000000000000034360000001b2423000000000000000000252536130000000000003b302b000000000000001b1b00000000312600000000000000000025331b000000000000003b2436130000000000000000000000001b30000000000000000000261b00000000000000003b301b0000000000000000001c0000003b30130000110000000000260000000000110000003b302b000000000000001111000000003b302b0000212223000000260000000000272b00003b302b0000000000003b21232b0000003b302b0000242525222300260000000000302b00000030110000000000003b24262b00160011302b0000242525252522260000000000302b00000024232b00000000003b31262b00003b2126000000312525252525260000000000300000003b2426110000000000001b302b00003b24330000003b2425252525260000000000300000003b2425232b00000000003b302b00003b371b0000003b2425252525260000000000302b00163b2425262b00000000003b302b0000001b000000003b2425252525260000000000302b00003b2425332b00000000003b302b00000000000000003b2425252525260000000000302b00003b24261b0000000000003b300000001100000000003b3125252525260000000000302b00003b24332b0000000000003b30000000270000000000003b24252525260000000000302b000000301b000000000000003b37000000372b00000000003b24252525260000000000302b000000372b00000000000000001b000000000000000000003b2425252526000000000037000000001b00000000000000000000000000000000000000003b312525252600001500001b00000000000000000000000000000000000000000000000000003b2425252600000000000000000000000000000000000000000000000000000000000000003b312525330000000000000000000000000000000000000000000000000000000000000000003b2425000000000000000000000000000000000000000000000000000000000000000000003b2425000000000000000000000000000000000000000000000000000000000000000000003b312500000000000000000000000000000000000000000000000000000000000000000000003b2400010000000000000000000000000000000000000000000000000000000000000000003b2422222222223600000000000000000000000000000000000000000000000000000000003b2425252525330000000000000000000000000000000000000000000000000000000000003b2425253233000000000000000000000000000000000000000000000000000000000000003b2425330000000000000000000000000000000000000000000000000000000000000000003b313300000000000000000000000000000000000000000000000000000000000000000000001b67676767676767676767676767676767676767676767676767676767676767676767676767",
  "25252532323368686868682425266868686868686868686868686868686868682525331b1b1b000000212225252523000000000000000000000000000000000025331b0000000000343232323232323600000000000000000000000000000000261b0000000000000000000000000000000000111111111111000000000000002600000000000000000000000000000000111121222222222311000000000000262b00000000000011000000000000003b343532323232252523000000000000262b0000000000112700000000000000001b1b1b1b1b1b312526000000000000262b001c00001121261100000000000011000000001a00002426000000000000262b0000003b212525232b000000003b34222300000000002433000000002122262b0000003b242525262b00000000001b31322300002122330000000021252533000000003b242532332b0000000000001b1b242222253300000000212525252b00000000112433000000000000000000003b242525260000112122252525252b0000003b2126000000110000000000001111242525330000212525252525252b0000001124260000112122362b00003b3435252526000011242525252525252b00003b21252600002125331b000000001b1b313233003b21252525252525252b000011242526000024261b00000000000000000000003b31323232252525252b003b21252533000024332b00000000160000000000000000000000313232322b003b2425262b0000301b00000011111111111100000000000000000000000000003b24252600003b302b00003b34353522222311000000000000000000000000003b242533000000302b0000001b1b1b31252523110000000000000000000000001124330000000030110000000000001b2425252300000000000000000000003b21262b0000001124232b00000000003b3125252611000000000000000000003b2426000000112125262b0000000000001b24252523110000000000000000003b242600003b34252526111111000000003b24252525230000000000000000003b24262b00003b3125252235362b0000003b24252525261100000000000000003b2426110000003b2425261b1b000000003b31323232252300000000000000003b2425230000003b2425332b0000000000001b000000242600000000000000003b3132330000003b24261b000000000000000000150024260000000000000000000000000000000024262b000000111100000000001124260000000000000000000000000000000024332b00003b3422222222222222253300000000000000000000000000000000301b000000001b3125252525252526000000000000000000000000000000003b302b00000000001b24252525252533000000000000000000003435360000003b302b00000000003b31252525253300000000000000000000000000000000003b302b0000000000001b312525260000000000000000000000000000000000003b302b000000000000001b2425330000000000000000000000000000000000003b372b000000000000003b31260000000000000000000000000000000000000000000000000000000000000037000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000022222222360000000000000000000000000000000000000000000000000000002525253300000000002122222222222236000000000000000000000000000000253233000000000000312525252525330000000000000000000000000000000033000000000000000000312525253300000000000000000000000000000000006767676767676767676767242526676767676767676767676767676767676767",
  "00000000002426000000000000000000000000242526000000000000000000000000000000000000000000003000002400000000212525222300000000110000000034323232360000000000110000000000000000000000000000003000003100000034323232323236000000270000000000000000000000000000270000000000000000000000110000003700001b000000000000000000000000003000000000000000000000001c0000300000000000000000000000271300001b00000000000000000000000000000000300000000000000000000000000000300000000000000000000000302b00000000000000000000000000000000000000300000000000000000000000000000300000000000000000000000302b00000000001100000000000000000000000000370000000000000000000000000000300000000000000000000000302b000011003b21000000000000000000110000001b0000000000000000000000000000370000000000000000000000302b00002700002400000000000000000020130000000000000000000000000000000000000000000000000000000011302b0000300000240000000015000000001b000000000000000000000000000011000000110000000000000000000034332b0000300000240000000000000000000000000000000000000000000000002013000027000000000000000000001b1b000000300000240001000000000000000000000000000000000000000000001b0000003000000000000000000000000000150030000024222222223600000000000000000000000000000000000000000000003000000000000000000000111100000037000024252525330000000000000000000000000000000000000000000000003700000000000034222300343600000011000024252533000000000000000000000000000000000000000000000000001b000000000000002433001b1b00003b272b0024252600000000000000000000000000000000000000000000000000000000000000000000300000000000003b302b0024",
  "00000000000000000000003000000000003000000000000000003b30000000242600000000003000003b31322525252500000000000000000000212523000000002423000000000000003b3000002125252300000021260000001b1b3132252500000000000000000000313232360000002425230000000000003b30000031323232360000313236000000001b1b2425000000000000000000001b1b1b1b0000343232323600000000003b30000000000000000000000000000000110000312500000000000000000000000000000000000000000000000000003b300000000000000000000000000000002700001b2400000000000000000000000000000000000000000000001c00003b300000000000000000000000000000003000003b2400000000000000000000000000000000000000000000000000003b3700000000000000000000001100000037000011240000000000000000000000150000000000000000000000000000001b00000000000000000000002700000000003b21250000000000000000000000000000000000000000000000000000000000150000000000000000003000000000003b24250001000000000000000000000000000000000000000000000000000000000000001100000000003700000011003b2425222222222222353600000000000000000000000000000000000000000000000000272b000000000000000027003b2425252525323233000000000000000000000000000000000000111111110000000011302b000000000000000030003b3125252533000000000000000000000000000000000000001111212222231111111121262b00000000000000003700001b24253300000000000000000000000000000000001111112122323232323522222225262b00000000000000000000003b242600000000000000000000000000111111111121222232331b1b1b1b1b31323225262b00000000001c00000000003b24330000000000111111111111111121222222222532331b1b00000000001b1b1b31262b00000000000000000000003b2400001111111121222222222222222525323232331b1b000000000000000000001b302b00000000000000000000003b24001121222222252532323232323232331b1b1b1b0000000000001100000000003b302b00000034222222222222360024112125253232323300000000000000000000000000000000003b272b000000003b302b000000003125252525330000242232323300000000000000001100000000001500000000000013302b000000003b372b00000000002432252600002125261b00000000000000001c00270011111100000000000000003b302b00000000001b0000000000003700312523002425261100000000000000000000300034222311110000000000003b302b0000000000110000000000001100003125222525252300000000342222223600301100312535361111000011113b372b3422222235232b110000001127000000313232322526000000001b3125331b0031231100371b1b342311112122361b001b3125331b372b2011111121252223001b1b1b1b252611000000001b371b0000112423001b00001b24222232331b00000000371b001b001b34353532322525360000000025252300150000001b00000034323236000000003132331b1b00000000001b000000000000000000003133000000000025252611000000000000000000000000000000000000000000001c0000000000000000001500000000000000000000002525253613000000000000000000000000000000000000001100000000000000000000000000000000000000001c00002532331b0000000000000000000000000000000000000000270000000000000000000000000000000000000000000000331b1b0000000000000000000000000000000000000000003000000000001100000000000000000000000000000000001b0000000000000000000000000000000000000000000000300034223600270000000000000000000000000034352222000000000000000000000000000000000000000000000000300000300000300000000000000000000000000000002425",
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
d5d5d5d50000000000000000000000000000000000111100008888004999999449999994499909940300b0b06661666100111100000000000000000070000000
dd5d5d5d000000000000000000040000000000000177661008888880911111199111411991140919003b33006c616c6101776610007700000770070007000007
d5d5ddd50000000000000000000950500aaaaaa017782661087888809111111991119119494004190288882067c167c1177b3661007770700777000000000000
5d5d5d5d007000700499994000090505a998888a1782226108888880911111199494041900000044089888801c101c1017633661077777700770000000000000
d555d5d5007000700050050000090505a988888a1662266108888880911111199114094994000000088889801c101c1016333361077777700000700000000000
5d5d5d55067706770005500000095050aaaaaaaa1662265108888880911111199111911991400499088988800100010016633651077777700000077000000000
d5ddd5d5567656760050050000040000a980088a0166551000888800911111199114111991404119028888200000000001665510070777000007077007000070
5d5d5d5d566656660005500000000000a988888a0011110000000000499999944999999444004994002882000000000000111100000000007000000000000000
5111111551111111111111111111111516761d1d1d1d1d1d1d1d177151111115d5d5d5d5d5d5d5d5d5d5d5d55500000051d1d1d5000000000000000000000000
111777111116666666666666666661111671d1d1d1d1d1d1d1d16771116667115d5d5d5d5d5d5d500d5d5d5d66700000d1666671000777770000000000000000
11766671116666777666777776677711167d1d1d1d1d1d1d1d1d167116777771d5d5d5d5d5d5d50000d5d5d5677770001668777d007766700000000000000000
176d6d7116677776777777766777776116d1d1d1d1d1d1d1d1d1d761167dd7615d5d5d5d5d5d5000000d5d5d66600000d6888271076777000000000000000000
176dd7711667761d1d667d6d1d767771166d1d1d1d1d1d1d1d1d67611676d761d5d5d5d5d5d500000000d5d5550000001682226d077660000777770000000000
17d667111677d1d1d1d1d1d1d1d667711761d1d1d1d1d1d1d1d1d661167767715d5d5d5d5d50000000000d5d66700000d7722671077770000777767007700000
11777111167d1d1d1d1d1d1d1d1d776117761d1d1d1d1d1d1d1d1d611777d761d5d5d5d5d5000000000000d5677770001777677d070000000700007707777770
511111151761d1d1d1d1d1d1d1d1d6611777d1d1d1d1d1d1d1d1d6611677d6715d5d5d5d500000000000000d666000005d1d1d15000000000000000000077777
166d7771176d1d1d1d1d1d1d1d1d1d71511111111111111111111115167d7771d5d55d55d0000000000000050000066651d1d1d5dddddddd1d1d1d1100000000
1666d7711771d1d1d1d1d1d1d1d1d1611116676766666776666771111676d6715d55555d5d0000000000005d00077776d1666671d116c6ddddd1d1d100000000
166d777117761d1d1d1d1d1d1d1d16611167777677777777777776111677d671d55d55d5d5d00000000005d500000766166b777dd671711d1d1ddd1d00000030
167d7761177766d1d1d1d6d1d1d176611667dd6ddd77dd67dddd77611677d7615d55d55d5d5d000000005d5d00000055d6bbb371d6c71dddd1ddd1d1000000b0
1676d76117777766661d676d1d16776117777ddd6dd76dddd667d66116767761d55555d5d5d5d0000005d5d50000066616b3336ddd6c1ddd1d1d1d1d00000b30
1677d771116677777766777666676611116677667667776667776711177d6761555d555d5d5d5d00005d5d5d00077776d7733671dd61ddddd1d1d1dd03000b00
1777d76111166666667777777766611111166677777776667766611111777611d5d5d555d5d5d5d005d5d5d5000007661777677dd661dddd1d1ddd1d00b0b300
167d667151111111111111111111111551111111111111111111111551111115555d5d5d5d5d5d5d5d5d5d5d000000555d1d1d15d61dddddd111d1d100303300
577775570d0d0d00077777777777777777777770077777700000000000000000ccccccccbbbbb30bb00000bb0bbbb30088880088088888000888888200000000
777777770000000d700007770000777000007777700077770000000000000000c77cccccbb33330b300000b30bb3333082222082088822200888222200000000
7777cc77d008000070cc777cccc777ccccc7770770c777070000000000000000c77cc7ccb300000b300000b30b30033000022082088002220880000000000000
777ccccc0088820d70c777cccc777ccccc777c0770777c070000000000000000ccccccccb300000b300000b30b30033000222082082000220820000000000000
77ccccccd0822200707770000777000007770007777700070002eeeeeeee2000ccccccccb3bb3003300000330b3bb33008220082082000220828882000000000
57cc77cc0002200d77770000777000007770000777700007002eeeeeeeeee200cc7ccccc33333003300000330333330082200022022000220222222000000000
577c77ccd00000007000000000000000000c000770000c0700eeeeeeeeeeee00ccccc7cc33000003300000330330000082000022022002220220000000000000
777ccccc00d0d0d07000000000000000000000077000000700e22222e2e22e00cccccccc330000033bbb30330330000022222022022882200228822200000000
777ccccc0d0d0d007000000000000000000000077000000700eeeeeeeeeeee000000000033000003333330330330000002222022022222000222222200000000
577ccccc0000000d7000000c000000000000000770cc000700e22e2222e22e000000000000000000000000000000000000000000000000000000000000000000
57cc7cccd00b000070000000000cc0000000000770cc000700eeeeeeeeeeee00000000008800000888882088088000000bbb30bb0bbbb3000bbbbbb300000000
77cccccc00bbb30d70c00000000cc00000000c0770000c0700eee222e22eee0000000000820000088882208208800000bb3330b30bb333300bb3333300000000
777cccccd0b333007000000000000000000000077000000700eeeeeeeeeeee0055555555820000088000008208200000b30000b30bb003330b30000000000000
7777cc770003300d70000000000000000000000770c0000700eeeeeeeeeeee0055555555828880088000008208288800b33000b30b3000330b3bbb3000000000
77777777d000000070000000c0000000000000077000000700ee77eee7777e0055555555822220088000008208222220033300b30b3000330b33333000000000
5777757700d0d0d07000000000000000000000077000c00707777777777777705555555522000008200000220820022000333033033000330330000000000000
0000000000000000700000000000000000000007700000070077770000000000d5d5d5d522000002200000220220022000033033033003330330000000000000
00aaaaaa00000000700000000000000000000007700c000707000070000000005d5d5d5d228822022000002202288220bb333033033bb330033bb33300000000
0a99999900000000700000000000c00000000007700000077077000705050505d5d5d5d522222202200000220222220033330033033333000333333300000000
a99aaaaa000000007000000cc0000000000000077000cc077077bb07505050505050505000000000000000000000000000000000000000000000000000000000
a9aaaaaa000000007000000cc0000000000c00077000cc07700bbb07050505050505050500000000000000000000000000000000000000000000000000000000
a99999990000000070c00000000000000000000770c00007700bbb075d5d5d5d5050505000000000000000000000000000000000000000000000000000000000
a9999999000000007000000000000000000000077000000707000070d5d5d5d50000000000000000000000000000000000000000000000000000000000000000
a99999990000000007777777777777777777777007777770007777005d5d5d5d0000000000000000000000000000000000000000000000000000000000000000
aaaaaaaa0000000007777777777777777777777007777770004bbb00004b000000400bbb00000000000000000000000000000000000000000000000000000000
a49494a10000000070007770000077700000777770007777004bbbbb004bb000004bbbbb00000000000000000000000000000000000000000000000000000000
a494a4a10000000070c777ccccc777ccccc7770770c7770704200bbb042bbbbb042bbb0000000000000000000000000000000000000000000000000000000000
a49444aa0000000070777ccccc777ccccc777c0770777c07040000000400bbb00400000000000000000000000000000000000000000000000000000000000000
a49999aa000000007777000007770000077700077777000704000000040000000400000000000000000000000000000000000000000000000000000000000000
a49444990000000077700000777000007770000777700c0742000000420000004200000000000000000000000000000000000000000000000000000000000000
a494a444000000007000000000000000000000077000000740000000400000004000000000000000000000000000000000000000000000000000000000000000
a4949999000000000777777777777777777777700777777040000000400000004000000000000000000000000000000000000000000000000000000000000000
__label__
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888eeeeee888eeeeee888eeeeee888777777888eeeeee888eeeeee888eeeeee888888888888888888ff8ff8888228822888222822888888822888888228888
8888ee888ee88ee88eee88ee888ee88778887788ee8e8ee88ee888ee88ee8eeee88888888888888888ff888ff888222222888222822888882282888888222888
888eee8e8ee8eeee8eee8eeeee8ee8777778778eee8e8ee8eee8eeee8eee8eeee88888e88888888888ff888ff888282282888222888888228882888888288888
888eee8e8ee8eeee8eee8eee888ee8777788778eee888ee8eee888ee8eee888ee8888eee8888888888ff888ff888222222888888222888228882888822288888
888eee8e8ee8eeee8eee8eee8eeee8777778778eeeee8ee8eeeee8ee8eee8e8ee88888e88888888888ff888ff888822228888228222888882282888222288888
888eee888ee8eee888ee8eee888ee8777888778eeeee8ee8eee888ee8eee888ee888888888888888888ff8ff8888828828888228222888888822888222888888
888eeeeeeee8eeeeeeee8eeeeeeee8777777778eeeeeeee8eeeeeeee8eeeeeeee888888888888888888888888888888888888888888888888888888888888888
1111111111111e1e1e1111e11e1e1e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111ee11ee111e11e1e1ee11e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111e1e1e1111e11e1e1e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
1111111111111e1e1eee11e111ee1e1e1e1e11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1ee11ee1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111e111e1e1e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111ee11e1e1e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111e111e1e1e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1e1e1eee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1eee111116661616166611661111161616661166166616611666166111661616166111111eee1e1e1eee1ee11111111111111111111111111111
1111111111e11e111111116116161161161111111616161616111161161616111616161616161616111111e11e1e1e111e1e1111111111111111111111111111
1111111111e11ee11111116116661161166611111616166616661161161616611616161616161616111111e11eee1ee11e1e1111111111111111111111111111
1111111111e11e111111116116161161111611111616161111161161161616111616161616661616111111e11e1e1e111e1e1111111111111111111111111111
111111111eee1e111111116116161666166111711166161116611666166616661666166116661616111111e11e1e1eee1e1e1111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111116661616166611661111161616661666166611661616111116661666116616661666166111661611166611711cc111111ccc11111c1111111ccc
111111111111116116161161161111111616116111611616161616161777161616111611116116161616161116111611171111c111111c1c11111c1111111c1c
111111111111116116661161166611111666116111611661161611611111166116611611116116661616161116111661171111c111111c1c11111ccc11111ccc
111111111111116116161161111611111616116111611616161616161777161616111611116116161616161616111611171111c111711c1c11711c1c11711c1c
11111111111111611616166616611171161616661161166616611616111116161666116611611616161616661666166611711ccc17111ccc17111ccc17111ccc
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1e1111ee1eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111e111e111e111e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111ee11e111eee1ee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111e111e11111e1e1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1eee1ee11eee11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111116661616166611661111161616661666166611661616111116661666116616661666166111661611166611711cc111111ccc11111c1111111ccc
111111111111116116161161161111111616116111611616161616161777161616111611116116161616161116111611171111c11111111c11111c1111111c11
111111111111116116661161166611111666116111611661161611611111166116611611116116661616161116111661171111c1111111cc11111ccc11111ccc
111111111111116116161161111611111616116111611616161616161777161616111611116116161616161616111611171111c11171111c11711c1c1171111c
11111111111111611616166616611171161616661161166616611616111116161666116611611616161616661666166611711ccc17111ccc17111ccc17111ccc
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1ee11ee1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111e111e1e1e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111ee11e1e1e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111e111e1e1e1e111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111eee1e1e1eee111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111dd1ddd11dd1ddd1ddd11111d111ddd1d1d1ddd1d1111111ddd1d1d1ddd1ddd11111ddd1ddd11dd1ddd11dd111111111111111111111111
11111111111111111d1111d11d1d1d1d1d1111111d111d111d1d1d111d1111111d111d1d11d111d111111d1d1d1d1d1d1d1d1d11111111111111111111111111
111111111ddd1ddd1ddd11d11d1d1dd11dd111111d111dd11d1d1dd11d1111111dd111d111d111d111111ddd1dd11d1d1ddd1ddd111111111111111111111111
1111111111111111111d11d11d1d1d1d1d1111111d111d111ddd1d111d1111111d111d1d11d111d111111d111d1d1d1d1d11111d111111111111111111111111
11111111111111111dd111d11dd11d1d1ddd11111ddd1ddd11d11ddd1ddd11111ddd1d1d1ddd11d111111d111d1d1dd11d111dd1111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111161116661616166616111666166611661666116611111111111111771111111111111111111111111111111111111111111111111111111111111111
11111111161116111616161116111616161616161616161111111777111111711111111111111111111111111111111111111111111111111111111111111111
11111111161116611616166116111666166116161666166611111111111117711111111111111111111111111111111111111111111111111111111111111111
11111111161116111666161116111611161616161611111611111777111111711111111111111111111111111111111111111111111111111111111111111111
11111111166616661161166616661611161616611611166111111111111111771111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111771666166111111ccc11111666166611661616166611111ccc1ccc1c1c1ccc1771111111111111111111111111111111111111111111111111
11111111111111711161161617771c1c111116161161161116161161177711c11c1c1c1c1c111171111111111111111111111111111111111111111111111111
11111111111117711161161611111c1c111116611161161116661161111111c11cc11c1c1cc11177111111111111111111111111111111111111111111111111
11111111111111711161161617771c1c117116161161161616161161177711c11c1c1c1c1c111171117111111111111111111111111111111111111111111111
11111111111111771666166611111ccc171116161666166616161161111111c11c1c11cc1ccc1771171111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111771666166111111cc111111616166611111ccc1ccc1c1c1c171771111111111111111111111111111111111111111111111111111111111111
111111111111117111611616177711c1111116161616177711c11c1c1c1c1c177171111111111111111111111111111111111111111111111111111111111111
111111111111177111611616111111c1111116161666111111c11cc11c1c1c177717111111111111111111111111111111111111111111111111111111111111
111111111111117111611616177711c1117116161611177711c11c1c1c1c1c177771117111111111111111111111111111111111111111111111111111111111
11111111111111771666166611111ccc171111661611111111c11c1c11cc1c177111171111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111711111111111111111111111111111111111111111111111111111111111111
11111111111111771666166111111ccc11111666166611661616166611111ccc1ccc1c1c1ccc1771111111111111111111111111111111111111111111111111
1111111111111171116116161777111c111116161161161116161161177711c11c1c1c1c1c111171111111111111111111111111111111111111111111111111
11111111111117711161161611111ccc111116611161161116661161111111c11cc11c1c1cc11177111111111111111111111111111111111111111111111111
11111111111111711161161617771c11117116161161161616161161177711c11c1c1c1c1c111171111111111111111111111111111111111111111111111111
11111111111111771666166611111ccc171116161666166616161161111111c11c1c11cc1ccc1771111111111111111111111111111111111111111111111111
11111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111188888111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111177111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111117111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111177111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
111111111111111111111d1d11dd1ddd1ddd1ddd11dd1dd11ddd1ddd1d1111111ddd1dd11ddd1d1d1ddd11111111111111111111111111111111111111111111
111111111111111111111d1d1d1d1d1d11d1111d1d1d1d1d11d11d1d1d11111111d11d1d1d1d1d1d11d111111111111111111111111111111111111111111111
111111111ddd1ddd11111ddd1d1d1dd111d111d11d1d1d1d11d11ddd1d11111111d11d1d1ddd1d1d11d111111111111111111111111111111111111111111111
111111111111111111111d1d1d1d1d1d11d11d111d1d1d1d11d11d1d1d11111111d11d1d1d111d1d11d111111111111111111111111111111111111111111111
111111111111111111111d1d1dd11d1d1ddd1ddd1dd11d1d11d11d1d1ddd11111ddd1d1d1d1111dd11d111111111111111111111111111111111111111111111
11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
82888222822882228888822282228882822282228222888888888888888888888888888888888888888882228222822282228882822282288222822288866688
82888828828282888888888288828828888288828882888888888888888888888888888888888888888882888882828282828828828288288282888288888888
82888828828282288888882288228828882282228882888888888888888888888888888888888888888882228882822282228828822288288222822288822288
82888828828282888888888288828828888282888882888888888888888888888888888888888888888888828882828288828828828288288882828888888888
82228222828282228888822282228288822282228882888888888888888888888888888888888888888882228882822288828288822282228882822288822288
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__gff__
0000000000000000000000000008080804020000000000000000000200000000030303030303030304040402000000000303030303030303040404020003030200001313131302020300020200020202000013131313020204020202020202020000131313130004040202020202020200001313131300000002020202020202
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

