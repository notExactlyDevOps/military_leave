surface.CreateFont("MilDocs_Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("MilDocs_TextBold", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("MilDocs_Text", { font = "Roboto", size = 15, weight = 400, extended = true })
surface.CreateFont("MilDocs_TabletSys", { font = "Arial", size = 13, weight = 700, extended = true })
surface.CreateFont("MilDocs_OH_Main", { font = "Roboto", size = 25, weight = 800, extended = true }) -- Главная строка (крупная)
surface.CreateFont("MilDocs_OH_Sub", { font = "Roboto", size = 14, weight = 700, extended = true })  -- Время и причина (поменьше)


local function GetSafeModel(modelPath)
    if not modelPath or modelPath == "" or not util.IsValidModel(modelPath) then
        return "models/player/combine_soldier.mdl"
    end
    return modelPath
end

local blur = Material("pp/blurscreen")
local function DrawBlur(panel, amount)
    local x, y = panel:LocalToScreen(0, 0)
    local scrW, scrH = ScrW(), ScrH()
    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(blur)
    for i = 1, 3 do
        blur:SetFloat("$blur", (i / 3) * (amount or 6))
        blur:Recompute()
        render.UpdateScreenEffectTexture()
        surface.DrawTexturedRect(-x, -y, scrW, scrH)
    end
end

net.Receive("LeaveSys_OpenTablet", function()
    local tablet = vgui.Create("DFrame")
    tablet:SetSize(880, 540)
    tablet:SetTitle("")
    tablet:Center()
    tablet:SetDeleteOnClose(true)
    tablet:ShowCloseButton(false) 
    tablet:MakePopup()
    
    tablet.Paint = function(self, w, h)
        DrawBlur(self, 4)
        draw.RoundedBox(16, 0, 0, w, h, Color(15, 18, 22, 255)) 
        draw.RoundedBox(12, 18, 25, w - 36, h - 45, Color(30, 35, 43, 245)) 
        draw.RoundedBox(4, w/2 - 35, 10, 70, 6, Color(40, 45, 50, 255)) 
        draw.RoundedBox(6, w/2 + 50, 8, 10, 10, Color(5, 5, 20, 255)) 
        draw.RoundedBox(4, w/2 + 53, 11, 4, 4, Color(30, 30, 150, 200)) 
        draw.RoundedBoxEx(12, 18, 25, w - 36, 25, Color(20, 24, 30, 255), true, true, false, false)
        
        draw.SimpleText("Rusklav Minestry Of Defense", "MilDocs_TabletSys", 35, 31, Color(0, 180, 255, 200))
        draw.SimpleText("5G (VoLTE)", "MilDocs_TabletSys", 655, 31, Color(255, 255, 255, 150))
        draw.SimpleText(os.date("%H:%M"), "MilDocs_TabletSys", (w - 36)/2 + 18, 31, Color(255, 255, 255, 220), TEXT_ALIGN_CENTER)
        draw.SimpleText("БАТАРЕЯ: 87% [/// ]    ", "MilDocs_TabletSys", w - 160, 31, Color(76, 175, 80, 200))
        
        draw.RoundedBox(0, 18, 50, w - 36, 45, Color(10, 15, 20, 240)) 
        draw.SimpleText("Управление Составом", "MilDocs_TextBold", 35, 63, Color(0, 215, 255), TEXT_ALIGN_LEFT)
    end

    local closeBtn = vgui.Create("DButton", tablet)
    closeBtn:SetSize(25, 25)
    closeBtn:SetPos(825, 60)
    closeBtn:SetText("✕")
    closeBtn:SetFont("MilDocs_TextBold")
    closeBtn:SetTextColor(Color(220, 80, 80))
    closeBtn.Paint = function() end
    closeBtn.DoClick = function() tablet:Close() end

    local list = vgui.Create("DListView", tablet)
    list:SetPos(35, 110)
    list:SetSize(450, 390)
    list:SetMultiSelect(false)
    list:AddColumn("Военнослужащий"):SetWidth(200)
    list:AddColumn("Должность"):SetWidth(140)
    list:AddColumn("Статус"):SetWidth(110)

    local infoPanel = vgui.Create("DPanel", tablet)
    infoPanel:SetPos(505, 110)
    infoPanel:SetSize(340, 390)
    infoPanel.Paint = function(self, w, h)
        if not self.HasTarget then
            draw.RoundedBox(6, 0, 0, w, h, Color(15, 18, 22, 180))
            draw.SimpleText("ВЫБЕРИТЕ СОТРУДНИКА", "MilDocs_TextBold", w/2, h/2 - 10, Color(90, 100, 110), TEXT_ALIGN_CENTER)
            draw.SimpleText("ДЛЯ СКАНИРОВАНИЯ ДАННЫХ", "MilDocs_Text", w/2, h/2 + 10, Color(70, 80, 90), TEXT_ALIGN_CENTER)
        else
            draw.RoundedBox(6, 0, 0, w, h, Color(38, 44, 52, 255))
            draw.RoundedBox(6, 0, 0, w, 35, Color(15, 20, 25, 255))
            draw.SimpleText("ЛИЧНОЕ ДЕЛО ВОЕННОСЛУЖАЩЕГО", "MilDocs_TextBold", w/2, 10, Color(255, 215, 0), TEXT_ALIGN_CENTER)
        end
    end

    local avatarBack = vgui.Create("DPanel", infoPanel)
    avatarBack:SetSize(110, 110)
    avatarBack:SetPos(115, 45)
    avatarBack:SetVisible(false)
    avatarBack.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(10, 10, 15, 255))
        draw.RoundedBox(4, 2, 2, w-4, h-4, Color(55, 62, 70, 255))
    end

    local icon = vgui.Create("SpawnIcon", avatarBack)
    icon:SetSize(102, 102)
    icon:SetPos(4, 4)

    local lblNameTitle = vgui.Create("DLabel", infoPanel)
    lblNameTitle:SetPos(15, 160)
    lblNameTitle:SetSize(310, 20)
    lblNameTitle:SetFont("MilDocs_TextBold")
    lblNameTitle:SetText("ФИО:")
    lblNameTitle:SetTextColor(Color(160, 160, 160))
    lblNameTitle:SetVisible(false)

    local lblName = vgui.Create("DLabel", infoPanel)
    lblName:SetPos(15, 177)
    lblName:SetSize(310, 20)
    lblName:SetFont("MilDocs_Text")
    lblName:SetTextColor(Color(255, 255, 255))
    lblName:SetVisible(false)

    local lblJobTitle = vgui.Create("DLabel", infoPanel)
    lblJobTitle:SetPos(15, 200)
    lblJobTitle:SetSize(310, 20)
    lblJobTitle:SetFont("MilDocs_TextBold")
    lblJobTitle:SetText("ДОЛЖНОСТЬ / РОЛЬ:")
    lblJobTitle:SetTextColor(Color(160, 160, 160))
    lblJobTitle:SetVisible(false)

    local lblJob = vgui.Create("DLabel", infoPanel)
    lblJob:SetPos(15, 217)
    lblJob:SetSize(310, 20)
    lblJob:SetFont("MilDocs_Text")
    lblJob:SetTextColor(Color(255, 255, 255))
    lblJob:SetVisible(false)

    local lblStatusTitle = vgui.Create("DLabel", infoPanel)
    lblStatusTitle:SetPos(15, 240)
    lblStatusTitle:SetSize(310, 20)
    lblStatusTitle:SetFont("MilDocs_TextBold")
    lblStatusTitle:SetText("ТЕКУЩИЙ СТАТУС:")
    lblStatusTitle:SetTextColor(Color(160, 160, 160))
    lblStatusTitle:SetVisible(false)

    local lblStatus = vgui.Create("DLabel", infoPanel)
    lblStatus:SetPos(15, 257)
    lblStatus:SetSize(310, 20)
    lblStatus:SetFont("MilDocs_TextBold")
    lblStatus:SetVisible(false)

    local lblReasonTitle = vgui.Create("DLabel", infoPanel)
    lblReasonTitle:SetPos(15, 280)
    lblReasonTitle:SetSize(310, 20)
    lblReasonTitle:SetFont("MilDocs_TextBold")
    lblReasonTitle:SetText("ПРИЧИНА ОТЛУЧКИ:")
    lblReasonTitle:SetTextColor(Color(240, 173, 78))
    lblReasonTitle:SetVisible(false)

    local lblReason = vgui.Create("DLabel", infoPanel)
    lblReason:SetPos(15, 297)
    lblReason:SetSize(310, 20)
    lblReason:SetFont("MilDocs_Text")
    lblReason:SetTextColor(Color(255, 255, 255))
    lblReason:SetVisible(false)

    local btnIssue = vgui.Create("DButton", infoPanel)
    btnIssue:SetSize(310, 32)
    btnIssue:SetPos(15, 315)
    btnIssue:SetText("ВЫДАТЬ УВОЛЬНИТЕЛЬНУЮ")
    btnIssue:SetFont("MilDocs_TextBold")
    btnIssue:SetTextColor(Color(255, 255, 255))
    btnIssue:SetVisible(false)

    local btnRevoke = vgui.Create("DButton", infoPanel)
    btnRevoke:SetSize(310, 32)
    btnRevoke:SetPos(15, 315)
    btnRevoke:SetText("АННУЛИРОВАТЬ УВОЛЬНИТЕЛЬНУЮ")
    btnRevoke:SetFont("MilDocs_TextBold")
    btnRevoke:SetTextColor(Color(255, 255, 255))
    btnRevoke:SetVisible(false)
    btnRevoke.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(150, 30, 30)) else draw.RoundedBox(4, 0, 0, w, h, Color(180, 40, 40)) end
    end

    local btnFire = vgui.Create("DButton", infoPanel)
    btnFire:SetSize(310, 32)
    btnFire:SetPos(15, 352)
    btnFire:SetText("СНЯТЬ С ДОЛЖНОСТИ (УВОЛИТЬ)")
    btnFire:SetFont("MilDocs_TextBold")
    btnFire:SetTextColor(Color(255, 255, 255))
    btnFire:SetVisible(false)
    btnFire.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(180, 20, 20)) else draw.RoundedBox(4, 0, 0, w, h, Color(220, 30, 30)) end
    end

    net.Start("LeaveSys_RequestRoster")
    net.SendToServer()

    net.Receive("LeaveSys_SendRoster", function()
    if not IsValid(list) then return end
    list:Clear()
    local roster = net.ReadTable()
    for _, info in ipairs(roster) do
        if IsValid(info.ent) then
            local statusText = "● В ЧАСТИ"
            local colColor = Color(76, 175, 80) 
            
            if info.currentStatusRaw == "active" then
                statusText = "● В ОТЛУЧКЕ"
                colColor = Color(255, 152, 0) 
            elseif info.currentStatusRaw == "expired" then
                statusText = "● СРОК ИСТЕК"
                colColor = Color(220, 40, 40) 
            elseif info.currentStatusRaw == "soch" then
                statusText = "● СОЧ"
                colColor = Color(255, 0, 0) 
            end

            local line = list:AddLine(info.name, info.job, statusText)
            line.PlayerEntity = info.ent
            line.PlayerCmd = info.cmd
            line.HasLeave = info.hasLeave
            line.CurrentStatusRaw = info.currentStatusRaw
            line.PlayerModel = info.ent:GetModel()
            line.LeaveReasonText = info.leaveReason or ""
            
            for i = 1, 3 do
                if line.Columns[i] then line.Columns[i]:SetTextColor(colColor) end
            end
        end
    end
end)

