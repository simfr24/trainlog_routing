api_version = 4

function setup()
  return {
    default_speed             = 120
}

end


function process_way(profile, way, result, relations)
    result.forward_speed = 1
    result.backward_speed = 1
    result.forward_rate = 1
    result.backward_rate = 1
    result.forward_mode = mode.route
    result.backward_mode = mode.route
end


return {
    setup = setup,
    process_way = process_way
}