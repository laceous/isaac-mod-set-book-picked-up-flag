local mod = RegisterMod('Set Book Picked Up Flag', 1)
local game = Game()

-- prove this works:
-- repentance start seed: GXM6 T0ND (normal)
-- > g the mind (so you can see the entire map)
-- > stage 3 (notice there's no library)
-- > lua Game():SetStateFlag(8, true)
-- > stage 3 (notice there's now a library on the map)

-- seed to test stage 1: EMFE RGJ0 (normal)

mod.books = nil

-- not using QueuedItem so we can check for default items
-- as well as items given via the debug console
function mod:onPlayerUpdate(player)
  if game:GetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP) then
    return
  end
  
  if mod.books == nil then
    mod.books = mod:getBooks()
  end
  
  for _, book in ipairs(mod.books) do
    if player:HasCollectible(book, true) then
      game:SetStateFlag(GameStateFlag.STATE_BOOK_PICKED_UP, true)
      --print('set STATE_BOOK_PICKED_UP = true')
      
      -- setting the state in MC_POST_PLAYER_INIT causes the first floor to load with the correct library state
      -- unfortunately, HasCollectible doesn't work from there, so reload the stage from here
      if game:GetFrameCount() == 0 then
        -- this does not break true co-op
        mod:reloadStage()
      end
      
      return
    end
  end
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

-- MC_POST_UPDATE runs less often, but reloading the stage looks janky
mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, mod.onPlayerUpdate, 0) -- 0 is player, 1 is co-op baby