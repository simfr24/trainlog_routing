api_version = 4

function setup()
  return {
    properties = {
      max_speed_for_map_matching     = 220/3.6, -- speed conversion to m/s
      weight_name                    = 'routability',
      left_hand_driving              = true,
      u_turn_penalty                 = 60 * 10, -- 10 minutes to change cabin
      turn_duration                  = 20,
      continue_straight_at_waypoint  = false,
      max_angle                      = 30,

      secondary_speed                = 30,
      speed                          = 130,
    },

    default_mode              = mode.train,
    default_speed             = 120,
}

end


function ternary ( cond , T , F )
    if cond then return T else return F end
end


function process_way(profile, way, result, relations)
    local data = {
        railway = way:get_value_by_key("railway"),
        service = way:get_value_by_key("service"),
        usage = way:get_value_by_key("usage"),
        maxspeed = way:get_value_by_key("maxspeed"),
        gauge = way:get_value_by_key("gauge"),
    }

    -- Remove everything that is not railway
    if not data.railway then
        return
    end

    local is_secondary = (
        data.service == "siding" or
        data.service == "spur" or
        data.service == "yard" or
        data.usage == "industrial"
    )

    -- by default, use 30km/h for secondary rails, else 160
    local default_speed = ternary(is_secondary, profile.properties.secondary_speed, profile.properties.speed)
    -- but if OSM specifies a maxspeed, use the one from OSM
    local speed = ternary(data.maxspeed, data.maxspeed, default_speed)

    -- Discourage use of railways under construction or disused by reducing rate
    local rate = 1  -- Default rate
    if data.railway == "construction" or data.railway == "disused" or data.railway == "razed" or data.railway == "abandoned" or data.railway == "proposed" or data.service == "yard" then
        rate = 0.01  -- Less preferred rate
    elseif data.railway == "ferry" then
        speed = 20/3.6
        rate = 0.5
    end

    -- Set speed for mph issue
    speed = tostring(speed)
    if speed:find(" mph") or speed:find("mph") then
      speed = speed:gsub(" mph", "")
      speed = speed:gsub("mph", "")
      speed = tonumber(speed)
      if speed == nil then speed = 20 end
      speed = speed * 1.609344
    else
     speed = tonumber(speed)
	 if speed == nil then speed = 32.18688 end
    end
    -- Set speed for mph issue end

    result.forward_speed = speed
    result.backward_speed = speed
    result.forward_rate = rate * ternary(speed == nil, 1, speed) * 1.5
    result.backward_rate = rate * ternary(speed == nil, 1, speed) * 1.5
    result.forward_mode = mode.train
    result.backward_mode = mode.train
end



function process_turn(profile, turn)
    -- Refuse truns that have a big angle
    if math.abs(turn.angle) >  profile.properties.max_angle then
        return
    end

    -- If we go backwards, add the penalty to change cabs
    if turn.is_u_turn then
      turn.duration = turn.duration + profile.properties.u_turn_penalty
    end
end

return {
    setup = setup,
    process_way = process_way,
    process_node = process_node,
    process_turn = process_turn
}