list.OnRowSelected = function(lst, index, pnl)
    if not IsValid(pnl.PlayerEntity) then return end
    
    infoPanel.HasTarget = true
    icon:SetModel(GetSafeModel(pnl.PlayerModel))
    lblName:SetText(pnl.PlayerEntity:Nick())
    lblJob:SetText(pnl.PlayerEntity:getDarkRPVar("job") or "Неизвестно")
    
    btnFire:SetVisible(true)
    
    if pnl.CurrentStatusRaw == "active" then
        lblStatus:SetText("Увольнительная активна")
        lblStatus:SetTextColor(Color(255, 152, 0))
        lblReason:SetText(pnl.LeaveReasonText ~= "" and pnl.LeaveReasonText or "Не указана")
        lblReasonTitle:SetVisible(true)
        lblReason:SetVisible(true)
        btnIssue:SetVisible(false)
        btnRevoke:SetVisible(true)
    elseif pnl.CurrentStatusRaw == "expired" then
        lblStatus:SetText("Срок увольнительной истёк")
        lblStatus:SetTextColor(Color(220, 40, 40))
        lblReasonTitle:SetVisible(false)
        lblReason:SetVisible(false)
        btnIssue:SetVisible(false)
        btnRevoke:SetVisible(true)
    elseif pnl.CurrentStatusRaw == "soch" then
        lblStatus:SetText("С.О.Ч. / Дезертирство!")
        lblStatus:SetTextColor(Color(255, 0, 0))
        lblReasonTitle:SetVisible(false)
        lblReason:SetVisible(false)
        btnIssue:SetVisible(false)
        btnRevoke:SetVisible(false)
    else
        lblStatus:SetText("На службе в расположении")
        lblStatus:SetTextColor(Color(76, 175, 80))
        lblReasonTitle:SetVisible(false)
        lblReason:SetVisible(false)
        btnIssue:SetVisible(true)
        btnRevoke:SetVisible(false)
    end
    
    avatarBack:SetVisible(true)
    lblNameTitle:SetVisible(true)
    lblName:SetVisible(true)
    lblJobTitle:SetVisible(true)
    lblJob:SetVisible(true)
    lblStatusTitle:SetVisible(true)
    lblStatus:SetVisible(true)

    local highRanks = { ["fbicid"] = true, ["general"] = true }
    if highRanks[pnl.PlayerCmd] then
        btnFire:SetVisible(false)
        if pnl.CurrentStatusRaw == "soch" or pnl.CurrentStatusRaw == "expired" then
        else
            if pnl.CurrentStatusRaw == "active" then
                lblStatus:SetText("В ОТЛУЧКЕ")
                lblStatus:SetTextColor(Color(255, 152, 0))
                btnIssue:SetVisible(false)
                btnRevoke:SetVisible(true)
            else
                lblStatus:SetText("В ШТАБЕ")
                lblStatus:SetTextColor(Color(0, 200, 255))
                btnIssue:SetVisible(true)
                btnRevoke:SetVisible(false)
            end
        end
    end

        btnIssue.Paint = function(self, w, h)
            if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(46, 125, 50)) else draw.RoundedBox(4, 0, 0, w, h, Color(56, 142, 60)) end
        end
        btnIssue.DoClick = function()
            local targetPlayer = pnl.PlayerEntity
            if not IsValid(targetPlayer) then return end

            tablet:SetVisible(false) 

            local frame = vgui.Create("DFrame")
            frame:SetSize(560, 240)
            frame:SetTitle("")
            frame:Center()
            frame:MakePopup()
            frame.Paint = function(self, w, h)
                DrawBlur(self, 4)
                draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 40, 240))
                draw.RoundedBox(6, 0, 0, w, 30, Color(20, 25, 30, 255))
                draw.SimpleText("ВЫДАЧА УВОЛЬНИТЕЛЬНОЙ: " .. targetPlayer:Nick(), "MilDocs_TextBold", 10, 7, Color(220, 220, 220), TEXT_ALIGN_LEFT)
            end

            local backBtn = vgui.Create("DButton", frame)
            backBtn:SetSize(100, 30)
            backBtn:SetPos(325, 0)
            backBtn:SetText("< Назад")
            backBtn:SetFont("MilDocs_TextBold")
            backBtn:SetTextColor(Color(200, 200, 200))
            backBtn.Paint = function() end
            backBtn.DoClick = function() frame:Close() tablet:SetVisible(true) end

            local lblReasonEntry = vgui.Create("DLabel", frame)
            lblReasonEntry:SetPos(155, 45)
            lblReasonEntry:SetFont("MilDocs_TextBold")
            lblReasonEntry:SetText("Цель / Причина отлучки:")
            lblReasonEntry:SetTextColor(Color(180, 180, 180))
            lblReasonEntry:SizeToContents()

            local txtReason = vgui.Create("DTextEntry", frame)
            txtReason:SetPos(55, 65)
            txtReason:SetSize(430, 30)
            txtReason:SetFont("MilDocs_Text")
            txtReason:SetText("По семейным обстоятельствам")

            local lblTime = vgui.Create("DLabel", frame)
            lblTime:SetPos(155, 110)
            lblTime:SetFont("MilDocs_TextBold")
            lblTime:SetText("Время действия (в минутах):")
            lblTime:SetTextColor(Color(180, 180, 180))
            lblTime:SizeToContents()

            local numTime = vgui.Create("DNumberWang", frame)
            numTime:SetPos(200, 130)
            numTime:SetSize(120, 30)
            numTime:SetFont("MilDocs_Text")
            numTime:SetMin(5)
            numTime:SetMax(180)
            numTime:SetValue(30)

            local btnSubmit = vgui.Create("DButton", frame)
            btnSubmit:SetPos(110, 185)
            btnSubmit:SetSize(330, 40)
            btnSubmit:SetText("ПОДПИСАТЬ И ВЫДАТЬ")
            btnSubmit:SetFont("MilDocs_Title")
            btnSubmit:SetTextColor(Color(255, 255, 255))
            btnSubmit.Paint = function(self, w, h)
                if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(46, 125, 50)) else draw.RoundedBox(4, 0, 0, w, h, Color(56, 142, 60)) end
            end
            btnSubmit.DoClick = function()
                net.Start("LeaveSys_IssueLeave")
                    net.WriteEntity(targetPlayer)
                    net.WriteUInt(numTime:GetValue(), 16)
                    net.WriteString(txtReason:GetValue())
                net.SendToServer()
                frame:Close()
                tablet:Close()
            end
        end

        btnRevoke.DoClick = function()
            tablet:Close()
            net.Start("LeaveSys_RevokeLeave")
                net.WriteEntity(pnl.PlayerEntity)
            net.SendToServer()
        end

        btnFire.DoClick = function()
            local selectedID = list:GetSelectedLine()
            if not selectedID then return end
            local line = list:GetLine(selectedID)
            if not line or not IsValid(line.PlayerEntity) then return end

            local targetPlayer = line.PlayerEntity

            tablet:SetVisible(false) 
            Derma_StringRequest(
                "Разжалование", 
                "Укажите официальную причину снятия с должности бойца " .. targetPlayer:Nick() .. ":", 
                "Нарушение воинского устава / Дезертирство", 
                function(text)
                    if not IsValid(targetPlayer) then return end
                    
                    net.Start("LeaveSys_FirePlayer")
                        net.WriteEntity(targetPlayer)
                        net.WriteString(text)
                    net.SendToServer()
                    
                    tablet:Close()
                end, 
                function()
                    tablet:SetVisible(true) 
                end
            )
        end
    end
