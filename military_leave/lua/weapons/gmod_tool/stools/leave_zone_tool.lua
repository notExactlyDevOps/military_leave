TOOL.Category = "Military Admin"
TOOL.Name = "#Tool.leave_zone_tool.name"
TOOL.Command = nil
TOOL.ConfigName = ""

LeaveSys = LeaveSys or {}
LeaveSys.ClientZones = LeaveSys.ClientZones or {}
LeaveSys.TempPoints = LeaveSys.TempPoints or {}

local ActiveCPanel = nil

if CLIENT then
    language.Add("Tool.leave_zone_tool.name", "Зоны Части (JSON)")
    language.Add("Tool.leave_zone_tool.desc", "Создание, удаление и редактирование геозон.")
    language.Add("Tool.leave_zone_tool.left", "ЛКМ: Добавить/Установить опорную точку диагонали (макс. 2)")
    language.Add("Tool.leave_zone_tool.right", "ПКМ: Стереть последнюю поставленную точку")

    net.Receive("LeaveSys_SyncZonesToClient", function()
        local raw = net.ReadTable()
        LeaveSys.ClientZones = {}
        for name, data in pairs(raw) do
            if data.min and data.max then
                LeaveSys.ClientZones[name] = {
                    min = Vector(data.min.x, data.min.y, data.min.z),
                    max = Vector(data.max.x, data.max.y, data.max.z)
                }
            end
        end
        
        if ActiveCPanel and ActiveCPanel:IsValid() then
            ActiveCPanel:Clear()
            local tool = LocalPlayer():GetTool("leave_zone_tool")
            if tool then tool.BuildCPanel(ActiveCPanel) end
        end
    end)

    net.Receive("LeaveSys_OpenToolMenu", function()
        local isMenu = net.ReadBool()
        local count = net.ReadUInt(4)
        LeaveSys.TempPoints = {}
        for i = 1, count do LeaveSys.TempPoints[i] = net.ReadVector() end
    end)
end

local function IsSuperAdmin(ply)
    if not IsValid(ply) then return false end
    if sam and sam.player then return ply:HasPermission("manage_military_zones") or ply:IsSuperAdmin() end
    return ply:IsSuperAdmin()
end

