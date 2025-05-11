ESX = nil

-- Cache for checking if the account refresh handlers have been registered
local accountRefreshHandlersRegistered = false
local jobRefreshHandlersRegistered = false

-- When resource starts, we need to initialize
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        while ESX == nil do
            TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
            Wait(10)
        end
        
        -- Make sure we have our event handlers registered
        RegisterESXEventHandlers()
        
        -- Notify in the console
        print('^2[whiskakii-Mafia] Resource started^0')
    end
end)

-- Register our ESX event handlers
function RegisterESXEventHandlers()
    -- First check if the ESX functions exist, and if not, create them
    
    -- Check if esx_addonaccount has the refreshAccounts event handler
    if not accountRefreshHandlersRegistered then
        -- Register our custom event handler for refreshing accounts
        TriggerEvent('esx_addonaccount:isRefreshHandlerRegistered', function(isRegistered)
            if not isRegistered then
                print('^3[whiskakii-Mafia] Registering esx_addonaccount:refreshAccounts event handler^0')
                -- Create a temporary event to handle account refresh
                AddEventHandler('esx_addonaccount:refreshAccounts', function()
                    -- Forward to the actual handler in esx_addonaccount
                    TriggerEvent('esx_addonaccount:refreshAccountsInternal')
                end)
                
                accountRefreshHandlersRegistered = true
            else
                print('^2[whiskakii-Mafia] esx_addonaccount:refreshAccounts already registered^0')
                accountRefreshHandlersRegistered = true
            end
        end)
    end
    
    -- Check if es_extended has the refreshJobs event handler
    if not jobRefreshHandlersRegistered then
        -- Register our custom event handler for refreshing jobs
        TriggerEvent('esx:isRefreshJobsHandlerRegistered', function(isRegistered)
            if not isRegistered then
                print('^3[whiskakii-Mafia] Registering esx:refreshJobs event handler^0')
                -- Create a temporary event to handle job refresh
                AddEventHandler('esx:refreshJobs', function()
                    -- Forward to the actual handler in es_extended
                    TriggerEvent('esx:refreshJobsInternal')
                end)
                
                jobRefreshHandlersRegistered = true
            else
                print('^2[whiskakii-Mafia] esx:refreshJobs already registered^0')
                jobRefreshHandlersRegistered = true
            end
        end)
    end
end

-- Main event for gang creation
RegisterServerEvent('whiskakii-Mafia:sendCreationData')
AddEventHandler('whiskakii-Mafia:sendCreationData', function(creationData)
    -- Validate input to prevent SQL injection
    if type(creationData) ~= 'string' or creationData:match('[^%w_]') then
        -- Send error if invalid characters (only allow alphanumeric and underscore)
        local xPlayer = ESX.GetPlayerFromId(source)
        xPlayer.showNotification('Invalid gang name. Use only letters, numbers, and underscores.')
        closeMenu(xPlayer)
        return
    end
    
    local playerId = source 
    local xPlayer = ESX.GetPlayerFromId(playerId)
    
    if not xPlayer then
        print("^1[whiskakii-Mafia] ERROR: Player not found.^0")
        return
    end

    -- Check if player is in a blacklisted job
    for _, blacklistedJob in pairs(Config.BlackListedJobs) do
        if xPlayer.job.name == blacklistedJob then
            xPlayer.showNotification('You can\'t create a gang because of your job: ' .. xPlayer.job.label)
            closeMenu(xPlayer)
            return
        end
    end

    -- Check if the job already exists
    if ESX.DoesJobExist(creationData, 1) then
        xPlayer.showNotification('Criminal Job ' .. creationData .. ' already exists. Try another name!')
        closeMenu(xPlayer)
    else
        xPlayer.showNotification('Criminal Job ' .. creationData .. ' is available. Please wait a moment...')
        startCreation(xPlayer, creationData)
    end
end)

-- Check if player can afford the gang creation
startCreation = function(xPlayer, creationData)
    local playerMoney = xPlayer.getAccount(Config.Currency).money

    if playerMoney >= Config.Price then
        xPlayer.removeAccountMoney(Config.Currency, Config.Price)
        accountCreation(creationData, xPlayer)
    else
        xPlayer.showNotification('You don\'t have enough ' .. Config.CurrencyLabel .. '!')
        closeMenu(xPlayer)
    end
end

