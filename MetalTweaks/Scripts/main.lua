-- MetalTweaks: Metal Bringer multipliers, controlled by MetalTweaksPanel through settings.txt / status.txt
-- (both next to this mod's Scripts folder). Every value x1 = off. Memory only: nothing touches the save file
-- format or the DataTables.
--   coin   : D.Chip (PlayerState.Coin) gains xN. Only increases <= MAX_STEP are
--            multiplied, decreases (spending) are untouched, a new PlayerState only resyncs.
--   disk   : each disk (chip, CoinMgr item type 1) the game drops brings N-1 extra disks drawn from the same
--            floor bag (MainSeq.ChipWaitList), so floor limits and the rarity weights below still apply.
--   rarity : Rank 4/5 chips weigh xN inside the floor's chip bags; chips the floor excluded stay excluded.
--   exp    : every MainSeq.AddExp(ID, Val) the game makes is followed by AddExp(ID, Val*(N-1)), so the game's own
--            level-up logic handles the extra EXP.
--   hit    : the player's hit combo (BP_Labor.Comb, the HUD's HIT) grows xN per hit; it still resets on timeout.

math.randomseed(os.time())
local DIR = debug.getinfo(1, "S").source:match("^@(.*[\\/])[Ss]cripts[\\/]") or ""
local SETTINGS, STATUS = DIR .. "settings.txt", DIR .. "status.txt"
local LIMITS = { coin = 20, disk = 10, rarity = 20, exp = 20, hit = 20 }
local cfg = { coin = 1, disk = 1, rarity = 1, exp = 1, hit = 1 }
local st = { coinBonus = 0, diskExtra = 0, expBonus = 0, share = "-", floor = "-", inGame = false, last = "loaded" }

local TAG = "[MetalTweaks] "
local function note(msg) -- panel's "Last:" line only; for events that fire many times a second
    st.last = os.date("%H:%M:%S ") .. msg
end

local function log(msg)
    print(TAG .. msg .. "\n")
    note(msg)
end

local function get(obj, key)
    local ok, v = pcall(function() return obj[key] end)
    if ok then return v end
end

