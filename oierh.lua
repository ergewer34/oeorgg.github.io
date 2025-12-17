local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer
local character = player.CharacterAdded:Wait()
local DEBUG_MODE = true
local PetFarmMode = false
local petFarmCoroutine = nil
local petFarmPetID = nil
local currentToyID = nil
local currentStrollerID = nil
local currentFoodID = nil
local AutoPetPenMode = false
local autoPetPenCoroutine = nil
local lastPetPenCommitTime = 0
local sessionBucksEarned = 0
local sessionPotionsEarned = 0
local lastMoneyAmount = 0
local lastPotionAmount = 0
local ContinuousMode = false
local continuousCoroutine = nil
local AILMENT_TASKS = {
    sleepy = "BasicBed",
    hungry = "PetFoodBowl",
    thirsty = "PetWaterBowl",
    dirty = "CheapPetBathtub",
    bored = "Piano",
    toilet = "AilmentsRefresh2024LitterBox",
    play = "THROW_TOY",
    walk = "WALK_HANDLER",
    ride = "STROLLER_HANDLER",
    sick = "HEALING_APPLE",
    mystery = "MYSTERY_HANDLER",
    pet_me = "PET_ME_HANDLER"
}
local lastTaskTime = {}
local TASK_COOLDOWN = 30
local scriptInitialized = false
local PetID = nil
local Pet = nil
local PetsShow = {}
local currentSelectedPetKey = nil
local lastValidPetID = nil
local priorityEggs = {
    "basic_egg_2022_mouse",
    "basic_egg_2022_ant",
    "cracked_egg"
}
local prioritySet = {}
for _, v in ipairs(priorityEggs) do prioritySet[v] = true end
local function debugPrint(message)
    if not DEBUG_MODE then return end
    local hours = os.date("%H")
    local minutes = os.date("%M")
    local seconds = os.date("%S")
    local timestamp = string.format("[%s:%s:%s]", hours, minutes, seconds)
    print(timestamp .. " " .. message)
end
local function sendTradeRequest(targetPlayerName)
    if targetPlayerName == "" or not targetPlayerName then
        debugPrint("No player name provided for trade")
        return
    end
  
    local targetPlayer = Players:FindFirstChild(targetPlayerName)
    if not targetPlayer then
        debugPrint("Player not found: " .. targetPlayerName)
        return
    end
  
    debugPrint("Sending trade request to: " .. targetPlayerName)
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/SendTradeRequest"):FireServer(targetPlayer)
    end)
  
    if success then
        debugPrint("Trade request sent successfully")
    else
        debugPrint("Failed to send trade request: " .. tostring(err))
    end
end
local function getAllPetIDsFromInventory()
    local neonAged6 = {}
    local neonUnder6 = {}
    local others = {}
  
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.pets then
            for petIndex, petData in pairs(playerData.inventory.pets) do
                if petData and petData.unique and petData.id and petData.properties then
                    local petName = tostring(petData.id):lower()
                    if not string.find(petName, "practice_dog") and not (string.find(petName, "dog") or string.find(petName, "cat")) then
                        if petData.properties.neon and (petData.properties.age or 0) == 6 then
                            table.insert(neonAged6, petData.unique)
                        elseif petData.properties.neon and (petData.properties.age or 0) < 6 then
                            table.insert(neonUnder6, petData.unique)
                        else
                            table.insert(others, petData.unique)
                        end
                    end
                end
            end
        end
    end)
  
    if not success then
        debugPrint("Error getting pet IDs from inventory: " .. tostring(errorMsg))
    end
  
    local allPets = {}
    for _, petID in ipairs(neonAged6) do table.insert(allPets, petID) end
    for _, petID in ipairs(neonUnder6) do table.insert(allPets, petID) end
    for _, petID in ipairs(others) do table.insert(allPets, petID) end
  
    return allPets
end
local function addAllPetsToTrade()
    debugPrint("Adding all pets to trade...")
    local petIDs = getAllPetIDsFromInventory()
    if #petIDs == 0 then
        debugPrint("No pets found to add to trade")
        return
    end
  
    local maxPets = math.min(#petIDs, 18)
    debugPrint("Adding " .. maxPets .. " pets to trade")
  
    for i = 1, maxPets do
        local petID = petIDs[i]
        local success, err = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AddItemToOffer"):FireServer(petID)
        end)
      
        if success then
            debugPrint("Added pet " .. i .. "/" .. maxPets .. " to trade")
        else
            debugPrint("Failed to add pet to trade: " .. tostring(err))
        end
        task.wait(0.2)
    end
  
    debugPrint("Finished adding pets to trade")
end
local function completeTradeProcess(targetPlayer)
    local args = { targetPlayer, true }
    local success1, result1 = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptOrDeclineTradeRequest"):InvokeServer(unpack(args))
    end)
  
    if success1 then
        task.wait(2)
      
        addAllPetsToTrade()
        task.wait(3)
      
        local success2, result2 = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/AcceptNegotiation"):FireServer()
        end)
      
        if success2 then
            task.wait(9)
          
            local success3, result3 = pcall(function()
                ReplicatedStorage:WaitForChild("API"):WaitForChild("TradeAPI/ConfirmTrade"):FireServer()
            end)
          
            if success3 then
                debugPrint("Trade completed successfully with " .. targetPlayer.Name)
                return true
            end
        end
    end
  
    debugPrint("Trade failed with " .. targetPlayer.Name)
    return false
end
local function scanAndCompleteAllTrades()
    local players = Players:GetPlayers()
    local localPlayer = Players.LocalPlayer
  
    for _, targetPlayer in ipairs(players) do
        if targetPlayer ~= localPlayer and ContinuousMode then
            debugPrint("Attempting trade with: " .. targetPlayer.Name)
            completeTradeProcess(targetPlayer)
            task.wait(0.1)
        end
    end
end
local function startContinuousAcceptConfirm()
    while ContinuousMode do
        scanAndCompleteAllTrades()
        task.wait(9)
    end
end
local function toggleContinuousMode()
    ContinuousMode = not ContinuousMode
    if ContinuousMode then
        debugPrint("Auto Trade: ENABLED")
        continuousCoroutine = coroutine.wrap(startContinuousAcceptConfirm)()
    else
        debugPrint("Auto Trade: DISABLED")
        continuousCoroutine = nil
    end
end
local function safelyUnequipFood(foodID)
    if foodID then
        debugPrint("Unequipping food: " .. foodID)
        local args = { foodID }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully unequipped food")
        else
            debugPrint("Failed to unequip food: " .. tostring(result))
        end
        task.wait(1)
    end
end
local SQUEAKY_BONE_ID = nil
local function getSqueakyBoneID()
    if SQUEAKY_BONE_ID then
        return SQUEAKY_BONE_ID
    end
 
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
 
    if not success or not data or not data.inventory or not data.inventory.toys then
        debugPrint("No inventory or toys data found!")
        return nil
    end
 
    for uniqueId, toyData in pairs(data.inventory.toys) do
        if toyData.id == "squeaky_bone_default" then
            debugPrint("Found squeaky_bone_default → ID: " .. uniqueId)
            SQUEAKY_BONE_ID = uniqueId
            return uniqueId
        end
    end
 
    debugPrint("squeaky_bone_default NOT FOUND in inventory!")
    return nil
end
local function safelyUnequipToy()
    if currentToyID then
        debugPrint("Unequipping toy: " .. currentToyID)
        local args = { currentToyID }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(args))
        end)
     
        if success then
            debugPrint("Successfully unequipped toy")
        else
            debugPrint("Failed to unequip toy: " .. tostring(result))
        end
     
        currentToyID = nil
        task.wait(1)
    else
        debugPrint("No toy equipped to unequip - skipping")
    end
