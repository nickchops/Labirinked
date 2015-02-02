
--if androidFullscreen.isAvailable() and androidFullscreen.isImmersiveSupported() then
--    androidFullscreen.turnOn(true, true)
--end

----------------------------------------------------------------------------
require("helpers/Utility")
dofile("Globals.lua")
require("helpers/VirtualResolution")

-- All code is in user coords - will be scaled to screen with fixed aspect ration and
-- letterboxes we can draw over
vr = virtualResolution
vr:initialise{userSpaceW=appWidth, userSpaceH=appHeight}

function updateVirtualResolution(scene)
    if (scene) then
        virtualResolution:update()
        virtualResolution:applyToScene(scene)
    end
    
    -- User space values of screen edges: for detecting edges of full screen area, including letterbox/borders
    -- Useful for making sure things are on/off screen when needed
    screenWidth = vr:winToUserSize(director.displayWidth)
    screenHeight = vr:winToUserSize(director.displayHeight)

    screenMinX = appWidth/2 - screenWidth/2
    screenMaxX = appWidth/2 + screenWidth/2
    screenMinY = appHeight/2 - screenHeight/2
    screenMaxY = appHeight/2 + screenHeight/2
end

updateVirtualResolution(nil)

dofile("SceneMainMenu.lua")
dofile("SceneGame.lua")
dofile("SceneCredits.lua")
dofile("SceneWinLose.lua")

device:enableVibration()

director:moveToScene(sceneMainMenu)



-- Shutdown/cleanup

function shutDownApp()
    dbg.print("Exiting app")
    system:quit()
end

function shutDownCleanup(event)
    dbg.print("Cleaning up app on shutdown")
    audio:stopStream()
end

system:addEventListener("exit", shutDownCleanup)
