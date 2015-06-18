
--NB: general logic only supports thew whole grid being on the screen!
-- can tgo beyond screen bounds. maxTilesWide doesnt do anything yet!
-- would like to allow it to go outwards, but will change logic later if time

-- elements are in a 30x30 sparse matrix

GameBoard = inheritsFrom(baseClass)

--tilesWide etc are how many tiles wide the widthOnScreen are is
--maxTiles is max gameboard size (extending off the screen edges)
--menuHeight is distance from bottom where menu area for grabbing tiles, pause, etc lives
--menuHeight is *in tiles* not pixels!
--board will be centered on the screen in the area left after that
-- grid positions start at 0,0

function GameBoard:init(maxWidthOnScreen, tilesWide, maxHeightOnScreen, tilesHigh, maxTilesWide, menuHeight, debugDraw)
    self.board = {}
    self.boardVisited = {}
    self.boardReserved = {}
    self.tilesWide = tilesWide
    self.tilesHigh = tilesHigh
    self.maxTilesWide = maxTilesWide
    
    --get smallest tiles to fit both dimensions plus allow for menu/slots area
    self.tileWidth = math.min(maxWidthOnScreen/tilesWide, maxHeightOnScreen/(tilesHigh+menuHeight))
    self.halfTile = self.tileWidth/2
    self.menuHeight = menuHeight*self.tileWidth
    
    self.widthOnScreen = self.tilesWide * self.tileWidth
    self.heightOnScreen = self.tilesHigh * self.tileWidth
    self.startWidth = self.widthOnScreen
    self.startHeight = self.heightOnScreen
    
    self.startHeight = self.tileWidth * self.tilesHigh
    self.origin = director:createNode({x=appWidth/2 - self.startWidth/2,
            y = self.menuHeight + (appHeight-self.menuHeight)/2 - self.startHeight/2})
    
    self.canRotatePlayerTiles = false
    --true=allow rotation of tile underneath a player. Can create broken paths but might be nice mechanic...
    
    self.debugDraw = debugDraw
    if debugDraw then
        director:createRectangle({xAnchor=0, yAnchor=0, x=self.origin.x, y=self.origin.y, alpha=0, strokeWidth=2, strokeAlpha=0.5,
                strokeColor=color.red, w=self.widthOnScreen, h=self.heightOnScreen})
        
        for i=0,self.tilesHigh-1 do
            for j=0,self.tilesWide-1 do
                director:createCircle({x=self.origin.x + j*self.tileWidth+self.halfTile,
                        y = self.origin.y + i*self.tileWidth+self.halfTile,
                        alpha=0, strokeWidth=2, strokeAlpha=0.5, strokeColor=color.blue, radius=3})
            end
        end
    end
    
    print("BOARD HIGH: " .. self.tilesHigh)
    print("BOARD WIDE: " .. self.tilesWide)
end

function GameBoard:getMaxDepth()
    return self.tilesHigh * 10 -- 10 level per row, last ropw starts at x9
end

-- add Tile at position. Simple sparse row*column matrix as a table
function GameBoard:addTile(x,y,tile)
    self.board[y*self.maxTilesWide+x] = tile
    tile.gridX = x
    tile.gridY = y
    self:setDepth(tile)
end

function GameBoard:setVisited(x, y, visited, checkAndHideForegroundTile, animateHide)
    self.boardVisited[y*self.maxTilesWide+x] = visited
    
    if visited and checkAndHideForegroundTile then
        return self:checkAndHideTile(x, y-1, animateHide)
    end
end

--hide tile at position if height >=1
function GameBoard:checkAndHideTile(x, y, animate)
    local tile = self:getTile(x,y)
    
    if tile and tile:getCenterHeight() > self:getTile(x,y+1):getHeight() then
        dbg.print("hiding tile!")
        tile:setFade(true, animate)
        return tile -- returns a tile if it hides the tile
    end
end

--as above, but check given tile is in front of a player
function GameBoard:hideTileIfOverPlayer(tile, animate)
    dbg.print("hide tile...")
    local height = tile:getHeight()
    if height < 1 then
        return
    end
    dbg.print("hide tile...2")
    for k,player in pairs(players) do
        if player.x == tile.gridX and player.y == tile.gridY+1 and height > self:getTile(player.x,player.y):getHeight() then
            foundPlayer = true
            tile:setFade(true, animate)
            tile.overlaps = player
            player.overlapTile = tile
            return
        end
    end
