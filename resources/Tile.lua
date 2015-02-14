
Tile = inheritsFrom(baseClass)

--tileTypes = debugTileTypes or { "floor", "stairAscend", "corner", "road", "bridge", "threeway", "extratime", "blocker", "stairAscend", "floorRaised", "roadRaised", "roadRaisedGateway", "roadRaisedOverpass" }
Tile.tileTypes = debugTileTypes or { "floor", "stairAscend", "corner", "road", "bridge", "threeway", "extratime", "blocker", "stairAscend", "floorRaised", "roadRaised" }

Tile.tileTypeCount = 0
for k,v in pairs(Tile.tileTypes) do
    Tile.tileTypeCount = Tile.tileTypeCount + 1
end

-- Directions supported. 1=0deg, 2=90cw, 3=180, 4=270cw.
-- 0 = the image's rotation in file
-- Doesn't indicate the direction of actual travel
tileRotations = { floor={1}, corner={1,2,3,4}, road={1,2}, bridge={1},
        threeway={1,2,3,4}, extratime={1}, blocker={1}, stairAscend = {1,3},
        floorRaised = {1}, roadRaised = {1}, roadRaisedGateway = {1}, roadRaisedOverpass = {1}
        }

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
              stairAscend={{"left","right"}, nil, {"left","right"}},
              floorRaised={{"up","left","down","right"}},
              roadRaised={{"left","right"}},
              roadRaisedGateway={{"left","right"}},
              roadRaisedOverpass={{"left","right"}}
        }

--currently using 1->4 to represent up->right->down->left.
--we should change the tables to use 'up={"up", "left"}' etc instead of being array
--we should also prob use different terminology for rotation, direction and sides
--e.g. "side-top", "side-right"... "side-top", "side-right"...  "rot-0", "rot-90"...
--tileHeights would then have {left=1, right=0} etc. No need for any of the nils anywhere

--this converts tileRotations and tileHeights indexes to directions
dirToIndex = {up=1,right=2,down=3,left=4}

--1st value is height at centre (stationary player height)
--2nd index exists -> we are on a ramp.
-- Values of 2nd index are height at each edge (up,right,down,left) per orientation
--0==floor height, 1 = walkway height (1 extra tile height high).
--3rd value is extra to adjust player y pos by (so that visual height
-- doesnt interfere with logic)
tileHeights = { floor={0},
              corner={0},
              road={0},
              threeway={0},
              bridge={0,nil,0.2},
              extratime={0},
              blocker={0},
              stairAscend={0.5, {{nil,1,nil,0}, nil, {nil,0,nil,1}}},
              floorRaised={1},
              roadRaised={1},
              roadRaisedGateway={1}, --TODO these two need to support two layers!
              roadRaisedOverpass={1}
        }

 --TODO prob make gateway, overpass and bridge work as-is
 -- and instead update GameBoard to allow two tiles in same space
 -- with floor, river, etc either drawn underneath or ivisible
 -- Then just do "if tile is table then try both tiles"
 --Plus add logic to put bridges on rivers. Maybe allow bridges
 -- on top of roads? Or force user to swap them out?

tileAlpha = 0.95

--x and y are screen positions since doesnt usually start on the grid
function Tile:init(x, y, tileType, rotation, tileWidth)
    
    if not tileRotations[tileType][rotation] then rotation = tileRotations[tileType][1] end
    
    self.tileType = tileType
    self.rotation = rotation
    self.x = x
    self.y = y
    self.posOffset = tileWidth/2
    
    self.players = {} --for tracking players the tile was previously near
    
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
        if self.rotation == 1 or self.rotation == 2 then -- 2->3!
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
    
    self:setRotation()
end

