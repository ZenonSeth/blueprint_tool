-- Y-axis rotation helpers (90-degree increments only).
-- Supports facedir, colorfacedir, wallmounted, colorwallmounted, 4dir.
-- All other paramtype2 values are passed through unchanged.

----------------------------------------------------------------
-- param2 rotation tables (clockwise when viewed from above)
----------------------------------------------------------------

local facedir_y = {
	[90]  = { 3,  0,  1,  2, 19, 16, 17, 18, 15, 12, 13, 14,
	           7,  4,  5,  6, 11,  8,  9, 10, 21, 22, 23, 20},
	[180] = { 2,  3,  0,  1, 10, 11,  8,  9,  6,  7,  4,  5,
	          18, 19, 16, 17, 14, 15, 12, 13, 22, 23, 20, 21},
	[270] = { 1,  2,  3,  0, 13, 14, 15, 12, 17, 18, 19, 16,
	           9, 10, 11,  8,  5,  6,  7,  4, 23, 20, 21, 22},
}

local wallmounted_y = {
	[90]  = {0, 1, 4, 5, 3, 2, 0, 0},
	[180] = {0, 1, 3, 2, 5, 4, 0, 0},
	[270] = {0, 1, 5, 4, 2, 3, 0, 0},
}

----------------------------------------------------------------
-- Offset rotation (Y axis only)
-- size is the blueprint's size vector (max - min).
-- Returns new_offset, new_size.
----------------------------------------------------------------

function blueprint_tool.logic.rotate_offset(offset, angle, size)
	angle = angle % 360
	if angle == 0 then
		return vector.copy(offset), vector.copy(size)
	elseif angle == 90 then
		return vector.new(size.z - offset.z, offset.y, offset.x),
		       vector.new(size.z, size.y, size.x)
	elseif angle == 180 then
		return vector.new(size.x - offset.x, offset.y, size.z - offset.z),
		       vector.new(size.x, size.y, size.z)
	elseif angle == 270 then
		return vector.new(offset.z, offset.y, size.x - offset.x),
		       vector.new(size.z, size.y, size.x)
	end
	error("rotate_offset: angle must be 0/90/180/270, got " .. tostring(angle))
end

----------------------------------------------------------------
-- param2 rotation (Y axis only)
----------------------------------------------------------------

function blueprint_tool.logic.rotate_param2(node_name, param2, angle)
	angle = angle % 360
	if angle == 0 then return param2 end

	local def = minetest.registered_nodes[node_name]
	if not def then return param2 end

	local pt2 = def.paramtype2

	if pt2 == "facedir" or pt2 == "colorfacedir" then
		local orient = param2 % 32
		local color  = param2 - orient
		return color + facedir_y[angle][orient + 1]

	elseif pt2 == "wallmounted" or pt2 == "colorwallmounted" then
		local orient = param2 % 8
		local color  = param2 - orient
		return color + wallmounted_y[angle][orient + 1]

	elseif pt2 == "4dir" then
		-- 0=+Z, 1=+X, 2=-Z, 3=-X; each 90° CW adds one step
		local steps = angle / 90
		return (param2 + steps) % 4
	end

	return param2
end
