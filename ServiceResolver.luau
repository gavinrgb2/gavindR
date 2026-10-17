--!strict
--[[
    ServiceResolver
    Mengambil service Roblox dengan aman + cache.

    Pemakaian:
        local S = require(path.ServiceResolver)       -- ModuleScript
        -- atau: local S = loadstring(readfile("ServiceResolver.luau"))()

        local Players = S.Players                     -- akses langsung (lazy + cache)
        local UIS = S:Get("UserInputService")         -- via method
        local a, b = S:GetMany("RunService", "Lighting")
        if S:Has("VirtualInputManager") then ... end
]]

local ServiceResolver = {}

local cache: { [string]: any } = {}
local missing: { [string]: boolean } = {}

-- cloneref (executor) dipakai kalau ada, supaya referensi service aman dari deteksi
local cloneref = (getgenv and (getgenv() :: any).cloneref) or (cloneref :: any)
local function protect(service: any): any
	if type(cloneref) == "function" then
		local ok, clone = pcall(cloneref, service)
		if ok and clone then
			return clone
		end
	end
	return service
end

-- Ambil service. Mengembalikan nil kalau service tidak ada (tidak error).
function ServiceResolver:Get(name: string): any?
	local cached = cache[name]
	if cached ~= nil then
		return cached
	end
	if missing[name] then
		return nil
	end

	local ok, service = pcall(function()
		return game:GetService(name)
	end)

	if ok and service then
		service = protect(service)
		cache[name] = service
		return service
	end

	-- fallback: cari lewat FindFirstChild (beberapa service tidak bisa lewat GetService)
	local found = game:FindFirstChild(name)
	if found then
		found = protect(found)
		cache[name] = found
		return found
	end

	missing[name] = true
	return nil
end

-- Ambil service wajib. Error jelas kalau tidak ketemu.
function ServiceResolver:Require(name: string): any
	local service = self:Get(name)
	if service == nil then
		error(("ServiceResolver: service '%s' tidak ditemukan"):format(name), 2)
	end
	return service
end

-- Ambil banyak service sekaligus, urutan sesuai input.
function ServiceResolver:GetMany(...: string): ...any
	local names = { ... }
	local out = table.create(#names)
	for i, name in ipairs(names) do
		out[i] = self:Get(name)
	end
	return table.unpack(out, 1, #names)
end

-- Cek apakah service tersedia.
function ServiceResolver:Has(name: string): boolean
	return self:Get(name) ~= nil
end

-- Panaskan cache untuk daftar service (opsional).
function ServiceResolver:Preload(names: { string })
	for _, name in ipairs(names) do
		self:Get(name)
	end
end

-- Hapus cache (mis. setelah teleport / reset). Satu nama atau semuanya.
function ServiceResolver:Clear(name: string?)
	if name then
		cache[name] = nil
		missing[name] = nil
	else
		table.clear(cache)
		table.clear(missing)
	end
end

-- Akses langsung: ServiceResolver.Players, ServiceResolver.RunService, dst.
setmetatable(ServiceResolver, {
	__index = function(self, key)
		if type(key) == "string" then
			return ServiceResolver.Get(self, key)
		end
		return nil
	end,
})

return ServiceResolver