end

function GameBoard:isVisited(x,y)
    return self.boardVisited[y*self.maxTilesWide+x]
end

function GameBoard:addNewTileToGrid(gridX, gridY, tileType, rotation)
    local tile = Tile:create()
    local screenX
    local screenY
    screenX, screenY = self:getScreenPosCentre(gridX, gridY)
    tile:init(screenX, screenY, tileType, rotation, self.tileWidth)
    self:addTile(gridX, gridY, tile)
    self:setDepth(tile)
    return tile
end

function GameBoard:setDepth(tile)
    tile.origin.zOrder = (self.tilesHigh - tile.gridY) * 10 --allowing 10 levels per row, not using most of them yet!
end

function GameBoard:getPlayerDepth(x,y)
    return (self.tilesHigh - y) * 10 + 2 --allow 1 pos between player and tile
end
-- input: grid pos starting at zero. output: screen position
function GameBoard:getScreenPosCentre(x,y,matchTileHeight)
    local retX = self.origin.x + self.tileWidth*x + self.halfTile
    local retY = self.origin.y + self.tileWidth*y + self.halfTile
    
    if matchTileHeight then
        local tile = self:getTile(x,y)
        local height = tile:getHeight(true)
        retY = retY + height*self.halfTile*1.7
    end
    
    return retX, retY
end

function GameBoard:getScreenPos(x,y)
    return self.origin.x + self.tileWidth*x,
           self.origin.y + self.tileWidth*y
end

function GameBoard:getNearestGridPos(x,y)
    x = math.floor((x-self.origin.x)/self.tileWidth)
    y = math.floor((y-self.origin.y)/self.tileWidth)
    
    if y < 0 then
        return -1, -1 
    end
    
    if x < 0 then x = 0 end
    if x > self.tilesWide-1 then x = self.tilesWide-1 end
    if y > self.tilesHigh-1 then y = self.tilesHigh-1 end
    
    return x,y
end

--[[
This function finds which of the 4 triangels below the point is in
in the current square and then gets the adjacent square that
triangle is next to. Returns false if adjacent square is not in the grid.
      /\
   --------
   | \  / |
<- |  \/  | ->
   |  /\  |
   | /  \ |
   --------
      \/  
      
]]--
function GameBoard:getNearestAdjacentGridPos(x,y)
    x = x-self.origin.x
    y = y-self.origin.y
    
    local xGrid = math.floor(x/self.tileWidth)
    local yGrid = math.floor(y/self.tileWidth)
    
    local xInSquare = x - self.tileWidth*xGrid
    local yInSquare = y - self.tileWidth*yGrid
    
    if xInSquare > yInSquare then --bottom/right
        if xInSquare + yInSquare > self.tileWidth then --right
            xGrid = xGrid + 1
        else --bottom
            yGrid = yGrid - 1
        end
    else --top/left
        if xInSquare + yInSquare > self.tileWidth then --top
            yGrid = yGrid + 1
        else --left
            xGrid = xGrid - 1
        end
    end
        
    if xGrid < 0 or xGrid > self.tilesWide-1 or yGrid < 0 or yGrid > self.tilesHigh-1 then
        return false
    end
    
    return true, xGrid, yGrid
end

function GameBoard:hasTile(x, y, includeReservedCells)
    local index = self:getTileIndex(x,y)
    if self:getTileAtIndex(index) then
        return true
    else
        if includeReservedCells and self.boardReserved[index] then
            return true
        else
            return false
        end
    end
end

function GameBoard:getTile(x,y)
    return self.board[y*self.maxTilesWide+x]
end

function GameBoard:getTileIndex(x,y)
    return y*self.maxTilesWide+x
end

function GameBoard:getTileAtIndex(index)
    return self.board[index]
end

function GameBoard:getAndRemoveTile(x, y, reserveGridPos)
    local index = self:getTileIndex(x,y)
    local tile = self:getTileAtIndex(index)
    self.board[index] = nil
    
    if reserveGridPos then
        self.boardReserved[index] = true
    end
    
    return tile
end

function GameBoard:freeUpTile(gridPos)
    self.boardReserved[self:getTileIndex(gridPos.x,gridPos.y)] = nil
end

