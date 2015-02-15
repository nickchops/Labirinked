
--dofile("helpers/OnScreenDPad.lua")
--dofile("helpers/OnScreenButton.lua")
require("BackButton")

dofile("Player.lua")
dofile("Tile.lua")
dofile("GameBoard.lua")

sceneGame = director:createScene()
sceneGame.name = "game"

function sceneGame:setUp(event)
    -- force re-show fullscreen just in case. Only really care about it in the
    -- game scene. screen will shrink and fire orientation events if it changes.
    if androidFullscreen and androidFullscreen:isImmersiveSupported() then
        androidFullscreen:turnOn()
    end
    
    updateVirtualResolution(self)
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    self.background = director:createSprite(0, 0, "textures/paper-1024.png")
    self.background.alpha=0.2
    setDefaultSize(self.background, vr.userWinW, vr.userWinH)
    self.background.x = vr.userWinMinX
    self.background.y = vr.userWinMinY
    self.background.zOrder = -1
    
    math.randomseed(os.time())
    
    --softPad =  OnScreenDPad.Create({x=100,   y=100, baseRadius=appWidth/13, topRadius=appWidth/23})
    --btnA = OnScreenButton.Create({x=80, y=appWidth-100, radius=15, topColor=color.red, baseColor=color.darkRed, scale3d=5, depth3d=5})
    --btnB = OnScreenButton.Create({x=30, y=appWidth-100, radius=15, topColor=color.green, baseColor=color.darkGreen, scale3d=5, depth3d=5})
    
    self:generateQueueOfTiles(10, debugTileTypes or gameInfo.levels[gameInfo.level].tileTypes)
    print("!!!!!!!!!!!!!!!!!!!!!!!! " .. gameInfo.level .. "!!!!!!!!!!!!")
    gameInfo.levelTime = gameInfo.levels[gameInfo.level].time
    
    local tilesWide = debugTilesWide or gameInfo.levels[gameInfo.level].width
    local tilesHigh = gameInfo.levels[gameInfo.level].height
    
    local padAdjust
    if tilesHigh < 5 then
        padAdjust = 0.75
    elseif tilesHigh < 6 then
        padAdjust = 0.8
    else
        padAdjust = 0.9
    end

    board = GameBoard:create()
    board:init(appWidth*padAdjust, tilesWide, appHeight*padAdjust, tilesHigh, 30, 1.8, debugOn)
    
    
    tileSlots = {} -- tiles at bottom of screen
    tileSlotsMax = 4
    tileSlotsSize = 0
    tileSlotsY = (board.menuHeight/3+10) + vr.userWinMinY/2
    tileXSpace = 20
    
    player1 = Player:create()
    player2 = Player:create()
    player1:init(1,board,player2,{"down","right"})
    player2:init(2,board,player1,{"up","left"})
    
    players = {}
    players[1] = player1
    players[2] = player2
    
    --TODO: could allow as many fingers as wanted!
    fingers = {}
    fingers[1] = {id=1, phase="ready"}
    fingers[2] = {id=2, phase="ready"}
    
    local p1StartX = 0
    local p1StartY = board.tilesHigh-1
    local p2StartX = board.tilesWide-1
    local p2StartY = 0
    
    self.startTile1 = board:addNewTileToGrid(p1StartX, p1StartY, "floor", 1)
    player1:setGridPos(p1StartX, p1StartY, true, true, true)
    player1.sprite.alpha=0
    self.startTile1.sprite.alpha =0
    
    self.startTile2 = board:addNewTileToGrid(p2StartX, p2StartY, "floor", 1)
    player2:setGridPos(p2StartX, p2StartY, true, true, true)
    player2.sprite.alpha=0
    self.startTile2.sprite.alpha = 0
    
    gameInfo.winLose = "lose"
    self.timeUp = false
    
    -- set some tiles to play with to start
end

function sceneGame:generateQueueOfTiles(size, tileTypes)
    self.tileQueue = {}
    self.tileQueueSize = size
    self.tileTypes = tileTypes
    self.tileTypeCount = 0
    for k,v in pairs(tileTypes) do
        self.tileTypeCount = self.tileTypeCount + 1
    end
    
    for i=1,size do
        self.tileQueue[i] = self:generateTile()
    end
end

function sceneGame:generateTile(tileTypes)
    local tileType = self.tileTypes[math.random(1, self.tileTypeCount)]
    local dir = math.random(1, 4)
    while not tileRotations[tileType][dir] do
        dir = dir + 1
        if dir > 4 then dir = 1 end
    end
    return {tileType=tileType, dir=dir}
end

function sceneGame:dequeueTile()
    local tile = self.tileQueue[self.tileQueueSize]
    self.tileQueueSize = self.tileQueueSize - 1
    return tile
end

