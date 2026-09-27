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
local in_timer = false

local function record(line)
  log[#log + 1] = line
end

-- Arguments as a stable, readable string: sorted, so a test can assert on it.
local function render(args)
  if args == nil then
    return ""
  end
  if type(args) ~= "table" then
    return " " .. tostring(args)
  end
  local keys = {}
  for key in pairs(args) do
    keys[#keys + 1] = tostring(key)
  end
  table.sort(keys)
  local pairs_out = {}
  for _, key in ipairs(keys) do
    pairs_out[#pairs_out + 1] = ("%s=%s"):format(key, tostring(args[key]))
  end
  return " {" .. table.concat(pairs_out, ",") .. "}"
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
  if type(dispatcher) == "table" and dispatcher.kind == "dispatch" then
    return ("dispatch %s%s (argc %d)"):format(dispatcher.dsp, render(dispatcher.args), dispatcher.argc)
  end
  return "dispatch " .. type(dispatcher)
end

-- Every other dispatcher, by the name the registry gave it. hl.dsp is a tree of
-- namespaces ending in factories; the ones this repo names are listed here, and anything
-- else resolves to nil exactly as it would against the real API, so a typo in the
-- registry fails a test rather than only the session.
--
-- `argc` is recorded because "called with no argument" and "called with nil" are not the
-- same thing to the real API: hl.dsp.focus(nil) raises "expected a table".
local DISPATCHERS = {
  ["exit"] = true,
  ["focus"] = true,
  ["no_op"] = true,
  ["window.close"] = true,
  ["window.kill"] = true,
  ["window.move"] = true,
}
local NAMESPACES = { cursor = true, group = true, window = true, workspace = true }

local function dsp_node(path)
  return setmetatable({}, {
    __index = function(_, key)
      local child = path .. "." .. key
      if DISPATCHERS[child] or NAMESPACES[child] then
        return dsp_node(child)
      end
      return nil
    end,
    __call = function(_, ...)
      return { kind = "dispatch", dsp = path, args = ..., argc = select("#", ...) }
    end,
  })
end

hl = {
  -- The two the keymap treats specially are explicit; everything else resolves through
  -- the node proxy above, so a registry entry can name any dispatcher Hyprland has.
  dsp = setmetatable({
    exec_cmd = function(cmd)
      return { kind = "exec_cmd", cmd = cmd }
    end,
    submap = function(name)
      return { kind = "submap", name = name }
    end,
  }, {
    __index = function(_, key)
      if DISPATCHERS[key] or NAMESPACES[key] then
        return dsp_node(key)
      end
      return nil
    end,
  }),

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

  -- Measured on 0.56.2: a submap dispatched from inside a timer callback is silently
  -- ignored -- the call returns ok, no submap event is emitted, the submap does not
  -- change. The stub drops it the same way, so a keymap that leaves a group from a timer
  -- fails here rather than only on the machine.
  dispatch = function(dispatcher)
    local ignored = in_timer and type(dispatcher) == "table" and dispatcher.kind == "submap"
    record(describe(dispatcher) .. (ignored and " (ignored: dispatched from a timer)" or ""))
  end,

  timer = function(callback, opts)
    timers_created = timers_created + 1
    timer = {
      callback = callback,
      timeout = opts and opts.timeout,
      kind = opts and opts.type,
      enabled = true,
      set_timeout = function(self, timeout)
        self.timeout = timeout
      end,
      set_enabled = function(self, enabled)
        self.enabled = enabled
        record(enabled and ("timer enabled " .. tostring(self.timeout)) or "timer disabled")
      end,
      is_enabled = function(self)
        return self.enabled
      end,
    }
    record(("timer created %s %s"):format(tostring(timer.kind), tostring(timer.timeout)))
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

-- One tick of the timer, in the timer's own context -- where a submap dispatch does not
-- work. A "oneshot" cannot be made to fire twice, as on the machine.
function stub.fire_timer()
  if not timer or not timer.enabled then
    record("timer not running")
    return
  end
  if timer.kind == "oneshot" and timer.fired then
    record("oneshot timer cannot fire twice")
    return
  end
  timer.fired = true
  in_timer = true
  timer.callback()
  in_timer = false
end

-- Enough ticks to cover an idle wait of `ms`.
function stub.idle_for(ms)
  local groups = require("keymap.groups")
  for _ = 1, math.ceil(ms / groups.TICK) do
    stub.fire_timer()
  end
end

function stub.timer_kind()
  return timer and tostring(timer.kind) or ""
end

function stub.timer_running()
  return timer and tostring(timer.enabled) or ""
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
