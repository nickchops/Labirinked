
Tile = inheritsFrom(baseClass)

tileTypes = { "floor", "corner", "road", "bridge", "threeway", "extratime", "blocker", "stairAscend" }
--tileTypes = debugTileTypes or { "floor", "corner", "road", "bridge", "threeway", "extratime"}

tileTypeCount = 0
for k,v in pairs(tileTypes) do
    tileTypeCount = tileTypeCount + 1
end

-- Directions supported. 1=0deg, 2=90cw, 3=180, 4=270cw.
-- 0 = the image's rotation in file
-- Doesn't indicate the direction of actual travel
tileRotations = { floor={1}, corner={1,2,3,4}, road={1,2}, bridge={1},
        threeway={1,2,3,4}, extratime={1}, blocker={1}, stairAscend = {1} }

--Directions a tile of each type lets you move off of it.
--corner: "up" is curve from bottom to right!
--road: up/down it top to bottom, left/right is other way!
--bridge: currently only goes left/right always
--floor: goes in all direcitons always
--threeway: 
tilePaths = { floor={{"up","left","down","right"}},
              corner={{"down","right"},{"left","down"},{"up","left"},{"up","right"}},
              road={{"left","right"},{"up","down"}},
              threeway={{"up","down","right"},{"left","right","down"},{"up","down","left"},{"up","left","right"}},
              bridge={{"left","right"}},
              extratime={{"up","left","down","right"}},
              blocker={{}},
              stairAscend={{"left","right"}}
          }

tileAlpha = 0.9

--x and y are screen positions since doesnt usually start on the grid
function Tile:init(x, y, tileType, rotation, tileWidth)
    
    if not tileRotations[tileType][rotation] then rotation = tileRotations[tileType][1] end
    
    self.tileType = tileType
    self.rotation = rotation
    self.x = x
    self.y = y
    self.posOffset = tileWidth/2
    
    self:createSprite(self.x - self.posOffset, self.y - self.posOffset, 0)
    --centre pos on when creating and fade in, e.g. in queue
end

function Tile:process(player)
    if self.tileType == "extratime" then
        sceneGame:incrementTimer(5)
    
        self.sprite:removeFromParent()
        self.tileType = "floor"
        self.sprite = self:createSprite(self.x, self.y) --position back where it already was
    end
end

function Tile:createSprite(x,y,startAlpha)
    startAlpha = startAlpha or tileAlpha
    local suffix
    if self.tileType == "bridge" then
        if self.rotation == 1 then
            suffix = "-horiz"
        else
            suffix = "-vert" --doesnt exist yet but wont ever be hit
        end
    elseif self.tileType == "stairAscend" then
        if self.rotation == 1 or self.rotation == 3 then
            suffix = "-horiz"
        else
            suffix = rotation --also doesnt exist
        end
    --elseif self.tileType == THINGS WITH UNIQUE IMAGES FOR EACH ROTATION then
    --    suffix = rotation
    else
        suffix = "" --one image that is just rotated!
    end
    
    self.imageType = self.tileType .. suffix
    
    self.sprite = director:createSprite(x, y, "textures/tile-" .. self.imageType .. ".png")
    setDefaultSize(self.sprite, self.posOffset*2)
    self.sprite.alpha=startAlpha
    
    if self.gridY then
        board:setDepth(self)
    end
end

function Tile:canRotate()
    return tileRotations[self.tileType][2]--array larger than 1
end

function Tile:rotateRight()
    
end

function Tile:rotateLeft()
    
end

function Tile:setPos(x,y)
    self.sprite.x = x
    self.sprite.y = y
end

function Tile:setPosCentered(x,y)
    self.sprite.x = x - self.posOffset
    self.sprite.y = y - self.posOffset
end

function tilePlaced(target)
    local tile = target.tile
    if not tile.startSlot then
        board:addTile(tile.gridX, tile.gridY, tile)
    
        if target.player then
            target.player:tryToMove()
        end
    end
    target.tile = nil
    target.player = nil
end

-- return true = placed in new place on grid
function Tile:setGridTarget(gridX, gridY, nearPlayer)
    self.sprite.tile = self
    self.sprite.player = nearPlayer
    if gridX < 0 or gridY < 0 then
        if self.startSlot then
            --back to slot
            tween:to(self.sprite, {x=self.startX-self.posOffset, y=self.startY-self.posOffset, time=0.2, onComplete=tilePlaced})
        else
            --back to where it came from on grid
            
            --TODO: allow to go back to queue if came from board by finding next empty slot
            -- for now, jsut always return to where it came from
            -- prob do this by leaving this as-is and setting the startSlot val elsewhere...
            self.x, self.Y = board:getScreenPos(self.gridX, self.gridY)
            tween:to(self.sprite, {x=self.x, y=self.y, time=0.2, onComplete=tilePlaced})
        end
        return false, false
    else
        --to new grid position
        self.gridX = gridX
        self.gridY = gridY
        self.x, self.y = board:getScreenPos(gridX,gridY)
        tween:to(self.sprite, {x=self.x, y=self.y, time=0.2, onComplete=tilePlaced})
        
        if self.startSlot then
            local oldSlot = self.startSlot
            self.startSlot = nil
            return nearPlayer or true, oldSlot
        else
            return nearPlayer or true, false
        end
    end
end

