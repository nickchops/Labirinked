
require("helpers/BackButton")

sceneCredits = director:createScene()
sceneCredits.name = "credits"

function sceneCredits:setUp(event)
    updateVirtualResolution(self)
    
    system:addEventListener({"suspend", "resume", "update"}, self)

    self.background = director:createSprite(0, 0, "textures/paper-1024.png")
    self.background.alpha=0.2
    
    setDefaultSize(self.background, vr.userWinW, vr.userWinH)
    self.background.x = vr.userWinMinX
    self.background.y = vr.userWinMinY
    self.background.zOrder = -1
    
    self.title = director:createSprite({x=appWidth/2, y=appHeight*0.85, xAnchor=0.5, yAnchor=0.5,
            source="textures/menu_credits.png"})
    setDefaultSize(self.title, 200)
    self.title.alpha=0
end

function sceneCredits:enterPostTransition(event)
    tween:to(self.background, {alpha=1, time=1.5})
    tween:to(self.title, {alpha=1, time=1.5, delay=0.5, onComplete=sceneCredits.activateBack})
end

function sceneCredits.activateBack()
    backButtonHelper:add({listener=sceneCredits.quit, xCentre=130, yCentre=60, btnWidth=150,
            btnTexture=btnTexture, pulse=false, activateOnRelease=true, animatePress=true,
            deviceKeyOnly=false, drawArrowOnBtn=true, arrowThickness=4})
    
    if backButtonHelper.backBtn then -- in case we change to non-visible on Android etc!
        tween:from(backButtonHelper.backBtn, {alpha=0, time=0.2})
    end
    
    director:createLabel({x=260, y=appHeight*0.5, text="Nick Smith: Design and programming\n\n\nRocco: Design, art and music", color=color.black})
end


function sceneCredits.quit()
    system:removeEventListener({"suspend", "resume"}, sceneCredits)
    pauseNodesInTree(sceneCredits)
    backButtonHelper:disable()
    director:moveToScene(sceneMainMenu, {transitionType="slideInL", transitionTime=0.8})
end   

function sceneCredits:exitPreTransition(event)
end

function sceneCredits:exitPostTransition(event)
    backButtonHelper:remove()

    destroyNodesInTree(sceneCredits, false)
    self.background=nil
    
    self:releaseResources()
    collectgarbage("collect")
    director:cleanupTextures()
end

---- Pause/resume logic/anims on app suspend/resume ---------------------------

function sceneCredits:suspend(event)
    if not pauseflag then
        system:pauseTimers()
        pauseNodesInTree(self) --pauses timers and tweens
    end
end

function sceneCredits:resume(event)
    pauseflag = true
        
    if androidFullscreen.isAvailable() and androidFullscreen.isImmersiveSupported() then
        androidFullscreen.turnOn(true, true)
    end
end

function sceneCredits:update(event)
    if pauseflag then
        pauseflag = false
        system:resumeTimers()
        resumeNodesInTree(self)
    end
end

function sceneCredits:orientation(event)
    updateVirtualResolution(self)
end


sceneCredits:addEventListener({"setUp", "enterPostTransition", "exitPreTransition",
        "exitPostTransition", "orientation"}, sceneCredits)
