-- Mock peripherals for the CC-OS VM (CraftOS-PC only).
-- CraftOS-PC's periphemu only knows its built-in types, so mods like Mekanism
-- are faked in Lua: the peripheral API is wrapped so these devices show up in
-- peripheral.getNames / wrap / find / call like real ones, with values that
-- drift over time. run-local.ps1 puts this file in front of vm-startup.lua.
--
-- A peripheral list line uses the Mekanism type name, e.g.
--   matrix_0   inductionPort   max=4e11 fill=0.4
-- Options (key=value) are passed to the mock; see each type below.

local function num(v, default) return tonumber(v) or default end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function now() return os.epoch("utc") / 1000 end

-- A smooth fake fluctuation: base +/- amp, repeating every `period` seconds.
local function wave(base, amp, period, phase)
    return base + amp * math.sin((now() + (phase or 0)) * 2 * math.pi / period)
end

-- getEnergy / getMaxEnergy / getEnergyNeeded / getEnergyFilledPercentage (Joules, like Mekanism)
local function energyMethods(m, o, defaultMax, phase)
    local max, fill = num(o.max, defaultMax), num(o.fill, 0.6)
    local function energy() return clamp(wave(max * fill, max * 0.05, 40, phase), 0, max) end
    m.getEnergy = energy
    m.getMaxEnergy = function() return max end
    m.getEnergyNeeded = function() return max - energy() end
    m.getEnergyFilledPercentage = function() return energy() / max end
    return energy, max
end

-- A tank of some fluid/chemical: get<Name>, get<Name>Capacity, get<Name>FilledPercentage, get<Name>Needed
local function tankMethods(m, prefix, stack, capacity, fill, phase)
    local function amount() return math.floor(clamp(wave(capacity * fill, capacity * 0.04, 25, phase), 0, capacity)) end
    m["get" .. prefix] = function() return { name = stack, amount = amount() } end
    m["get" .. prefix .. "Capacity"] = function() return capacity end
    m["get" .. prefix .. "Needed"] = function() return capacity - amount() end
    m["get" .. prefix .. "FilledPercentage"] = function() return amount() / capacity end
end

local function multiblock(m, o)
    local w, h, l = num(o.width, 5), num(o.height, 5), num(o.length, 5)
    m.isFormed = function() return o.formed ~= "false" end
    m.getWidth = function() return w end
    m.getHeight = function() return h end
    m.getLength = function() return l end
end

local MOCK_TYPES = {}

-- Energy cube.  options: max=<J> fill=<0-1> tier=BASIC|ADVANCED|ELITE|ULTIMATE|CREATIVE
MOCK_TYPES.energyCube = function(o)
    local m = {}
    energyMethods(m, o, 8e7, 3)
    local tier = (o.tier or "ADVANCED"):upper()
    m.getTier = function() return tier end
    return m
end

-- Induction matrix (its port).  options: max=<J> fill=<0-1> transfer=<J/t> cells= providers=
MOCK_TYPES.inductionPort = function(o)
    local m = {}
    multiblock(m, o)
    energyMethods(m, o, 2.56e11, 7)
    local transfer = num(o.transfer, 2.56e7)
    m.getTransferCap = function() return transfer end
    m.getLastInput = function() return math.max(0, wave(transfer * 0.3, transfer * 0.2, 15)) end
    m.getLastOutput = function() return math.max(0, wave(transfer * 0.25, transfer * 0.2, 11, 5)) end
    m.getInstalledCells = function() return num(o.cells, 8) end
    m.getInstalledProviders = function() return num(o.providers, 4) end
    return m
end

