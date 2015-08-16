if not core.get_gravity then
	local gravity,grav_updating = 10
	function core.get_gravity()
		if not grav_updating then
			gravity = tonumber(core.setting_get("movement_gravity")) or gravity
			grav_updating = true
			core.after(50, function()
				grav_updating = false
			end)
		end
		return gravity
	end
	local set_setting = core.setting_set
	function core.setting_set(name, v, ...)
		if name == "gravity" then
			name = "movement_gravity"
			gravity = tonumber(v) or gravity
		end
		return set_setting(name, v, ...)
	end
	local get_setting = core.setting_get
	function core.setting_get(name, ...)
		if name == "gravity" then
			name = "movement_gravity"
		end
		return get_setting(name, ...)
	end
end

local item_entity = minetest.registered_entities["__builtin:item"]
local old_on_step = item_entity.on_step or function()end

item_entity.on_step = function(self, dtime)
	old_on_step(self, dtime)

	local p = self.object:getpos()

	local name = minetest.get_node(p).name
	if name == "default:lava_flowing"
	or name == "default:lava_source"
	or name == "fire:basic_flame" then
		minetest.sound_play("builtin_item_lava", {pos=p})
		minetest.add_particlespawner({
			amount = 3,
			time = 0.1,
			minpos = {x=p.x, y=p.y, z=p.z},
			maxpos = {x=p.x, y=p.y+0.2, z=p.z},
			minacc = {x=-0.5,y=5,z=-0.5},
			maxacc = {x=0.5,y=5,z=0.5},
			minexptime = 0.1,
			minsize = 2,
			maxsize = 4,
			texture = "smoke_puff.png"
		})
		minetest.add_particlespawner ({
			amount = 1, time = 0.4,
			minpos = {x = p.x, y= p.y + 0.25, z= p.z},
			maxpos = {x = p.x, y= p.y + 0.5, z= p.z},
			minexptime = 0.2, maxexptime = 0.4,
			minsize = 4, maxsize = 6,
			collisiondetection = false,
			vertical = false,
			texture = "fire_basic_flame.png",
		})
		self.object:remove()
		return
	end

	local tmp = minetest.registered_nodes[name]
	if tmp
	and tmp.liquidtype == "flowing" then
		get_flowing_dir = function(self)
			local pos = self.object:getpos()
			local node = minetest.env:get_node(pos)
			return quick_flow(pos,node)
		end
			
		local vec = get_flowing_dir(self)
		if vec then
			local v = self.object:getvelocity()
			self.object:setvelocity({x=vec.x,y=v.y,z=vec.z})
			
			self.object:setacceleration({x=0, y=-core.get_gravity(), z=0})
			self.physical_state = true
			self.object:set_properties({
				physical = true
			})
		end
	end
end

minetest.register_entity(":__builtin:item", item_entity)

if minetest.setting_get("log_mods") then
	minetest.log("action", "builtin_item loaded")
end