end
local function performThrowToy()
    local toyID = getSqueakyBoneID()
    if not toyID then
        debugPrint("NO squeaky_bone_default → Play ailment skipped")
        return false
    end
 
    debugPrint("Using squeaky_bone_default → " .. toyID)
    currentToyID = toyID
 
    local success1, err1 = pcall(function()
        return ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(toyID, {
            use_sound_delay = true,
            equip_as_last = false
        })
    end)
 
    if not success1 then
        debugPrint("Failed to equip toy: " .. tostring(err1))
        safelyUnequipToy()
        return false
    end
 
    task.wait(1.2)
 
    local success2, err2 = pcall(function()
        return ReplicatedStorage.API["ToolAPI/ServerUseTool"]:FireServer(toyID, "START")
    end)
 
    if not success2 then
        debugPrint("Failed to start using toy: " .. tostring(err2))
        safelyUnequipToy()
        return false
    end
 
    task.wait(1)
 
    local success3, err3 = pcall(function()
        return ReplicatedStorage.API["PetObjectAPI/CreatePetObject"]:InvokeServer(
            "__Enum_PetObjectCreatorType_1",
            { reaction_name = "ThrowToyReaction", unique_id = toyID }
        )
    end)
 
    if not success3 then
        debugPrint("Failed to trigger pet reaction: " .. tostring(err3))
        safelyUnequipToy()
        return false
    end
 
    task.wait(1.1)
 
    local success4, err4 = pcall(function()
        return ReplicatedStorage.API["ToolAPI/ServerUseTool"]:FireServer(toyID, "END")
    end)
 
    if not success4 then
        debugPrint("Failed to end using toy: " .. tostring(err4))
        safelyUnequipToy()
        return false
    end
 
    debugPrint("squeaky_bone_default throw SUCCESS")
    return true
end
local function performThrowToySequence()
    debugPrint("Starting squeaky_bone_default throw sequence (3x)...")
    local toyID = getSqueakyBoneID()
    if not toyID then
        debugPrint("NO squeaky_bone_default → Play ailment skipped")
        return false
    end
 
    local successfulThrows = 0
 
    for i = 1, 3 do
        if not PetFarmMode then
            debugPrint("PetFarm stopped → canceling throw sequence")
            safelyUnequipToy()
            return false
        end
     
        debugPrint("Throw #" .. i .. " with squeaky_bone_default")
        local success, err = pcall(performThrowToy)
     
        if success and err then
            successfulThrows += 1
            debugPrint("Throw #" .. i .. " SUCCESS")
        else
            debugPrint("Throw #" .. i .. " FAILED: " .. tostring(err))
        end
     
        task.wait(2)
    end
 
    safelyUnequipToy()
 
    if successfulThrows >= 2 then
        debugPrint("Throw sequence completed: " .. successfulThrows .. "/3 successful")
        return true
    else
        debugPrint("Throw sequence mostly failed: " .. successfulThrows .. "/3 successful")
        return false
    end
end
local function handlePlayAilment()
    debugPrint("PLAY AILMENT HANDLER: Using only squeaky_bone_default")
    local toyID = getSqueakyBoneID()
    if not toyID then
        debugPrint("NO squeaky_bone_default in inventory! Play ailment SKIPPED.")
        return false
    end
 
    local success, err = pcall(performThrowToySequence)
 
    if success and err then
        debugPrint("PLAY AILMENT: Resolved with squeaky_bone_default")
        return true
    else
        debugPrint("PLAY AILMENT: FAILED → " .. tostring(err))
        safelyUnequipToy()
        return false
    end
end
local function isPetEquipped(petUniqueID)
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
    if not success or not data or not data.equip_manager or not data.equip_manager.equipped_pets then
        return false
    end
    for _, equippedPet in pairs(data.equip_manager.equipped_pets) do
        if equippedPet == petUniqueID then
            return true
        end
    end
    return false
end
local function resolveMysteryAilment(petUniqueID)
    debugPrint("Resolving mystery ailment for pet: " .. tostring(petUniqueID))
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("AilmentsAPI/RevealMysteryAilment"):InvokeServer(petUniqueID)
    end)
    if success then
        debugPrint("Mystery ailment revealed successfully")
        task.wait(2)
        return true
    else
        debugPrint("Failed to reveal mystery ailment: " .. tostring(result))
        return false
    end
end
local function findPetModel(petUniqueID)
    if not workspace:FindFirstChild("Pets") then
        debugPrint("No Pets folder in workspace")
        return nil
    end
    for _, petModel in ipairs(workspace.Pets:GetChildren()) do
        if petModel:IsA("Model") then
            local uniqueId = petModel:FindFirstChild("UniqueId") or petModel:FindFirstChild("PetId") or petModel:FindFirstChild("Id")
            if uniqueId and uniqueId:IsA("StringValue") and uniqueId.Value == petUniqueID then
                return petModel
            end
            if petModel:FindFirstChild("Owner") then
                local owner = petModel.Owner
                if owner:IsA("ObjectValue") and owner.Value == player then
                    return petModel
                end
            end
        end
    end
    local char = player.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        local hrp = char.HumanoidRootPart
        local closestPet = nil
        local closestDist = math.huge
        for _, petModel in ipairs(workspace.Pets:GetChildren()) do
            if petModel:IsA("Model") and petModel:FindFirstChild("HumanoidRootPart") then
                local dist = (petModel.HumanoidRootPart.Position - hrp.Position).Magnitude
                if dist < closestDist and dist < 30 then
                    closestDist = dist
                    closestPet = petModel
                end
            end
        end
        if closestPet then
            debugPrint("Found closest pet by distance: " .. closestPet.Name)
            return closestPet
        end
    end
    debugPrint("Could not find pet model for: " .. tostring(petUniqueID))
    return nil
end
local function focusPet(petModel)
    if not petModel then return false end
    local args = { petModel }
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/FocusPet"):FireServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully focused on pet: " .. petModel.Name)
        return true
    else
        debugPrint("Failed to focus on pet: " .. tostring(err))
        return false
    end
end
local function unfocusPet(petModel)
    if not petModel then return false end
    local args = { petModel }
    local success, err = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/UnfocusPet"):FireServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully unfocused pet: " .. petModel.Name)
        return true
    else
        debugPrint("Failed to unfocus pet: " .. tostring(err))
        return false
    end
end
local function progressPetMeAilment(petUniqueID, petModel)
    local possibleEndpoints = {
        "AilmentsAPI/ProgressPetMeAilment",
        "AilmentsAPI/PetThePet",
        "AilmentsAPI/ProgressAilment",
        "AdoptAPI/PetPet",
        "AdoptAPI/InteractWithPet"
    }
    for _, endpoint in pairs(possibleEndpoints) do
        local remoteEvent = ReplicatedStorage.API:FindFirstChild(endpoint)
        if remoteEvent then
            debugPrint("Trying endpoint with unique ID: " .. endpoint)
            local args = { petUniqueID }
            local success, err = pcall(function()
                remoteEvent:FireServer(unpack(args))
            end)
            if success then
                debugPrint("Successfully called: " .. endpoint)
                return true
            else
                debugPrint("Failed to call " .. endpoint .. ": " .. tostring(err))
            end
        end
    end
    for _, endpoint in pairs(possibleEndpoints) do
        local remoteEvent = ReplicatedStorage.API:FindFirstChild(endpoint)
        if remoteEvent then
            debugPrint("Trying endpoint with model: " .. endpoint)
            local args = { petModel }
            local success, err = pcall(function()
                remoteEvent:FireServer(unpack(args))
            end)
            if success then
                debugPrint("Successfully called: " .. endpoint)
                return true
            else
                debugPrint("Failed to call " .. endpoint .. ": " .. tostring(err))
            end
        end
    end
    debugPrint("Could not find working endpoint for ailment progression")
    return false
