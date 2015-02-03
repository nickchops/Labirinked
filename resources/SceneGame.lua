
--dofile("helpers/OnScreenDPad.lua")
--dofile("helpers/OnScreenButton.lua")
require("BackButton")

dofile("Player.lua")
dofile("Tile.lua")
dofile("GameBoard.lua")

sceneGame = director:createScene()
sceneGame.name = "game"

menuHeight = 130
tileQueueY = (menuHeight/3+10) + screenMinY/2
tilesWide = debugTilesWide or 12

function sceneGame:setUp(event)
    virtualResolution:applyToScene(self)
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    self.background = director:createSprite(0, 0, "textures/paper-1024.png")
    self.background.alpha=0.2
    setDefaultSize(self.background, screenWidth, screenHeight)
    self.background.x = screenMinX
    self.background.y = screenMinY
    self.background.zOrder = -1
    
    
    math.randomseed(os.time())
    
    --softPad =  OnScreenDPad.Create({x=100,   y=100, baseRadius=appWidth/13, topRadius=appWidth/23})
    --btnA = OnScreenButton.Create({x=80, y=appWidth-100, radius=15, topColor=color.red, baseColor=color.darkRed, scale3d=5, depth3d=5})
    --btnB = OnScreenButton.Create({x=30, y=appWidth-100, radius=15, topColor=color.green, baseColor=color.darkGreen, scale3d=5, depth3d=5})

    tileQueue = {}
    tileQueueMax = 4
    tileQueueSize = 0
    
    tileXSpace = 20

    board = GameBoard:create()
    board:init(900, tilesWide, 30, menuHeight, debugOn)
    
    player1 = Player:create()
    player2 = Player:create()
    player1:init(1,board,player2)
    player2:init(2,board,player1)
    
    players = {}
    players[1] = player1
    players[2] = player2
    
    fingers = {}
    fingers[1] = {id=1, phase="ready"}
    fingers[2] = {id=2, phase="ready"}
    
    local p1StartX = 0
    local p1StartY = board.tilesHigh-1
    local p2StartX = board.tilesWide-1
    local p2StartY = 0
    
    player1:setGridPos(p1StartX, p1StartY, true)
    self.startTile1 = board:addNewTileToGrid(player1.x, player1.y, "floor", 1)
    board:setVisited(p1StartX, p1StartY)
    player1:addPossibleMoves({"down","right"})
    player1.sprite.alpha=0
    self.startTile1.sprite.alpha =0
    
    player2:setGridPos(p2StartX, p2StartY, true)
    self.startTile2 = board:addNewTileToGrid(player2.x, player2.y, "floor", 1)
    board:setVisited(p2StartX, p2StartY)
    player2:addPossibleMoves({"up","left"})
    player2.sprite.alpha=0
    self.startTile2.sprite.alpha = 0
    
    -- set some tiles to play with to start
end

function sceneGame:queueTile(time, number)
    if not self.tileQueueTimers then
        self.tileQueueTimers = {}
        self.tileTimerCount = 0
    end
    self.tileTimerCount = self.tileTimerCount + 1
    
    local tileTimer = system:addTimer(sceneGame.addTileToQueue, time, number)
    tileTimer.id = self.tileTimerCount
    self.tileQueueTimers[tileTimer.id] = tileTimer
end

function sceneGame.addTileToQueue(event)
    if event.timer.doneIterations == event.timer.iterations then
        self.tileQueueTimers[event.timer.id] = nil
    end
    
    if tileQueueSize >= tileQueueMax then
        return
    end
    
    tileQueueSize = tileQueueSize +1
    local tileX
    
    local slot = nil
    for i=1,tileQueueMax do
        if not slot and not tileQueue[i] then
            slot = i
        end
    end
    
    if slot % 2 == 1 then
        tileX = appWidth/2 - (board.tileWidth+tileXSpace)*(slot+1)/2 + board.tileWidth/2 - 50
    else
        tileX = appWidth/2 + (board.tileWidth+tileXSpace)*slot/2 - board.tileWidth/2 + 50
    end
    
    local newType = tileTypes[math.random(1, tileTypeCount)]
    local newTile = createTile(tileX, tileQueueY, newType, 1)
    newTile.startX = tileX
    newTile.startY = tileQueueY
    newTile.startSlot = slot --indicates it's in the queue or being dragged about but not just put onto the grid
    newTile.available = false
    tween:to(newTile.sprite, {alpha=tileAlpha, time=0.5, onComplete=activateTile})
    newTile.sprite.tile = newTile
    tileQueue[slot] = newTile
end

