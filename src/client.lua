-- For support join my discord: https://discord.gg/Z9Mxu72zZ6

local NDCore = nil
if GetResourceState("ND_Core") == "started" then
    NDCore = exports["ND_Core"]
end

local priorityText = ""
local aopText = ""
local zoneName = ""
local streetName = ""
local crossingRoad = ""
local nearestPostal = {}
local compass = ""
local time = ""
local hidden = false
local cash = ""
local bank = ""
local postals = {}
local displayedSpeed = 0.0
local displayedFuel = 100.0
local displayedEngine = 100.0

if config.enableSpeedometerMetric then
    speedCalc = 3.6
    speedText = "kmh"
else
    speedCalc = 2.236936
    speedText = "mph"
end
for _, vehicleName in pairs(config.electricVehiles) do
    config.electricVehiles[GetHashKey(vehicleName)] = vehicleName
end


function getAOP()
    return aopText
end

function text(text, x, y, scale, font)
    SetTextFont(font)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextDropShadow(0, 0, 0, 0,255)
    SetTextOutline()
    SetTextJustification(1)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

function getHeading(heading)
    if ((heading >= 0 and heading < 45) or (heading >= 315 and heading < 360)) then
        return "N" -- North
    elseif (heading >= 45 and heading < 135) then
        return "W" -- West
    elseif (heading >= 135 and heading < 225) then
        return "S" -- South
    elseif (heading >= 225 and heading < 315) then
        return "E" -- East
    else
        return " "
    end
end

function getTime()
    hour = GetClockHours()
    minute = GetClockMinutes()
    if hour <= 9 then
        hour = "0" .. hour
    end
    if minute <= 9 then
        minute = "0" .. minute
    end
    return hour .. ":" .. minute
end


-- basic helpers for UI smoothing and clamping
function lerp(a, b, t)
    return a + (b - a) * t
end

function clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end


if config.enableMoneyHud and NDCore then
    AddEventHandler("playerSpawned", function()
        local selectedCharacter = NDCore.getPlayer()
        if not selectedCharacter then return end
        cash = selectedCharacter.cash
        bank = selectedCharacter.bank
    end)

    AddEventHandler("onResourceStart", function(resourceName)
        if (GetCurrentResourceName() ~= resourceName) then
        return
        end
        Wait(3000)
        local selectedCharacter = NDCore.getPlayer()
        if not selectedCharacter then return end
        cash = selectedCharacter.cash
        bank = selectedCharacter.bank
    end)

    RegisterNetEvent("ND:setCharacter")
    AddEventHandler("ND:setCharacter", function(character)
        local selectedCharacter = character
        if not selectedCharacter then return end
        cash = selectedCharacter.cash
        bank = selectedCharacter.bank
    end)

    RegisterNetEvent("ND:updateCharacter")
    AddEventHandler("ND:updateCharacter", function(character)
        local selectedCharacter = character
        if not selectedCharacter then return end
        cash = selectedCharacter.cash
        bank = selectedCharacter.bank
    end)

    RegisterNetEvent("ND:updateMoney")
    AddEventHandler("ND:updateMoney", function(updatedCash, updatedBank)
        cash = updatedCash
        bank = updatedBank
    end)
end

if config.enableAopStatus then
    RegisterNetEvent("AndyHUD:ChangeAOP")
    AddEventHandler("AndyHUD:ChangeAOP", function(aop)
        aopText = aop
    end)
    TriggerEvent("chat:addSuggestion", "/aop", "Change the current area of play?", {{name="Area", help=""}})
end

if config.enablePriorityStatus then
    TriggerEvent("chat:addSuggestion", "/prio-start", "Start a priority.")
    TriggerEvent("chat:addSuggestion", "/prio-stop", "Stop an active priority.")
    TriggerEvent("chat:addSuggestion", "/prio-cd", "Start a cooldown on priorities.", {
        {name="Time", help="Time in minutes to start a cooldown"}
    })
    TriggerEvent("chat:addSuggestion", "/prio-join", "Join the current priority.")
    TriggerEvent("chat:addSuggestion", "/prio-leave", "Leave the current priority.")

    RegisterNetEvent("AndyHUD:returnPriority")
    AddEventHandler("AndyHUD:returnPriority", function(priority)
        priorityText = priority
    end)
