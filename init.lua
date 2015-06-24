--sum of direction vectors must match an array index
local function to_unit_vector(dir_vector)
	--(sum,root)
	-- (0,1), (1,1+0=1), (2,1+1=2), (3,1+2^2=5), (4,2^2+2^2=8)
	local inv_roots = {[0] = 1, [1] = 1, [2] = 0.70710678118655, [4] = 0.5, [5] = 0.44721359549996, [8] = 0.35355339059327}
	local sum = dir_vector.x*dir_vector.x + dir_vector.z*dir_vector.z
	return {x=dir_vector.x*inv_roots[sum],y=dir_vector.y,z=dir_vector.z*inv_roots[sum]}
end

local function quick_water_flow_logic(node,pos_testing,direction)
	if node.name == "default:water_source" then
		local node_testing = minetest.get_node(pos_testing)
		local param2_testing = node_testing.param2
		if node_testing.name ~= "default:water_flowing" then
			return 0
		else
			return direction
		end
	elseif node.name == "default:water_flowing" then
		local node_testing = minetest.get_node(pos_testing)
		local param2_testing = node_testing.param2
		if node_testing.name == "default:water_source" then
			return -direction
		elseif node_testing.name == "default:water_flowing" then
			if param2_testing < node.param2 then
				if (node.param2 - param2_testing) > 6 then
					return -direction
				else
					return direction
				end
			elseif param2_testing > node.param2 then
				if (param2_testing - node.param2) > 6 then
					return direction
				else
					return -direction
				end
			end
		end
	end
	return 0
end

local function quick_water_flow(pos,node)
	local x = 0
	local z = 0
	
	if not node_is_water(node) then
		return {x=0,y=0,z=0}
	end
	
	x = x + quick_water_flow_logic(node,{x=pos.x-1,y=pos.y,z=pos.z},-1)
	x = x + quick_water_flow_logic(node,{x=pos.x+1,y=pos.y,z=pos.z}, 1)
	z = z + quick_water_flow_logic(node,{x=pos.x,y=pos.y,z=pos.z-1},-1)
	z = z + quick_water_flow_logic(node,{x=pos.x,y=pos.y,z=pos.z+1}, 1)
	
	return to_unit_vector({x=x,y=0,z=z})
end

minetest.register_entity(":__builtin:item", {
	initial_properties = {
		hp_max = 1,
		physical = true,
		collisionbox = {-0.17,-0.17,-0.17, 0.17,0.17,0.17},
		visual = "wielditem",
		visual_size = {x=0.5, y=0.5},
		textures = {""},
		spritediv = {x=1, y=1},
		initial_sprite_basepos = {x=0, y=0},
		is_visible = false,
		timer = 0,
	},
	
	itemstring = '',
	physical_state = true,

	set_item = function(self, itemstring)
		self.itemstring = itemstring
		local stack = ItemStack(itemstring)
		local itemtable = stack:to_table()
		local itemname = nil
		if itemtable then
			itemname = stack:to_table().name
		end
		local item_texture = nil
		local item_type = ""
		if minetest.registered_items[itemname] then
			item_texture = minetest.registered_items[itemname].inventory_image
			item_type = minetest.registered_items[itemname].type
		end
		prop = {
			is_visible = true,
			visual = "wielditem",
			textures = {itemname},
			visual_size = {x=0.20,y=0.20},
			automatic_rotate = math.pi * 0.25
		}
		self.object:set_properties(prop)
	end,

	get_staticdata = function(self)
		--return self.itemstring
		return minetest.serialize({
			itemstring = self.itemstring,
			always_collect = self.always_collect,
			timer = self.timer,
		})
	end,

	on_activate = function(self, staticdata, dtime_s)
		if string.sub(staticdata, 1, string.len("return")) == "return" then
			local data = minetest.deserialize(staticdata)
			if data and type(data) == "table" then
				self.itemstring = data.itemstring
				self.always_collect = data.always_collect
				self.timer = data.timer
				if not self.timer then
					self.timer = 0
				end
				self.timer = self.timer+dtime_s
			end
		else
			self.itemstring = staticdata
		end
		self.object:set_armor_groups({immortal=1})
		self.object:setvelocity({x=0, y=2, z=0})
		self.object:setacceleration({x=0, y=-10, z=0})
		self:set_item(self.itemstring)
	end,
	
	on_step = function(self, dtime)
		local time = tonumber(minetest.setting_get("remove_items"))
		if not time then
			time = 300
		end
		if not self.timer then
			self.timer = 0
		end
		self.timer = self.timer + dtime
		if time ~= 0 and (self.timer > time) then
			self.object:remove()
		end
		
		local p = self.object:getpos()
		
		local name = minetest.env:get_node(p).name
		if name == "default:lava_flowing" or name == "default:lava_source" then
			minetest.sound_play("builtin_item_lava", {pos=self.object:getpos()})
			self.object:remove()
			return
		end
		
		if minetest.registered_nodes[name].liquidtype == "flowing" then
			get_flowing_dir = function(self)
				local pos = self.object:getpos()
				local node = minetest.env:get_node(pos)
				return quick_water_flow(pos,node)
			end
			
			local vec = get_flowing_dir(self)
			if vec then
				local v = self.object:getvelocity()
				self.object:setvelocity({x=vec.x,y=v.y,z=vec.z})
				self.object:setacceleration({x=0, y=-10, z=0})
				self.physical_state = true
				self.object:set_properties({
					physical = true
				})
				return
			end
		end
		
		p.y = p.y - 0.3
		local nn = minetest.env:get_node(p).name
		-- If node is not registered or node is walkably solid
		if not minetest.registered_nodes[nn] or minetest.registered_nodes[nn].walkable then
			if self.physical_state then
				self.object:setvelocity({x=0,y=0,z=0})
				self.object:setacceleration({x=0, y=0, z=0})
				self.physical_state = false
				self.object:set_properties({
					physical = false
				})
			end
		else
			if not self.physical_state then
				self.object:setvelocity({x=0,y=0,z=0})
				self.object:setacceleration({x=0, y=-10, z=0})
				self.physical_state = true
				self.object:set_properties({
					physical = true
				})
			end
		end
	end,

	on_punch = function(self, hitter)
		if self.itemstring ~= '' then
			local left = hitter:get_inventory():add_item("main", self.itemstring)
			if not left:is_empty() then
				self.itemstring = left:to_string()
				return
			end
		end
		self.object:remove()
	end,
})

if minetest.setting_get("log_mods") then
	minetest.log("action", "builtin_item loaded")
end
