
Player = inheritsFrom(baseClass)

function Player:init(playerNumber, board, otherPlayer)
    self.id = playerNumber
    self.sprite = director:createSprite({x=0, y=0, source="textures/player.png", alpha=0.7})
    setDefaultSize(self.sprite, board.tileWidth*0.5)
    self.sprite.centreOffset = getWidth(self.sprite)/2
    
    self.board = board
    self.phase="ready"
    self.offset = getWidth(self.sprite)/2
    self.otherPlayer = otherPlayer
    
    self.canBacktrack = true --allows turning off by player (not used yet)...
    self.backtrackMoves = {}
    self.movesMade = 0
    self.pathMarkers = {}
    
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
    
    self.returnMoves = {}
    self.returnStackSize = 0
end

function Player:setGridPos(x,y, positionSprite, visitTile, setDepthNow)
    self.x = x
    self.y = y
    
    if setDepthNow then
        self.sprite.zOrder = board:getPlayerDepth(x,y)
    else
        -- when moving, player and crosses can be on old or new tile, needs to overlap both
        self.sprite.destinationZ = board:getPlayerDepth(x,y)
        self.sprite.zOrder = math.max(self.sprite.zOrder, self.sprite.destinationZ) - 1
    end
    
    if positionSprite then
        self.sprite.x, self.sprite.y = board:getScreenPosCentre(x,y,true)
        self.sprite.x = self.sprite.x - self.offset
        self.sprite.y = self.sprite.y - self.offset
    end
    
    if visitTile then
        self.overlapTile = board:setVisited(x,y, true, true, true)
        if self.overlapTile then
            self.overlapTile.overlaps = player
        end
    end
end

function Player:setPossibleMoves(moves)
    self.possibleMoves = moves
end

function Player:tryToMove()
    dbg.print("tryToMove for " .. self.id)
    if self.otherPlayer.phase == "levelComplete" then
        dbg.print("other player has finished!")
        return false --note: return value just used for debugging
    end
    
    -- possibleMoves is directions can move on current tile
    -- doesn't include direction player came from
    local moves = self.possibleMoves --[self.moveStackSize]
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
    moveCount, moveList = board:getAvailableMoves(self.x, self.y, moves, self.otherPlayer)
    
    if moveCount == -1 then
        if self.otherPlayer.x == moveList.gridX and self.otherPlayer.y == moveList.gridY
                    and self.otherPlayer.phase=="waitingForMove" then
            dbg.print("other player is already moving into the target - dont move")
            self.phase = "ready"
            return false --note: return value just used for debugging
        end
        
        dbg.print("LEVEL COMPLETE! animating out...")
        -- stop play, move players towards eachother, sceneGame will take care of ending the level
        sceneGame:levelCleared()
        self.phase="levelComplete"
        self.otherPlayer.phase="levelComplete"
        
        local targetX
        local targetY
        local otherTargetX
        local otherTargetY
        
        if self.sprite.x > self.otherPlayer.sprite.x then
            targetX = self.otherPlayer.sprite.x + (self.sprite.x - self.otherPlayer.sprite.x)*0.75
            otherTargetX = self.otherPlayer.sprite.x + (self.sprite.x - self.otherPlayer.sprite.x)*0.25
        else
            targetX = self.sprite.x + (self.otherPlayer.sprite.x - self.sprite.x)*0.25
            otherTargetX = self.sprite.x + (self.otherPlayer.sprite.x - self.sprite.x)*0.75
        end
        
        if self.sprite.y > self.otherPlayer.sprite.y then
            targetY = self.otherPlayer.sprite.y + (self.sprite.y - self.otherPlayer.sprite.y)*0.75
            otherTargetY = self.otherPlayer.sprite.y + (self.sprite.y - self.otherPlayer.sprite.y)*0.25
        else
            targetY = self.sprite.y + (self.otherPlayer.sprite.y - self.sprite.y)*0.25
            otherTargetY = self.sprite.y + (self.otherPlayer.sprite.y - self.sprite.y)*0.75
        end
        
        --bounce forever until level ends
        tween:to(self.sprite, {x = targetX, y = targetY, time=1, onComplete = Player.bounce, delay=0.2})
        tween:to(self.otherPlayer.sprite, {x = otherTargetX, y = otherTargetY, time=1, onComplete = Player.bounce})
        
        return false
    elseif moveCount == 0 then
        dbg.print("NO MOVES FOUND!")
        dbg.print("player set to ready in tryToMove: " .. self.id)
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
    
    -- just store directions so can move in reverse of them
    self.movesMade = self.movesMade + 1
    self.backtrackMoves[self.movesMade] = {dir=board:getReverse(dir), tile=board:getTile(self.x, self.y)}
    self.pathMarkers[self.movesMade] = {}
    
    --figure out *next* possible move once on the tile
    local tileSides = tilePaths[tile.tileType][tileRotations[tile.tileType][tile.rotation]]
    --local newMoves = {}
    self.possibleMoves = {}
    
    dbg.print("Exits on new square:")
    
    for k,v in pairs(tileSides) do
        dbg.print(v)
        if not (v == "up" and dir == "down") and not (v == "left" and dir == "right")
                and not (v == "down" and dir == "up") and not (v == "right" and dir == "left") then
            --table.insert(newMoves, v)
            table.insert(self.possibleMoves, v)
        end
    end
    
    
    dbg.print("Moves on new square (entry side removed):")
    
    if debugOn then
        for k,v in pairs(newMoves) do
            dbg.print(v)
        end
    end
    
    self:move(tile, false)
    
    Player.drawPath({target=self.sprite})
    self.sprite:addTimer(Player.drawPath, 0.33, 2)

    return true
