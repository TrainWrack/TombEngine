-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local Utilities = {}

Utilities.ColorCombine = function(color, transparency)

    return Color(color.r, color.g, color.b, transparency)

end

Utilities.OffsetY = function(position, offsetY)

    return Vec3(position.x, position.y + offsetY, position.z)

end


Utilities.CopyRotation = function(r)

    return Rotation(r.x, r.y, r.z)

end

Utilities.Contains = function(tbl, value)

    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end

    return false
end

return Utilities