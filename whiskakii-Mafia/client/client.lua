-- Main Variables
local ESX = nil
local PlayerData = nil
local menuClosed = true
local pedHandle = nil

-- Load ESX
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(100)
    end

    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(100)
    end

    PlayerData = ESX.GetPlayerData()
    
    -- Only start other threads once ESX is fully loaded
    StartMafiaResource()
end)

-- Event handlers for player data updates
RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    PlayerData = xPlayer
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
    PlayerData.job = job
end)

-- Main resource initialization
function StartMafiaResource()
    -- Create map blip for the gang creation location
    CreateGangCreationBlip()
    
    -- Create the NPC
    CreateGangCreationNPC()
    
    -- Start the interaction loop
    StartInteractionLoop()
end

-- Create map blip
function CreateGangCreationBlip()
    local blip = AddBlipForCoord(Config.PedSettings.coords)
    SetBlipSprite(blip, Config.PedSettings.blipSprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, Config.PedSettings.blipScale)
    SetBlipColour(blip, Config.PedSettings.blipColor)
    SetBlipAsShortRange(blip, true)
    
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Create Your Own Gang')
    EndTextCommandSetBlipName(blip)
end

-- Create the NPC
function CreateGangCreationNPC()
    -- Load the model first
    local modelHash = GetHashKey(Config.PedSettings.model)
    RequestModel(modelHash)
    
    -- Wait for the model to load with a timeout
    local timeout = 5000 -- 5 seconds
    local startTime = GetGameTimer()
    
    while not HasModelLoaded(modelHash) do
        Citizen.Wait(100)
        if GetGameTimer() - startTime > timeout then
            if Config.Debug then
                print('^1[whiskakii-Mafia] Failed to load NPC model after timeout^0')
            end
            return
        end
    end
    
    -- Create the ped once the model is loaded
    pedHandle = CreatePed(2, modelHash, Config.PedSettings.coords, Config.PedSettings.heading, false, true)
    
    -- Set ped properties
    FreezeEntityPosition(pedHandle, true)
    SetEntityInvincible(pedHandle, true)
    SetBlockingOfNonTemporaryEvents(pedHandle, true)
    SetPedDiesWhenInjured(pedHandle, false)
    SetPedCanPlayAmbientAnims(pedHandle, true)
    SetPedCanRagdollFromPlayerImpact(pedHandle, false)
    
    -- Set the ped to scenario
    TaskStartScenarioInPlace(pedHandle, Config.PedSettings.scenario, 0, true)
    
    -- Release the model
    SetModelAsNoLongerNeeded(modelHash)
    
    if Config.Debug then
        print('^2[whiskakii-Mafia] NPC created successfully^0')
    end
end

-- Interaction loop with performance optimizations
function StartInteractionLoop()
    Citizen.CreateThread(function()
        local interactionDistance = Config.PedSettings.interactionDistance
        local interactionKey = Config.PedSettings.interactionKey
        
        while true do
            local playerCoords = GetEntityCoords(PlayerPedId())
            local distance = #(Config.PedSettings.coords - playerCoords)
            
            -- Performance optimization - only check frequently when player is close
            if distance < 10.0 then
                -- Player is in interaction range
                if distance < interactionDistance then
                    -- Show help notification
                    ESX.ShowHelpNotification('Press ~INPUT_CONTEXT~ to interact with ~r~Whiskakii', true, false)
                    
                    -- Check for key press
                    if IsControlJustPressed(0, interactionKey) then
                        openMenu()
                    end
                    
                    Citizen.Wait(0) -- Check every frame when close
                else
                    Citizen.Wait(250) -- Check 4 times per second when nearby
                end
            else
                Citizen.Wait(1000) -- Check once per second when far away
            end
        end
    end)
end


--[[ Event Handlers ]]

-- Close menu event from server
RegisterNetEvent('whiskakii-Mafia:closeMenu')
AddEventHandler('whiskakii-Mafia:closeMenu', function()
    closeMenu()
end)

--[[ NUI Callbacks ]]

-- Handle gang creation request from UI
RegisterNUICallback('onPlayerCreation', function(data, cb)
    -- Validate input
    local gangName = data.value
    
    if not gangName or gangName == '' then
        ESX.ShowNotification('Gang name cannot be empty')
        cb({success = false, message = 'Invalid gang name'})
        return
    end
    
    -- Convert to lowercase for consistency
    gangName = string.lower(gangName)
    
    -- Check if player has a blacklisted job
    for _, blacklistedJob in pairs(Config.BlackListedJobs) do
        if PlayerData.job.name == blacklistedJob then
            ESX.ShowNotification('You can\'t create a gang because of your job: ' .. PlayerData.job.label)
            cb({success = false, message = 'Blacklisted job'})
            return
        end
    end
    
    -- All checks passed, send creation request to server
    TriggerServerEvent('whiskakii-Mafia:sendCreationData', gangName)
    cb({success = true})
end)

-- Handle UI close request
RegisterNUICallback('closeNUI', function(_, cb)
    closeMenu()
    cb({success = true})
end)

--[[ UI Management Functions ]]

-- Open the UI menu
function openMenu()
    if menuClosed then
        -- Focus browser and show cursor
        SetNuiFocus(true, true)
        
        -- Send data to NUI
        SendNUIMessage({
            action = 'show',
            data = {
                cost = Config.Price,
                currency = Config.CurrencyLabel
            }
        })
        
        -- Update menu state
        menuClosed = false
    end
end

-- Close the UI menu
function closeMenu()
    if not menuClosed then
        -- Remove focus from browser and hide cursor
        SetNuiFocus(false, false)
        
        -- Hide UI
        SendNUIMessage({
            action = 'hide'
        })
        
        -- Update menu state
        menuClosed = true
    end
end

-- Cleanup function to ensure proper resource shutdown
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Remove NPC if exists
        if pedHandle ~= nil and DoesEntityExist(pedHandle) then
            DeleteEntity(pedHandle)
        end
        
        -- Remove NUI focus if menu was open
        if not menuClosed then
            SetNuiFocus(false, false)
        end
    end
end)