-- ===== settings / status files =====
local function readSettings()
    local f = io.open(SETTINGS, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^%s*(%w+)%s*=%s*(%d+)")
        if k and LIMITS[k] then cfg[k] = math.max(1, math.min(LIMITS[k], tonumber(v))) end -- file is user-editable
    end
    f:close()
end

local function writeStatus()
    local f = io.open(STATUS, "w")
    if not f then return end
    f:write(string.format(
        "updated=%d\ningame=%s\nfloor=%s\ncoin=%d\ncoin_bonus=%d\ndisk=%d\ndisk_extra=%d\nrarity=%d\nrarity_share=%s\n" ..
        "exp=%d\nexp_bonus=%d\nhit=%d\nlast=%s\n",
        os.time(), st.inGame and "1" or "0", tostring(st.floor), cfg.coin, st.coinBonus, cfg.disk, st.diskExtra,
        cfg.rarity, st.share, cfg.exp, st.expBonus, cfg.hit, st.last))
    f:close()
end

-- ===== chip bags (rarity) =====
local BOOST_RANKS = { [4] = true, [5] = true } -- ChipData.Rank 4/5 = SR/SSR
local BAGS = { "ChipWaitList", "ChipWaitListSingle", "ChipWaitListSingle_Skill" }
local RANK_FIELD = "Rank_28_9361E7DF4695AA0C82DD38AE333F77D8"

local chipRank -- chip ID -> Rank, read once from the ChipData DataTable
local function ranks()
    if chipRank then return chipRank end
    for _, dt in ipairs(FindAllOf("DataTable") or {}) do
        local ok, rs = pcall(function() return dt:GetRowStruct():GetFName():ToString() end)
        if ok and rs == "S_ChipData" then
            local t = {}
            dt:ForEachRow(function(rowName, row) t[tonumber(tostring(rowName))] = get(row, RANK_FIELD) end)
            chipRank = t
            return t
        end
    end
end

-- nil while the bag is unreadable (seen mid boss-area transition); an error escaping a ForEach callback
-- also trips UE4SS's own "Ref was not function", so the callback never throws.
local function toTable(arr)
    local t, bad = {}, false
    arr:ForEach(function(_, e)
        local ok, v = pcall(function() return e:get() end)
        if ok and type(v) == "number" then t[#t + 1] = v else bad = true end
    end)
    if not bad then return t end
end

local function writeArr(arr, t)
    local n = 0
    arr:ForEach(function(_, e) n = n + 1; e:set(t[n]) end)
end

local function sameList(a, b)
    if not a or not b or #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    return true
end

-- Same length as the game's bag; slot k takes the chip at quantile (k-0.5)/L of the boosted weights.
local function weighted(orig, rk, mult)
    local w, ids, total = {}, {}, 0
    for _, id in ipairs(orig) do
        if not w[id] then ids[#ids + 1] = id; w[id] = 0 end
        w[id] = w[id] + (BOOST_RANKS[rk[id]] and mult or 1)
    end
    for _, id in ipairs(ids) do total = total + w[id] end
    local L, k, acc, out = #orig, 1, 0, {}
    for _, id in ipairs(ids) do
        acc = acc + w[id]
        while k <= L and (k - 0.5) / L * total <= acc do out[k] = id; k = k + 1 end
    end
    return out
end

local function boostedShare(list, rk)
    local n = 0
    for _, id in ipairs(list) do if BOOST_RANKS[rk[id]] then n = n + 1 end end
    return #list > 0 and n * 100 / #list or 0
end

local original, lastWritten = {}, {} -- per bag: game-built contents / what we wrote (so weights never stack)

-- Re-apply whenever a bag differs from what we last wrote (floor change, boss area, reload, new MainSeq).
local function applyRarity(seq, force)
    local rk = ranks()
    if not rk then return end -- ChipData not loaded yet; next tick retries
    for _, name in ipairs(BAGS) do
        local arr = get(seq, name)
        if arr then
            local cur = toTable(arr)
            local fresh = cur and not sameList(cur, lastWritten[name])
            if fresh then original[name] = cur end
            if cur and (fresh or force) and #cur > 0 then
                local out = weighted(original[name], rk, cfg.rarity)
                writeArr(arr, out)
                lastWritten[name] = out
                if name == "ChipWaitList" then
                    st.share = string.format("%.1f%%->%.1f%%", boostedShare(original[name], rk), boostedShare(out, rk))
                    log(string.format("rarity x%d: %s [%d] Rank4/5 %s", cfg.rarity, name, #out, st.share))
                end
            end
        end
    end
end

-- ===== gain multipliers (D.Chip, HIT combo) =====
local MAX_STEP = 1000 -- per-tick increase cap: a save load / scene change must not get multiplied

-- Returns a tick(obj) that multiplies increases of obj[field] by cfg[key]. Decreases (spending, a combo
-- reset) and a new object (scene change, reload) only resync.
local function gainTicker(field, key, onBonus)
    local addr, last
    return function(obj)
        if not (obj and obj:IsValid()) then last = nil return end
        local cur = get(obj, field)
        if type(cur) ~= "number" then last = nil return end
        local a = obj:GetAddress()
        if a ~= addr or last == nil then addr, last = a, cur return end
        local d = cur - last
        if d > 0 and d <= MAX_STEP and cfg[key] > 1 then
            local add = d * (cfg[key] - 1)
            obj[field] = cur + add
            cur = cur + add
            if onBonus then onBonus(add) end
        end
        last = cur
    end
end

local coinPS, player
local coinTick = gainTicker("Coin", "coin", function(add) st.coinBonus = st.coinBonus + add end)
local hitTick = gainTicker("Comb", "hit")

-- ===== extra disks =====
local spawning, pendingDisks = false, {}

local function flushDisks()
    if #pendingDisks == 0 then return end
    local list = pendingDisks
    pendingDisks = {}
    local mgr, seq = FindFirstOf("MBCoinMgr"), FindFirstOf("MainSeq_C")
    if not (mgr and mgr:IsValid() and seq and seq:IsValid()) then return end
    local bag = toTable(seq.ChipWaitList)
    if not bag or #bag == 0 then return end
    for _, p in ipairs(list) do
        for _ = 1, p.n do
            local id = bag[math.random(#bag)]
            spawning = true
            local ok, err = pcall(function()
                mgr:AddItem(1, { X = id, Y = 0, Z = 0, W = 0 }, { X = p.x, Y = p.y, Z = p.z }, {}, "", p.mode, p.start)
            end)
            spawning = false
            if not ok then log("extra disk failed: " .. tostring(err)) return end
            st.diskExtra = st.diskExtra + 1
        end
    end
end

local ok, err = pcall(RegisterHook, "/Script/MetalBringer.MBCoinMgr:AddItem",
    function(ctx, typ, addP, loc, itemRef, extra, mode, startType)
        if spawning or cfg.disk <= 1 or typ:get() ~= 1 then return end
        local l = loc:get()
        -- spawn on a later tick, outside the game's own AddItem call
        pendingDisks[#pendingDisks + 1] = { x = get(l, "X"), y = get(l, "Y"), z = get(l, "Z"),
            mode = mode:get(), start = startType:get(), n = cfg.disk - 1 }
    end)
if not ok then log("AddItem hook failed, disk multiplier disabled: " .. tostring(err)) end

-- ===== EXP =====
local EXP_FN = "/Game/Core/Sequence/MainSeq.MainSeq_C:AddExp"
local expHooked, expGranting, pendingExp = false, false, {}

-- Blueprint hooks need the class loaded, so this runs from the 1 s loop once a MainSeq exists.
local function hookExp()
    if expHooked then return end
    expHooked = true
    local okh, errh = pcall(RegisterHook, EXP_FN, function(_ctx, id, val)
        if expGranting or cfg.exp <= 1 then return end
        local i, v = id:get(), val:get()
        if v > 0 then pendingExp[i] = (pendingExp[i] or 0) + v * (cfg.exp - 1) end
    end)
    if not okh then log("AddExp hook failed, EXP multiplier disabled: " .. tostring(errh)) end
end

-- Granted on a later tick, outside the game's own AddExp call (same reason as the extra disks).
local function flushExp()
    if next(pendingExp) == nil then return end
    local list = pendingExp
    pendingExp = {}
    local seq = FindFirstOf("MainSeq_C")
    if not (seq and seq:IsValid()) then return end
    for id, v in pairs(list) do
        expGranting = true
        local okg, errg = pcall(function() seq:AddExp(id, v) end)
        expGranting = false
        if not okg then log("extra EXP failed: " .. tostring(errg)) return end
        st.expBonus = st.expBonus + v
        note(string.format("exp x%d: AddExp(%d) +%d", cfg.exp, id, v))
    end
end

-- ===== loops =====
-- Game-thread timers only. LoopAsync + ExecuteInGameThread built closures on UE4SS's async thread while the game
-- thread ran this mod's hooks; the shared Lua state got corrupted ("Ref was not function") and crashed the game.
LoopInGameThreadWithDelay(100, function()
    pcall(coinTick, coinPS)
    pcall(hitTick, player)
    local okd, errd = pcall(flushDisks)
    if not okd then log("disk error: " .. tostring(errd)) end
    local oke, erre = pcall(flushExp)
    if not oke then log("exp error: " .. tostring(erre)) end
end)

local lastRarity
LoopInGameThreadWithDelay(1000, function()
    readSettings()
    coinPS = FindFirstOf("BP_MetalPlayerState_C")
    player = FindFirstOf("BP_Player_C")
    local seq = FindFirstOf("MainSeq_C")
    st.inGame = seq ~= nil and seq:IsValid()
    if st.inGame then
        hookExp()
        st.floor = tostring(get(get(seq, "SaveData") or {}, "SaveFloor"))
        local okr, errr = pcall(applyRarity, seq, cfg.rarity ~= lastRarity)
        if okr then lastRarity = cfg.rarity else log("rarity error: " .. tostring(errr)) end
    end
    writeStatus()
end)

local existing = io.open(SETTINGS, "r")
if existing then
    existing:close()
else -- first run: create defaults for the panel
    local f = io.open(SETTINGS, "w")
    if f then f:write("coin=1\ndisk=1\nrarity=1\nexp=1\nhit=1\n"); f:close() end
end
log("loaded, settings: " .. SETTINGS)