function sceneGame:queueTilesForSlots(time, number)
    dbg.print("queueTilesForSlots")
    if not self.tileQueueTimers then
        self.tileQueueTimers = {}
        self.tileTimerCount = 0
    end
    self.tileTimerCount = self.tileTimerCount + 1
    
    local tileTimer = system:addTimer(sceneGame.addTileToSlots, time, number)
    tileTimer.id = self.tileTimerCount
    self.tileQueueTimers[tileTimer.id] = tileTimer
end

function sceneGame.addTileToSlots(event)
    dbg.print("addTileToSlots")
    if event.doneIterations == event.timer.iterations then
        sceneGame.tileQueueTimers[event.timer.id] = nil
    end
    
    if tileSlotsSize >= tileSlotsMax then
        return
    end
    
    tileSlotsSize = tileSlotsSize +1
    local tileX
    
    --get first empty slot
    local slot = nil
    for i=1,tileSlotsMax do
        if not slot and not tileSlots[i] then
            slot = i
        end
    end
    
    if slot % 2 == 1 then
        tileX = appWidth/2 - (board.tileWidth+tileXSpace)*(slot+1)/2 + board.tileWidth/2 - 50
    else
        tileX = appWidth/2 + (board.tileWidth+tileXSpace)*slot/2 - board.tileWidth/2 + 50
    end
    
    local tileInfo
    if sceneGame.tileQueueSize > 0 then
        dbg.print("dequeue")
        tileInfo = sceneGame:dequeueTile()
    else
        dbg.print("generate")
        tileInfo = sceneGame:generateTile()
    end
    
    local newTile = createTile(tileX, tileSlotsY, tileInfo.tileType, tileInfo.dir)
    newTile.startX = tileX
    newTile.startY = tileSlotsY
    newTile.startSlot = slot --indicates it's in the queue or being dragged about but not just put onto the grid
    newTile.available = false
    tween:to(newTile.sprite, {alpha=tileAlpha, time=0.5, onComplete=activateTile})
    newTile.sprite.tile = newTile
    tileSlots[slot] = newTile
end

function sceneGame:tileSlotsFadeOut(onComplete, duration)
    dbg.print("fadeout queue")
    for k,tile in pairs(tileSlots) do
        --dbg.print("fadeout queue: slot=" .. k .. " xy=" .. tile.startX .. "," .. tile.startY .. " " .. tile.tileType)
        tween:to(tile.sprite, {alpha=0, time=duration})
    end
    
    for k,finger in pairs(fingers) do
        if finger.dragTile then
            tween:to(finger.dragTile.sprite, {alpha=0, time=duration})
        end
    end
end

function activateTile(target)
    target.tile.available = true --only touchable once anim over
end

function sceneGame:enterPostTransition(event)
    tween:to(self.background, {alpha=1, time=1, onComplete=sceneGame.showPieces})
end

function sceneGame:exitPreTransition(event)
    saveUserData()
end

function sceneGame:exitPostTransition(event)
    backButtonHelper:remove()
        
    --globals to tear down
    tileSlots = nil
    board = nil
    player1 = nil
    player2 = nil
    players = nil
    fingers = nil

    destroyNodesInTree(sceneGame, false)
    --self.xxx = nil
    
    self:releaseResources()
    collectgarbage("collect")
    director:cleanupTextures()
end

function sceneGame:orientation(event)
    updateVirtualResolution(self)
    
    tileSlotsY = (board.menuHeight/3+10) + vr.userWinMinY/2
    
    for i=1,tileSlotsMax do
        if tileSlots[i] then
            tileSlots[i].startY = tileSlotsY
            tileSlots[i].origin.y = tileSlotsY
        end
    end
    
    backButtonHelper:setCenterPosition(nil, 55 + vr.userWinMinY)
end


sceneGame:addEventListener({"setUp", "enterPostTransition", "exitPreTransition",
        "exitPostTransition", "orientation"}, sceneGame)

-------------------------------------------------------------

-- Main logic


function sceneGame.showPieces()
    local self = sceneGame
    backButtonHelper:add({listener=self.quit, xCentre=80, yCentre=55+vr.userWinMinY, btnWidth=80,
            btnTexture=btnBackTexture, pulse=false, activateOnRelease=true, animatePress=true,
            deviceKeyOnly=false, drawArrowOnBtn=true, arrowThickness=4})
    
    if backButtonHelper.backBtn then -- in case we change to non-visible on Android etc!
        tween:from(backButtonHelper.backBtn, {alpha=0, time=0.2})
    end
    
    self:queueTilesForSlots(0.3, 4)
    
    tween:to(self.startTile1.sprite, {alpha = tileAlpha, time=1.0, delay=0.5, onComplete=sceneGame.startPlay})
    tween:to(self.startTile2.sprite, {alpha = tileAlpha, time=1.0, delay=0.5})
    tween:to(player1.sprite, {alpha = 1, time=1.0, delay=1.0})
    tween:to(player2.sprite, {alpha = 1, time=1.0, delay=1.0})
    
    self.levelTimerNode = director:createNode({x=appWidth/2, y=tileSlotsY})
    self.levelTimerNode.label = director:createLabel({x=-20, y=-20, color=color.black, text=gameInfo.levelTime,
            xScale=1, yScale=1, font=fontTimer})
    self.levelTimerNode:addChild(self.levelTimerNode.label)
    self.levelTimer = self.levelTimerNode:addTimer(self.levelTimerFunc, 1.0, gameInfo.levelTime)
    tween:to(self.levelTimerNode, {xScale=0.8, yScale=0.8, time=0.9})
    gameInfo.timeLeft = gameInfo.levelTime
    
    --softPad:activate()
