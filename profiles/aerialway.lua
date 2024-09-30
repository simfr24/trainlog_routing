api_version = 4

function setup()
  return {
    default_speed = 10
  }
end

function process_way(profile, way, result, relations)
    result.forward_speed = profile.default_speed
    result.backward_speed = profile.default_speed
    result.forward_rate = profile.default_speed
    result.backward_rate = profile.default_speed
    result.forward_mode = mode.route
    result.backward_mode = mode.route
end

return {
    setup = setup,
    process_way = process_way
}