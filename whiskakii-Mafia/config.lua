Config = {}

-- Main configuration
Config.Debug = false -- Set to true to enable debug messages

-- NPC Configuration
Config.PedSettings = {
    coords = vector3(-1150.94, -1519.34, 3.37),
    heading = 127.2398,
    model = 's_m_y_dealer_01', -- NPC model
    scenario = 'WORLD_HUMAN_SMOKING', -- NPC animation
    blipSprite = 437, -- Map marker sprite
    blipColor = 1, -- Map marker color
    blipScale = 1.0, -- Map marker scale
    interactionDistance = 2.0, -- Distance to interact with NPC
    interactionKey = 38 -- Key to interact (E key)
}

-- Legacy support for old code
Config.pedCoords = Config.PedSettings.coords
Config.pedHeading = Config.PedSettings.heading

-- Jobs that are not allowed to create gangs
Config.BlackListedJobs = {
    'police',
    'ambulance',
    'sheriff',
    'mechanic'
}

-- Gang creation pricing
Config.Price = 10000 -- Cost to create a gang
Config.Currency = 'bank' -- Money account type to use
Config.CurrencyLabel = 'Bank Money' -- Display name for currency

-- Gang structure settings
Config.GangStructure = {
    -- Job grades for the gang (id = database grade, name = internal name, label = display name, salary = payment amount)
    grades = {
        {id = 0, name = 'recruit', label = 'New Blood', salary = 300},
        {id = 1, name = 'enforcer', label = 'Enforcer', salary = 300},
        {id = 2, name = 'underboss', label = 'Vice Boss', salary = 400},
        {id = 3, name = 'boss', label = 'Drug Lord', salary = 500}
    },
    
    -- Default boss grade assigned to creator
    defaultBossGrade = 3
}