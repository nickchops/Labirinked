
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
    local moves = self.possibleMoves[self.moveStackSize]
    local moveCount
    local moveList
    moveCount, moveList = board:getAvailableMoves(self.x, self.y, moves)
    
    if moveCount == 0 then
        self.phase = "ready"
        return false
    end
    
    local move = moveList[math.random(1, moveCount)]
    local tile = move.tile
    local dir = move.dir
    
    --for back-tracking?
    self.returnStackSize = self.returnStackSize + 1
    table.insert(self.returnMoves, board:getReverse(dir))
    
    --figure out next possible move 
    local newMoves = tilePaths[tile.tileType][tile.direction]
    
    for k,v in pairs(newMoves) do
        if v == "up" and dir == "down" then newMoves[k] = nil     
        elseif v == "left" and dir == "right" then newMoves[k] = nil
        elseif v == "down" and dir == "up" then newMoves[k] = nil
        elseif v == "right" and dir == "left" then newMoves[k] = nil end
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
    
    return true
end


function reactivatePlayer(target)
    -- try to move recursively; return control once fails
    if not target.player:tryToMove() then
        target.player.phase = "ready"
    end
end