end

AddEventHandler("playerSpawned", function()
    if config.enableAopStatus then
        TriggerServerEvent("AndyHUD:getAop")
    end
    if config.enablePriorityStatus then
        TriggerServerEvent("AndyHUD:getPriority")
    end
end)

AddEventHandler("onResourceStart", function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then
      return
    end
    Wait(3000)
    if config.enableAopStatus then
        TriggerServerEvent("AndyHUD:getAop")
    end
    if config.enablePriorityStatus then
        TriggerServerEvent("AndyHUD:getPriority")
    end
end)

function markPostal(code)
    for i = 1, #postals do
        local postal = postals[i]
        if postal.code == code then
            SetNewWaypoint(postal.coords.x, postal.coords.y)
            return
        end
    end
end

RegisterCommand("postal", function(source, args, rawCommand)
    if not args[1] then return end
    markPostal(args[1])
end, false)

RegisterCommand("p", function(source, args, rawCommand)
    if not args[1] then return end
    markPostal(args[1])
end, false)

TriggerEvent("chat:addSuggestion", "/postal", "Mark a postal on the map", {{name="postal", help="The postal code"}})
TriggerEvent("chat:addSuggestion", "/p", "Mark a postal on the map", {{name="postal", help="The postal code"}})

function getPostal()
    return nearestPostal.code, nearestPostal
end

CreateThread(function()
    postals = json.decode(LoadResourceFile(GetCurrentResourceName(), "postals.json"))
    
    for i = 1, #postals do
        local postal = postals[i]
        postals[i] = {
            coords = vec(postal.x, postal.y),
            code = postal.code
        }
    end
end)

CreateThread(function()
    local totalPostals = #postals
    while true do
        ped = PlayerPedId()
        pedCoords = GetEntityCoords(ped)
        local nearestDist = nil
        local nearestIndex = nil
        local coords = vec(pedCoords.x, pedCoords.y)

        for i = 1, totalPostals do
            local dist = #(coords - postals[i].coords)
            if not nearestDist or dist < nearestDist then
                nearestDist = dist
                nearestIndex = i
            end
        end

        nearestPostal = postals[nearestIndex]

        streetName, crossingRoad = GetStreetNameAtCoord(pedCoords.x, pedCoords.y, pedCoords.z)
        streetName = GetStreetNameFromHashKey(streetName)
        crossingRoad = GetStreetNameFromHashKey(crossingRoad)
        zoneName = GetLabelText(GetNameOfZone(pedCoords.x, pedCoords.y, pedCoords.z))
        if config.streetNames[streetName] then
            streetName = config.streetNames[streetName]
        end
        if config.streetNames[crossingRoad] then
            crossingRoad = config.streetNames[crossingRoad]
        end
        if config.zoneNames[zoneName] then
            zoneName = config.zoneNames[zoneName]
        end
        if getHeading(GetEntityHeading(ped)) then
            compass = getHeading(GetEntityHeading(ped))
        end
        if crossingRoad ~= "" then
            streetName = streetName .. " ~c~/ " .. crossingRoad
        else
            streetName = streetName
        end

        Wait(1000)
    end
end)