function Tile:getHeight(visualAdjust, dir)
    local heightMap = tileHeights[self.tileType]
    local height
    if dir and heightMap[2] then
        local tH = heightMap[2] -- table of {1,0} pairs
        local tDir = tileRotations[self.tileType][self.rotation] -- 1 or 3
        local heightPair = tH[tDir]
        if heightPair then
            dbg.print("heightPair:")
            dbg.printTable(heightPair)
        else
            dbg.print("NO heightPair!")
        end
        dbg.print("DIR: " .. dirToIndex[dir])
        
        height = heightPair[dirToIndex[dir]]
        --height = [][dir]
        --height = tileHeights[self.tileType][2][tileRotations[self.TileType][self.rotation]][dir]
        dbg.assert(height, "Error getting tile height! - " .. self.x .. "," .. self.y .. " " .. dir)
    else
        height = heightMap[1]
        dbg.print("single height: " .. height)
    end
    
    if visualAdjust and heightMap[3] then
        height = height + heightMap[3]
    end
    return height
end

function Tile:setFade(faded, animate)
    local alpha = tileAlpha
    if faded == true then alpha = 0.3 end
    
    -- we're tracking if tile and player overlap, but not doing anything with that info
    -- atm. Just always trying to fade back and resetting flags when we do
    if self.overlaps then
        self.overlaps.overlapTile = nil
        self.overlaps = nil
    end
    
    if self.sprite.alpha == alpha then return end
    
    cancelTweensOnNode(self.sprite)
    
    if animate then
        tween:to(self.sprite, {alpha=alpha, time=0.6})
    else
        self.sprite.alpha=alpha
    end  
end

function Tile:getCenterHeight()
    return tileHeights[self.tileType][1]
end

function Tile:canRotate()
    return tileRotations[self.tileType][2]--array larger than 1
end

function Tile:rotateRight()
    if not self:canRotate() then return false end
    
    self.rotation = self.rotation + 1
    if not tileRotations[self.tileType][self.rotation] then
        self.rotation = 1
    end
    
    self:setRotation()
    return true
end

function Tile:rotateLeft()
    if not self:canRotate() then return false end
    
    self.rotation = self.rotation - 1
    if not tileRotations[self.tileType][self.rotation] then
        for k,v in ipairs(tileRotations[self.tileType]) do
            self.rotation = v
        end
    end
    
    self:setRotation()
    return true
end


function Tile:setRotation()
    local rotation = tileRotations[self.tileType][self.rotation]
    
    if self.tileType == "stairAscend" then
        self.sprite.xFlip = rotation == 3
        return
    end
    
    self.origin.rotation = (rotation - 1) * 90
end

function Tile:setPos(x,y)
    self.origin.x = x+self.posOffset
    self.origin.y = y+self.posOffset
end

function Tile:setPosCentered(x,y)
    self.origin.x = x
    self.origin.y = y
end

function Tile:bringToFront()
    self.origin.zOrder = board:getMaxDepth() + 2
    self:setFade(false,true)
end

function tilePlaced(target)
    local tile = target.tile
    tile.finger = nil --allow a finger to pick it up again
    
    if not tile.startSlot then
        board:addTile(tile.gridX, tile.gridY, tile)
            
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
    
    -- these are players we *were* next to. Reset for next time. Player phases set to
    -- ready, but this will be overriden below for any players that need to animate.
    for k,player in pairs(self.players) do
        player.phase = "ready"
    end
    self.players = {}
    
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
            board:hideTileIfOverPlayer(self, true)
        end
        return false
    else
        dbg.print("target is on grid")
        --to new grid position
        self.gridX = gridX
        self.gridY = gridY
        self.x, self.y = board:getScreenPosCentre(gridX,gridY)
        tween:to(self.origin, {x=self.x, y=self.y, time=0.2, onComplete=tilePlaced})
        board:hideTileIfOverPlayer(self, true)
        
        for k,player in pairs(nearPlayers) do
            player.phase = "waitingForMove"
            dbg.print("added tile to board: near player(" .. player.id ..") setting player phase=" .. player.phase)
        end
        
        if self.startSlot then
            dbg.print("got a start slot")
            local oldSlot = self.startSlot
            self.startSlot = nil
            return oldSlot
        else            
            if self.playerTileWasFrom then
                dbg.print("TILE! tile being positioned was a player tile")
                -- In this sitution, playerTileWasFrom should always be the other player whose tile nearPlayers stole
                self.playerTileWasFrom.phase = "backtracking"
                self.playerTileWasFrom:backtrack()
            else
                dbg.print("NO TILE FROM PLAYER")
            end
            
            return false
        end
    end
end

