local mod = RegisterMod('Set Book Picked Up Flag', 1)
local json = require('json')
local game = Game()

-- prove this works:
-- repentance start seed: GXM6 T0ND (normal)
-- > g the mind (so you can see the entire map)
-- > stage 3 (notice there's no library)
-- > lua Game():SetStateFlag(8, true)
-- > stage 3 (notice there's now a library on the map)

-- seed to test stage 1: EMFE RGJ0 (normal)

mod.books = nil

mod.state = {}
mod.state.checkQueuedItem = false

function mod:onGameStart(isContinue)
  if mod:HasData() then
    local _, state = pcall(json.decode, mod:LoadData())
    
    if type(state) == 'table' then
      if type(state.checkQueuedItem) == 'boolean' then
        mod.state.checkQueuedItem = state.checkQueuedItem
      end
    end
  end
  
  if not isContinue and game:GetFrameCount() == 0 then
    -- setting the state in MC_POST_PLAYER_INIT causes the first floor to load with the correct library state
    -- unfortunately, player:HasCollectible doesn't work from there, so reload the stage from here
    if mod:checkAndSetFlag() then
      -- this does not break true co-op
      mod:reloadStage()
    end
  end
end

function mod:onGameExit()
  mod:save()
end

function mod:save()
  mod:SaveData(json.encode(mod.state))
end

function mod:onUpdate()
  mod:checkAndSetFlag()
end

function mod:checkAndSetFlag()
  if game:GetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP) then
    return false
  end
  
  if mod.state.checkQueuedItem then
    for i = 0, game:GetNumPlayers() - 1 do
      local player = game:GetPlayer(i)
      
      if player.QueuedItem.Item and
         player.QueuedItem.Item:IsCollectible() and
         player.QueuedItem.Item:HasTags(ItemConfig.TAG_BOOK) and
         not player.QueuedItem.Touched -- new book that hasn't been touched yet
      then
        game:SetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP, true)
        --print('set STATE_BOOK_PICKED_UP = true')
        
        return true
      end
    end
  else
    if mod.books == nil then
      mod.books = mod:getBooks()
    end
    
    -- there should be more books than players
    for _, book in ipairs(mod.books) do
      for i = 0, game:GetNumPlayers() - 1 do
        local player = game:GetPlayer(i)
        
        if player:HasCollectible(book, true) then
          game:SetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP, true)
          --print('set STATE_BOOK_PICKED_UP = true')
          
          return true
        end
      end
    end
  end
  
  return false
end

-- get books so we can loop over a smaller list of items
function mod:getBooks()
  local itemConfig = Isaac.GetItemConfig()
  local books = {}
  
  for i = 0, #itemConfig:GetCollectibles() - 1 do
    local collectibleConfig = itemConfig:GetCollectible(i)
    
    if collectibleConfig and collectibleConfig:HasTags(ItemConfig.TAG_BOOK) then
      table.insert(books, collectibleConfig.ID)
    end
  end
  
  --print(#books .. ' books')
  return books
end

function mod:reloadStage()
  local level = game:GetLevel()
  local stage = level:GetStage()
  local stageTypeMap = {
    [StageType.STAGETYPE_ORIGINAL]     = '',
    [StageType.STAGETYPE_WOTL]         = 'a',
    [StageType.STAGETYPE_AFTERBIRTH]   = 'b',
    [StageType.STAGETYPE_REPENTANCE]   = 'c',
    [StageType.STAGETYPE_REPENTANCE_B] = 'd',
  }
  local stageType = stageTypeMap[level:GetStageType()]
  
  if stageType then
    Isaac.ExecuteCommand('stage ' .. stage .. stageType)
  end
end

-- start ModConfigMenu --
function mod:setupModConfigMenu()
  local category = 'Set Book Picked Up' -- Flag
  for _, v in ipairs({ 'Settings' }) do
    ModConfigMenu.RemoveSubcategory(category, v)
  end
  ModConfigMenu.AddText(category, 'Settings', 'What should we count as picking up a book?')
  ModConfigMenu.AddSetting(
    category,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return mod.state.checkQueuedItem
      end,
      Display = function()
        return mod.state.checkQueuedItem and 'Player picks up new book from a pedestal' or 'Player currently has a book in inventory'
      end,
      OnChange = function(b)
        mod.state.checkQueuedItem = b
        mod:save()
      end,
      Info = { 'Inventory: has book by any means incl start item', 'Pedestal: momentary check when you pick up a book' }
    }
  )
  ModConfigMenu.AddSpace(category, 'Settings')
  ModConfigMenu.AddSetting(
    category,
    'Settings',
    {
      Type = ModConfigMenu.OptionType.BOOLEAN,
      CurrentSetting = function()
        return game:GetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP)
      end,
      Display = function()
        return 'Current state : flag ' .. (game:GetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP) and 'enabled' or 'disabled')
      end,
      OnChange = function(b)
        game:SetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP, b)
      end,
      Info = { 'Toggle flag' }
    }
  )
end
-- end ModConfigMenu --

-- MC_POST_UPDATE runs less often than MC_POST_PLAYER_UPDATE
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)

if ModConfigMenu then
  mod:setupModConfigMenu()
end