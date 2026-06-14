-- Returns the blueprint table, or nil + error string on failure.
function blueprint_tool.logic.capture(itemstack, playerName)
  local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
  if not pos1 or not pos2 then
    return nil, "No selection set"
  end
  local result, err = blueprint_tool.logic.analyze_selection(pos1, pos2, playerName)
  if not result then return nil, err end
  -- Blueprint table format. If fields are added/removed/renamed here,
  -- bump CODEC_VERSION in logic/codec.lua.
  return {
    size        = result.size,
    nodes       = result.raw_nodes,
    forward     = vector.new(0, 0, 1),  -- front face is always world +Z at capture time
    captured_at = os.time(),
  }
end
