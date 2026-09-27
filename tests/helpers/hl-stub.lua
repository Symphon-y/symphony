-- A recording stand-in for Hyprland's `hl` API, so keymap.lua can be driven under
-- /usr/bin/lua with no compositor.
--
-- It records rather than simulates: every call lands in an ordered log, every bind keeps
-- its chord, submap, options and callback, and the callbacks can then be called by hand.
-- That is what makes the parts `hyprctl binds -j` cannot see -- which member closes a
-- group, how many timers exist -- assertable at all.
--
-- Returns a table of accessors; the `hl` it installs is a global, as in production.

local stub = {}

local log = {}
local binds = {}
local submaps = {}
local events = {}
local notices = {}
local timer = nil
local timers_created = 0
local current_submap = nil

local function record(line)
  log[#log + 1] = line
end

-- What a dispatcher table says it will do, for the log.
local function describe(dispatcher)
  if type(dispatcher) == "function" then
    return "dispatch fn"
  end
  if type(dispatcher) == "table" and dispatcher.kind == "exec_cmd" then
    return "exec_cmd " .. tostring(dispatcher.cmd)
  end
  if type(dispatcher) == "table" and dispatcher.kind == "submap" then
    return "submap " .. tostring(dispatcher.name)
  end
  return "dispatch " .. type(dispatcher)
end

hl = {
  dsp = {
    exec_cmd = function(cmd)
      return { kind = "exec_cmd", cmd = cmd }
    end,
    submap = function(name)
      return { kind = "submap", name = name }
    end,
  },

  bind = function(keys, dispatcher, opts)
    binds[#binds + 1] = {
      chord = keys,
      submap = current_submap,
      dispatcher = dispatcher,
      opts = opts or {},
    }
    record(("bind %s%s"):format(keys, current_submap and (" in " .. current_submap) or ""))
  end,

  -- The real one takes the function that installs the submap's binds, so anything bound
  -- outside it would land in the global map: the stub marks the window the same way.
  define_submap = function(name, reset_or_fn, fn)
    submaps[#submaps + 1] = name
    record("define_submap " .. name)
    local body = type(reset_or_fn) == "function" and reset_or_fn or fn
    current_submap = name
    if body then
      body()
    end
    current_submap = nil
  end,

  dispatch = function(dispatcher)
    record(describe(dispatcher))
  end,

  timer = function(callback, opts)
    timers_created = timers_created + 1
    timer = {
      callback = callback,
      timeout = opts and opts.timeout,
      enabled = true,
      set_timeout = function(self, timeout)
        self.timeout = timeout
      end,
      set_enabled = function(self, enabled)
        self.enabled = enabled
        record(enabled and ("timer armed " .. tostring(self.timeout)) or "timer disabled")
      end,
      is_enabled = function(self)
        return self.enabled
      end,
    }
    record("timer created " .. tostring(timer.timeout))
    record("timer armed " .. tostring(timer.timeout))
    return timer
  end,

  on = function(event, callback)
    events[#events + 1] = { event = event, callback = callback }
    record("on " .. event)
  end,

  notification = {
    create = function(spec)
      notices[#notices + 1] = tostring(spec and spec.text)
      record("notify " .. tostring(spec and spec.text))
    end,
  },
}

-- --- accessors ------------------------------------------------------------------------

local function find(chord)
  for i = #binds, 1, -1 do
    if binds[i].chord == chord then
      return binds[i]
    end
  end
end

function stub.log()
  return table.concat(log, "\n")
end

function stub.reset()
  log = {}
end

function stub.bind_description(chord)
  local bind = find(chord)
  return bind and bind.opts.description or ""
end

function stub.bind_locked(chord)
  local bind = find(chord)
  return bind and tostring(bind.opts.locked) or ""
end

function stub.bind_repeating(chord)
  local bind = find(chord)
  return bind and tostring(bind.opts.repeating) or ""
end

function stub.submap_of(chord)
  local bind = find(chord)
  return bind and bind.submap or ""
end

function stub.defined_submaps()
  return table.concat(submaps, " ")
end

-- Fire a bind's callback, the way pressing the key would.
function stub.press(chord)
  local bind = find(chord)
  if not bind then
    record("no bind for " .. chord)
  elseif type(bind.dispatcher) == "function" then
    bind.dispatcher()
  else
    record(describe(bind.dispatcher))
  end
end

function stub.fire_timer()
  if timer then
    timer.callback()
  end
end

function stub.timers_created()
  return timers_created
end

function stub.subscribed()
  local names = {}
  for _, subscription in ipairs(events) do
    names[#names + 1] = subscription.event
  end
  return table.concat(names, " ")
end

function stub.reload()
  for _, subscription in ipairs(events) do
    if subscription.event == "config.reloaded" then
      subscription.callback()
    end
  end
end

function stub.notifications()
  return table.concat(notices, "\n")
end

return stub
