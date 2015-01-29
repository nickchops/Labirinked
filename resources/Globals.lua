-------------------------------------------------------------------
-- Debugging --

debugOn = false
--debugTileTypes = {"floor"}

require("mobdebug").start() -- Uncomment for ZeroBrain IDE debuger support

-------------------------------------------------------------------

require("helpers/Utility")

director.isAlphaInherited = false

pauseflag = false -- flag to prevent Quick emulating time passed for timers on resume events

deviceId = device:getInfo("deviceID")
deviceIsTouch = true

-- virtual coordinates for user space
appWidth = 1024
appHeight = 768


---- Game globals go here for easy access --------

fontMain = "fonts/Default.fnt"
fontMainTitle = "fonts/Default.fnt"

textCol = color.black
goldColor = {231,215,99}
goldColorDark = {181,165,59}

lineColor = {0,0,0}

titleCol = lineColor
btnCol = color.aliceBlue
btnTexture = "textures/button1.png"
btnBackTexture = "textures/button2.png"
btnTextureShort = "textures/shortGoldButton.png"
titleMusic = "sounds/labirink.mp3"
gameMusic = nil
-- free music is from www.playonloop.com A handy website!
-- You should include attribution in the game if not paying!

gameInfo = {}
gameInfo.score = 0
gameInfo.soundOn = true
gameInfo.lastUserName = "P1 "
gameInfo.winloose = "loose"
gameInfo.levelTime = 60
-- name is hard coded in this example, could be extended to some entry system or game service login

gameInfo.scores = {}
local names = {"MAR", "MAL", "ADE", "PAC", "JNR", "CRS", "I3D", "MRK", "DAN", "FFS"}
for n=1, 10 do
    local score = (11-n)*20 --20->200
    gameInfo.scores[n] = {name=names[n], score=score}
end

---- Platform/device/app info --------

local appId = "com.mycompany.slots"

local platform = device:getInfo("platform")

useQuitButton = platform ~= "IPHONE"