end
local function handlePetMeAilment(petUniqueID)
    debugPrint("=== STARTING PET ME AILMENT HANDLING ===")
    local petModel = findPetModel(petUniqueID)
    if not petModel then
        debugPrint("FAILED: Could not find pet model")
        return false
    end
    debugPrint("Using pet: " .. petModel.Name)
    local success = progressPetMeAilment(petUniqueID, petModel)
    if success then
        debugPrint("SUCCESS: Ailment progression attempted")
        task.wait(2)
        debugPrint("Check if the 'Pet Me' ailment progressed in the game")
    else
        debugPrint("FAILED: Could not progress ailment")
    end
    debugPrint("Unfocusing pet...")
    if not unfocusPet(petModel) then
        local args = { Workspace:WaitForChild("Pets"):WaitForChild(petModel.Name) }
        local success, err = pcall(function()
            ReplicatedStorage:WaitForChild("API"):WaitForChild("AdoptAPI/UnfocusPet"):FireServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully unfocused pet using alternative method")
        else
            debugPrint("Failed to unfocus pet using alternative method: " .. tostring(err))
        end
    end
    debugPrint("=== PET ME AILMENT HANDLING COMPLETED ===")
    return success
end
local function getValidCharacter()
    local currentChar = player.Character
    if currentChar and currentChar.Parent and currentChar:FindFirstChild("HumanoidRootPart") then
        return currentChar
    end
    debugPrint("Character not found or invalid, waiting for CharacterAdded...")
    character = player.CharacterAdded:Wait()
    local startTime = os.time()
    while os.time() - startTime < 10 do
        if character and character.Parent and character:FindFirstChild("HumanoidRootPart") then
            debugPrint("Character loaded successfully")
            return character
        end
        task.wait(0.5)
    end
    debugPrint("Failed to load valid character after waiting")
    return nil
end
local function ensureCharacterSpawned()
    local char = getValidCharacter()
    if not char then
        debugPrint("Respawning character...")
        pcall(function()
            local api = ReplicatedStorage:FindFirstChild("API")
            if api then
                local spawnAPI = api:FindFirstChild("TeamAPI/Spawn")
                if spawnAPI then
                    spawnAPI:InvokeServer()
                end
            end
        end)
        task.wait(5)
        char = getValidCharacter()
    end
    return char
end
local function isPlayerAtHome()
    local hi = Workspace:FindFirstChild("HouseInteriors")
    if not hi then
        return false
    end
    for _, folder in ipairs(hi:GetChildren()) do
        if string.find(folder.Name, player.Name) then
            return true
        end
    end
    return false
end
local function findPlayerPetInWorkspace()
    local char = getValidCharacter()
    if not char then
        debugPrint("Cannot find pet: No valid character")
        return nil
    end
    if workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:FindFirstChild("Owner") and petInWorkspace.Owner.Value == player then
                return petInWorkspace
            end
        end
    end
    if workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:FindFirstChild("PetProperties") then
                local properties = petInWorkspace.PetProperties
                if properties:FindFirstChild("Owner") and properties.Owner.Value == player then
                    return petInWorkspace
                end
            end
        end
    end
    local humanoidRootPart = char:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart and workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:FindFirstChild("HumanoidRootPart") then
                local distance = (petInWorkspace.HumanoidRootPart.Position - humanoidRootPart.Position).Magnitude
                if distance < 20 then
                    return petInWorkspace
                end
            end
        end
    end
    if workspace:FindFirstChild("Pets") then
        for _, petInWorkspace in ipairs(workspace.Pets:GetChildren()) do
            if petInWorkspace:IsA("Model") and petInWorkspace:FindFirstChild("Humanoid") then
                return petInWorkspace
            end
        end
    end
    debugPrint("No pet found in workspace using all search methods")
    return nil
end
local function ensurePetEquipped(petUniqueID, timeout)
    timeout = timeout or 15
    if not petUniqueID then
        debugPrint("ensurePetEquipped: no petUniqueID provided")
        return false
    end
    if isPetEquipped(petUniqueID) then
        debugPrint("Pet already equipped via equip_manager")
        if findPlayerPetInWorkspace() then
            debugPrint("Pet also present in workspace")
            petFarmPetID = petUniqueID
            return true
        end
    end
    debugPrint("Pet not equipped, equipping: " .. tostring(petUniqueID))
    local success, result = pcall(function()
        return ReplicatedStorage.API["ToolAPI/Equip"]:InvokeServer(petUniqueID, {use_sound_delay = true, equip_as_last = false})
    end)
    if not success then
        debugPrint("Failed to equip pet: " .. tostring(result))
        return false
    end
    local startTime = os.time()
    while os.time() - startTime < timeout do
        if isPetEquipped(petUniqueID) and findPlayerPetInWorkspace() then
            debugPrint("Pet successfully equipped and present")
            petFarmPetID = petUniqueID
            return true
        end
        task.wait(0.5)
    end
    debugPrint("Pet did not fully equip within timeout")
    return false
end
local function findStrollers()
    local strollers = {}
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.strollers then
            for strollerId, strollerData in pairs(playerData.inventory.strollers) do
                if strollerData.id then
                    table.insert(strollers, {
                        id = strollerId,
                        name = strollerData.id,
                        amount = strollerData.amount or 1
                    })
                end
            end
        end
    end)
    if not success then
        debugPrint("Error finding strollers: " .. tostring(errorMsg))
    end
    return strollers
end
local function getStrollerID()
    local strollers = findStrollers()
    if #strollers > 0 then
        debugPrint("Found stroller: " .. strollers[1].name .. " (ID: " .. strollers[1].id .. ")")
        return strollers[1].id
    end
    debugPrint("No strollers found in inventory")
    return nil
end
local function buyHealingApple()
    debugPrint("Buying healing apple from shop...")
    local args = {
        "food",
        "healing_apple",
        {
            buy_count = 1
        }
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully purchased healing apple")
        return true
    else
        debugPrint("Failed to buy healing apple: " .. tostring(result))
        return false
    end
end
local function findHealingApple()
    debugPrint("Scanning inventory for healing apple...")
    local healingAppleID = nil
    local success, errorMsg = pcall(function()
        local clientData = require(ReplicatedStorage.ClientModules.Core.ClientData)
        local playerData = clientData.get_data()[player.Name]
        if playerData and playerData.inventory and playerData.inventory.food then
            for foodId, foodData in pairs(playerData.inventory.food) do
                if foodData.id and string.lower(foodData.id) == "healing_apple" then
                    healingAppleID = foodId
                    debugPrint("Found healing apple with ID: " .. foodId)
                    break
                end
            end
        end
    end)
    if not success then
        debugPrint("Error scanning inventory for healing apple: " .. tostring(errorMsg))
    end
    return healingAppleID
end
local function useHealingApple(foodID, petUniqueID)
    if not foodID or not petUniqueID then
        debugPrint("Cannot use healing apple: Missing foodID or petUniqueID")
        return false
    end
    debugPrint("Using healing apple " .. foodID .. " on pet " .. petUniqueID)
    local equipArgs = {
        foodID,
        {
            use_sound_delay = true,
            equip_as_last = false
        }
    }
    local equipSuccess, equipResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(equipArgs))
    end)
    if not equipSuccess then
        debugPrint("Failed to equip healing apple: " .. tostring(equipResult))
        return false
    end
    currentFoodID = foodID
    debugPrint("Successfully equipped healing apple")
    task.wait(2)
    local startArgs = {
        foodID,
        "START"
    }
    local startSuccess, startResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/ServerUseTool"):FireServer(unpack(startArgs))
    end)
    if not startSuccess then
        debugPrint("Failed to start using healing apple: " .. tostring(startResult))
        safelyUnequipFood(foodID)
        currentFoodID = nil
        return false
    end
    debugPrint("Started using healing apple, waiting 1 second...")
    task.wait(1)
    local petObjectArgs = {
        "__Enum_PetObjectCreatorType_2",
        {
            additional_consume_uniques = {},
            pet_unique = petUniqueID,
            unique_id = foodID
        }
    }
    local petObjectSuccess, petObjectResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("PetObjectAPI/CreatePetObject"):InvokeServer(unpack(petObjectArgs))
    end)
    if not petObjectSuccess then
        debugPrint("Failed to create pet object for healing: " .. tostring(petObjectResult))
        safelyUnequipFood(foodID)
        currentFoodID = nil
        return false
    end
    debugPrint("Healing apple consumed, waiting 9 seconds for effect...")
    task.wait(9)
    safelyUnequipFood(foodID)
    currentFoodID = nil
    debugPrint("Successfully used healing apple on pet")
    return true
