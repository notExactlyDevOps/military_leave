util.AddNetworkString("LeaveSys_OpenTablet")
util.AddNetworkString("LeaveSys_RequestRoster")
util.AddNetworkString("LeaveSys_SendRoster")
util.AddNetworkString("LeaveSys_OpenIssueMenu")
util.AddNetworkString("LeaveSys_IssueLeave")
util.AddNetworkString("LeaveSys_RevokeLeave")
util.AddNetworkString("LeaveSys_FirePlayer")

util.AddNetworkString("LeaveSys_OpenToolMenu")
util.AddNetworkString("LeaveSys_SaveZoneFromTool")
util.AddNetworkString("LeaveSys_SyncZonesToClient")
util.AddNetworkString("LeaveSys_CrossBoundaryNotify")
util.AddNetworkString("LeaveSys_DeleteZone")
util.AddNetworkString("LeaveSys_RenameZone")

LeaveSys = LeaveSys or {}
LeaveSys.Zones = LeaveSys.Zones or {}

local SAVE_FILE_PATH = "military_leave_zones.json"

local LEAVE_CONFIG = {
    AllowedToReceive = { ["sebmedic"] = true, ["fbicid"] = true },
    AllowedToIssue = { ["fbicid"] = true }
}

local function GetPlayerCommand(ply)
    if not IsValid(ply) then return "" end
    if ply.getJobTable and ply:getJobTable() and ply:getJobTable().command then
        return string.lower(ply:getJobTable().command)
    end
    return ""
end

local function SyncZones(ply)
    local compressedData = {}
    for name, v in pairs(LeaveSys.Zones) do
        if v.min and v.max then
            compressedData[name] = {
                min = { x = v.min.x, y = v.min.y, z = v.min.z },
                max = { x = v.max.x, y = v.max.y, z = v.max.z }
            }
        end
    end
    net.Start("LeaveSys_SyncZonesToClient")
    net.WriteTable(compressedData)
    if ply then net.Send(ply) else net.Broadcast() end
end

local function SaveZonesToFile()
    local saveData = {}
    for name, v in pairs(LeaveSys.Zones) do
        saveData[name] = {
            min = { x = v.min.x, y = v.min.y, z = v.min.z },
            max = { x = v.max.x, y = v.max.y, z = v.max.z }
        }
    end
    file.Write(SAVE_FILE_PATH, util.TableToJSON(saveData, true))
    SyncZones()
end

local function LoadZones()
    if file.Exists(SAVE_FILE_PATH, "DATA") then
        local rawData = file.Read(SAVE_FILE_PATH, "DATA")
        local decoded = util.JSONToTable(rawData)
        if decoded then
            LeaveSys.Zones = {}
            for name, data in pairs(decoded) do
                if data.min and data.max then
                    LeaveSys.Zones[name] = {
                        min = Vector(data.min.x, data.min.y, data.min.z),
                        max = Vector(data.max.x, data.max.y, data.max.z)
                    }
                end
            end
            print("[LeaveSys] База постоянных зон успешно загружена.")
            return
        end
    end
end

hook.Add("Initialize", "LeaveSys_LoadZonesOnStart", function()
    LoadZones()
end)

hook.Add("PlayerInitialSpawn", "LeaveSys_SyncOnSpawn", function(ply)
    timer.Simple(4, function() if IsValid(ply) then SyncZones(ply) end end)
end)

local function IsSuperAdmin(ply)
    if not IsValid(ply) then return false end
    if sam and sam.player then return ply:HasPermission("manage_military_zones") or ply:IsSuperAdmin() end
    return ply:IsSuperAdmin()
end


