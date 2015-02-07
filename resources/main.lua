
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
    vr:update()
    if (scene) then
        vr:applyToScene(scene)
        
        if (scene.background) then
            setDefaultSize(scene.background, vr.userWinW, vr.userWinH)
            scene.background.x = vr.userWinMinX
            scene.background.y = vr.userWinMinY
        end
    end
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