end
local function handleSickAilment()
    debugPrint("SICK AILMENT DETECTED! Starting healing process...")
    local currentPetID = petFarmPetID or PetID
    if not currentPetID then
        debugPrint("No pet ID available for healing")
        return false
    end
    local healingAppleID = findHealingApple()
    if not healingAppleID then
        debugPrint("No healing apple found in inventory, purchasing one...")
        local purchaseSuccess = buyHealingApple()
        if not purchaseSuccess then
            debugPrint("Failed to purchase healing apple")
            return false
        end
        task.wait(2)
        healingAppleID = findHealingApple()
        if not healingAppleID then
            debugPrint("Failed to find healing apple after purchase")
            return false
        end
    end
    local useSuccess = useHealingApple(healingAppleID, currentPetID)
    if useSuccess then
        debugPrint("Successfully handled sick ailment with healing apple")
        return true
    else
        debugPrint("Failed to use healing apple on pet")
        return false
    end
end
local function safelyUnequipStroller()
    if currentStrollerID then
        debugPrint("Unequipping stroller: " .. currentStrollerID)
        local args = { currentStrollerID }
        local success, result = pcall(function()
            return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Unequip"):InvokeServer(unpack(args))
        end)
        if success then
            debugPrint("Successfully unequipped stroller")
        else
            debugPrint("Failed to unequip stroller: " .. tostring(result))
        end
        currentStrollerID = nil
        task.wait(1)
    else
        debugPrint("No stroller equipped to unequip - skipping")
    end
end
local function handleWalkAilment()
    debugPrint("WALK AILMENT DETECTED! Starting walk sequence...")
    local currentPetID = petFarmPetID or PetID
    if not currentPetID then
        debugPrint("No pet ID available for walk sequence")
        return false
    end
    debugPrint("Storing current pet ID for re-equip: " .. tostring(currentPetID))
    local args = {
        player,
        true
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully unsubscribed from house")
    else
        debugPrint("Failed to unsubscribe from house: " .. tostring(result))
        return false
    end
    debugPrint("Waiting 5 seconds for transition...")
    task.wait(5)
    debugPrint("Starting walking simulation...")
    for i = 1, 20 do
        if not PetFarmMode then
            debugPrint("PetFarm stopped during walk sequence, cancelling...")
            return false
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        debugPrint("Pressing W key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
        debugPrint("Pressing S key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        debugPrint("Walk cycle " .. i .. "/20 completed")
    end
    debugPrint("Walk sequence completed, respawning to return home...")
    local respawnSuccess, respawnResult = pcall(function()
        local api = ReplicatedStorage:FindFirstChild("API")
        if api then
            local spawnAPI = api:FindFirstChild("TeamAPI/Spawn")
            if spawnAPI then
                return spawnAPI:InvokeServer()
            end
        end
    end)
    if respawnSuccess then
        debugPrint("Successfully respawned to return home")
        task.wait(5)
        debugPrint("Re-equipping pet after respawn...")
        local reequipSuccess = ensurePetEquipped(currentPetID, 10)
        if reequipSuccess then
            debugPrint("Successfully re-equipped pet after respawn")
            task.wait(2)
            return true
        else
            debugPrint("Failed to re-equip pet after respawn")
            return false
        end
    else
        debugPrint("Failed to respawn: " .. tostring(respawnResult))
        return false
    end
end
local function handleRideAilment()
    debugPrint("RIDE AILMENT DETECTED! Starting ride sequence with stroller...")
    local currentPetID = petFarmPetID or PetID
    if not currentPetID then
        debugPrint("No pet ID available for ride sequence")
        return false
    end
    debugPrint("Storing current pet ID for re-equip: " .. tostring(currentPetID))
    local args = {
        player,
        true
    }
    local success, result = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/UnsubscribeFromHouse"):InvokeServer(unpack(args))
    end)
    if success then
        debugPrint("Successfully unsubscribed from house")
    else
        debugPrint("Failed to unsubscribe from house: " .. tostring(result))
        return false
    end
    debugPrint("Waiting 5 seconds for transition...")
    task.wait(5)
    local strollerID = getStrollerID()
    if not strollerID then
        debugPrint("No strollers found in inventory!")
        return false
    end
    debugPrint("Equipping stroller: " .. strollerID)
    currentStrollerID = strollerID
    local equipArgs = {
        strollerID,
        {
            use_sound_delay = true,
            equip_as_last = true
        }
    }
    local equipSuccess, equipResult = pcall(function()
        return ReplicatedStorage:WaitForChild("API"):WaitForChild("ToolAPI/Equip"):InvokeServer(unpack(equipArgs))
    end)
    if not equipSuccess then
        debugPrint("Failed to equip stroller: " .. tostring(equipResult))
        currentStrollerID = nil
        return false
    end
    debugPrint("Successfully equipped stroller, starting walking simulation...")
    task.wait(3)
    debugPrint("Starting walking simulation with stroller...")
    for i = 1, 20 do
        if not PetFarmMode then
            debugPrint("PetFarm stopped during ride sequence, cancelling...")
            safelyUnequipStroller()
            return false
        end
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.W, false, nil)
        debugPrint("Pressing W key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.W, false, nil)
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.S, false, nil)
        debugPrint("Pressing S key...")
        task.wait(1)
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.S, false, nil)
        debugPrint("Ride cycle " .. i .. "/20 completed")
    end
    debugPrint("Ride sequence completed, unequipping stroller and respawning to return home...")
    safelyUnequipStroller()
    local respawnSuccess, respawnResult = pcall(function()
        local api = ReplicatedStorage:FindFirstChild("API")
        if api then
            local spawnAPI = api:FindFirstChild("TeamAPI/Spawn")
            if spawnAPI then
                return spawnAPI:InvokeServer()
            end
        end
    end)
    if respawnSuccess then
        debugPrint("Successfully respawned to return home")
        task.wait(5)
        debugPrint("Re-equipping pet after respawn...")
        local reequipSuccess = ensurePetEquipped(currentPetID, 10)
        if reequipSuccess then
            debugPrint("Successfully re-equipped pet after respawn")
            task.wait(2)
            return true
        else
            debugPrint("Failed to re-equip pet after respawn")
            return false
        end
    else
        debugPrint("Failed to respawn: " .. tostring(respawnResult))
        return false
    end
end
local function extractFurnitureData(model, folderName)
    local activationParts = {"UseBlock", "Seat1"}
    local folderId = string.match(folderName, "f%-%d+") or folderName
    for _, partName in ipairs(activationParts) do
        local useBlocksFolder = model:FindFirstChild("UseBlocks")
        if useBlocksFolder then
            local part = useBlocksFolder:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                debugPrint("Using " .. partName .. " in UseBlocks folder")
                return {
                    folderId = folderId,
                    partName = partName,
                    position = part.Position,
                    cframe = part.CFrame,
                    model = model
                }
            end
        end
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            debugPrint("Using " .. partName .. " directly in model")
            return {
                folderId = folderId,
                partName = partName,
                position = part.Position,
                cframe = part.CFrame,
                model = model
            }
        end
    end
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then
            debugPrint("Using fallback part: " .. part.Name)
            return {
                folderId = folderId,
                partName = part.Name,
                position = part.Position,
                cframe = part.CFrame,
                model = model
            }
        end
    end
    return nil
end
local function findFurnitureByName(name)
    debugPrint("Searching for furniture: " .. name)
    local hi = Workspace:FindFirstChild("HouseInteriors")
    if hi then
        for _, folder in ipairs(hi:GetChildren()) do
            if string.find(folder.Name, player.Name) or string.find(folder.Name, "f%-%d+") then
                local model = folder:FindFirstChild(name)
                if model and model:IsA("Model") then
                    debugPrint("Found " .. name .. " in " .. folder.Name)
                    return extractFurnitureData(model, folder.Name)
                end
            end
        end
    end
    local model = Workspace:FindFirstChild(name, true)
    if model and model:IsA("Model") then
        debugPrint("Found " .. name .. " in workspace (fallback)")
        local folderId = model.Parent and string.match(model.Parent.Name, "f%-%d+") or "unknown"
        return extractFurnitureData(model, folderId)
    end
    debugPrint("Furniture not found: " .. name)
    return nil
