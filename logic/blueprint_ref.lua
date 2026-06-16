-- Logic for blueprint reference items.
-- Functions are param-based so they work regardless of where the data came from.

function blueprint_tool.logic.check_blueprint_ref_valid(bp_id, captured_at)
  if not bp_id or not captured_at then return false end
  local bp = blueprint_tool.storage.get_blueprint(bp_id)
  if not bp then return false end
  return bp.captured_at == captured_at
end

-- Copies the referenced blueprint into targetPlayerName's storage.
-- Returns slot_index on success, or nil + error string on failure.
-- disallow_copy propagates to the new slot for the machine to enforce later.
-- Access and slot-limit checks are the caller's responsibility.
function blueprint_tool.logic.import_blueprint_ref(bp_id, captured_at, oc, disallow_copy, targetPlayerName)
  if not blueprint_tool.logic.check_blueprint_ref_valid(bp_id, captured_at) then
    return nil, "Invalid or expired blueprint reference"
  end

  local limit = blueprint_tool.get_player_slot_limit(targetPlayerName)
  local slot  = blueprint_tool.storage.get_next_empty_slot(targetPlayerName, limit)
  if not slot then
    return nil, "No free blueprint slots"
  end

  local bp = blueprint_tool.storage.get_blueprint(bp_id)
  local new_bp = {
    size        = bp.size,
    nodes       = bp.nodes,
    forward     = bp.forward,
    captured_at = bp.captured_at,
    oc          = oc,
  }

  local id = blueprint_tool.storage.store_blueprint(new_bp)
  blueprint_tool.storage.set_player_slot(targetPlayerName, slot, {
    name          = "",
    bp_id         = id,
    disallow_copy = disallow_copy,
  })

  return slot
end
