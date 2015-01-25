
--dofile("helpers/OnScreenDPad.lua")
--dofile("helpers/OnScreenButton.lua")
require("BackButton")

dofile("Player.lua")
dofile("Tile.lua")
dofile("GameBoard.lua")

sceneGame = director:createScene()
sceneGame.name = "game"

menuHeight = 130

function sceneGame:setUp(event)
    virtualResolution:applyToScene(self)
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    self.background = director:createSprite(0, 0, "textures/paper-1024.png")
    self.background.alpha=0.2
    tween:to(self.background, {alpha=1, time=1.5})
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
    tileQueueY = menuHeight/3+10
    tileXSpace = 20

    board = GameBoard:create()
    board:init(1000, 12, 30, menuHeight, debugOn)
    
    player1 = Player:create()
    player2 = Player:create()
    player1:init(1,board)
    player2:init(2,board)
    
    players = {}
    players[1] = player1
    players[2] = player2
    
    fingers = {}
    fingers[1] = {id=1, phase="ready"}
    fingers[2] = {id=2, phase="ready"}
    
    player1:setGridPos(0,board.tilesHigh-1)
    self.startTile1 = board:addNewTileToGrid(player1.x, player1.y, "floor", 1)
    player1:addPossibleMoves({"down","right"})
    player1.sprite.alpha=0
    self.startTile1.sprite.alpha =0
    
    player2:setGridPos(board.tilesWide-1,0)
    self.startTile2 = board:addNewTileToGrid(player2.x, player2.y, "floor", 1)
    player2:addPossibleMoves({"up","left"})
    player2.sprite.alpha=0
    self.startTile2.sprite.alpha = 0
    
    -- set some tiles to play with to start
end

function addTileToQueue(event)
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
        tileX = appWidth/2 - (board.tileWidth+tileXSpace)*(slot+1)/2 + board.tileWidth/2
    else
        tileX = appWidth/2 + (board.tileWidth+tileXSpace)*slot/2 - board.tileWidth/2
    end
    
    local newType = tileTypes[math.random(1, tileTypeCount)]
    local newTile = createTile(tileX, tileQueueY, newType, 1)
    newTile.startX = tileX
    newTile.startY = tileQueueY
    newTile.startSlot = slot --indicates it's in the queue or being dragged about but not just put onto the grid
    newTile.available = false
    tween:from(newTile.sprite, {alpha=0, time=0.5, onComplete=activateTile})
    newTile.sprite.tile = newTile
    tileQueue[slot] = newTile
end

function activateTile(target)
    target.tile.available = true --only touchable once anim over
end

function sceneGame:enterPostTransition(event)
    system:addTimer(addTileToQueue, 0.3, 4)
    sceneGame:startPlay()
end

function sceneGame:exitPreTransition(event)
    sceneGame:pausePlay()
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

sceneGame:addEventListener({"setUp", "enterPostTransition", "exitPreTransition", "exitPostTransition"}, sceneGame)

-------------------------------------------------------------

-- Main logic


function sceneGame:startPlay()
    if backButtonHelper.added then
        backButtonHelper:enable()
    else
        backButtonHelper:add({listener=self.quit, xCentre=130, yCentre=60, btnWidth=150,
                btnTexture=btnTexture, pulse=false, activateOnRelease=true, animatePress=true,
                deviceKeyOnly=false, drawArrowOnBtn=true, arrowThickness=4})
        
        if backButtonHelper.backBtn then -- in case we change to non-visible on Android etc!
            tween:from(backButtonHelper.backBtn, {alpha=0, time=0.2})
        end
    end
    
    system:addEventListener({"suspend", "resume", "update", "touch"}, self)
    
    tween:to(self.startTile1.sprite, {alpha = 1, time=1.0, delay=0.5})
    tween:to(self.startTile2.sprite, {alpha = 1, time=1.0, delay=0.5})
    tween:to(player1.sprite, {alpha = 1, time=1.0, delay=1.0})
    tween:to(player2.sprite, {alpha = 1, time=1.0, delay=1.0})
    
    --softPad:activate()
end

function sceneGame:pausePlay()
    --todo: pause drag events if needed
    system:removeEventListener("touch", self)
    backButtonHelper:disable()
    sceneGame.disableButtons()
end

function createTile(screenX, screenY, tileType, rotation)
    local tile = Tile:create()
    tile:init(screenX, screenY, tileType, rotation, board.tileWidth)
    tile.sprite.zOrder=board.tilesHigh+1
    return tile
end

-----------------------------------------------------------------

function sceneGame.quit()
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
                for k,player in pairs(players) do
                    if player.phase == "ready" and board:isAdjacentToPlayer(xGrid, yGrid, player, true) then
                        player.phase = "changingTilePos" --TODO: not using this yet. will check animating/moving
                        finger.phase = "placingTile"
                        finger.dragTile = board:getAndRemoveTile(xGrid, yGrid)
                        finger.dragTile.player = player
                        break
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
                print("TOUCH END tile has no finger - should be releasing a grid tile")
            end
            local addedtoBoard
            local takenFromQueue
            addedToBoard, takenFromQueue = finger.dragTile:setGridTarget(board:getNearestGridPos(x,y, finger.dragTile))
            if addedToBoard then
                --TODO: check for movement and update movement and player phase
                -- might want to set finger.phase = "wait" while above animates!
                local updatedPlayer = addedToBoard
                updatedPlayer.phase = "waitingForMove"
            else
                if finger.dragTile.player then
                finger.dragTile.player.phase = "ready"
                end
            end
            
            print("TOUCH END resetting finger " .. finger.id)
            finger.phase = "ready"
            finger.dragTile.finger = nil
            finger.dragTile = nil
            
            if takenFromQueue then --if added a tile from the queue -> new tile
                print("TOUCH END queuing new tile")
                tileQueueSize = tileQueueSize -1
                tileQueue[takenFromQueue] = nil
                system:addTimer(addTileToQueue, 0.5, 1)
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