end
local function checkAndBuyMissingFurniture()
    debugPrint("Checking for missing furniture...")
    local missingFurniture = {}
    local pianoFound = findFurnitureByName("Piano")
    if not pianoFound then
        debugPrint("Piano not found, adding to buy list")
        table.insert(missingFurniture, {category = "furniture", item = "piano", buyCount = 1})
    end
    local bedFound = findFurnitureByName("BasicBed")
    if not bedFound then
        debugPrint("BasicBed not found, adding to buy list")
        table.insert(missingFurniture, {category = "furniture", item = "basic_bed", buyCount = 1})
    end
    local foodBowlFound = findFurnitureByName("PetFoodBowl")
    if not foodBowlFound then
        debugPrint("PetFoodBowl not found, adding to buy list")
        table.insert(missingFurniture, {category = "furniture", item = "pet_food_bowl", buyCount = 1})
    end
    local waterBowlFound = findFurnitureByName("PetWaterBowl")
    if not waterBowlFound then
        debugPrint("PetWaterBowl not found, adding to buy list")
        table.insert(missingFurniture, {category = "furniture", item = "pet_water_bowl", buyCount = 1})
    end
    local bathtubFound = findFurnitureByName("CheapPetBathtub")
    if not bathtubFound then
        debugPrint("CheapPetBathtub not found, adding to buy list")
        table.insert(missingFurniture, {category = "furniture", item = "cheap_pet_bathtub", buyCount = 1})
    end
    local litterBoxFound = findFurnitureByName("AilmentsRefresh2024LitterBox")
    if not litterBoxFound then
        debugPrint("AilmentsRefresh2024LitterBox not found, adding to buy list")
        table.insert(missingFurniture, {category = "furniture", item = "ailments_refresh_2024_litter_box", buyCount = 1})
    end
    if #missingFurniture > 0 then
        debugPrint("Buying " .. #missingFurniture .. " missing furniture items...")
        for _, item in ipairs(missingFurniture) do
            local args = {
                item.category,
                item.item,
                {
                    buy_count = item.buyCount
                }
            }
            local success, result = pcall(function()
                return ReplicatedStorage:WaitForChild("API"):WaitForChild("ShopAPI/BuyItem"):InvokeServer(unpack(args))
            end)
            if success then
                debugPrint("Bought: " .. item.item)
            else
                debugPrint("Failed to buy " .. item.item .. ": " .. tostring(result))
            end
            task.wait(1)
        end
        debugPrint("Furniture purchase complete")
    else
        debugPrint("All required furniture is present")
    end
end
local function useFurnitureWithPet(furnitureName)
    debugPrint("Attempting to use furniture: " .. furnitureName)
    local furnitureData = findFurnitureByName(furnitureName)
    if not furnitureData then
        debugPrint("Furniture not found: " .. furnitureName)
        return false
    end
    local char = getValidCharacter()
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        debugPrint("No valid character for furniture use")
        return false
    end
    local hrp = char.HumanoidRootPart
    local originalCFrame = hrp.CFrame
    debugPrint("Teleporting to furniture...")
    hrp.CFrame = furnitureData.cframe + Vector3.new(0, 3, 0)
    task.wait(1)
    local pet = findPlayerPetInWorkspace()
    if not pet then
        debugPrint("No pet found in workspace for furniture interaction")
        hrp.CFrame = originalCFrame
        return false
    end
    debugPrint("Interacting with furniture...")
    local interactArgs = {
        furnitureData.model,
        furnitureData.partName
    }
    local interactSuccess, interactResult = pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("FurnitureAPI/InteractWithFurniture"):FireServer(unpack(interactArgs))
    end)
    if interactSuccess then
        debugPrint("Furniture interaction initiated")
    else
        debugPrint("Furniture interaction failed: " .. tostring(interactResult))
    end
    debugPrint("Waiting for ailment to progress...")
    task.wait(15)
    debugPrint("Returning to original position...")
    hrp.CFrame = originalCFrame
    return true
end
local function getPetPenSnapshot()
    local snapshot = {}
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
    if not success or not data or not data.idle_progression or not data.idle_progression.pets then
        return snapshot
    end
    for uniqueId, petData in pairs(data.idle_progression.pets) do
        table.insert(snapshot, {
            unique_id = uniqueId,
            name = petData.id or "unknown",
            age = petData.age or 0,
            neon = petData.neon or false
        })
    end
    debugPrint("PetPen snapshot: " .. #snapshot .. " pets")
    return snapshot
end
local function purgeNonPriorityGarbage()
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
    if not success or not data or not data.inventory or not data.inventory.pets then
        return
    end
    local garbagePatterns = {"orangutan", "practice_dog"}
    for uniqueId, petData in pairs(data.inventory.pets) do
        local petName = string.lower(petData.id or "")
        for _, pattern in ipairs(garbagePatterns) do
            if string.find(petName, pattern) then
                debugPrint("PURGING garbage pet: " .. petData.id)
                pcall(function()
                    ReplicatedStorage.API["InventoryAPI/DeleteItem"]:FireServer(uniqueId)
                end)
                task.wait(0.5)
                break
            end
        end
    end
end
local function performNeonFusion()
    local fusionsPerformed = 0
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
    if not success or not data or not data.inventory or not data.inventory.pets then
        return fusionsPerformed
    end
    local petsByType = {}
    for uniqueId, petData in pairs(data.inventory.pets) do
        if petData.properties and (petData.properties.age or 0) >= 6 and not petData.properties.neon then
            local petType = petData.id
            if not petsByType[petType] then
                petsByType[petType] = {}
            end
            table.insert(petsByType[petType], uniqueId)
        end
    end
    for petType, pets in pairs(petsByType) do
        if #pets >= 4 then
            debugPrint("Fusing 4x " .. petType .. " into NEON!")
            local petsToFuse = {pets[1], pets[2], pets[3], pets[4]}
            local fuseSuccess = pcall(function()
                ReplicatedStorage.API["CombineAPI/CombinePets"]:InvokeServer(petsToFuse)
            end)
            if fuseSuccess then
                debugPrint("NEON FUSION SUCCESS: " .. petType)
                fusionsPerformed += 1
                task.wait(2)
            else
                debugPrint("NEON FUSION FAILED: " .. petType)
            end
        end
    end
    return fusionsPerformed
end
local function getAvailablePets(snapshot)
    local available = {}
    local inPen = {}
    for _, pet in ipairs(snapshot) do
        inPen[pet.unique_id] = true
    end
    local success, data = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
    end)
    if success and data and data.inventory and data.inventory.pets then
        for uniqueId, petData in pairs(data.inventory.pets) do
            if not inPen[uniqueId] and (petData.properties.age or 0) < 6 then
                table.insert(available, {
                    unique_id = uniqueId,
                    name = petData.id,
                    age = petData.properties.age or 0,
                    neon = petData.properties.neon or false
                })
            end
        end
    end
    return available
