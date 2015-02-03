
Tile = inheritsFrom(baseClass)

tileTypes = debugTileTypes or { "floor", "corner", "road", "bridge", "threeway", "extratime", "blocker", "stairAscend" }
--tileTypes = debugTileTypes or { "floor", "corner", "road", "bridge", "threeway", "extratime"}

tileTypeCount = 0
for k,v in pairs(tileTypes) do
    tileTypeCount = tileTypeCount + 1
end

-- Directions supported. 1=0deg, 2=90cw, 3=180, 4=270cw.
-- 0 = the image's rotation in file
-- Doesn't indicate the direction of actual travel
tileRotations = { floor={1}, corner={1,2,3,4}, road={1,2}, bridge={1},
        threeway={1,2,3,4}, extratime={1}, blocker={1}, stairAscend = {1,3} }
    
-- NB: self.rotation indicates which of the above is used, not actual rotation.
-- Actual rotation of the tile is: tileRotations[tile.tileType][tile.rotation]

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
              stairAscend={{"left","right"}, nil, {"left","right"}} --needs to track height too...
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
    
    self.origin = director:createNode({x=self.x, y=self.y})
    self:createSprite(0)
    
    --use centre pos when creating and fade in, e.g. in queue
end

function Tile:process(player)
    if self.tileType == "extratime" then
        sceneGame:incrementTimer(5)
    
        self.sprite:removeFromParent()
        self.tileType = "floor"
        self:createSprite() --position back where it already was
    end
end

function Tile:createSprite(startAlpha,x,y)
    startAlpha = startAlpha or tileAlpha
    x = x or -self.posOffset
    y = y or -self.posOffset
    
    local suffix
    --TODO: this logic is bad, but not being used yet/anymore anyway...
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
    
    self.origin:addChild(self.sprite)
    
    if self.gridY then
        board:setDepth(self)
    end
end

function Tile:canRotate()
    return tileRotations[self.tileType][2]--array larger than 1
end

function Tile:rotateRight()
    if not self:canRotate() then return end
    
    self.rotation = self.rotation + 1
    if not tileRotations[self.tileType][self.rotation] then
        self.rotation = 1
    end
    
    self:setRotation()
end

function Tile:rotateLeft()
    if not self:canRotate() then return end
    
    self.rotation = self.rotation - 1
    if not tileRotations[self.tileType][self.rotation] then
        for k,v in ipairs(tileRotations[self.tileType]) do
            self.rotation = v
        end
    end
    
    self:setRotation()
end


function Tile:setRotation()
    if self.tileType == "stairAscend" then
        self.sprite.xFlip = self.rotation == 2
        return
    end
    
    self.origin.rotation = (self.rotation - 1) * 90
end

function Tile:setPos(x,y)
    self.origin.x = x+self.posOffset
    self.origin.y = y+self.posOffset
end

function Tile:setPosCentered(x,y)
    self.origin.x = x
    self.origin.y = y
end

function tilePlaced(target)
    local tile = target.tile
    if not tile.startSlot then
        board:addTile(tile.gridX, tile.gridY, tile)
    
        if tile.gridX==1 and tile.gridY==0 then
            dbg.print("------------------------")
            dbg.print("TILE LAID FOR FINAL MOVE")
        end
            
        if target.players then
            for k,player in pairs(target.players) do
                dbg.print("CALLING TRY MOVE FOR: " .. player.id)
                player:tryToMove() -- if other player's move already completed the level, this just returns
            end
        end
    end
    target.tile = nil
    target.players = nil
end

-- return true = placed in new place on grid
function Tile:setGridTarget(gridX, gridY, nearPlayers)
    self.origin.tile = self
    self.origin.players = nearPlayers
    dbg.print("setGridTarget: x,y=" .. gridX .. "," .. gridY)
    if gridX < 0 or gridY < 0 then
        if self.startSlot then
            --back to slot
            tween:to(self.origin, {x=self.startX, y=self.startY, time=0.2, onComplete=tilePlaced})
        else
            --back to where it came from on grid
            
            --TODO: allow to go back to queue if came from board by finding next empty slot
            -- for now, jsut always return to where it came from
            -- prob do this by leaving this as-is and setting the startSlot val elsewhere...
            self.x, self.Y = board:getScreenPosCentre(self.gridX, self.gridY)
            tween:to(self.origin, {x=self.x, y=self.y, time=0.2, onComplete=tilePlaced})
        end
        return false, false
    else
        dbg.print("target is on grid")
        --to new grid position
        self.gridX = gridX
        self.gridY = gridY
        self.x, self.y = board:getScreenPosCentre(gridX,gridY)
        tween:to(self.origin, {x=self.x, y=self.y, time=0.2, onComplete=tilePlaced})
        
        if self.startSlot then
            dbg.print("got a start slot")
            local oldSlot = self.startSlot
            self.startSlot = nil
            return nearPlayers or true, oldSlot
        else
            return nearPlayers or true, false
        end
    end
end

