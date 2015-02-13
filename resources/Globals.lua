-------------------------------------------------------------------
-- Debugging --

--debugOn = true
--debugTileTypes = {"threeway"}-- {"floor", "stairAscend", "roadRaised"}

--require("mobdebug").start() -- Uncomment for ZeroBrain IDE debuger support

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
titleMusic = "sounds/labirink.mp3"
gameMusic = nil
gameInfo = {}
gameInfo.score = 0
gameInfo.soundOn = true
gameInfo.lastUserName = "P1 "
gameInfo.winLose = "lose"
gameInfo.levelTime = 60
gameInfo.level = 1
gameInfo.levels = {
    {tileTypes = {"floor"}, time = 60},
    {tileTypes = {"floor", "corner", "road"}, time = 60},
    {tileTypes = {"floor", "corner", "road", "threeway"}, time = 40},
    {tileTypes = {"floor", "corner", "road", "threeway", "blocker"}, time = 40},
    {tileTypes = {"corner", "road", "bridge", "blocker"}, time = 50},
    {tileTypes = {"corner", "road", "bridge", "blocker", "extratime"}, time = 30},
    {tileTypes = {"floor", "corner", "road", "bridge", "blocker", "extratime", "stairAscend"}, time = 60},
    {tileTypes = {"corner", "road", "threeway", "extratime", "stairAscend", "floorRaised"}, time = 60},
    {tileTypes = {"corner", "road", "threeway", "extratime", "stairAscend", "floorRaised", "roadRaised"}, time = 60},
    {tileTypes = {"corner", "road", "extratime", "stairAscend", "roadRaised"}, time = 60}
}

gameInfo.maxLevel = table.getn(gameInfo.levels)

tapThreshold = 5 --pixels for tap vs drag. TODO: should use dist via PixelDensity, not just pixels

-- name is hard coded, could be extended to some entry system or game service login
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