end
local function addPriorityPets(snapshot)
    local available = getAvailablePets(snapshot)
    local slotsOpen = 4 - #snapshot
    if slotsOpen <= 0 then return 0 end
    local added = 0
    local addedSet = {}
    for _, pet in ipairs(available) do
        if pet.neon and added < slotsOpen then
            if not addedSet[pet.unique_id] then
                pcall(function() ReplicatedStorage.API["IdleProgressionAPI/AddPet"]:FireServer(pet.unique_id) end)
                debugPrint("Added NEON: " .. pet.name)
                added += 1
                addedSet[pet.unique_id] = true
                task.wait(0.6)
            end
        end
    end
    for _, eggName in ipairs(priorityEggs) do
        for _, pet in ipairs(available) do
            if pet.name == eggName and added < slotsOpen and not addedSet[pet.unique_id] then
                pcall(function() ReplicatedStorage.API["IdleProgressionAPI/AddPet"]:FireServer(pet.unique_id) end)
                debugPrint("Added PRIORITY: " .. pet.name)
                added += 1
                addedSet[pet.unique_id] = true
                task.wait(0.6)
            end
        end
    end
    while added < slotsOpen and AutoPetPenMode do
        debugPrint("Buying cracked_egg to fill slot...")
        local bought = pcall(function()
            ReplicatedStorage.API["ShopAPI/BuyItem"]:InvokeServer("pets", "cracked_egg", {buy_count = 1})
        end)
        if bought then
            task.wait(3)
            local newPets = getAvailablePets(getPetPenSnapshot())
            for _, pet in ipairs(newPets) do
                if pet.name == "cracked_egg" and not addedSet[pet.unique_id] then
                    pcall(function() ReplicatedStorage.API["IdleProgressionAPI/AddPet"]:FireServer(pet.unique_id) end)
                    debugPrint("Added PURCHASED cracked_egg")
                    added += 1
                    addedSet[pet.unique_id] = true
                    task.wait(0.6)
                    break
                end
            end
        else
            break
        end
    end
    debugPrint("Added " .. added .. " pets this cycle")
    return added
end
local function startAutoPetPen()
    while AutoPetPenMode do
        debugPrint("=== AUTO PETPEN CYCLE START ===")
        local fusionsPerformed = performNeonFusion()
        if fusionsPerformed > 0 then
            debugPrint("Neon Fusion completed, waiting 5 seconds before continuing...")
            task.wait(5)
        end
     
        purgeNonPriorityGarbage()
     
        local snapshot = getPetPenSnapshot()
     
        for _, pet in ipairs(snapshot) do
            if pet.age >= 6 then
                debugPrint("Removing aged pet: " .. pet.name .. " (Age: " .. pet.age .. ")")
                pcall(function() ReplicatedStorage.API["IdleProgressionAPI/RemovePet"]:FireServer(pet.unique_id) end)
                task.wait(0.7)
            end
        end
     
        task.wait(2)
        snapshot = getPetPenSnapshot()
     
        addPriorityPets(snapshot)
     
        if os.time() - lastPetPenCommitTime >= 300 then
            pcall(function() ReplicatedStorage.API["IdleProgressionAPI/CommitAllProgression"]:FireServer() end)
            debugPrint("Committed PetPen rewards")
            lastPetPenCommitTime = os.time()
        end
     
        debugPrint("=== AUTO PETPEN CYCLE COMPLETE ===")
        task.wait(60)
    end
end
local function toggleAutoPetPenMode()
    AutoPetPenMode = not AutoPetPenMode
    if AutoPetPenMode then
        debugPrint("Auto PetPen: ENABLED (WITH SMART NEON FUSION)")
        lastPetPenCommitTime = os.time()
        autoPetPenCoroutine = coroutine.wrap(startAutoPetPen)()
        task.spawn(purgeNonPriorityGarbage)
    else
        debugPrint("Auto PetPen: DISABLED")
    end
end
local function monitorAndHandleAilments()
    debugPrint("Starting ailment-only monitoring system with ALWAYS KEEP EQUIPPED...")
    local lastAilmentScanTime = 0
    local SCAN_INTERVAL = 10
    local lastEquipCheckTime = 0
    local EQUIP_CHECK_INTERVAL = 5
    local lastPetCheckTime = 0
    local PET_CHECK_INTERVAL = 10
    while PetFarmMode do
        local currentTime = os.time()
        if currentTime - lastEquipCheckTime >= EQUIP_CHECK_INTERVAL then
            local currentPetID = petFarmPetID or PetID
            if currentPetID then
                if not isPetEquipped(currentPetID) then
                    debugPrint("Pet not equipped in equip_manager, re-equipping immediately...")
                    local success = ensurePetEquipped(currentPetID, 8)
                    if not success then
                        debugPrint("Critical: Failed to re-equip pet via equip_manager, stopping PetFarm")
                        PetFarmMode = false
                        break
                    end
                else
                    debugPrint("Pet confirmed equipped in equip_manager")
                    if not findPlayerPetInWorkspace() then
                        debugPrint("Pet equipped but not in workspace, quick re-equip...")
                        ensurePetEquipped(currentPetID, 5)
                    end
                end
            else
                debugPrint("No pet ID available for equip check, stopping PetFarm")
                PetFarmMode = false
                break
            end
            lastEquipCheckTime = currentTime
        end
        if currentTime - lastPetCheckTime >= PET_CHECK_INTERVAL then
            local currentPetID = petFarmPetID or PetID
            if currentPetID then
                if not findPlayerPetInWorkspace() then
                    debugPrint("Pet not in workspace (legacy check), re-equipping...")
                    local success = ensurePetEquipped(currentPetID, 10)
                    if not success then
                        debugPrint("Failed to re-equip pet (legacy), but equip_manager says OK - continuing")
                    end
                end
            end
            lastPetCheckTime = currentTime
        end
        local success, data = pcall(function()
            return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
        end)
        if success and data and data.ailments_manager and data.ailments_manager.ailments then
            local foundActionableAilments = false
            local currentPetID = petFarmPetID or PetID
            local selectedPetUniqueID = nil
            if currentPetID then
                local playerData = require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
                if playerData and playerData.inventory and playerData.inventory.pets and playerData.inventory.pets[currentPetID] then
                    selectedPetUniqueID = playerData.inventory.pets[currentPetID].unique
                end
            end
            if not selectedPetUniqueID then
                debugPrint("No selected pet or pet not found in inventory")
                task.wait(SCAN_INTERVAL)
                continue
            end
            for ailmentId, ailmentData in pairs(data.ailments_manager.ailments) do
                if ailmentId == selectedPetUniqueID then
                    foundActionableAilments = true
                    for ailmentType, furnitureName in pairs(AILMENT_TASKS) do
                        if ailmentData[ailmentType] and type(ailmentData[ailmentType]) == "table" then
                            if not lastTaskTime[ailmentType] or (currentTime - lastTaskTime[ailmentType]) >= TASK_COOLDOWN then
                                if not isPetEquipped(selectedPetUniqueID) then
                                    debugPrint("Ailment detected but pet not equipped - re-equipping before handling...")
                                    ensurePetEquipped(selectedPetUniqueID, 10)
                                end
                                if ailmentType == "play" then
                                    debugPrint("PLAY AILMENT DETECTED! Using squeaky_bone_default")
                                    local success = handlePlayAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "walk" then
                                    debugPrint("WALK AILMENT DETECTED! Starting walk sequence")
                                    local success = handleWalkAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "ride" then
                                    debugPrint("RIDE AILMENT DETECTED! Starting ride sequence")
                                    local success = handleRideAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "sick" then
                                    debugPrint("SICK AILMENT DETECTED! Using healing apple")
                                    local success = handleSickAilment()
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "mystery" then
                                    debugPrint("MYSTERY AILMENT DETECTED! Starting resolution...")
                                    local success = resolveMysteryAilment(ailmentId)
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                elseif ailmentType == "pet_me" then
                                    debugPrint("PET ME AILMENT DETECTED! Handling...")
                                    local success = handlePetMeAilment(currentPetID)
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                else
                                    debugPrint(string.upper(ailmentType) .. " AILMENT DETECTED! Using " .. furnitureName)
                                    local success = useFurnitureWithPet(furnitureName)
                                    if success then lastTaskTime[ailmentType] = currentTime end
                                end
                                break
                            else
                                debugPrint(ailmentType .. " task on cooldown (" .. (TASK_COOLDOWN - (currentTime - lastTaskTime[ailmentType])) .. "s remaining)")
                            end
                        end
                    end
                    if foundActionableAilments then break end
                end
            end
            if not foundActionableAilments and currentTime - lastAilmentScanTime >= 60 then
                debugPrint("No actionable ailments detected for selected pet")
                lastAilmentScanTime = currentTime
            end
        else
            if currentTime - lastAilmentScanTime >= 60 then
                debugPrint("Error reading ailments data or no ailments found")
                lastAilmentScanTime = currentTime
            end
        end
        task.wait(SCAN_INTERVAL)
    end