--returns nil if move invalid, or a list of players next to the target square if move is valid
function GameBoard:isValidMove(x, y, tile, returningTileIsValid)
    if x < 0 or y < 0 or x >= self.tilesWide or y>= self.tilesHigh then
        return nil
    end
    
    local reCheckRotatedTile = returningTileIsValid and tile.gridX == x and tile.gridY == y
    -- -> putting rotated tile back where it came from on board.
    
    if not reCheckRotatedTile and self:hasTile(x,y,true) then
        --NB: hasTile is false if tile is currently being dragged from the position
        --(cant put new tile where old tile was until old tile is placed somewhere new)
        return nil
    end 
    
    --TODO?: use player.tilesLaid to check if player can have tiles (cant be more than 1 ahead of other player)
    -- to stop just using one player, though this is prob not actually needed...
    
    return self:isAdjacentToPlayers(x, y)  --no need to check if player as player square is always full ;)
    --return self:isAdjacentToPlayer(x, y, tile.player) --for alternative rules...
end

function GameBoard:isAdjacentToPlayers(x, y, playerSquareInvalid)
    local nearPlayers = {}
    local gotPlayer = false
    for k,player in pairs(players) do
        if self:isAdjacentToPlayer(x, y, player, playerSquareInvalid) then
            table.insert(nearPlayers,player)
            gotPlayer = true
        end
    end
    if gotPlayer then
        return nearPlayers
    else
        return nil
    end
end

function GameBoard:isAdjacentToPlayer(x, y, player, playerSquareInvalid)
    -- can take player square if player can backtrack and has made some moves
    
    if player.phase == "willBacktrack" then
        return nil -- cant place tile near 
    end
    
    if playerSquareInvalid and player.x == x and player.y == y then
        dbg.print("CHECKING PLAYER TILE")
        if type(playerSquareInvalid) == "boolean" then
            return nil
        elseif playerSquareInvalid == "checkBacktrack" and (not player.canBacktrack or player.movesMade == 0) then
            dbg.print("moves: " .. player.movesMade)
            dbg.print("can back track: " .. tostring(player.canBacktrack))
            dbg.print("PLAYER CANT BACKTRACK")
            return nil
        end
    end
    
    if player.phase == "waitingForMove" then
        dbg.print("check adjacent to player " .. player.id ..": ignoring as phase is waitingForMove")
        return nil --ignore player while animating
    end
    
    if player.x > x-2 and player.x < x+2 and player.y == y then
        return true
    elseif player.y > y-2 and player.y < y+2 and player.x == x then
        return true
    else
        return nil
    end
end

function GameBoard:canTakeTile(x, y, player)
    if self:isVisited(x,y) and not (player.x == x and player.y == y) then
        if self:isVisited(x,y) then
            dbg.print("TILE VISITED checking player: " .. player.id .. " at pos " .. x .. "," .. y)
        else
            dbg.print("ON SAME SQAURE checking player: " .. player.id .. " at pos " .. x .. "," .. y)
        end
        return nil
    end
    
    dbg.print("TILE not VISITED checking player: " .. player.id .. " at pos " .. x .. "," .. y)
    
    if player then
        return self:isAdjacentToPlayer(x, y, player, "checkBacktrack")
    else
        return self:isAdjacentToPlayers(x, y, "checkBacktrack")
    end
end

function GameBoard:getAvailableMoves(x, y, moves, otherPlayer)
    local startTile = self:getTile(x,y)
    local tile
    local moveCount = 0
    local possibleMoves = {}
    for k,move in pairs(moves) do
        --get tile move would go onto
        if move == "up" then
            tile = self.board[(y+1)*self.maxTilesWide+x]
        elseif move == "right" then
            tile = self.board[y*self.maxTilesWide+x+1]
        elseif move == "down" then
            tile = self.board[(y-1)*self.maxTilesWide+x]
        elseif move == "left" then
            tile = self.board[y*self.maxTilesWide+x-1]
        end
        
        if tile then
            local hitOtherPlayer = false
            if otherPlayer.x == tile.gridX and otherPlayer.y == tile.gridY then
                hitOtherPlayer = true
            end
            
            if hitOtherPlayer or not self:isVisited(tile.gridX, tile.gridY) then
                dbg.print("get start tile height")
                local height = startTile:getHeight(false, move)
                
                --get list of sides this tile has exits on
                local entrySides = tilePaths[tile.tileType][tileRotations[tile.tileType][tile.rotation]] --eg {"down", "up"}
                
                for k,dir in pairs(entrySides) do
                    if move == self.getReverse(dir) then --matching entry/exit sides means move is valid
                        dbg.print("get end tile height")
                        local newHeight = tile:getHeight(false, dir)
                        if newHeight == height then
                            dbg.print("board: found move: " .. tile.tileType .. " dir" .. move)
                            if hitOtherPlayer then
                                dbg.print("move hits player - will end game")
                                -- -1 indicates level complete, returns just the target tile but not actually using that atm
                                return -1, tile
                            end
                        
                            moveCount = moveCount + 1
                            table.insert(possibleMoves, {tile=tile, dir=move})
                            break
                        end
                    end
                end
            end
        end
    end
    
    return moveCount, possibleMoves