net.Receive("LeaveSys_SaveZoneFromTool", function(len, ply)
    if not IsSuperAdmin(ply) then return end

    local zoneName = net.ReadString()
    local p1 = net.ReadVector()
    local p2 = net.ReadVector()

    local minVec = Vector(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.min(p1.z, p2.z))
    local maxVec = Vector(math.max(p1.x, p2.x), math.max(p1.y, p2.y), math.max(p1.z, p2.z))

    LeaveSys.Zones[zoneName] = { min = minVec, max = maxVec }
    SaveZonesToFile()
    ply:ChatPrint("Зона '" .. zoneName .. "' успешно добавлена.")
end)

net.Receive("LeaveSys_DeleteZone", function(len, ply)
    if not IsSuperAdmin(ply) then return end
    local zoneName = net.ReadString()

    if LeaveSys.Zones[zoneName] then
        LeaveSys.Zones[zoneName] = nil
        SaveZonesToFile()
        ply:ChatPrint("Зона '" .. zoneName .. "' полностью удалена из JSON.")
    end
end)

net.Receive("LeaveSys_RenameZone", function(len, ply)
    if not IsSuperAdmin(ply) then return end
    local oldName = net.ReadString()
    local newName = net.ReadString()

    if LeaveSys.Zones[oldName] and newName ~= "" then
        LeaveSys.Zones[newName] = LeaveSys.Zones[oldName]
        LeaveSys.Zones[oldName] = nil
        SaveZonesToFile()
        ply:ChatPrint("Зона успешно переименована в '" .. newName .. "'.")
    end
end)

local function IsInBaseZone(pos)
    if not LeaveSys.Zones or table.Count(LeaveSys.Zones) == 0 then return false end
    for _, zone in pairs(LeaveSys.Zones) do
        if zone.min and zone.max then
            if (pos.x >= zone.min.x and pos.x <= zone.max.x) and
               (pos.y >= zone.min.y and pos.y <= zone.max.y) then
                return true
            end
        end
    end
    return false
end
timer.Create("LeaveSys_TriggerCheck", 1, 0, function()
    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) or not p:Alive() then continue end
        
        local pCmd = GetPlayerCommand(p)
        if not LEAVE_CONFIG.AllowedToReceive[pCmd] and not LEAVE_CONFIG.AllowedToIssue[pCmd] then continue end

        local currentStatus = p:GetNW2String("LeaveSys_Status", "")
        local inZone = IsInBaseZone(p:GetPos())
        
        p.LeaveSys_WasInZone = p.LeaveSys_WasInZone or false

        if inZone then
            if not p.LeaveSys_WasInZone then
                net.Start("LeaveSys_CrossBoundaryNotify")
                net.WriteBool(true)
                net.Send(p)
                p.LeaveSys_WasInZone = true
            end

            if currentStatus == "expired" or currentStatus == "soch" then
                p:SetNW2String("LeaveSys_Status", "") 
                p:SetNW2String("LeaveSys_Reason", "")
                p:SetNW2Int("LeaveSys_TimeLeft", 0)
                p:ChatPrint("Вы вернулись в расположение части. Нарушение аннулировано.")
            end
        else
            if p.LeaveSys_WasInZone then
                net.Start("LeaveSys_CrossBoundaryNotify")
                net.WriteBool(false)
                net.Send(p)
                p.LeaveSys_WasInZone = false
            end

            if currentStatus == "" then
                p:SetNW2String("LeaveSys_Status", "soch")
                p:SetNW2String("LeaveSys_Reason", "Самовольное оставление части")
                DarkRP.notifyAll(1, 4, "Боец " .. p:Nick() .. " покинул расположение части! Выставлен статус: СОЧ.")
            end
        end
    end
end)

timer.Create("LeaveSys_GlobalTimer", 60, 0, function()
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:GetNW2String("LeaveSys_Status", "") == "active" then
            local timeLeft = p:GetNW2Int("LeaveSys_TimeLeft", 0)
            if timeLeft > 1 then
                p:SetNW2Int("LeaveSys_TimeLeft", timeLeft - 1)
            else
                p:SetNW2String("LeaveSys_Status", "expired")
                p:SetNW2Int("LeaveSys_TimeLeft", 0)
                p:ChatPrint("Срок увольнительной истек!")
                DarkRP.notifyAll(1, 4, "У бойца " .. p:Nick() .. " истекла увольнительная!")
            end
        end
    end
end)

