
sceneWinLose = director:createScene()
sceneWinLose.name = "winlose"

function sceneWinLose:setUp(event)
    updateVirtualResolution(self)
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    self.background = director:createSprite(0, 0, "textures/paper-1024.png")
    self.background.alpha=0.2
    
    setDefaultSize(self.background, vr.userWinW, vr.userWinH)
    self.background.x = vr.userWinMinX
    self.background.y = vr.userWinMinY
    self.background.zOrder = -1
    
    self.backgroundLines = director:createSprite(0, 0, "textures/menu_bg.png")
    setDefaultSize(self.backgroundLines, appWidth, appHeight)
    
    local title_texture
    if gameInfo.winLose == "win" then
        title_texture = "youwon.png"
    else
        title_texture = "youlose.png"
    end
    
    self.menu = director:createNode({x=appWidth/2,y=appHeight-150})
    
    self.title = director:createSprite({x=appWidth/2, y=390, xAnchor=0.5, yAnchor=0.5, source="textures/" .. title_texture})
    setDefaultSize(self.title, 220)
    self.title.alpha=0
end

function sceneWinLose:enterPostTransition(event)
    tween:to(self.background, {alpha=1, time=1.5})
    tween:to(self.title, {alpha=1, time=1.5, delay=0.5, onComplete=sceneWinLose.activateButtons})
end

function sceneWinLose.activateButtons()
    sceneWinLose.btns = {}

    sceneWinLose:addButton("menu", "image", "menu_button.png", 0, 0, 180, sceneWinLoseTouchMenu)
    if gameInfo.winLose == "win" then
        sceneWinLose:addButton("goToGame", "image", "next_level.png", 0, -440, 160, sceneWinLoseTouchNextLevel)
    else
        sceneWinLose:addButton("goToGame", "image", "retry.png", 0, -440, 80, sceneWinLoseTouchRetry)
    end
    
    sceneWinLose.enableMenu()
end

function sceneWinLose:addButton(name, btnType, textOrImage, btnX, btnY, w, touchListener, textX)
    if btnType == "text" then
        self.btns[name] = director:createSprite({x=btnX, y=btnY, xAnchor=0.5, yAnchor=0.5, source=btnTexture, alpha=0.65})
        setDefaultSize(self.btns[name], w)
        
        self.btns[name].label = director:createLabel({x=textX, y=40, w=btnW, h=btnH, hAlignment="left", vAlignment="bottom", text=textOrImage, color=textCol, font=fontMain, xScale=2, yScale=2})
        
        self.btns[name]:addChild(self.btns[name].label)
        --NB: font scale is applied after x/yAnchor ofset so using those makes it very hard!
        --For text, better to use left/bottom and position manually.
    else
        self.btns[name] = director:createSprite({x=btnX, y=btnY, xAnchor=0.5, yAnchor=0.5, source="textures/" .. textOrImage, alpha=0.9})
        setDefaultSize(self.btns[name], w)
    end

    self.menu:addChild(self.btns[name])
    self.btns[name].touch = touchListener
end

function sceneWinLose.enableMenu(target)
    for k,v in pairs(sceneWinLose.btns) do
        v:addEventListener("touch", v)
    end
end

function sceneWinLose.disableMenu(target)
    for k,v in pairs(sceneWinLose.btns) do
        v:removeEventListener("touch", v)
    end
end

function sceneWinLoseTouchMenu(self,event)
    if event.phase == "ended" then
        sceneWinLose.disableMenu()
        local btnScale = sceneWinLose.btns.menu.defaultScaleX
        tween:to(sceneWinLose.btns.menu, {xScale=btnScale*0.8, yScale=btnScale*0.8, time=0.2})
        tween:to(sceneWinLose.btns.menu, {xScale=btnScale, yScale=btnScale, time=0.2, delay=0.2, onComplete=sceneWinLose.gotoMenu})
    end
end

function sceneWinLose.gotoMenu()
    pauseNodesInTree(sceneWinLose)
    director:moveToScene(sceneMainMenu, {transitionType="slideInL", transitionTime=0.8})
end

function sceneWinLose.goToGame1()
    sceneWinLose.disableMenu()
    local btnScale = sceneWinLose.btns.goToGame.defaultScaleX
    tween:to(sceneWinLose.btns.goToGame, {xScale=btnScale*0.8, yScale=btnScale*0.8, time=0.2})
    tween:to(sceneWinLose.btns.goToGame, {xScale=btnScale, yScale=btnScale, time=0.2, delay=0.2, onComplete=sceneWinLose.goToGame2})
end

function sceneWinLose.goToGame2()
    pauseNodesInTree(sceneWinLose)
    director:moveToScene(sceneGame, {transitionType="slideInR", transitionTime=0.8})
end

function sceneWinLoseTouchNextLevel(self,event)
    gameInfo.level = math.min(gameInfo.level + 1, gameInfo.maxLevel)
    if event.phase == "ended" then
        sceneWinLose.goToGame1()
    end
end

function sceneWinLoseTouchRetry(self,event)
    if event.phase == "ended" then
        sceneWinLose.goToGame1()
    end
end

function sceneWinLose:exitPreTransition(event)
    system:removeEventListener({"suspend", "resume", "update"}, self)
end

function sceneWinLose:exitPostTransition(event)
    backButtonHelper:remove()

    destroyNodesInTree(sceneWinLose, false)
    self.background=nil
    
    self:releaseResources()
    collectgarbage("collect")
    director:cleanupTextures()
end


---- Pause/resume logic/anims on app suspend/resume ---------------------------

function sceneWinLose:suspend(event)
    if not pauseflag then
        system:pauseTimers()
        pauseNodesInTree(self) --pauses timers and tweens
    end
end

function sceneWinLose:resume(event)
    pauseflag = true
        
    if androidFullscreen.isAvailable() and androidFullscreen.isImmersiveSupported() then
        androidFullscreen.turnOn(true, true)
    end
end

function sceneWinLose:update(event)
    if pauseflag then
        pauseflag = false
        system:resumeTimers()
        resumeNodesInTree(self)
    end
end

function sceneWinLose:orientation(event)
    updateVirtualResolution(self)
end

sceneWinLose:addEventListener({"setUp", "enterPostTransition", "exitPreTransition",
        "exitPostTransition", "orientation"}, sceneWinLose)