end

function sceneGame.startPlay()
    system:addEventListener({"touch"}, sceneGame)
    backButtonHelper:enable()
end

function sceneGame.levelTimerFunc(event)
    cancelTweensOnNode(sceneGame.levelTimerNode)
    
    gameInfo.timeLeft = gameInfo.timeLeft - 1
    event.target.label.text = gameInfo.timeLeft
    event.target.xScale = 1.2
    event.target.yScale = 1.2
    
    if gameInfo.timeLeft == 9 then
        event.target.label.x = event.target.label.x/2
    end
    
    if gameInfo.timeLeft <= 0 then
        dbg.print("time up, pausing play")
        sceneGame:pausePlay()
        sceneGame.timeUp = true
        board:fadeOut(sceneGame.gotoWinLose, 5)
        sceneGame:tileSlotsFadeOut(3)
    else
        tween:to(event.target, {xScale=0.8, yScale=0.8, time=0.9})
    end
end

function sceneGame:incrementTimer(time)
    self.levelTimer:cancel()
    cancelTweensOnNode(self.levelTimerNode)
    
    time = gameInfo.timeLeft + time
    self.levelTimerNode.label.text = time
    
    if time > 9 and gameInfo.timeLeft < 10 then
        self.levelTimerNode.label.x = self.levelTimerNode.label.x*2
    end
    
    gameInfo.timeLeft = time
    self.levelTimerNode.xScale = 1.6
    self.levelTimerNode.yScale = 1.6
    self.levelTimer = self.levelTimerNode:addTimer(self.levelTimerFunc, 1.0, gameInfo.timeLeft)
    tween:to(self.levelTimerNode, {xScale=0.8, yScale=0.8, time=0.9})
end

function sceneGame:pausePlay()
    dbg.print("PAUSE PLAY")
    --todo: pause drag events if needed
    system:removeEventListener("touch", self)
    backButtonHelper:disable()
    
    if self.levelTimer then --could hit zero just as we pause
        self.levelTimer:cancel()
        self.levelTimer = nil
    end
    if self.tileQueueTimers then
        for k,timer in pairs(self.tileQueueTimers) do
            timer:cancel()
        end
        self.tileQueueTimers = nil
    end
end

function createTile(screenX, screenY, tileType, rotation)
    local tile = Tile:create()
    tile:init(screenX, screenY, tileType, rotation, board.tileWidth)
    tile:bringToFront()
    return tile
end

function sceneGame.gotoWinLose()
    audio:stopStream()
    system:removeEventListener({"suspend", "resume", "update"}, sceneGame)
    pauseNodesInTree(sceneGame)
    backButtonHelper:disable()
    director:moveToScene(sceneWinLose, {transitionType="slideInL", transitionTime=0.8})
end

function sceneGame:levelCleared()
    if self.timeUp then -- time up first = failed
        return false
    end
    
    dbg.print("level cleared, pausing play")
    sceneGame:pausePlay()
    gameInfo.winLose = "win"
    board:fadeOut(sceneGame.gotoWinLose, 7)
    self:tileSlotsFadeOut(3)
    return true
end

-----------------------------------------------------------------

function sceneGame.quit()
    dbg.print("quit level, pausing play")
    sceneGame:pausePlay()
    audio:stopStream()
    system:removeEventListener({"suspend", "resume", "update", "touch"}, sceneGame)
    pauseNodesInTree(sceneGame)
    backButtonHelper:disable()
    director:moveToScene(sceneMainMenu, {transitionType="slideInL", transitionTime=0.8})
end

-----------------------------------------------------------------

