
Player = inheritsFrom(baseClass)

function Player:init(playerNumber, board)
    self.id = playerNumber
    self.sprite = director:createSprite({x=0, y=0, source="textures/player.png", alpha=0.7})
    setDefaultSize(self.sprite, board.tileWidth*0.5)
    self.board = board
    self.phase="ready"
    self.offset = getWidth(self.sprite)/2
    
    if playerNumber == 1 then
        self.sprite.color = color.pink
    else
        self.sprite.color = color.blue
    end
    
    -- we're keeping new and old moves in a stack, however not sure this is
    -- useful if the level can change! Prob just have to calculate moves at
    -- at each time layout changes
    self.tilesLaid = 0
    self.possibleMoves = {}
    self.moveStackSize = 0
    self.returnMoves = {}
    self.returnStackSize = 0
end

function Player:setGridPos(x,y)
    self.x = x
    self.y = y
    self.sprite.x, self.sprite.y = board:getScreenPosCentre(x,y)
    self.sprite.x = self.sprite.x - self.offset
    self.sprite.y = self.sprite.y - self.offset
    self.sprite.zOrder = board:getPlayerDepth(x,y) + 1
end

function Player:addPossibleMoves(moves)
    table.insert(self.possibleMoves, moves)
    self.moveStackSize = self.moveStackSize + 1
end

function Player:tryToMove()
    -- possibleMoves is directions can move on current tile
    -- doesn't include direction player came from
    local moves = self.possibleMoves[self.moveStackSize]
    local moveCount
    local moveList
    
    if debugOn then
        dbg.print("------------------------------------------")
        dbg.print("TRYING TO MOVE: player " .. self.id)
        dbg.print("directions to leave current tile:")
        for k,v in pairs(moves) do
            dbg.print(" - " .. v)
        end
    end
    -- gets list of valid moves - i.e where directions above match tiles
    -- player can move onto (joins match)
    -- moveList constains destination tile and direction to move onto that tile
    moveCount, moveList = board:getAvailableMoves(self.x, self.y, moves)
    
    if moveCount == 0 then
        dbg.print("NO MOVES FOUND!")
        self.phase = "ready"
        dbg.print("------------------------------------------")
        return false
    
    elseif debugOn then
        dbg.print("available moves found:")
        for i=1,moveCount do
            for k,v in pairs(moveList) do
                dbg.print(" - move " .. v.dir .. " onto " .. v.tile.tileType .. " tile with rotation " .. v.tile.rotation)
            end
        end
    end
    
    --pick tile at random. TODO: prob needs pathfinding or at least
    -- we have our move now.
    local move = moveList[math.random(1, moveCount)]
    local tile = move.tile
    local dir = move.dir
    
    dbg.print("Move chosen: " .. move.dir .. " onto " .. move.tile.tileType .. " tile with rotation " .. move.tile.rotation)
    
    --might be useful for back-tracking? Not currently used
    self.returnStackSize = self.returnStackSize + 1
    table.insert(self.returnMoves, board:getReverse(dir))
    
    --figure out *next* possible move once on the tile
    local tileSides = tilePaths[tile.tileType][tile.rotation]
    local newMoves = {}
    
    dbg.print("Exits on new square:")
    
    for k,v in pairs(tileSides) do
        dbg.print(v)
        if not (v == "up" and dir == "down") and not (v == "left" and dir == "right")
                and not (v == "down" and dir == "up") and not (v == "right" and dir == "left") then
            table.insert(newMoves, v)
        end
    end
    
    
    dbg.print("Moves on new square (entry side removed):")
    
    if debugOn then
        for k,v in pairs(newMoves) do
            dbg.print(v)
        end
    end
    
    self:addPossibleMoves(newMoves)
    
    --make move
    self.x = tile.startGridX
    self.y = tile.startGridY
    local targetX
    local targetY
    targetX, targetY = board:getScreenPosCentre(self.x, self.y)
    
    -- hacky temporary make bridges work
    if tile.tileType == "bridge" then
        targetY=targetY+self.offset*0.2
    end
    
    self.sprite.player = self
    tween:to(self.sprite, {x = targetX - self.offset, y = targetY - self.offset, onComplete = reactivatePlayer})
    --TODO: set height and zOrder depending on tile height!
    
    dbg.print("------------------------------------------")
    return true
end


function reactivatePlayer(target)
    -- try to move recursively; return control once fails
    if not target.player:tryToMove() then
        target.player.phase = "ready"
    end
end