net.Receive("LeaveSys_RequestRoster", function(len, ply)
    if not IsValid(ply) or not LEAVE_CONFIG.AllowedToIssue[GetPlayerCommand(ply)] then return end
    local roster = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local pCmd = GetPlayerCommand(p)
            if LEAVE_CONFIG.AllowedToReceive[pCmd] or LEAVE_CONFIG.AllowedToIssue[pCmd] then
                local status = p:GetNW2String("LeaveSys_Status", "")
                
                local statusText = "● В ЧАСТИ"
                if status == "active" then statusText = "● В ОТЛУЧКЕ"
                elseif status == "expired" then statusText = "● СРОК ИСТЕК"
                elseif status == "soch" then statusText = "● СОЧ" end

                roster[#roster + 1] = {
                    ent = p,
                    name = p:Nick(),
                    job = p:getDarkRPVar("job") or "Неизвестно",
                    cmd = pCmd,
                    hasLeave = (status == "active" or status == "expired"),
                    currentStatusRaw = status,
                    leaveReason = p:GetNW2String("LeaveSys_Reason", "")
                }
            end
        end
    end
    net.Start("LeaveSys_SendRoster")
    net.WriteTable(roster)
    net.Send(ply)
end)

net.Receive("LeaveSys_IssueLeave", function(len, ply)
    if not LEAVE_CONFIG.AllowedToIssue[GetPlayerCommand(ply)] then return end
    local target = net.ReadEntity()
    local duration = net.ReadUInt(16)
    local reason = net.ReadString()
    if not IsValid(target) or not target:IsPlayer() then return end
    
    target:SetNW2String("LeaveSys_Status", "active")
    target:SetNW2Int("LeaveSys_TimeLeft", duration)
    target:SetNW2String("LeaveSys_Reason", reason)
    ply:ChatPrint("Вы выдали увольнительную бойцу " .. target:Nick())
end)

net.Receive("LeaveSys_RevokeLeave", function(len, ply)
    if not LEAVE_CONFIG.AllowedToIssue[GetPlayerCommand(ply)] then return end
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end
    target:SetNW2String("LeaveSys_Status", "")
    target:SetNW2Int("LeaveSys_TimeLeft", 0)
    target:SetNW2String("LeaveSys_Reason", "")
    ply:ChatPrint("Вы аннулировали увольнительную бойца " .. target:Nick())
end)

net.Receive("LeaveSys_FirePlayer", function(len, ply)
    if not IsValid(ply) or not LEAVE_CONFIG.AllowedToIssue[GetPlayerCommand(ply)] then return end
    
    local target = net.ReadEntity()
    local reason = net.ReadString()
    
    if not IsValid(target) or not target:IsPlayer() then return end
    if LEAVE_CONFIG.AllowedToIssue[GetPlayerCommand(target)] then return end

    local citizenTeam = TEAM_CITIZEN or 1

    target:SetNW2String("LeaveSys_Status", "")
    target:SetNW2Int("LeaveSys_TimeLeft", 0)
    target:SetNW2String("LeaveSys_Reason", "")
    target.LeaveSys_WasInZone = false

    target:changeTeam(citizenTeam, true, true)
    
    DarkRP.notifyAll(1, 4, "Боец " .. target:Nick() .. " был снят с должности офицером " .. ply:Nick() .. ". Причина: " .. reason)
end)

concommand.Add("leavesys_open_tablet", function(ply) 
    if IsValid(ply) and LEAVE_CONFIG.AllowedToIssue[GetPlayerCommand(ply)] then 
        net.Start("LeaveSys_OpenTablet") 
        net.Send(ply) 
    elseif IsValid(ply) then
        ply:ChatPrint("Отказано в доступе! У вас нет полномочий для управления планшетом.")
    end
end)