end)

hook.Add("PostPlayerDraw", "LeaveSys_DrawOverheadStatus", function(ply)
    if not IsValid(ply) or not ply:Alive() or ply == LocalPlayer() then return end
    if ply:GetNoDraw() then return end
    
    local status = ply:GetNW2String("LeaveSys_Status", "")
    if status == "" or status == nil then return end
    local distance = LocalPlayer():GetPos():DistToSqr(ply:GetPos())
    if distance > 400000 then return end

    local bone = ply:LookupBone("ValveBiped.Bip01_Head1")
    local pos = bone and (ply:GetBonePosition(bone) + Vector(0, 0, 18)) or (ply:GetPos() + Vector(0, 0, 80))
    local angle = EyeAngles()
    angle:RotateAroundAxis(angle:Up(), -90)
    angle:RotateAroundAxis(angle:Forward(), 90)
    
    cam.Start3D2D(pos, angle, 0.1)
        local mainText, mainColor, showSubInfo
        
        if status == "active" then
            mainText = "[ В ОТЛУЧКЕ ]"
            mainColor = Color(240, 173, 78)
            showSubInfo = true
        elseif status == "expired" then
            mainText = "[ СРОК УВОЛЬНИТЕЛЬНОЙ ИСТЕК ]"
            mainColor = Color(220, 40, 40)
            showSubInfo = false
        elseif status == "soch" then
            mainText = "[ С.О.Ч. / ДЕЗЕРТИР ]"
            local blink = math.abs(math.sin(CurTime() * 4))
            mainColor = Color(255 * blink, 0, 0) 
            showSubInfo = false
        else
            cam.End3D2D()
            return
        end
        
        local boxHeight = showSubInfo and 75 or 36
        local boxWidth = (status == "expired" or status == "soch") and 480 or 250
        
        draw.RoundedBox(6, -boxWidth/2, -5, boxWidth, boxHeight, Color(15, 20, 25, 230))

        draw.SimpleText(mainText, "MilDocs_OH_Main", 0, 12, mainColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        
        if showSubInfo then
            local timeLeft = ply:GetNW2Int("LeaveSys_TimeLeft", 0)
            local reason = ply:GetNW2String("LeaveSys_Reason", "Не указана")
            
            draw.SimpleText("Остаток времени: " .. timeLeft .. " мин.", "MilDocs_OH_Sub", 0, 38, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Цель: " .. reason, "MilDocs_OH_Sub", 0, 56, Color(170, 180, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end)

surface.CreateFont("MilDocs_HUD_Notify", { font = "Roboto", size = 28, weight = 800, extended = true })

local notifyText = ""
local notifyColor = Color(255, 255, 255)
local notifyTime = 0

net.Receive("LeaveSys_CrossBoundaryNotify", function()
    local isEntering = net.ReadBool()
    
    if isEntering then
        notifyText = "ВЫ ЗАШЛИ НА ТЕРРИТОРИЮ ВЧ"
        notifyColor = Color(46, 204, 113)
        surface.PlaySound("buttons/blip1.wav")
    else
        notifyText = "ВЫ ВЫШЛИ В ГОРОД"
        notifyColor = Color(231, 76, 60)
        surface.PlaySound("ambient/alarms/warningbell1.wav")
    end
    
    notifyTime = CurTime() + 4
end)

hook.Add("HUDPaint", "LeaveSys_DrawBoundaryHUD", function()
    if notifyTime > CurTime() then
        local w, h = ScrW(), ScrH()
        local boxW, boxH = 450, 50
        local x, y = w / 2 - boxW / 2, 60

        local alpha = math.Clamp((notifyTime - CurTime()) * 255, 0, 240)

        draw.RoundedBox(6, x, y, boxW, boxH, Color(15, 20, 25, alpha))
        draw.RoundedBoxEx(6, x, y, 8, boxH, Color(notifyColor.r, notifyColor.g, notifyColor.b, alpha), true, false, true, false)

        draw.SimpleText(notifyText, "MilDocs_HUD_Notify", w / 2, y + boxH / 2, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

LeaveSys = LeaveSys or {}
function LeaveSys.OpenTablet() 
    RunConsoleCommand("leavesys_open_tablet") 
end