CreateThread(function()
    Wait(500)
    while true do
        Wait(300)
        time = getTime()
        hidden = IsHudHidden()
        vehicle = GetVehiclePedIsIn(ped)
        vehClass = GetVehicleClass(vehicle)
        driver = GetPedInVehicleSeat(vehicle, -1)
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if config.enableMoneyHud and NDCore then
            text("💵", 0.885, 0.028, 0.35, 7)
            text("💳", 0.885, 0.068, 0.35, 7)
            text("~g~$~w~".. cash, 0.91, 0.03, 0.55, 7)
            text("~b~$~w~".. bank, 0.91, 0.07, 0.55, 7)
        end
        if not hidden then
            if config.enableAopStatus then
                text("~s~AOP: ~c~" .. aopText, 0.168, 0.868, 0.40, 4)
            end
            if config.enablePriorityStatus then
                text(priorityText, 0.168, 0.890, 0.40, 4)
            end
            if config.enablePostals and nearestPostal and nearestPostal.code then
                text("~s~Nearby Postal: ~c~(" .. nearestPostal.code .. ")", 0.168, 0.912, 0.40, 4)
            end
            text("~c~" .. time .. " ~s~" .. zoneName, 0.168, 0.96, 0.40, 4)
            text("~c~| ~s~" .. compass .. " ~c~| ~s~" .. streetName, 0.168, 0.932, 0.55, 4)
        end
        if vehicle ~= 0 and vehClass ~= 13 and driver then
            -- modern cluster (bottom-right)
            local baseX = 0.90
            local baseY = 0.915
            local bgW  = 0.176
            local bgH  = 0.108
            DrawRect(baseX, baseY, bgW, bgH, 0, 0, 0, 120)

            -- speed (smoothed)
            local targetSpeed = GetEntitySpeed(vehicle) * speedCalc
            displayedSpeed = lerp(displayedSpeed, targetSpeed, 0.15)
            local speedValue = math.floor(displayedSpeed + 0.5)
            text(tostring(speedValue), baseX - 0.070, baseY - 0.020, 0.7, 4)
            text(speedText,           baseX + 0.005, baseY - 0.004, 0.35, 4)

            -- bars baseline
            local barLeftX = baseX - (bgW / 2) + 0.014
            local fuelY    = baseY + 0.022
            local engY     = baseY + 0.047
            local barW     = bgW - 0.028
            local barH     = 0.010

            -- fuel
            if config.enableFuelHUD then
                local rawFuel = GetVehicleFuelLevel(vehicle) or 0.0
                local fuelPct = clamp((rawFuel / 100.0), 0.0, 1.0)
                displayedFuel = lerp(displayedFuel, fuelPct * 100.0, 0.10)
                local currentFuelPct = clamp(displayedFuel / 100.0, 0.0, 1.0)

                -- background
                DrawRect(baseX, fuelY, barW, barH + 0.006, 40, 40, 40, 150)

                -- choose color
                local isElectric = config.electricVehiles[GetEntityModel(vehicle)] ~= nil
                local r, g, b = 206, 145, 40
                if isElectric then r, g, b = 20, 140, 255 end
                if currentFuelPct <= 0.15 then r, g, b = 200, 40, 40 end

                -- fill from left
                local leftEdge = baseX - (barW / 2)
                local fillW = barW * currentFuelPct
                local fillX = leftEdge + (fillW / 2)
                DrawRect(fillX, fuelY, fillW, barH, r, g, b, 220)
                text(isElectric and "⛽ (E)" or "⛽", barLeftX, fuelY - 0.008, 0.30, 4)
            end

            -- engine health - show small symbol with % of damage (badness)
            if config.enableEngineHUD then
                local rawHealth = GetVehicleEngineHealth(vehicle) or 0.0 -- 0 to 1000
                local engPct = clamp(rawHealth / 1000.0, 0.0, 1.0)        -- 1.0 = perfect, 0.0 = blown
                local badPct = math.floor((1.0 - engPct) * 100.0 + 0.5)   -- 0 = good, 100 = worst

                -- choose text color by severity of damage
                local colorPrefix = "~g~"                                -- green when <= 20% bad
                if badPct > 20 and badPct <= 50 then colorPrefix = "~y~" end -- yellow
                if badPct > 50 and badPct <= 75 then colorPrefix = "~o~" end -- orange
                if badPct > 75 then colorPrefix = "~r~" end                 -- red

                -- display compact gear icon with percent badness
                text(colorPrefix .. "⚙ " .. tostring(badPct) .. "%~w~", barLeftX, engY - 0.008, 0.30, 4)
            end
        end
    end
end)