end

function Player:move(targetTile, backtrack)
    if self.overlapTile then
        self.overlapTile:setFade(false, true)
        self.overlapTile = nil
    end
    
    self:setGridPos(targetTile.gridX, targetTile.gridY, false, true)
    
    --tile change logic (powerups, effects, etc)
    targetTile:process(player)
    
    --animate
    local targetX
    local targetY
    targetX, targetY = board:getScreenPosCentre(self.x, self.y, true)
    
    self.sprite.player = self
    tween:to(self.sprite, {x = targetX - self.offset, y = targetY - self.offset, time=1, onComplete = Player.reactivatePlayer})

    dbg.print("------------------------------------------")
end

function Player.drawPath(event)
    local crossSize = getWidth(event.target) *0.4
    
    local cross = director:createRectangle({xAnchor=0.5, yAnchor=0.5, x=event.target.x+event.target.centreOffset, y=event.target.y+event.target.centreOffset, w=crossSize, h=crossSize/4, color={0,0,100}, strokeWidth=0, rotation=45, zOrder=event.target.zOrder-1, alpha=0.7})
    cross.player = event.target.player
    tween:from(cross, {alpha=0, time=0.2, onComplete=Player.drawCross2})
end

function Player.drawCross2(target)
    local cross2 = director:createRectangle({xAnchor=0.5, yAnchor=0.5, x=target.x, y=target.y, w=target.w, h=target.h, color=target.color, rotation=135, strokeWidth=0, zOrder=target.zOrder, alpha=0.7})
    tween:from(cross2, {alpha=0, time=0.1})
    
    local player = target.player
    table.insert(player.pathMarkers[player.movesMade], {target, cross2})
end

function Player:removePath(event)
    -- crosses are in scenegraph so we can just queue timers to hide them all at once
    -- NB: code assumes 3 crosses! counts go down as need to remove in reverse order
    local crossPairs = self.pathMarkers[self.movesMade]
    local pairCount = 2
    for k,crosses in ipairs(crossPairs) do
        local crossCount = 1
        for j,cross in ipairs(crosses) do
            tween:to(cross, {delay=0.33*pairCount+0.2*crossCount, alpha=0, time=0.2, onComplete=destroyNode})
            crossCount = crossCount - 1
        end
        pairCount = pairCount - 1
    end
end

function Player.reactivatePlayer(target)    
    target.zOrder = target.destinationZ
    local player = target.player

    if player.phase == "backtracking" then
        player.phase = "ready"
        return
    end
    
    -- try to move recursively; return control (phase=ready) will be set in tryToMove once it fails
    if not player:tryToMove() then
        dbg.print("tryToMove failed in reactivatePlayer(" .. player.id .. ") should have already set phase to ready...")
    end
end

function Player:backtrack()
    print("BACKTRACK!")
    
    board:setVisited(self.x, self.y, false)
    
    self:move(self.backtrackMoves[self.movesMade]["tile"], true)
    self:removePath()
    
    self.backtrackMoves[self.movesMade] = nil
    self.movesMade = self.movesMade - 1
end

function Player.bounce(target)
    dbg.print("bounce!")
    tween:to(target, {y=target.y+15, mode="mirror", easing=ease.bounceInOut})
end