end
local function startAilmentOnlyPetFarm()
    debugPrint("Starting AILMENT-ONLY PetFarm system with ALWAYS KEEP EQUIPPED...")
    debugPrint("Features: Ailment Monitoring + Throw Toys for Play Ailment + Walk Handler + Ride Handler + Sick Handler + Mystery Handler + Auto Pet Re-equip (via equip_manager)")
    local currentCyclePetID = PetID or lastValidPetID or petFarmPetID
    if not currentCyclePetID then
        debugPrint("No pet selected for PetFarm")
        PetFarmMode = false
        return
    end
    local char = ensureCharacterSpawned()
    if not char then
        debugPrint("Cannot start PetFarm: No valid character")
        PetFarmMode = false
        return
    end
    debugPrint("Ensuring pet is equipped and present (via equip_manager)...")
    local ensured = ensurePetEquipped(currentCyclePetID, 18)
    if not ensured then
        debugPrint("Failed to ensure pet is equipped/present")
        PetFarmMode = false
        return
    end
    petFarmPetID = currentCyclePetID
    lastValidPetID = currentCyclePetID
    checkAndBuyMissingFurniture()
    task.wait(3)
    local args = {true}
    pcall(function()
        ReplicatedStorage:WaitForChild("API"):WaitForChild("HousingAPI/SetDoorLocked"):InvokeServer(unpack(args))
    end)
    debugPrint("Door locked, starting ailment monitoring with always-equipped...")
    monitorAndHandleAilments()
    safelyUnequipToy()
    safelyUnequipStroller()
    safelyUnequipFood(currentFoodID)
    if petFarmPetID then
        pcall(function()
            ReplicatedStorage.API["ToolAPI/Unequip"]:InvokeServer(petFarmPetID)
        end)
        petFarmPetID = nil
    end
    debugPrint("Ailment-only PetFarm stopped")
end
local function togglePetFarmMode()
    if PetFarmMode and petFarmCoroutine then
        debugPrint("PetFarm is already running, stopping first...")
        PetFarmMode = false
        task.wait(2)
    end
    PetFarmMode = not PetFarmMode
    if PetFarmMode then
        if not PetID and lastValidPetID then
            PetID = lastValidPetID
            debugPrint("Restored PetID from lastValidPetID: " .. tostring(PetID))
        end
        if not PetID then
            debugPrint("Please select a pet first!")
            PetFarmMode = false
            return
        end
        debugPrint("AILMENT-ONLY PetFarm: ENABLED with selected pet (ALWAYS KEEP EQUIPPED)")
        lastValidPetID = PetID
        if not isPlayerAtHome() then
            debugPrint("Player not at home when enabling PetFarm. Waiting 2 seconds and performing a single respawn.")
            task.wait(2)
            pcall(function()
                local api = ReplicatedStorage:FindFirstChild("API")
                if api then
                    local spawnAPI = api:FindFirstChild("TeamAPI/Spawn")
                    if spawnAPI then
                        spawnAPI:InvokeServer()
                    end
                end
            end)
            task.wait(5)
        else
            debugPrint("Player is at home, no respawn required.")
        end
        local ensured = ensurePetEquipped(PetID, 18)
        if not ensured then
            debugPrint("Could not ensure selected pet is equipped/present. Starting PetFarm anyway may fail. Aborting start to be safe.")
            PetFarmMode = false
            return
        end
        petFarmCoroutine = coroutine.wrap(startAilmentOnlyPetFarm)()
    else
        debugPrint("AILMENT-ONLY PetFarm: DISABLED")
        petFarmCoroutine = nil
        safelyUnequipToy()
        safelyUnequipStroller()
        safelyUnequipFood(currentFoodID)
        if petFarmPetID then
            pcall(function()
                ReplicatedStorage.API["ToolAPI/Unequip"]:InvokeServer(petFarmPetID)
            end)
            petFarmPetID = nil
        end
    end