function sceneGame:tileQueueFadeOut(onComplete, duration)
    dbg.print("fadeout queue")
    for k,tile in pairs(tileQueue) do
        --dbg.print("fadeout queue: slot=" .. k .. " xy=" .. tile.startX .. "," .. tile.startY .. " " .. tile.tileType)
        tween:to(tile.sprite, {alpha=0, time=duration})
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
    tileQueue = nil
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
    
    tileQueueY = (menuHeight/3+10) + screenMinY/2
    
    for k,tile in pairs(tileQueueMax) do
        tile.startY = tileQueueY
        tile.origin.y = tileQueueY
    end
    
    backButtonHelper:setCenterPosition(nil, 55+screenMinY)
end


sceneGame:addEventListener({"setUp", "enterPostTransition", "exitPreTransition",
        "exitPostTransition", "orientation"}, sceneGame)

-------------------------------------------------------------

-- Main logic


function sceneGame.showPieces()
    local self = sceneGame
    backButtonHelper:add({listener=self.quit, xCentre=80, yCentre=55+screenMinY, btnWidth=80,
            btnTexture=btnBackTexture, pulse=false, activateOnRelease=true, animatePress=true,
            deviceKeyOnly=false, drawArrowOnBtn=true, arrowThickness=4})
    
    if backButtonHelper.backBtn then -- in case we change to non-visible on Android etc!
        tween:from(backButtonHelper.backBtn, {alpha=0, time=0.2})
    end
    
    self:queueTile(0.3, 4)
    
    tween:to(self.startTile1.sprite, {alpha = tileAlpha, time=1.0, delay=0.5, onComplete=sceneGame.startPlay})
    tween:to(self.startTile2.sprite, {alpha = tileAlpha, time=1.0, delay=0.5})
    tween:to(player1.sprite, {alpha = 1, time=1.0, delay=1.0})
    tween:to(player2.sprite, {alpha = 1, time=1.0, delay=1.0})
    
    self.levelTimerNode = director:createNode({x=appWidth/2, y=tileQueueY})
    self.levelTimerNode.label = director:createLabel({x=-20, y=-20, color=color.black, text=gameInfo.levelTime,
            xScale=1.5, yScale=1.5})
    self.levelTimerNode:addChild(self.levelTimerNode.label)
    self.levelTimer = self.levelTimerNode:addTimer(self.levelTimerFunc, 1.0, gameInfo.levelTime)
    tween:to(self.levelTimerNode, {xScale=1, yScale=1, time=0.9})
    gameInfo.timeLeft = gameInfo.levelTime
    
    --softPad:activate()
end

function sceneGame.startPlay()
    system:addEventListener({"touch"}, sceneGame)
    backButtonHelper:enable()
end

function sceneGame.levelTimerFunc(event)
    gameInfo.timeLeft = gameInfo.timeLeft - 1
    event.target.label.text = gameInfo.timeLeft
    event.target.xScale = 1.5
    event.target.yScale = 1.5
    
    if gameInfo.timeLeft == 9 then
        event.target.label.x = event.target.label.x/2
    end
    
    if gameInfo.timeLeft <= 0 then
        dbg.print("time up, pausing play")
        sceneGame:pausePlay()
        board:fadeOut(sceneGame.gotoWinLose, 5)
        sceneGame:tileQueueFadeOut(3)
    else
        tween:to(event.target, {xScale=1, yScale=1, time=0.9})
    end
end

function sceneGame:incrementTimer(time)
    self.levelTimer:cancel()
    
    time = gameInfo.timeLeft + time
    if time > 9 and gameInfo.timeLeft < 10 then
        event.target.label.x = event.target.label.x*2
    end
    
    gameInfo.timeLeft = time
    self.levelTimerNode.xScale = 2
    self.levelTimerNode.yScale = 2
    self.levelTimer = self.levelTimerNode:addTimer(self.levelTimerFunc, 1.0, gameInfo.timeLeft)
end

