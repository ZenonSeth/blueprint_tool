-- Blueprint import/export codec.
-- Exported string: minetest.serialize → zlib compress → base64.
-- Result is plain ASCII, safe to copy/paste/share.
--
-- VERSIONING: bump CODEC_VERSION whenever the blueprint table structure changes
-- (fields added/removed/renamed in capture.lua). Import rejects mismatched versions.
-- If backwards-compatible migration is needed, handle it in the version check below.

blueprint_tool.codec = {}

local CODEC_VERSION = 1

-- Returns a plain ASCII string, or nil + error string on failure.
function blueprint_tool.codec.export(bp)
  local ok, payload = pcall(minetest.serialize, { v = CODEC_VERSION, bp = bp })
  if not ok then return nil, "Serialization failed" end

  local ok2, compressed = pcall(minetest.compress, payload, "deflate")
  if not ok2 then return nil, "Compression failed" end

  local ok3, encoded = pcall(minetest.encode_base64, compressed)
  if not ok3 then return nil, "Encoding failed" end

  return encoded
end

-- Returns a blueprint table, or nil + error string on failure.
function blueprint_tool.codec.import(str)
  if type(str) ~= "string" or str == "" then
    return nil, "Empty input"
  end

  local ok, compressed = pcall(minetest.decode_base64, str)
  if not ok or not compressed then return nil, "Invalid base64" end

  local ok2, payload = pcall(minetest.decompress, compressed, "deflate")
  if not ok2 or not payload then return nil, "Decompression failed" end

  local data = minetest.deserialize(payload)
  if type(data) ~= "table" then return nil, "Invalid data" end

  if data.v ~= CODEC_VERSION then
    return nil, "Unsupported version "..tostring(data.v).." (expected "..CODEC_VERSION..")"
  end

  local bp = data.bp
  if type(bp) ~= "table"       then return nil, "Missing blueprint"   end
  if type(bp.size) ~= "table"  then return nil, "Missing size"        end
  if type(bp.nodes) ~= "table" then return nil, "Missing nodes"       end

  local s = blueprint_tool.settings
  if (bp.size.x or 0) > s.max_size_x or
     (bp.size.y or 0) > s.max_size_y or
     (bp.size.z or 0) > s.max_size_z then
    return nil, "Blueprint exceeds server size limits"
  end

  for i, entry in ipairs(bp.nodes) do
    if type(entry.offset) ~= "table" or type(entry.name) ~= "string" then
      return nil, "Invalid node entry at index "..i
    end
    -- param2 defaults to 0 if missing (forward-compatibility with older exports)
    if entry.param2 == nil then entry.param2 = 0 end
  end

  return bp
end
