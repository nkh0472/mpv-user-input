--[[
    This is a module designed to interface with mpv-user-input
    https://github.com/CogentRedTester/mpv-user-input

    Loading this script as a module will return a table with two functions to format
    requests to get and cancel user-input requests. See the README for details.

    Alternatively, developers can just paste these functions directly into their script,
    however this is not recommended as there is no guarantee that the formatting of
    these requests will remain the same for future versions of user-input.
]]

local API_VERSION = "0.1.0"

local mp = require 'mp'
local utils = require 'mp.utils'
local mod = {}

local name = mp.get_script_name()
local counter = 1

local function pack(...)
    local t = {...}
    t.n = select("#", ...)
    return t
end

local request_mt = {}

function request_mt:cancel()
    assert(self.uid, "request object missing UID")
    mp.commandv("script-message-to", "user_input", "cancel-user-input/uid", self.uid)
end

-- sends a request to ask the user for input using formatted options provided
-- creates a script message to recieve the response and call fn
function mod.get_user_input(fn, options, ...)
    options = options or {}
    local response_string = name.."/__user_input_request/"..counter
    counter = counter + 1

    local request = {
        uid = response_string,
        passthrough_args = pack(...),
        callback = fn,
        pending = true
    }

    -- create a callback for user-input to respond to
    mp.register_script_message(response_string, function(response)
        mp.unregister_script_message(response_string)
        request.pending = false

        response = utils.parse_json(response)
        request.callback(response.line, response.err, unpack(request.passthrough_args, 1, request.passthrough_args.n or #request.passthrough_args))
    end)

    -- send the input command
    mp.commandv("script-message-to", "user_input", "request-user-input", (utils.format_json({
        version = API_VERSION,
        id = name..'/'..(options.id or ""),
        source = name,
        response = response_string,
        request_text = ("[%s] %s"):format(options.source or name, options.request_text or options.text or "requesting user input:"),
        default_input = options.default_input,
        cursor_pos = options.cursor_pos,
        queueable = options.queueable and true
    })))

    return setmetatable(request, { __index = request_mt })
end

-- sends a request to cancel all input requests with the given id
function mod.cancel_user_input(id)
    id = name .. '/' .. (id or "")
    mp.commandv("script-message-to", "user_input", "cancel-user-input/id", id)
end

return mod