end
local function createEnhancedCompactUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PetFarmUI"
    screenGui.Parent = player:WaitForChild("PlayerGui")
  
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 180, 0, 195)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.BackgroundTransparency = 0.1
    frame.Parent = screenGui
  
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame
    local sessionLabel = Instance.new("TextLabel")
    sessionLabel.Size = UDim2.new(1, 0, 0, 20)
    sessionLabel.Position = UDim2.new(0, 5, 0, 0)
    sessionLabel.BackgroundTransparency = 1
    sessionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    sessionLabel.Text = "💵 0 +0 | 🧪 0 +0 | ♻️ 0 | 🥚 0"
    sessionLabel.Font = Enum.Font.SourceSans
    sessionLabel.TextSize = 11
    sessionLabel.TextXAlignment = Enum.TextXAlignment.Left
    sessionLabel.Parent = frame
    sessionLabel.RichText = true
    local devConsoleButton = Instance.new("TextButton")
    devConsoleButton.Size = UDim2.new(0, 20, 0, 20)
    devConsoleButton.Position = UDim2.new(1, -20, 0, 0)
    devConsoleButton.BackgroundTransparency = 1
    devConsoleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    devConsoleButton.Text = "⚠️"
    devConsoleButton.Font = Enum.Font.SourceSansBold
    devConsoleButton.TextSize = 14
    devConsoleButton.Parent = frame
    devConsoleButton.MouseButton1Click:Connect(function()
        game:GetService("StarterGui"):SetCore("DevConsoleVisible", true)
    end)
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 20)
    title.Position = UDim2.new(0, 0, 0, 20)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "🐾 Cocoon PetFarm"
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 14
    title.Parent = frame
    local playerNameBox = Instance.new("TextBox")
    playerNameBox.Size = UDim2.new(0, 160, 0, 20)
    playerNameBox.Position = UDim2.new(0, 10, 0, 45)
    playerNameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    playerNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerNameBox.PlaceholderText = "Enter player name"
    playerNameBox.Text = ""
    playerNameBox.Font = Enum.Font.SourceSans
    playerNameBox.TextSize = 11
    playerNameBox.Parent = frame
  
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 4)
    boxCorner.Parent = playerNameBox
    local tradeButton = Instance.new("TextButton")
    tradeButton.Size = UDim2.new(0, 78, 0, 20)
    tradeButton.Position = UDim2.new(0, 10, 0, 70)
    tradeButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
    tradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tradeButton.Text = "Send Trade"
    tradeButton.Font = Enum.Font.SourceSansBold
    tradeButton.TextSize = 10
    tradeButton.Parent = frame
  
    local tradeButtonCorner = Instance.new("UICorner")
    tradeButtonCorner.CornerRadius = UDim.new(0, 4)
    tradeButtonCorner.Parent = tradeButton
    local addPetsButton = Instance.new("TextButton")
    addPetsButton.Size = UDim2.new(0, 78, 0, 20)
    addPetsButton.Position = UDim2.new(0, 92, 0, 70)
    addPetsButton.BackgroundColor3 = Color3.fromRGB(170, 0, 170)
    addPetsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    addPetsButton.Text = "Add All Pets"
    addPetsButton.Font = Enum.Font.SourceSansBold
    addPetsButton.TextSize = 10
    addPetsButton.Parent = frame
  
    local addPetsCorner = Instance.new("UICorner")
    addPetsCorner.CornerRadius = UDim.new(0, 4)
    addPetsCorner.Parent = addPetsButton
    local autoTradeButton = Instance.new("TextButton")
    autoTradeButton.Size = UDim2.new(0, 160, 0, 20)
    autoTradeButton.Position = UDim2.new(0, 10, 0, 95)
    autoTradeButton.BackgroundColor3 = Color3.fromRGB(215, 120, 0)
    autoTradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoTradeButton.Text = "Auto Trade [OFF]"
    autoTradeButton.Font = Enum.Font.SourceSansBold
    autoTradeButton.TextSize = 10
    autoTradeButton.Parent = frame
  
    local autoTradeCorner = Instance.new("UICorner")
    autoTradeCorner.CornerRadius = UDim.new(0, 4)
    autoTradeCorner.Parent = autoTradeButton
    local autoPetPenButton = Instance.new("TextButton")
    autoPetPenButton.Size = UDim2.new(0, 160, 0, 20)
    autoPetPenButton.Position = UDim2.new(0, 10, 0, 120)
    autoPetPenButton.BackgroundColor3 = Color3.fromRGB(170, 170, 0)
    autoPetPenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoPetPenButton.Text = "Auto PetPen [ON]"
    autoPetPenButton.Font = Enum.Font.SourceSansBold
    autoPetPenButton.TextSize = 10
    autoPetPenButton.Parent = frame
  
    local autoPetPenCorner = Instance.new("UICorner")
    autoPetPenCorner.CornerRadius = UDim.new(0, 4)
    autoPetPenCorner.Parent = autoPetPenButton
    local petFarmButton = Instance.new("TextButton")
    petFarmButton.Size = UDim2.new(0, 160, 0, 25)
    petFarmButton.Position = UDim2.new(0, 10, 0, 145)
    petFarmButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    petFarmButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    petFarmButton.Text = "Start PetFarm [OFF]"
    petFarmButton.Font = Enum.Font.SourceSansBold
    petFarmButton.TextSize = 12
    petFarmButton.Parent = frame
  
    local petFarmCorner = Instance.new("UICorner")
    petFarmCorner.CornerRadius = UDim.new(0, 4)
    petFarmCorner.Parent = petFarmButton
    local petSelectButton = Instance.new("TextButton")
    petSelectButton.Size = UDim2.new(0, 160, 0, 20)
    petSelectButton.Position = UDim2.new(0, 10, 0, 175)
    petSelectButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    petSelectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    petSelectButton.Text = "Select Pet ▼"
    petSelectButton.Font = Enum.Font.SourceSansBold
    petSelectButton.TextSize = 10
    petSelectButton.Parent = frame
  
    local petSelectCorner = Instance.new("UICorner")
    petSelectCorner.CornerRadius = UDim.new(0, 4)
    petSelectCorner.Parent = petSelectButton
    tradeButton.MouseButton1Click:Connect(function()
        sendTradeRequest(playerNameBox.Text)
    end)
    addPetsButton.MouseButton1Click:Connect(function()
        addAllPetsToTrade()
    end)
    autoTradeButton.MouseButton1Click:Connect(function()
        toggleContinuousMode()
        if ContinuousMode then
            autoTradeButton.Text = "Auto Trade [ON]"
            autoTradeButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        else
            autoTradeButton.Text = "Auto Trade [OFF]"
            autoTradeButton.BackgroundColor3 = Color3.fromRGB(215, 120, 0)
        end
    end)
    autoPetPenButton.MouseButton1Click:Connect(function()
        toggleAutoPetPenMode()
        if AutoPetPenMode then
            autoPetPenButton.Text = "Auto PetPen [ON]"
            autoPetPenButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        else
            autoPetPenButton.Text = "Auto PetPen [OFF]"
            autoPetPenButton.BackgroundColor3 = Color3.fromRGB(170, 170, 0)
        end
    end)
    petFarmButton.MouseButton1Click:Connect(function()
        togglePetFarmMode()
        if PetFarmMode then
            petFarmButton.Text = "Stop PetFarm [ON]"
            petFarmButton.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        else
            petFarmButton.Text = "Start PetFarm [OFF]"
            petFarmButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        end
    end)
    local petDropdown = nil
    local dropdownOpen = false
    petSelectButton.MouseButton1Click:Connect(function()
        if dropdownOpen and petDropdown then
            petDropdown:Destroy()
            petDropdown = nil
            dropdownOpen = false
            return
        end
        dropdownOpen = true
        petDropdown = Instance.new("ScrollingFrame")
        petDropdown.Size = UDim2.new(0, 160, 0, 150)
        petDropdown.Position = UDim2.new(0, 10, 0, 195)
        petDropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        petDropdown.BorderSizePixel = 0
        petDropdown.ScrollBarThickness = 6
        petDropdown.Parent = frame
        local dropdownCorner = Instance.new("UICorner")
        dropdownCorner.CornerRadius = UDim.new(0, 4)
        dropdownCorner.Parent = petDropdown
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Parent = petDropdown
        local success, data = pcall(function()
            return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
        end)
        if success and data and data.inventory and data.inventory.pets then
            local petIndex = 0
            for uniqueId, petData in pairs(data.inventory.pets) do
                petIndex = petIndex + 1
                local petButton = Instance.new("TextButton")
                petButton.Size = UDim2.new(1, -10, 0, 25)
                petButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
                petButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                local petName = petData.id or "Unknown"
                local petAge = petData.properties and petData.properties.age or 0
                local isNeon = petData.properties and petData.properties.neon
                local displayText = petName .. " (Age: " .. petAge .. ")"
                if isNeon then
                    displayText = "✨ " .. displayText
                end
                petButton.Text = displayText
                petButton.Font = Enum.Font.SourceSans
                petButton.TextSize = 10
                petButton.LayoutOrder = petIndex
                petButton.Parent = petDropdown
                local petButtonCorner = Instance.new("UICorner")
                petButtonCorner.CornerRadius = UDim.new(0, 4)
                petButtonCorner.Parent = petButton
                petButton.MouseButton1Click:Connect(function()
                    PetID = uniqueId
                    lastValidPetID = uniqueId
                    petSelectButton.Text = "Pet: " .. petName
                    debugPrint("Selected pet: " .. petName .. " (ID: " .. uniqueId .. ")")
                    petDropdown:Destroy()
                    petDropdown = nil
                    dropdownOpen = false
                end)
            end
            petDropdown.CanvasSize = UDim2.new(0, 0, 0, petIndex * 25)
        end
    end)
    local function updateSessionStats()
        local success, data = pcall(function()
            return require(ReplicatedStorage.ClientModules.Core.ClientData).get_data()[player.Name]
        end)
        if success and data then
            local currentMoney = data.currency and data.currency.bucks or 0
            local currentPotions = 0
            if data.inventory and data.inventory.food then
                for _, foodData in pairs(data.inventory.food) do
                    if foodData.id and string.lower(foodData.id) == "pet_age_potion" then
                        currentPotions = currentPotions + (foodData.amount or 1)
                    end
                end
            end
            if lastMoneyAmount > 0 then
                local moneyDiff = currentMoney - lastMoneyAmount
                if moneyDiff > 0 then
                    sessionBucksEarned = sessionBucksEarned + moneyDiff
                end
            end
            lastMoneyAmount = currentMoney
            if lastPotionAmount > 0 then
                local potionDiff = currentPotions - lastPotionAmount
                if potionDiff > 0 then
                    sessionPotionsEarned = sessionPotionsEarned + potionDiff
                end
            end
            lastPotionAmount = currentPotions
            local neonCount = 0
            local eggCount = 0
            if data.inventory and data.inventory.pets then
                for _, petData in pairs(data.inventory.pets) do
                    if petData.properties and petData.properties.neon then
                        neonCount = neonCount + 1
                    end
                    local petName = string.lower(petData.id or "")
                    if string.find(petName, "egg") then
                        eggCount = eggCount + 1
                    end
                end
            end
            sessionLabel.Text = "💵 " .. currentMoney .. " +" .. sessionBucksEarned .. " | 🧪 " .. currentPotions .. " +" .. sessionPotionsEarned .. " | ♻️ " .. neonCount .. " | 🥚 " .. eggCount
        end
    end
    task.spawn(function()
        while true do
            updateSessionStats()
            task.wait(5)
        end
    end)
    return screenGui
end
local function initializeScript()
    if scriptInitialized then return end
    scriptInitialized = true
    debugPrint("Initializing PetFarm Script...")
    createEnhancedCompactUI()
    toggleAutoPetPenMode()
    debugPrint("Script initialized successfully!")
end
initializeScript()