-- Fission reactor logic adapter.  options: burn=<mB/t> maxburn=<mB/t> active=true|false
MOCK_TYPES.fissionReactorLogicAdapter = function(o)
    local m = {}
    multiblock(m, o)
    local active = o.active == "true"
    local burn, maxBurn = num(o.burn, 1), num(o.maxburn, 20)
    local damage = 0
    m.getStatus = function() return active end
    m.activate = function()
        if active then error("Reactor is already active", 0) end
        active = true
    end
    m.scram = function()
        if not active then error("Reactor is already inactive", 0) end
        active = false
    end
    m.getBurnRate = function() return burn end
    m.setBurnRate = function(rate)
        rate = tonumber(rate)
        if not rate or rate < 0 or rate > maxBurn then error("Burn rate must be between 0 and " .. maxBurn, 0) end
        burn = rate
    end
    m.getActualBurnRate = function() return active and burn or 0 end
    m.getMaxBurnRate = function() return maxBurn end
    m.getTemperature = function() -- Kelvin
        return active and wave(300 + burn * 40, 5, 20) or 300
    end
    m.getDamagePercent = function() return damage end
    m.getHeatingRate = function() return active and burn * 20000 or 0 end
    tankMethods(m, "Fuel", "mekanism:fissile_fuel", 1e6, 0.8, 1)
    tankMethods(m, "Coolant", "minecraft:water", 2e6, 0.9, 2)
    tankMethods(m, "HeatedCoolant", "mekanism:steam", 2e6, 0.2, 3)
    tankMethods(m, "Waste", "mekanism:nuclear_waste", 1e6, 0.1, 4)
    return m
end

-- Industrial turbine valve.  options: max=<J> production=<J/t> flow=<mB/t>
MOCK_TYPES.turbineValve = function(o)
    local m = {}
    multiblock(m, o)
    energyMethods(m, o, 1.6e9, 9)
    local production, flow = num(o.production, 3e6), num(o.flow, 20000)
    m.getProductionRate = function() return math.max(0, wave(production * 0.8, production * 0.15, 18)) end
    m.getMaxProduction = function() return production end
    m.getFlowRate = function() return math.floor(math.max(0, wave(flow * 0.8, flow * 0.15, 18))) end
    m.getMaxFlowRate = function() return flow end
    m.getMaxWaterOutput = function() return flow end
    m.getDumpingMode = function() return o.dumping or "IDLE" end
    tankMethods(m, "Steam", "mekanism:steam", 6.4e5, 0.5, 6)
    return m
end

-- Thermoelectric boiler valve.  options: boil=<mB/t>
MOCK_TYPES.boilerValve = function(o)
    local m = {}
    multiblock(m, o)
    local boil = num(o.boil, 10000)
    m.getTemperature = function() return wave(400, 10, 30) end
    m.getBoilRate = function() return math.floor(math.max(0, wave(boil * 0.7, boil * 0.2, 22))) end
    m.getMaxBoilRate = function() return boil end
    m.getBoilCapacity = function() return boil end
    tankMethods(m, "Water", "minecraft:water", 1.6e6, 0.85, 1)
    tankMethods(m, "Steam", "mekanism:steam", 1.6e6, 0.3, 2)
    tankMethods(m, "HeatedCoolant", "mekanism:superheated_sodium", 1.6e6, 0.0, 3)
    tankMethods(m, "CooledCoolant", "mekanism:sodium", 1.6e6, 0.0, 4)
    return m
end

-- Chemical tank.  options: chemical=<id> capacity=<mB> fill=<0-1> tier=...
MOCK_TYPES.chemicalTank = function(o)
    local m = {}
    local chem, capacity = o.chemical or "mekanism:hydrogen", num(o.capacity, 1.6e7)
    tankMethods(m, "Stored", chem, capacity, num(o.fill, 0.5), 5)
    m.getCapacity, m.getFilledPercentage, m.getNeeded = m.getStoredCapacity, m.getStoredFilledPercentage, m.getStoredNeeded
    local tier = (o.tier or "ADVANCED"):upper()
    m.getTier = function() return tier end
    m.getDumpingMode = function() return "IDLE" end
    return m
end

