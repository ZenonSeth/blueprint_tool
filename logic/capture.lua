-- Captures the selected volume into a blueprint and stores it.
-- Returns the blueprint and its assigned id, or nil + error string on failure.
function blueprint_tool.logic.capture(itemstack)
  local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
  if not pos1 or not pos2 then
    return nil, "No selection set"
  end
  local min = vector.new(
    math.min(pos1.x, pos2.x),
    math.min(pos1.y, pos2.y),
    math.min(pos1.z, pos2.z)
  )
  local max = vector.new(
    math.max(pos1.x, pos2.x),
    math.max(pos1.y, pos2.y),
    math.max(pos1.z, pos2.z)
  )
  local nodes = {}
  for x = min.x, max.x do
    for y = min.y, max.y do
      for z = min.z, max.z do
        local pos = vector.new(x, y, z)
        local node = minetest.get_node(pos)
        if node.name ~= "air" and node.name ~= "ignore" then
          nodes[#nodes + 1] = {
            offset = vector.subtract(pos, min),
            name   = node.name,
            param2 = node.param2,
          }
        end
      end
    end
  end
  return {
    size  = vector.subtract(max, min),
    nodes = nodes,
  }
end
