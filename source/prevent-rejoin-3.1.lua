local TARGET_USERNAMES = {
    "TargetUsername2",
    "TargetUsername2",
    "TargetUsername3"
}

local TARGET_GROUP_ID = 13746149 -- Replace with the target Group ID
local CHECK_ANY_MEMBER = false   -- Set to true to flag any member, false to look for a specific rank or higher
local MIN_RANK_HANDLED = 10    -- Only used if CHECK_ANY_MEMBER is false

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local targetSet = {}
for _, name in ipairs(TARGET_USERNAMES) do
    targetSet[name] = true
end

local function leaveGame()
    LocalPlayer:Kick("Target detected. Evacuating session.")
end

local function serverHop()
    local servers = {}
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    local success, res = pcall(function()
        return game:HttpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true")
    end)
    
    if success and res then
        local decodeSuccess, body = pcall(function()
            return HttpService:JSONDecode(res)
        end)
        
        if decodeSuccess and body and body.data then
            for _, v in next, body.data do
                if type(v) == "table" and tonumber(v.playing) and tonumber(v.maxPlayers) and v.playing < v.maxPlayers and v.id ~= jobId then
                    table.insert(servers, v.id)
                end
            end
        end
    end

    if #servers > 0 then
        local randomServer = servers[math.random(1, math.min(#servers, 10))]
        local teleportSuccess, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, randomServer, LocalPlayer)
        end)
        
        if not teleportSuccess then
            leaveGame()
        end
    else
        leaveGame()
    end
end

local function sendWarningNotification(player)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "⚠️ Moderator in game! ⚠️",
            Text = string.format("%s is in this session!", player.Name),
            Duration = 10,
            Button1 = "Dismiss"
        })
    end)
end

local function checkPlayer(player)
    if player == LocalPlayer then return end
    
    local shouldEvacuate = false
    
    if targetSet[player.Name] then
        shouldEvacuate = true
    elseif TARGET_GROUP_ID then
        local inGroup = false
        pcall(function()
            if CHECK_ANY_MEMBER then
                inGroup = player:IsInGroup(TARGET_GROUP_ID)
            else
                inGroup = player:GetRankInGroup(TARGET_GROUP_ID) >= MIN_RANK_HANDLED
            end
        end)
        if inGroup then
            shouldEvacuate = true
        end
    end
    
    if shouldEvacuate then
        sendWarningNotification(player)
        task.defer(serverHop)
        
        task.delay(5, function()
            if Players:FindFirstChild(player.Name) then
                leaveGame()
            end
        end)
    end
end

Players.PlayerAdded:Connect(checkPlayer)

task.spawn(function()
    while true do
        for _, player in ipairs(Players:GetPlayers()) do
            checkPlayer(player)
        end
        task.wait(3)
    end
end)