if SERVER then
    function TOOL:LeftClick(trace)
        local ply = self:GetOwner()
        if not IsSuperAdmin(ply) then return false end

        ply.LeaveSys_TempFB = ply.LeaveSys_TempFB or {}
        if #ply.LeaveSys_TempFB >= 2 then
            ply:ChatPrint("[Тул] Вы уже наметили 2 точки! Сохраните их в CPanel справа.")
            return false
        end

        table.insert(ply.LeaveSys_TempFB, trace.HitPos)
        ply:ChatPrint("[Тул] Опорная точка #" .. #ply.LeaveSys_TempFB .. " зафиксирована кликом ЛКМ.")

        net.Start("LeaveSys_OpenToolMenu")
        net.WriteBool(false)
        net.WriteUInt(#ply.LeaveSys_TempFB, 4)
        for i = 1, #ply.LeaveSys_TempFB do net.WriteVector(ply.LeaveSys_TempFB[i]) end
        net.Send(ply)

        return true
    end

    function TOOL:RightClick(trace)
        local ply = self:GetOwner()
        if not IsSuperAdmin(ply) then return false end

        ply.LeaveSys_TempFB = ply.LeaveSys_TempFB or {}
        if #ply.LeaveSys_TempFB == 0 then return false end

        table.remove(ply.LeaveSys_TempFB)
        ply:ChatPrint("[Тул] Точка удалена кликом ПКМ.")

        net.Start("LeaveSys_OpenToolMenu")
        net.WriteBool(false)
        net.WriteUInt(#ply.LeaveSys_TempFB, 4)
        for i = 1, #ply.LeaveSys_TempFB do net.WriteVector(ply.LeaveSys_TempFB[i]) end
        net.Send(ply)

        return true
    end

    function TOOL:Reload(trace) return false end
end

if CLIENT then
    local function DrawSolidAABB(min, max, color)
        render.SetColorMaterial()
        
        local visualMin = Vector(min.x, min.y, min.z - 40)
        local visualMax = Vector(max.x, max.y, max.z + 1200)

        render.DrawBox(Vector(0, 0, 0), Angle(0, 0, 0), visualMin, visualMax, Color(color.r, color.g, color.b, 25))
        render.DrawWireframeBox(Vector(0, 0, 0), Angle(0, 0, 0), visualMin, visualMax, color, true)
    end

    hook.Add("PostDrawTranslucentRenderables", "LeaveSys_DrawToolBoxes", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end

        local activeWeapon = ply:GetActiveWeapon()
        if not IsValid(activeWeapon) or activeWeapon:GetClass() != "gmod_weapon_tool" then return end

        local activeTool = ply:GetTool()
        if not activeTool or activeTool.Mode != "leave_zone_tool" then return end

        if LeaveSys.ClientZones then
            for name, zone in pairs(LeaveSys.ClientZones) do
                if zone.min and zone.max then
                    DrawSolidAABB(zone.min, zone.max, Color(46, 204, 113, 200))
                end
            end
        end

        if LeaveSys.TempPoints and #LeaveSys.TempPoints > 0 then
            render.SetColorMaterial()
            render.DrawSphere(LeaveSys.TempPoints[1], 8, 8, 8, Color(230, 126, 34, 255))
            
            if #LeaveSys.TempPoints == 2 then
                local p1 = LeaveSys.TempPoints[1]
                local p2 = LeaveSys.TempPoints[2]
                local min = Vector(math.min(p1.x, p2.x), math.min(p1.y, p2.y), math.min(p1.z, p2.z))
                local max = Vector(math.max(p1.x, p2.x), math.max(p1.y, p2.y), math.max(p1.z, p2.z))

                DrawSolidAABB(min, max, Color(230, 126, 34, 255))
            end
        end
    end)

    function TOOL.BuildCPanel(panel)
        ActiveCPanel = panel
        
        panel:AddControl("Header", { Text = "Конструктор зон ВЧ", Description = "ЛКМ - добавление точки. ПКМ - удаление предыдущей поставленной точки." })

        local txtName = vgui.Create("DTextEntry", panel)
        txtName:SetPlaceholderText("Название новой зоны...")
        txtName:SetText("Территория Части")
        panel:AddItem(txtName)

        local btnSave = vgui.Create("DButton", panel)
        btnSave:SetText("СОХРАНИТЬ ЗОНУ В JSON")
        btnSave:SetImage("icon16/disk.png")
        btnSave.DoClick = function()
            if txtName:GetValue() == "" or not LeaveSys.TempPoints or #LeaveSys.TempPoints < 2 then return end

            net.Start("LeaveSys_SaveZoneFromTool")
                net.WriteString(txtName:GetValue())
                net.WriteVector(LeaveSys.TempPoints[1])
                net.WriteVector(LeaveSys.TempPoints[2])
            net.SendToServer()

            LeaveSys.TempPoints = {}
        end
        panel:AddItem(btnSave)

        local btnClear = vgui.Create("DButton", panel)
        btnClear:SetText("Сбросить текущую разметку")
        btnClear:SetImage("icon16/delete.png")
        btnClear.DoClick = function() LeaveSys.TempPoints = {} end
        panel:AddItem(btnClear)

        local lblTitle = vgui.Create("DLabel", panel)
        lblTitle:SetText("\nСПИСОК АКТИВНЫХ ЗОН НА СЕРВЕРЕ:")
        lblTitle:SetFont("DermaDefaultBold")
        lblTitle:SetTextColor(Color(200, 200, 200))
        lblTitle:SizeToContents()
        panel:AddItem(lblTitle)

        local zoneList = vgui.Create("DListView", panel)
        zoneList:SetHeight(150)
        zoneList:SetMultiSelect(false)
        zoneList:AddColumn("Название зоны")

        if LeaveSys.ClientZones then
            for zoneName, _ in pairs(LeaveSys.ClientZones) do
                zoneList:AddLine(zoneName)
            end
        end
        panel:AddItem(zoneList)

        local btnDeleteZone = vgui.Create("DButton", panel)
        btnDeleteZone:SetText("УДАЛИТЬ ВЫБРАННУЮ ЗОНУ")
        btnDeleteZone:SetImage("icon16/cross.png")
        btnDeleteZone.DoClick = function()
            local selected = zoneList:GetSelectedLine()
            if not selected then return end
            local line = zoneList:GetLine(selected)
            local name = line:GetValue(1)

            net.Start("LeaveSys_DeleteZone")
                net.WriteString(name)
            net.SendToServer()
        end
        panel:AddItem(btnDeleteZone)

        local btnRenameZone = vgui.Create("DButton", panel)
        btnRenameZone:SetText("ПЕРЕИМЕНОВАТЬ ЗОНУ")
        btnRenameZone:SetImage("icon16/textfield_rename.png")
        btnRenameZone.DoClick = function()
            local selected = zoneList:GetSelectedLine()
            if not selected then return end
            local line = zoneList:GetLine(selected)
            local oldName = line:GetValue(1)

            Derma_StringRequest(
                "Переименование зоны",
                "Укажите новое название для геозоны '" .. oldName .. "':",
                oldName,
                function(newName)
                    if newName == "" or newName == oldName then return end
                    net.Start("LeaveSys_RenameZone")
                        net.WriteString(oldName)
                        net.WriteString(newName)
                    net.SendToServer()
                end
            )
        end
        panel:AddItem(btnRenameZone)
    end
end