function sceneGame:pausePlay()
    dbg.print("PAUSE PLAY")
    --todo: pause drag events if needed
    system:removeEventListener("touch", self)
    backButtonHelper:disable()
    sceneGame.disableButtons()
    self.levelTimer:cancel()
    self.levelTimer = nil
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
    tile.origin.zOrder=board.tilesHigh+2
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
    dbg.print("level cleared, pausing play")
    sceneGame:pausePlay()
    gameInfo.winLose = "win"
    board:fadeOut(sceneGame.gotoWinLose, 7)
    self:tileQueueFadeOut(3)
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
    if event.id > 1 then return end
    
    local x = vr:getUserX(event.x)
    local y = vr:getUserY(event.y)
    
    local finger = fingers[event.id]
    
    if event.phase == "began" and finger.phase == "ready" then
        if y < menuHeight then
            for k,tile in pairs(tileQueue) do
                if (not tile.finger) and tile.available and
                        x > tile.startX-board.tileWidth/2 and x < tile.startX+board.tileWidth/2 then
                    finger.phase = "placingTile"
                    finger.dragTile = tile
                    finger.dragTile.finger = finger
                    finger.startX = x
                    finger.startY = y
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
                        player.phase = "changingTilePos" --TODO: not using this yet. will check animating/moving
                        dbg.print("moving tile, player(" .. player.id .. ") setting phase=" .. player.phase)
                        finger.phase = "placingTile"
                        if not gotTile then
                            gotTile = board:getAndRemoveTile(xGrid, yGrid)
                            finger.dragTile = gotTile
                            finger.startX = x
                            finger.startY = y
                        end
                        if not finger.dragTile.players then finger.dragTile.players={} end
                        finger.dragTile.players[player.id] = player
                    end
                end
            end
        end
    elseif finger.phase == "placingTile" then
        if event.phase == "moved" then
            finger.dragTile:setPosCentered(x,y)
        elseif event.phase == "ended" then
            if finger.dragTile.finger then
                print("TOUCH END tile has finger: " .. finger.dragTile.finger.id)
            else
                print("TOUCH END tile has no finger - should be releasing a grid tile") --TODO check this!!
            end
            
            -- for laziness, using tap to rotate. may want to change to two finger rotate...
            if math.abs(finger.startX - x) < tapThreshold and math.abs(finger.startY - y) < tapThreshold then
                finger.dragTile:rotateRight()
            end
            
            local tilePlacedNearPlayers, tileWasFromQueue
                    = finger.dragTile:setGridTarget(board:getNearestGridPos(x,y, finger.dragTile))
            -- tilePlacedNearPlayers = false: tile not placed so return it.
            -- tilePlacedNearPlayers = list: tile was moved and this is a list of players the tile is now next to
            
            if tilePlacedNearPlayers then
                --TODO: check for movement and update movement and player phase
                -- might want to set finger.phase = "wait" while above animates!
                for k,player in pairs(tilePlacedNearPlayers) do
                    player.phase = "waitingForMove"
                    dbg.print("added tile to board: near player(" .. player.id ..") setting player phase=" .. player.phase)
                end
            else
                if finger.dragTile.players then
                    for k,player in pairs(finger.dragTile.players) do
                        player.phase = "ready"
                        finger.dragTile.players[player.id] = nil
                        dbg.print("NOT added to board (from queue): player(" .. player.id ..") setting phase=" .. player.phase)
                    end
                end
            end
            
            print("TOUCH END resetting finger " .. finger.id)
            finger.phase = "ready"
            finger.dragTile.finger = nil
            finger.dragTile = nil
            
            if tileWasFromQueue then --if added a tile from the queue (not dragged from other spot on board) -> new tile
                print("TOUCH END queuing new tile")
                tileQueueSize = tileQueueSize -1
                tileQueue[tileWasFromQueue] = nil
                self:queueTile(0.5, 1)
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


--- coin buttons

function sceneGame:addButton(name, text, x, y, width, touchListener, textX, btnColor)
    local btn = director:createSprite({x=x, y=y, xAnchor=0.5, yAnchor=0.5, source=btnTextureShort, color=btnColor})
    
    if not self.btns then
        self.btns = {}
    end
    self.btns[name] = btn
    
    btn.btnScale = width/btn.w

    btn.xScale = btn.btnScale
    btn.yScale = btn.btnScale
    btn.defaultScale = btn.btnScale
    
    --btn.x = btn.x+btn.w/2
    --btn.y = btn.y+btn.h/2
    
    sceneGame:addChild(btn)
    btn.label = director:createLabel({x=-width+textX, y=10, w=btn.w, h=btn.h, hAlignment="center", vAlignment="bottom", text=text, color=color.white, font=fontMain, xScale=2, yScale=2})
    btn:addChild(btn.label)

    btn.touch = touchListener
    return btn
end

function sceneGame.enableButtons()
    for k,v in pairs(sceneGame.btns) do
        v:addEventListener("touch", v)
        v.color=color.red
    end
end

function sceneGame.disableButtons()
    if sceneGame.btns then
        for k,v in pairs(sceneGame.btns) do
            v:removeEventListener("touch", v)
            v.color={100,0,0}
        end
    end
end

function sceneGame.touchButton1(self, event)
    if event.phase == "ended" then
        --do logic
        
        tween:to(self, {xScale=self.btnScale*0.9, yScale=self.btnScale*0.9, time=0.1})
        tween:to(self, {xScale=self.btnScale, yScale=self.btnScale, time=0.1, delay=0.1, onComplete=nil}) --TODO: set on complete!
    end
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
        
    if androidFullscreen.isAvailable() and androidFullscreen.isImmersiveSupported() then
        androidFullscreen.turnOn(true, true)
    end
end
