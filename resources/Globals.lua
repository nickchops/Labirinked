-------------------------------------------------------------------
-- Debugging --

--debugOn = true
--debugTileTypes = {"threeway"}
debugTileTypes = {"floor", "corner", "stairAscend", "roadRaised"}

--require("mobdebug").start() -- Uncomment for ZeroBrain IDE debuger support

-------------------------------------------------------------------

require("helpers/Utility")

director.isAlphaInherited = false

pauseflag = false -- flag to prevent Quick emulating time passed for timers on resume events

local deviceId = device:getInfo("deviceID")
local platform = device:getInfo("platform")

-- virtual coordinates for user space
appWidth = 1024
appHeight = 768

ppi = 216 --slightly arbitrary default!
if not PixelDensity then --needs ppi/PixelDensity extension. allow building without it
    dbg.assert(false, "PixelDensity module not found. rebuild quick binaries with this module!")
else
    ppi = PixelDensity.GetScreenPPI()
end

-- turn fullscreen on if have extension. screen size won't update till bar is gone
if not androidFullscreen then
    dbg.assert(false, "androidFullscreen extension not found. rebuild quick binaries with this extension!")
else
    if androidFullscreen.isImmersiveSupported() then
        androidFullscreen.turnOn()
    end
end

tapThreshold = 20

---- Game globals go here for easy access --------

fontMain = "fonts/Default.fnt"
fontMainTitle = "fonts/Default.fnt"
fontTimer = "fonts/Segoe40pxNumbers.fnt"

textCol = color.black
lineColor = {0,0,0}

fingerColors = {{markerColor={r=200,g=100,b=255}, tileColor={r=230,g=210,b=255}},
                {markerColor={r=255,g=200,b=100}, tileColor={r=255,g=230,b=210}}}

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
gameInfo.showDragHelper = true
gameInfo.canReturnToQueue = true
gameInfo.levelTime = 60
gameInfo.level = 1
gameInfo.levels = {
    {tileTypes={"floor"}, time=940, width=6, height=3},
    {tileTypes={"floor", "road"}, time=40, width=6, height=4},
    {tileTypes={"corner", "road", "threeway"}, time=40, width=6, height=4},
    {tileTypes={"floor", "corner", "road", "threeway", "blocker"}, time=40, width=7, height=4},
    {tileTypes={"corner", "road", "bridge", "blocker"}, time=50, width=8, height=5},
    {tileTypes={"corner", "road", "bridge", "blocker", "extratime"}, time=30, width=8, height=5},
    {tileTypes={"floor", "corner", "road", "bridge", "blocker", "extratime", "stairAscend"}, time=60, width=9, height=6},
    {tileTypes={"corner", "road", "threeway", "extratime", "stairAscend", "floorRaised"}, time=60, width=9, height=6},
    {tileTypes={"corner", "road", "threeway", "extratime", "stairAscend", "floorRaised", "roadRaised"},
        time=60, width=11, height=6},
    {tileTypes={"corner", "road", "extratime", "stairAscend", "roadRaised"}, time=60, width=10, height=6},
    
    {tileTypes={"floor", "corner", "road", "bridge", "blocker", "extratime", "stairAscend", "roadRaised"},
        time=60, width=12, height=7}
}

gameInfo.maxLevel = table.getn(gameInfo.levels)

-- name is hard coded, could be extended to some entry system or game service login
gameInfo.scores = {}
local names = {"MAR", "MAL", "ADE", "PAC", "JNR", "CRS", "I3D", "MRK", "DAN", "FFS"}
for n=1, 10 do
    local score = (11-n)*20 --20->200
    gameInfo.scores[n] = {name=names[n], score=score}
end

---- Platform/device/app info --------

local appId = "com.mycompany.slots"

useQuitButton = platform ~= "IPHONE"

