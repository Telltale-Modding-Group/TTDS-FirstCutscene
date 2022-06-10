--[[
-------------------------------------------------------------------------
This script is included in the main menu and contains the main function for when pressing the Play Cutscene Button,
It exectues the main cutscene level script.
]]--

--sets some season 2 project settings when we load into the cutscene
local SetSeason2ProjectSettings = function()
    local prefs = GetPreferences();
    PropertySet(prefs, "Enable Graphic Black", false);
    PropertySet(prefs, "Render - Graphic Black Enabled", false);
    PropertySet(prefs, "Camera Lens Engine", false);
    PropertySet(prefs, "Enable Dialog System 2.0", true);
    PropertySet(prefs, "Enable LipSync 2.0", true);
    PropertySet(prefs, "Legacy Light Limits", false);
    PropertySet(prefs, "Render - Feature Level", 1);
    PropertySet(prefs, "Use Legacy DOF", true);
    PropertySet(prefs, "Animated Lookats Active", false);
    PropertySet(prefs, "Camera Lens Engine", false);
    PropertySet(prefs, "Chore End Lipsync Buffer Time", -1);
    PropertySet(prefs, "Enable Callbacks For Unchanged Key Sets", true);
    PropertySet(prefs, "Enable Lipsync Line Buffers", false);
    PropertySet(prefs, "Fix Pop In Additive Idle Transitions", false);
    PropertySet(prefs, "Fix Recursive Animation Contribution (set to false before Thrones)", false);
    PropertySet(prefs, "Legacy Use Default Lighting Group", true);
    PropertySet(prefs, "Lipsync Line End Buffer", 0);
    PropertySet(prefs, "Lipsync Line Start Buffer", 0);
    PropertySet(prefs, "Mirror Non-skeletal Animations", false);
    PropertySet(prefs, "Project Generates Procedural Look At Targets", false);
    PropertySet(prefs, "Remap bad bones", true);
    PropertySet(prefs, "Set Default Intensity", false);
    PropertySet(prefs, "Strip action lines", true);
    PropertySet(prefs, "Text Leading Fix", true);
end

--enables some archives that the cutscene uses assets from
local EnableCutsceneArchives = function()
    --enable these archives since the cutscene was built in S2 and uses S2 assets.
    ResourceSetEnable("ProjectSeason2");
    ResourceSetEnable("WalkingDead201"); --need this especially, contains flashback clem
    
    --enable these since we use some particle effects from S4
    ResourceSetEnable("WalkingDead401");
end

--function that is exectued when the user presses the play cutscene button in the menu
PlayFirstCutsceneLevel = function()
    SetSeason2ProjectSettings();
    EnableCutsceneArchives();

    OverlayShow("ui_loadingScreen.overlay", true);

    --execute the cutscene level script
    dofile("FCM_Level_FirstCutscene.lua");
end