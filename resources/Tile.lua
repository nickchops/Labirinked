
Tile = inheritsFrom(baseClass)

tileTypes = debugTileTypes or { "floor", "floor", "corner", "road", "bridge", "threeway", "extratime", "blocker", "stairAscend", "floorRaised", "roadRaised", "roadRaisedGateway", "roadRaisedOverpass" }
--tileTypes = debugTileTypes or { "floor", "corner", "road", "bridge", "threeway", "extratime"}

tileTypeCount = 0
for k,v in pairs(tileTypes) do
    tileTypeCount = tileTypeCount + 1
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

