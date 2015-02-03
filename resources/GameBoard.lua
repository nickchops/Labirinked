
--NB: general logic only supports thew whole grid being on the screen!
-- can tgo beyond screen bounds. maxTilesWide doesnt do anything yet!
-- would like to allow it to go outwards, but will change logic later if time

-- elements are in a 30x30 sparse matrix

GameBoard = inheritsFrom(baseClass)

--tilesWide etc are how many tiles wide the widthOnScreen are is
--maxTiles is max gameboard size (extenidng off the screen edges)
--menuHeight is distance form bottom where menu area for grabbing tiles, pause, etc lives
--board will be centered on the screen in the area left after that
--tiles high is however many can live in the space left!

-- grid positions start at 0,0
function GameBoard:init(widthOnScreen, tilesWide, maxTilesWide, menuHeight, debugDraw)
    self.board = {}
    self.boardVisited = {}
    self.widthOnScreen = widthOnScreen
    self.startWidth = widthOnScreen
    self.tileWidth = widthOnScreen/tilesWide
    self.halfTile = self.tileWidth/2
    self.tilesWide = tilesWide
    self.tilesHigh = math.floor((appHeight-menuHeight)/self.tileWidth)
    self.heightOnScreen = self.tilesHigh * self.tileWidth
    self.maxTilesWide = maxTilesWide
    self.startHeight = self.tileWidth * self.tilesHigh
    self.origin = director:createNode({x=appWidth/2 - self.startWidth/2,
            y= menuHeight + (appHeight-menuHeight)/2 - self.startHeight/2})
    self.menuHeight = menuHeight
    
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

-- add Tile at position. Simple sparse row*column matrix as a table
function GameBoard:addTile(x,y,tile)
    self.board[y*self.maxTilesWide+x] = tile
    tile.gridX = x
    tile.gridY = y
    self:setDepth(tile)
end

function GameBoard:setVisited(x,y)
    self.boardVisited[y*self.maxTilesWide+x] = true
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
    tile.origin.zOrder = self.tilesHigh - tile.gridY
end

function GameBoard:getPlayerDepth(x,y)
    return self.tilesHigh - y + 2 --allow 1 pos between player and tile
end
-- input: grid pos starting at zero. output: screen position
function GameBoard:getScreenPosCentre(x,y)
    return self.origin.x + self.tileWidth*x + self.halfTile,
            self.origin.y + self.tileWidth*y + self.halfTile
end

function GameBoard:getScreenPos(x,y)
    return self.origin.x + self.tileWidth*x,
           self.origin.y + self.tileWidth*y
end

function GameBoard:getNearestGridPos(x,y, tileToCheckIsValid)
    x = math.floor((x-self.origin.x)/self.tileWidth)
    y = math.floor((y-self.origin.y)/self.tileWidth)
    
    if y < 0 then
        return -1, -1 
    end
    
    if x < 0 then x = 0 end
    if x > self.tilesWide-1 then x = self.tilesWide-1 end
    if y > self.tilesHigh-1 then y = self.tilesHigh-1 end
    
    local nearPlayers = nil
    if tileToCheckIsValid then
        --if near both players, returns first found
        dbg.print("checking isValidMove")
        nearPlayers = self:isValidMove(x, y, tileToCheckIsValid)
        if not nearPlayers then
            dbg.print("move not valid!")
            return -1,-1
        end
    end
    
    return x, y, nearPlayers
end

function GameBoard:hasTile(x, y)
    if self.board[y*self.maxTilesWide+x] then
        return true
    else
        return false
    end
end


function GameBoard:getAndRemoveTile(x, y)
    local tile = self.board[y*self.maxTilesWide+x]
    self.board[y*self.maxTilesWide+x] = nil
    return tile
end

function GameBoard:isValidMove(x, y, tile)
    local cell = self.board[y*self.maxTilesWide+x]
    if cell then
        return false
    end
    
    --TODO: use player.tilesLaid to check if player can have tiles (cant be more than 1 ahead of other player)
    
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
        return false
    end
end

function GameBoard:isAdjacentToPlayer(x, y, player, playerSquareInvalid)
    if playerSquareInvalid and player.x == x and player.y == y then
        return false
    end
    
    if player.phase == "waitingForMove" then
        dbg.print("check adjacent to player " .. player.id ..": ignoring as phase is waitingForMove")
        return false --ignore player while animating
    end
    
    if player.x > x-2 and player.x < x+2 and player.y == y then
        return true
    elseif player.y > y-2 and player.y < y+2 and player.x == x then
        return true
    else
        return false
    end
end

function GameBoard:canTakeTile(x, y, player)
    if self:isVisited(x,y) then return false end
    
    if player then
        return self:isAdjacentToPlayer(x, y, player, true)
    else
        return self:isAdjacentToPlayers(x, y, true)
    end
end

function GameBoard:getAvailableMoves(x, y, moves, otherPlayer)
    local cell = self.board[y*self.maxTilesWide+x]
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
            if otherPlayer.x == tile.gridX and otherPlayer.y == tile.gridY then
                -- -1 indicates level complete, returns just the target tile b ut not actually using that atm
                return -1, tile
            elseif not self:isVisited(tile.gridX, tile.gridY) then
                --get list of sides this tile has exits on
                local entrySides = tilePaths[tile.tileType][tileRotations[tile.tileType][tile.rotation]] --eg {"down", "up"}
                local success = false
                
                --matching entry/exit sides means move is valid
                for k,dir in pairs(entrySides) do
                    if move == "up" and dir == "down" then success = true end
                    if move == "right" and dir == "left" then success = true end
                    if move == "down" and dir == "up" then success = true end
                    if move == "left" and dir == "right" then success = true end
                    
                    if success then
                        dbg.print("board: found move: " .. tile.tileType .. " dir" .. move)
                        moveCount = moveCount + 1
                        table.insert(possibleMoves, {tile=tile, dir=move})
                        break
                    end
                end
            end
        end
    end
    
    return moveCount, possibleMoves
end

function GameBoard:getReverse(dir)
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