end

function GameBoard.getReverse(dir)
    if dir == "up" then return "down" end
    if dir == "down" then return "up" end
    if dir == "left" then return "right" end
    if dir == "right" then return "left" end
end

function GameBoard:fadeOut(onComplete, duration)
    dbg.print("fadeout board")
    for k,tile in pairs(self.board) do
        --dbg.print("fadeout: pos=" .. k .. " xy=" .. tile.gridX .. "," .. tile.gridY .. " " .. tile.tileType)
        tween:to(tile.sprite, {alpha=0, time=duration*0.6})
    end
    system:addTimer(onComplete, duration, 1)
end

function GameBoard:showMoves(finger)
    dbg.print("showMoves for finger:" .. finger.id)
    for y=0,self.tilesHigh-1 do
        for x=0, self.tilesWide-1 do
            nearPlayers = self:isValidMove(x, y, finger.dragTile)
            local index = y*self.maxTilesWide+x
            local target = finger.targetMarkers[index]
            
            -- hide if no longer valid on update
            if target and not nearPlayers then
                dbg.print("x:" .. x .. ", y:" .. y .. ", index:" .. index)
                dbg.print("target type: " .. type(target))
                cancelTweensOnNode(target)
                tween:to(target, {alpha=0, radius=0, strokeWidth=0, strokeAlpha=0,
                        time=0.3, onComplete=destroyNode})
                finger.targetMarkers[index] = nil
            -- show new move
            elseif not target and nearPlayers then
                local xPos,yPos = self:getScreenPosCentre(x,y)
                target = director:createCircle({xAnchor=0.5, yAnchor=0.5, x=xPos+finger.targetXOffset, y=yPos, radius=0,
                        color=finger.markerColor, alpha=0, strokeWidth=0, strokeAlpha=0,
                        strokeColor=finger.markerColor})
                tween:to(target, {alpha=0.3, strokeAlpha=0.25, strokeWidth=2, mode="mirror",
                        radius=self.halfTile/2, time=1})
                finger.targetMarkers[index] = target
            end
        end
    end
    
    if not finger.showingTargets then
        tween:to(finger.dragTile.sprite, {color={r=finger.tileColor.r, g=finger.tileColor.g, b=finger.tileColor.b},
                mode="mirror", time=1})
        finger.showingTargets = true
    end
end

function GameBoard:stopShowingMoves(finger)
    dbg.print(">> stopShowingMoves for finger: " .. finger.id)
    finger.showingTargets = false
    for k,v in pairs(finger.targetMarkers) do
        cancelTweensOnNode(v)
        tween:to(v, {alpha=0, radius=0, alpha=0, strokeWidth=0, strokeAlpha=0, time=0.3, onComplete=destroyNode})
    end
    finger.targetMarkers = {}
    if finger.dragTile then
        cancelTweensOnNode(finger.dragTile.sprite)
        cancelTweensOnNode(finger.dragTile.sprite)
        --looks like an engine bug... have to cancel twice here or else it doesn't stop!
        --likely about tween disaptching vs events/update
        
        tween:to(finger.dragTile.sprite, {color={r=255, g=255, b=255}, time=0.3})
    end
end

function GameBoard:updateFingerTargets(fingers)
    dbg.print(">> updateFingerTargets")
    for k,finger in pairs(fingers) do
        if finger.showingTargets then
            board:showMoves(finger) --recheck and update other fingers
        end
    end
end