-- Create all necessary database entries for the new gang
accountCreation = function(creationData, xPlayer)
    local society = "society_" .. creationData
    local queries = 0
    local totalQueries = 7 -- Total number of queries we'll execute
    local errorOccurred = false
    
    -- Create society accounts, inventory, and datastore
    MySQL.Async.execute('INSERT INTO addon_account (name, label, shared) VALUES (@name, @label, @shared)', {
        ['@name'] = society,
        ['@label'] = creationData,
        ['@shared'] = 1
    }, function(rowsChanged)
        queries = queries + 1
        if rowsChanged == 0 then errorOccurred = true end
        checkCompletion()
    end)

    MySQL.Async.execute('INSERT INTO addon_inventory (name, label, shared) VALUES (@name, @label, @shared)', {
        ['@name'] = society,
        ['@label'] = creationData,
        ['@shared'] = 1
    }, function(rowsChanged)
        queries = queries + 1
        if rowsChanged == 0 then errorOccurred = true end
        checkCompletion()
    end)

    MySQL.Async.execute('INSERT INTO datastore (name, label, shared) VALUES (@name, @label, @shared)', {
        ['@name'] = society,
        ['@label'] = creationData,
        ['@shared'] = 1
    }, function(rowsChanged)
        queries = queries + 1
        if rowsChanged == 0 then errorOccurred = true end
        checkCompletion()
    end)

    -- Use job grades from config
    local jobGrades = Config.GangStructure.grades
    
    -- Create job
    MySQL.Async.execute('INSERT INTO jobs (name, label) VALUES (@name, @label)', {
        ['@name'] = creationData,
        ['@label'] = creationData
    }, function(rowsChanged)
        queries = queries + 1
        if rowsChanged == 0 then errorOccurred = true end
        checkCompletion()
    end)
    
    -- Create job grades in a transaction
    for _, grade in ipairs(jobGrades) do
        MySQL.Async.execute('INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (@job_name, @grade, @name, @label, @salary, @skin_male, @skin_female)', {
            ['@job_name'] = creationData,
            ['@grade'] = grade.id, 
            ['@name'] = grade.name,
            ['@label'] = grade.label,
            ['@salary'] = grade.salary,
            ['@skin_male'] = "{}",
            ['@skin_female'] = "{}"
        }, function(rowsChanged)
            queries = queries + 1
            if rowsChanged == 0 then errorOccurred = true end
            checkCompletion()
        end)
    end
    
    -- Function to check if all queries are complete and finish the process
    function checkCompletion()
        if queries == totalQueries then
            if errorOccurred then
                xPlayer.showNotification('An error occurred during gang creation. Please contact an administrator.')
                closeMenu(xPlayer)
            else
                -- All queries succeeded, refresh and set job
                refreshDB(function()
                    Wait(500)
                    setCreationJob(creationData, xPlayer)
                    xPlayer.showNotification('Congratulations! You have successfully created the ' .. creationData .. ' gang!')
                end)
            end
        end
    end
end

-- Refresh database with new data
refreshDB = function(callback)
    -- Trigger our registered events to refresh the jobs and accounts
    TriggerEvent('esx_addonaccount:refreshAccounts')
    TriggerEvent('esx:refreshJobs')
    
    if callback then
        callback()
    end
end

-- Set player's job to the newly created gang
setCreationJob = function(creationData, xPlayer)
    local bossGrade = Config.GangStructure.defaultBossGrade
    
    if ESX.DoesJobExist(creationData, bossGrade) then
        xPlayer.setJob(creationData, bossGrade)
    else
        -- If job doesn't exist yet, wait and try again
        refreshDB(function()
            Wait(2000)
            if ESX.DoesJobExist(creationData, bossGrade) then
                xPlayer.setJob(creationData, bossGrade)
            else
                xPlayer.showNotification('There was an issue assigning you to the gang. Please contact an administrator.')
            end
        end)
    end
end

-- Close the UI menu
closeMenu = function(xPlayer)
    TriggerClientEvent('whiskakii-Mafia:closeMenu', xPlayer.source)
end

-- Check if our event handlers are registered when es_extended loads
AddEventHandler('esx:extended:ready', function()
    RegisterESXEventHandlers()
end)

-- Check if our event handlers are registered when esx_addonaccount loads
AddEventHandler('esx_addonaccount:ready', function()
    RegisterESXEventHandlers()
end)