-- Digital miner.  options: radius= miny= maxy= ores=<count left>
MOCK_TYPES.digitalMiner = function(o)
    local m = {}
    energyMethods(m, o, 5e7, 2)
    local running, startedAt, ores = o.running == "true", now(), num(o.ores, 500)
    local mined = 0
    local function toMine()
        local left = ores - mined - (running and math.floor((now() - startedAt) / 2) or 0)
        return math.max(0, left)
    end
    m.isRunning = function() return running and toMine() > 0 end
    m.start = function() if not running then running, startedAt = true, now() end end
    m.stop = function()
        if running then mined, running = ores - toMine(), false end
    end
    m.reset = function() mined, running = 0, false end
    m.getToMine = toMine
    m.getRadius = function() return num(o.radius, 32) end
    m.getMinY = function() return num(o.miny, -64) end
    m.getMaxY = function() return num(o.maxy, 64) end
    m.getState = function() return m.isRunning() and "SEARCHING" or "IDLE" end
    return m
end

-- Wrap the peripheral API so the mocks look like attached peripherals.
local function installMockPeripherals(entries)
    local mocks, order = {}, {}
    for _, p in ipairs(entries) do
        local make = MOCK_TYPES[p.kind]
        if make and not mocks[p.name] then
            local ok, methods = pcall(make, p.opts or {}, p.name)
            if ok then
                mocks[p.name] = { kind = p.kind, methods = methods }
                order[#order + 1] = p.name
            else
                print("Could not mock " .. p.kind .. " '" .. p.name .. "': " .. tostring(methods))
            end
        end
    end
    if not next(mocks) then return end

    local P, native = peripheral, {}
    for k, v in pairs(peripheral) do native[k] = v end

    local function mockOf(p)
        if type(p) == "string" then return mocks[p], p end
        if type(p) == "table" then
            local mt = getmetatable(p)
            if type(mt) == "table" and mt.CCOSMock then return mocks[mt.name], mt.name end
        end
    end

    function P.getNames()
        local names = native.getNames()
        for _, n in ipairs(order) do names[#names + 1] = n end
        return names
    end
    function P.isPresent(name)
        if mocks[name] then return true end
        return native.isPresent(name)
    end
    function P.getType(p)
        local mock = mockOf(p)
        if mock then return mock.kind end
        return native.getType(p)
    end
    function P.hasType(p, kind)
        local mock = mockOf(p)
        if mock then return mock.kind == kind end
        return native.hasType(p, kind)
    end
    function P.getName(p)
        local mock, name = mockOf(p)
        if mock then return name end
        return native.getName(p)
    end
    function P.getMethods(name)
        local mock = mocks[name]
        if not mock then return native.getMethods(name) end
        local list = {}
        for k in pairs(mock.methods) do list[#list + 1] = k end
        table.sort(list)
        return list
    end
    function P.call(name, method, ...)
        local mock = mocks[name]
        if not mock then return native.call(name, method, ...) end
        local fn = mock.methods[method]
        if not fn then error("No such method " .. tostring(method), 2) end
        return fn(...)
    end
    function P.wrap(name)
        local mock = mocks[name]
        if not mock then return native.wrap(name) end
        local t = {}
        for k, fn in pairs(mock.methods) do t[k] = fn end
        return setmetatable(t, { __name = "peripheral", name = name, type = mock.kind, types = { mock.kind }, CCOSMock = true })
    end
    function P.find(kind, filter)
        local found = {}
        for _, name in ipairs(P.getNames()) do
            if P.hasType(name, kind) then
                local wrapped = P.wrap(name)
                if wrapped and (filter == nil or filter(name, wrapped)) then found[#found + 1] = wrapped end
            end
        end
        return table.unpack(found)
    end
end

-- Handed to vm-startup.lua (both files end up in the same startup.lua).
_G.CCOS_MOCKS = { types = MOCK_TYPES, install = installMockPeripherals }
