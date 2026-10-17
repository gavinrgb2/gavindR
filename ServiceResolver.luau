--[[
    ServiceResolver (versi executor)
    Satu script, tanpa require/ModuleScript. Aman dijalankan berulang kali.

    Cara pakai:
        local S = loadstring(readfile("ServiceResolver_Executor.luau"))()
        -- atau tempel langsung di bagian atas script kamu.
        -- Setelah dijalankan sekali, juga tersedia global: getgenv().ServiceResolver

        local Players = S.Players
        local UIS, RS = S:GetMany("UserInputService", "RunService")
        local VIM = S:Get("VirtualInputManager")
        local gui = S:GetGuiParent()   -- gethui() / CoreGui / PlayerGui
]]

local env = (getgenv and getgenv()) or _G

-- Kalau sudah pernah dimuat, pakai instance yang sama
if env.ServiceResolver then
	return env.ServiceResolver
end

local ServiceResolver = {}

local cache = {}
local missing = {}

local _cloneref = cloneref or (env and env.cloneref)

local function protect(obj)
	if type(_cloneref) == "function" then
		local ok, clone = pcall(_cloneref, obj)
		if ok and clone then
			return clone
		end
	end
	return obj
end

-- Ambil service. nil kalau tidak ada (tidak error).
function ServiceResolver:Get(name)
	local cached = cache[name]
	if cached ~= nil then
		return cached
	end
	if missing[name] then
		return nil
	end

	local ok, service = pcall(game.GetService, game, name)
	if not (ok and service) then
		service = game:FindFirstChild(name)
	end

	if service then
		service = protect(service)
		cache[name] = service
		return service
	end

	missing[name] = true
	return nil
end

-- Ambil service wajib, error jelas kalau tidak ada.
function ServiceResolver:Require(name)
	local service = self:Get(name)
	if service == nil then
		error(("ServiceResolver: service '%s' tidak ditemukan"):format(tostring(name)), 2)
	end
	return service
end

function ServiceResolver:GetMany(...)
	local names = { ... }
	local out = {}
	for i = 1, #names do
		out[i] = self:Get(names[i])
	end
	return table.unpack(out, 1, #names)
end

function ServiceResolver:Has(name)
	return self:Get(name) ~= nil
end

function ServiceResolver:Preload(names)
	for _, name in ipairs(names) do
		self:Get(name)
	end
end

function ServiceResolver:Clear(name)
	if name then
		cache[name] = nil
		missing[name] = nil
	else
		table.clear(cache)
		table.clear(missing)
	end
end

-- ===== Tambahan khusus executor =====

-- Parent terbaik untuk GUI: gethui() -> CoreGui -> PlayerGui
function ServiceResolver:GetGuiParent()
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui then
			return hui
		end
	end

	local core = self:Get("CoreGui")
	if core then
		local ok = pcall(function()
			local probe = Instance.new("Folder")
			probe.Parent = core
			probe:Destroy()
		end)
		if ok then
			return core
		end
	end

	local lp = self:GetLocalPlayer()
	return lp and lp:WaitForChild("PlayerGui")
end

function ServiceResolver:GetLocalPlayer()
	local players = self:Get("Players")
	return players and players.LocalPlayer
end

function ServiceResolver:GetCharacter()
	local lp = self:GetLocalPlayer()
	return lp and lp.Character
end

function ServiceResolver:GetHumanoid()
	local char = self:GetCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

function ServiceResolver:GetRoot()
	local char = self:GetCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

function ServiceResolver:GetCamera()
	return workspace.CurrentCamera
end

-- Akses langsung: ServiceResolver.Players, ServiceResolver.RunService, dst.
-- (nama method di atas diprioritaskan karena ada di tabel)
setmetatable(ServiceResolver, {
	__index = function(self, key)
		if type(key) == "string" then
			return ServiceResolver.Get(self, key)
		end
		return nil
	end,
})

env.ServiceResolver = ServiceResolver
return ServiceResolver