function sceneGame:touch(event)
    --if event.id > 1 then return end --lock to single touch for testing
    if event.id > 2 then return end
    
    local x = vr:getUserX(event.x)
    local y = vr:getUserY(event.y)
    
    local finger = fingers[event.id]
    
    if event.phase == "began" and finger.phase == "ready" then
        if y < board.menuHeight then
            for k,tile in pairs(tileSlots) do
                if (not tile.finger) and tile.available and
                        x > tile.startX-board.tileWidth/2 and x < tile.startX+board.tileWidth/2 then
                    finger.phase = "placingTile"
                    finger.dragTile = tile
                    finger.dragTile.finger = finger
                    finger.startX = x
                    finger.startY = y
                    tile:bringToFront()
                    print("TOUCH START SUCCESS")
                    break
                elseif tile.finger then
                    print("TOUCH START tile still has finger already: " .. tile.finger.id)
                elseif not tile.available then
                    print("TOUCH START tile not available:")
                end
            end
        else
            local xGrid
            local yGrid
            xGrid, yGrid = board:getNearestGridPos(x,y)
            if board:hasTile(xGrid, yGrid) then
                dbg.print("HAS TILE")
                local gotTile --tile can be valid for both players (but doesnt mean we've won!)
                for k,player in pairs(players) do
                    dbg.print("Has tile: check player(" .. player.id .. ") phase=" .. player.phase)
                    if player.phase == "ready" and board:canTakeTile(xGrid, yGrid, player) then
                        dbg.print("CAN TAKE TILE")
                        
                        dbg.print("moving tile, player(" .. player.id .. ") setting phase=" .. player.phase)
                        finger.phase = "placingTile"
                        
                        if not gotTile then
                            gotTile = board:getAndRemoveTile(xGrid, yGrid, true)
                            finger.reservedTile = {x=xGrid,y=yGrid}
                            finger.dragTile = gotTile
                            finger.startX = x
                            finger.startY = y
                            gotTile:bringToFront()
                        end
                        
                        if xGrid == player.x and yGrid == player.y then
                            --tile was under a player
                            dbg.print("!!!! got a player tile")
                            finger.dragTile.playerTileWasFrom = player
                            player.phase = "willBacktrack"
                            --TODO: animate tile removal nicely.....
                        else
                            player.phase = "changingTilePos"
                        end
                        
                        if not finger.dragTile.players then finger.dragTile.players={} end
                        finger.dragTile.players[player.id] = player
                    end
                end
            end
        end
    elseif finger.phase == "placingTile" then
        local yShow = y
        local tap = true
        if math.abs(finger.startX - x) > tapThreshold or math.abs(finger.startY - y) > tapThreshold then
            yShow = yShow + ppi*0.7/vr.scale
            --move tile up by 0.65 inches. Needs scaling for virt res.
            tap = false
        end
        
        if event.phase == "moved" then
            finger.dragTile:setPosCentered(x,yShow)
        elseif event.phase == "ended" then
            print("TOUCH END")
            
            -- tap to rotate. may want to change to two finger rotate. but that might not be intuitive...
            local rotated = false
            if (board.canRotatePlayerTiles or not finger.dragTile.playerTileWasFrom) and tap then
                rotated = finger.dragTile:rotateRight()
                -- we still carry on after this so that player can try to move, tile repositions, flags reset
            end
            
            --TODO: if we allow board.canRotatePlayerTiles, prob need logic to update next move dirs for player
            
            local tileWasFromQueue = finger.dragTile:setGridTarget(board:getNearestGridPos(x,yShow, finger.dragTile, rotated))
            -- This triggers any player updates and animations. And sets or resets player.phase for each player
            -- that was in finger.dragTile.players
            
            if finger.reservedTile then
                board:freeUpTile(finger.reservedTile)
                finger.reservedTile = nil
            end
            
            print("TOUCH END resetting finger " .. finger.id)
            finger.phase = "ready"
            --finger.dragTile.finger = nil
            finger.dragTile = nil
            
            if tileWasFromQueue then --if added a tile from the queue (not dragged from other spot on board) -> new tile
                print("TOUCH END queuing new tile")
                tileSlotsSize = tileSlotsSize -1
                tileSlots[tileWasFromQueue] = nil
                dbg.print("QUEUE TILE!!!!")
                self:queueTilesForSlots(0.5, 1)
            end
            
        end
    end
end

function sceneGame:update(event)
    if pauseflag then
        pauseflag = false
        system:resumeTimers()
        resumeNodesInTree(self)
    end
end

function restartGame(event)
    --destroyNode(sceneGame.label)
    --sceneGame.label = nil
    sceneGame:startPlay()
    --sceneGame.score = 0
end

---- Pause/resume logic/anims on app suspend/resume ---------------------------

function sceneGame:suspend(event)
    dbg.print("suspending game...")
	
    if not pauseflag then
        system:pauseTimers()
        pauseNodesInTree(self) --pauses timers and tweens
        saveUserData()
    end
	
    dbg.print("...game suspended!")
end

function sceneGame:resume(event)
    dbg.print("resuming game...")
    pauseflag = true
    dbg.print("...game resumed")
    
    if androidFullscreen and androidFullscreen:isImmersiveSupported() then
        androidFullscreen:turnOn()
    end
end
