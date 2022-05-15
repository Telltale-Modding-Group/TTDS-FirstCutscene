--[[
-------------------------------------------------------------------------
This script is the main level script for the cutscene.
It also contains the main logic in here that I created for doing a cutscene.

It's worth noting for this ctuscene script, it is bascially implemented in its own completely original level, and not an existing level script.
Granted, you can still implement this kind of cutscene logic into an existing level script, however for the sake of exploration and simplicity I created my own.

The basic process of making/creating a cutscene goes something like this.
- Take an existing TWD level (preferably something close to what is intended).
- Completely strip all of the agents in the original scene that we don't need.
- Instantiate our own agents into the scene (those can be enviorment assets, characters, objects, etc.)
- Setup our cutscene content (cameras, angles, sequence clips, audio, etc.)
- Finally, we have update functions where we programmatically create and do things during the cutscene (camera work, acting)

Is there are better way to do this? If you are telltale dev yes... 
But we are not and don't have your chore editor... so we have to make do with lua scripting at the moment.

CUTSCENE SYSTEM EXPLANATION
For sequencing I have a basic psudeo timeline objects. You will see those in the script and they go by the names of [sequence_clips] and [sequence_cameraAngles].
There are a few more but to elaborate on how this sequencing system works (once again because we don't have a chore editor yet)
we have a time sequence value variable that gets incremented 1 every single frame (could I have actually grabbed the game time? yes, that does exist however I did it this way first and it worked... in a newer version of this psudeo system I will definetly try to attempt to use it)
This time sequence variable is [sequence_currentTimer] and it basically acts as our psudeo playhead (but not quite with the way I coded it and you'll see later)
[sequence_clips] contains an array of clip objects, these will be accessed sequentially as the scene goes on
[sequence_cameraAngles] contains an array of camera angle objects, these are referenced by the sequence clips by the variable [angleIndex] inside the clip object. (normally I geuss you would include this camera data inside the clip object, however I kept it seperate because we often in cinema cut back to shots thta have these angles)
For the current clip that we are on, the object also has a [shotDuration] field which obviously tells us how long the shot will last.
When the playhead value [sequence_currentTimer] reaches the end of the current clip [shotDuration]
we then move on to the next shot in the sequence by incrementing [sequence_currentShotIndex] and by also resetting [sequence_currentTimer] back to zero. (Yes, you could change it so [sequence_currentTimer] keeps counting as the game goes on, or again also use the actual game time value which we have access to, but this is the way I did it first :P but also didn't really want to deal with very long numbers)
when we do that, now our current clip is the next shot in the sequence, and this cycle repeats until the sequence effectively ends.
]]--

--include our custom scripts/extensions
--these scripts contain a ton of functionality and useful functions to make things easier for us.
require("FCM_Utilities.lua");
require("FCM_AgentExtensions.lua");
require("FCM_Color.lua");
require("FCM_Printing.lua");
require("FCM_PropertyKeys.lua");
require("FCM_Development_Freecam.lua");
require("FCM_Development_AgentBrowser.lua");
require("FCM_DepthOfFieldAutofocus.lua");

--|||||||||||||||||||||||||||||||||||||||||||||| SCRIPT VARIABLES ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| SCRIPT VARIABLES ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| SCRIPT VARIABLES ||||||||||||||||||||||||||||||||||||||||||||||

--main level variables
local kScript = "FirstCutsceneLevel"; --dont touch (the name of this script and also the name of the level function at the bottom of the script, which will be called as soon as this scene opens)
local kScene = "adv_truckStopBathroom"; --dont touch (the name of the scene asset file)

--scene agent name variable
local agent_name_scene = "adv_truckStopBathroom.scene"; --dont touch (this is the name of the scene agent object, using it to set post processing effects later)

--cutscene development variables variables (these are variables required by the development scripts)
Custom_CutsceneDev_SceneObject = kScene; --dont touch (the development scripts need to reference the main level)
Custom_CutsceneDev_SceneObjectAgentName = agent_name_scene; --dont touch (the development scripts also need to reference the name of the scene agent)
Custom_CutsceneDev_UseSeasonOneAPI = false; --dont touch (this is leftover but if the development tools were implemented inside season 1 we need to use the S1 functions because the api changes)
Custom_CutsceneDev_FreecamUseFOVScale = false; --changes the camera zooming from modifing the FOV directly, to modifying just the FOV scalar (only useful if for some reason the main field of view property is chorelocked or something like that)

--dof autofocus variables
Custom_DOF_AUTOFOCUS_SceneObject = kScene; --dont touch (the dof autofocus script need to reference the main level)
Custom_DOF_AUTOFOCUS_SceneObjectAgentName = agent_name_scene; --dont touch
Custom_DOF_AUTOFOCUS_UseCameraDOF = true; --uses the depth of field properties on the camera rather than on the scene post processing.

--list of gameplay camera agent names, putting a camera name in here means that DOF will be disabled since its a gameplay camera, and we dont want DOF during gameplay.
Custom_DOF_AUTOFOCUS_GameplayCameraNames = 
{
    "test"
};

--list of objects in the scene that are our targets for depth of field autofocusing
Custom_DOF_AUTOFOCUS_ObjectEntries =
{
    "Clementine",
    "Christa",
    "Omid"
};

--cutscene variables
local MODE_FREECAM = false; --enable freecam rather than the cutscene camera
local agent_name_cutsceneCamera = "myCutsceneCamera"; --cutscene camera agent name
local agent_clementine = nil; --dont touch (reference to clementine agent object in the scene, its nil now but will be assigned later)
local agent_christa = nil; --dont touch (reference to christa agent object in the scene, its nil now but will be assigned later)
local agent_omid = nil; --dont touch (reference to omid agent object in the scene, its nil now but will be assigned later)

--controller variables (these just store a reference to the animations/chores that are playing during the cutscene)
local controller_animation_clementineWalk = nil; --dont touch
local controller_animation_christaWalk = nil; --dont touch
local controller_animation_omidWalk = nil; --dont touch
local controller_animation_clementineBlink = nil; --dont touch
local controller_animation_clementineEyesLookUp = nil; --dont touch
local controller_animation_clementineEyesLookDown = nil; --dont touch
local controller_animation_clementineEyesDarting = nil; --dont touch
local controller_animation_clementineHeadLookUp = nil; --dont touch
local controller_animation_clementineHeadLookDown = nil; --dont touch
local controller_chore_clementineEmotion = nil; --dont touch

--update tick variables for clementine additive blinking animation
local maxTick_animation_clementine_blink = 100.0; --the (duration) that clem has her eyes open before she blinks
local tick_animation_clementine_blink = 0.0; --dont touch (main tick blink variable, this gets incremented 1 every frame and resets when we reach the maxtick for blink)

--enviorment scrolling variables
local enviorment_scroll_maxPositionZ = 25; --the maximum z position in which the enviorment scrolls to, when it reaches this it will reset back to 0 and go again.
local enviorment_scroll_positionZ = 0; --dont touch (the main z position that gets incremented every frame by the scroll speed)
local enviorment_scroll_speed = 0.01; --the speed at which the enviorment will scroll/move

--procedual handheld camera animation (adds a bit of extra life and motion to the camera throughout the sequence)
local camera_handheld_rot_strength = 15; --the amount of (shake) for the camera rotation
local camera_handheld_pos_strength = 0.35; --the amount of (shake) for the camera position
local camera_handheld_rot_lerpFactor = 1.0; --how smooth/snappy the rotation shake will be
local camera_handheld_pos_lerpFactor = 1.0;--how smooth/snappy the position shake will be
local camera_handheld_desiredRot = Vector(0, 0, 0); --dont touch (the desired random calculated shake for rotational movement)
local camera_handheld_desiredPos = Vector(0, 0, 0); --dont touch (the desired random calculated shake for positional movement)
local camera_handheld_currentRot = Vector(0, 0, 0); --dont touch (the current rotation of the shake, overtime it tries to [match] the desired rotation)
local camera_handheld_currentPos = Vector(0, 0, 0); --dont touch (the current position of the shake, overtime it tries to [match] the desired position)
local camera_handheld_tick = 0; --dont touch (main handheld tick variable, this gets incremented 1 every frame until we reach the update level, and then the time resets (so we don't calculate a new shake every single frame, this spaces it out)
local camera_handheld_updateLevel = 20; --the (duration) until a new desired shake rotation/position is calculated

--current sequence variables
local currentSequence_clip = nil; --dont touch (the current clip object that we are on)
local currentSequence_clipInfo_duration = nil; --dont touch (the duration of the shot)
local currentSequence_clipInfo_angleIndex = nil; --dont touch (the chosen angle item index for the shot)
local currentSequence_angle = nil; --dont touch (the actual angle object the clip references)

--main sequence variables
local sequence_maxClips = 6; --the maximum amount of clips in the sequence
local sequence_currentShotIndex = 1; --dont touch (the current shot index that are are on)
local sequence_currentTimer = 0; --dont touch (update tick that gets incremented 1 every frame and resets when we reach the end of the current shot duration)

--this variable is an array that will contain our (clips)
local sequence_clips = 
{
    clip1 = 
    {
        angleIndex = 1,
        shotDuration = 680
    },
    clip2 = 
    {
        angleIndex = 2,
        shotDuration = 575
    },
    clip3 = 
    {
        angleIndex = 4,
        shotDuration = 320
    },
    clip4 = 
    {
        angleIndex = 12,
        shotDuration = 420
    },
    clip5 = 
    {
        angleIndex = 9,
        shotDuration = 410
    },
    clip6 = 
    {
        angleIndex = 10,
        shotDuration = 720
    }
};

--this variable is an array that will contain all of our camera angles in the scene (this gets referenced by the current sequence clip according to the angle index number)
local sequence_cameraAngles = 
{
    angle1 = --sky upward trees
    {
        FieldOfView = 54.5,
        CameraPosition = Vector(0.974798, 1.287862, 1.140622),
        CameraRotation = Vector(-52.166679, 3.281267, 0.0)
    },
    angle2 = --clem meduim shot
    {
        FieldOfView = 47.5,
        CameraPosition = Vector(-0.271737, 0.904765, 1.928374),
        CameraRotation = Vector(-12.499946, 156.250137, 0.0)
    },
    angle3 = --clem meduim shot (opposite side)
    {
        FieldOfView = 44.5,
        CameraPosition = Vector(0.434692, 0.826559, 2.050152),
        CameraRotation = Vector(-13.679152, -149.443787, 0.0)
    },
    angle4 = --clem over the shoulder looking to christa and omid
    {
        FieldOfView = 58.5,
        CameraPosition = Vector(-0.296256, 1.135606, 0.623154),
        CameraRotation = Vector(0.833244, 15.085524, 0.0)
    },
    angle5 = --christa over the shoulder frame right (facing forward) with clem behind on frame left
    {
        FieldOfView = 27,
        CameraPosition = Vector(-0.789052, 1.774310, 5.265550),
        CameraRotation = Vector(10.335145, 160.968811, 0.0)
    },
    angle6 = --same as angle 5 but lower and christas hands on frame right
    {
        FieldOfView = 33,
        CameraPosition = Vector(-1.023112, 0.810442, 5.421932),
        CameraRotation = Vector(-2.166778, 159.093506, 0.0)
    },
    angle7 = --clem meduim front angle
    {
        FieldOfView = 38,
        CameraPosition = Vector(-0.002530, 1.066046, 2.182070),
        CameraRotation = Vector(-2.833421, 179.498123, 0.0)
    },
    angle8 = --clem over the should looking to christa and omid (wider and farther back)
    {
        FieldOfView = 69.5,
        CameraPosition = Vector(-0.788173, 0.807784, -0.294484),
        CameraRotation = Vector(-0.500023, 15.550955, 0.0)
    },
    angle9 = --clem closeup shot
    {
        FieldOfView = 48,
        CameraPosition = Vector(-0.197903, 1.032091, 1.552511),
        CameraRotation = Vector(-12.166755, 151.862289, 0.0)
    },
    angle10 = --far wide shot in forest with foliage in foreground
    {
        FieldOfView = 36,
        CameraPosition = Vector(-8.381993, 1.011575, 0.253241),
        CameraRotation = Vector(0.166695, 75.187233, 0.0)
    },
    angle11 = --birds eye from right side looking down at clem
    {
        FieldOfView = 42.5,
        CameraPosition = Vector(2.375937, 8.759699, 5.460268),
        CameraRotation = Vector(60.99947, -142.312469, 0.0)
    },
    angle12 = --birds eye from left side looking down at clem
    {
        FieldOfView = 50.5,
        CameraPosition = Vector(-1.335250, 5.916360, 4.442194),
        CameraRotation = Vector(59.056675, 144.886063, 0.0)
    },
    angle13 = --front facing shot with christa and omid in foreground
    {
        FieldOfView = 40.0,
        CameraPosition = Vector(0.036317, 0.935897, 6.181844),
        CameraRotation = Vector(-0.333559, -179.415298, 0.0)
    }
};

--hides the cursor in game
HideCusorInGame = function()
    --hide the cursor
    CursorHide(true);
    
    --enable cusor functionality
    CursorEnable(true);
end

--|||||||||||||||||||||||||||||||||||||||||||||| SCENE SETUP ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| SCENE SETUP ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| SCENE SETUP ||||||||||||||||||||||||||||||||||||||||||||||

--completely strips the original scene of almost all of its original objects
--however we will only keep a few things that we will need later on
Scene_CleanUpOriginalScene = function()
    --bulk remove all of the following assets
    Custom_RemovingAgentsWithPrefix(kScene, "light_CHAR_CC"); --character light objects
    Custom_RemovingAgentsWithPrefix(kScene, "lightrig"); --character light rigs
    Custom_RemovingAgentsWithPrefix(kScene, "fx_"); --particle effects
    Custom_RemovingAgentsWithPrefix(kScene, "fxg_"); --particle effects
    Custom_RemovingAgentsWithPrefix(kScene, "fxGroup_"); --particle effects groups
    Custom_RemovingAgentsWithPrefix(kScene, "light_bathroom_"); --bathroom lights
    Custom_RemovingAgentsWithPrefix(kScene, "light_point"); --scene point lights
    Custom_RemovingAgentsWithPrefix(kScene, "Crow"); --crow objects
    Custom_RemovingAgentsWithPrefix(kScene, "templateRig"); --template light rigs
    Custom_RemovingAgentsWithPrefix(kScene, "charLightComposer"); --light composers
    
    --get all agents within the scene
    local scene_agents = SceneGetAgents(kScene);

    --loop through all agents inside the scene
    for i, agent_object in pairs(scene_agents) do
        --get the name of the current agent item that we are on in the loop
        local agent_name = tostring(AgentGetName(agent_object));

        --if the name of the agent has an adv_ prefix then its a level mesh, so remove it
        --if the name of the agent has an obj_ prefix then it is an object (ocassionaly a mesh but sometimes its something else like look at targets), so remove it.
        if string.match(agent_name, "adv_") or string.match(agent_name, "obj_") then
            --make sure that the current agent that we are deleting is not a skybox, we will need it
            if not (agent_name == "obj_skydomeTruckStopExterior") then
                Custom_RemoveAgent(agent_name, kScene);
            end
        end
    end
    
    --remove other specific lights in the scene (there are a couple that we are keeping however because we need them for when relightng later);
    Custom_RemoveAgent("light_Amb_int", kScene);
    Custom_RemoveAgent("light_ambEnlighten", kScene);
    Custom_RemoveAgent("light_wall_highlight", kScene);
    Custom_RemoveAgent("light_ENV_P_stallLight01", kScene);
    Custom_RemoveAgent("light_ENV_P_stallLight02", kScene);
end

--creates the enviorment that the cutscene will take place in
Scene_CreateEnviorment = function()
    --create a group object that the enviorment meshes/objects will be parented to (so we can scroll the enviorment later to make it look like characters are walking through the scene).
    local tile_group = AgentCreate("env_tile", "group.prop", Vector(0,0,0), Vector(0,0,0), kScene, false, false);
    
    --instantiate our enviorment meshes/objects into the scene
    local tile1 = AgentCreate("env_tile1", "obj_riverShoreTrailTileLower_foliageBrushMeshesA.prop", Vector(0.000000,0.000000,24.000000), Vector(0,0,0), kScene, false, false);
    local tile2 = AgentCreate("env_tile2", "obj_riverShoreTrailTileLower_foliageBrushMeshesB.prop", Vector(0.119385,0.302429,0.314697), Vector(0,0,0), kScene, false, false);
    local tile3 = AgentCreate("env_tile3", "obj_riverShoreTrailTileLower_foliageBrushMeshesC.prop", Vector(12.000000,0.000000,-14.000000), Vector(0,0,0), kScene, false, false);
    local tile4 = AgentCreate("env_tile4", "obj_riverShoreTrailTileLower_foliageBrushMeshesD.prop", Vector(-0.357460,0.000000,48.000000), Vector(0,0,0), kScene, false, false);
    local tile5 = AgentCreate("env_tile5", "obj_riverShoreTrailTileLower_foliageBrushMeshesE.prop", Vector(-0.443689,0.000000,71.967827), Vector(0,0,0), kScene, false, false);
    local tile6 = AgentCreate("env_tile6", "obj_riverShoreTrailTileLower_foliageTreeMeshesA.prop", Vector(0.000000,0.000000,24.000000), Vector(0,0,0), kScene, false, false);
    local tile7 = AgentCreate("env_tile7", "obj_riverShoreTrailTileLower_foliageTreeMeshesB.prop", Vector(0.000000,0.000000,0.000000), Vector(0,0,0), kScene, false, false);
    local tile8 = AgentCreate("env_tile8", "obj_riverShoreTrailTileLower_foliageTreeMeshesC.prop", Vector(12.000000,0.000000,-14.000000), Vector(0,-90,0), kScene, false, false);
    local tile9 = AgentCreate("env_tile9", "obj_riverShoreTrailTileLower_foliageTreeMeshesD.prop", Vector(-0.357460,0.000000,48.000000), Vector(0,180,0), kScene, false, false);
    local tile10 = AgentCreate("env_tile10", "obj_riverShoreTrailTileLower_foliageTreeMeshesE.prop", Vector(-0.443689,0.000000,71.967827), Vector(0,0,0), kScene, false, false);
    local tile11 = AgentCreate("env_tile11", "obj_riverShoreTrailTileLowerA.prop", Vector(0.000000,0.000000,24.000000), Vector(0,0,0), kScene, false, false);
    local tile12 = AgentCreate("env_tile12", "obj_riverShoreTrailTileLowerB.prop", Vector(0.000000,0.000000,0.000000), Vector(0,0,0), kScene, false, false);
    local tile13 = AgentCreate("env_tile13", "obj_riverShoreTrailTileLowerC.prop", Vector(12.000000,0.000000,-14.000000), Vector(0,-90,0), kScene, false, false);
    local tile14 = AgentCreate("env_tile14", "obj_riverShoreTrailTileLowerD.prop", Vector(-0.357460,0.000000,48.000000), Vector(0,-180,0), kScene, false, false);
    local tile15 = AgentCreate("env_tile15", "obj_riverShoreTrailTileLowerE.prop", Vector(-0.443689,0.000000,71.967827), Vector(0,0,0), kScene, false, false);
    local tile16 = AgentCreate("env_tile16", "obj_riverShoreTrailTileLowerF.prop", Vector(0.000000,0.000000,71.967827), Vector(0,0,0), kScene, false, false);
    
    --attach it to the enviormnet group we created earlier
    AgentAttach(tile1, tile_group);
    AgentAttach(tile2, tile_group);
    AgentAttach(tile3, tile_group);
    AgentAttach(tile4, tile_group);
    AgentAttach(tile5, tile_group);
    AgentAttach(tile6, tile_group);
    AgentAttach(tile7, tile_group);
    AgentAttach(tile8, tile_group);
    AgentAttach(tile9, tile_group);
    AgentAttach(tile10, tile_group);
    AgentAttach(tile11, tile_group);
    AgentAttach(tile12, tile_group);
    AgentAttach(tile13, tile_group);
    AgentAttach(tile14, tile_group);
    AgentAttach(tile15, tile_group);
    AgentAttach(tile16, tile_group);
    
    --move the whole enviorment to a good starting point
    Custom_SetAgentWorldPosition("env_tile", Vector(1.35, 0, -34), kScene);
end

--adds additional grass meshes to make the enviorment/ground look more pleasing and not so flat/barren/low quality
Scene_AddProcedualGrass = function()
    --the amount of grass objects placed on the x and z axis (left and right, forward and back)
    local grassCountX = 40;
    local grassCountZ = 40;
    
    --the spacing between the grass objects
    local grassPlacementIncrement = 0.375;
    
    --the starting point for the grass placement
    local grassPositionStart = Vector(-(grassCountX / 2) * grassPlacementIncrement, 0.0, -(grassCountZ / 2) * grassPlacementIncrement);

    --the base name of a grass object
    local grassAgentName = "myObject_grass";

    --the prop (prefab) object file for the grass
    local grassPropFile = "obj_grassHIRiverCampWalk.prop"
    
    --and lets create a group object that we will attach all the spawned grass objects to, to make it easier to move the placement of the grass.
    local newGroup = AgentCreate("procedualGrassGroup", "group.prop", Vector(0,0,0), Vector(0,0,0), kScene, false, false);
    
    --loop x amount of times for the x axis
    for x = 1, grassCountX, 1 do 
        --calculate our x position right now
        local newXPos = grassPositionStart.x + (x * grassPlacementIncrement);
        
        --loop z amount of times for the z axis
        for z = 1, grassCountZ, 1 do 
            --build the agent name for the current new grass object
            local xIndexString = tostring(x);
            local zIndexString = tostring(z);
            local newAgentName = grassAgentName .. "_x_" .. xIndexString .. "_z_" .. zIndexString;

            --claculate the z position
            local newZPos = grassPositionStart.z + (z * grassPlacementIncrement);
            
            --randomize the Y rotation
            local newYRot = math.random(0, 180);
            
            --randomize the scale
            local scaleOffset = math.random(0, 0.6);
            
            --combine our calculated position/rotation/scale values
            local newPosition = Vector(newXPos, grassPositionStart.y, newZPos);
            local newRotation = Vector(0, newYRot, 0);
            local newScale = 0.75 + scaleOffset;

            --instantiate the new grass object using our position/rotation
            local newGrassAgent = AgentCreate(newAgentName, grassPropFile, newPosition, newRotation, kScene, false, false);
            
            --scale the grass
            Custom_AgentSetProperty(newAgentName, "Render Global Scale", newScale, kScene);
                
            --attach it to the main grass group
            AgentAttach(newGrassAgent, newGroup);
        end
    end
end

--adds additional particle effects to the scene to help make it more lively
Scene_AddAdditionalParticleEffects = function()
    --note: normally for modifying properties on an agent you would have the actual property name.
    --however after extracting all the strings we could get from the game exectuable, and also all of the lua scripts in the entire game
    --not every single property name was listed, and attempting to print all of the (keys) in the properties object throws out symbols instead.
    --so painfully, PAINFULLY through trial and error I found the right symbol keys I was looking for, and we basically set the given property like normal using the symbol.
    --note for telltale dev: yes I tried many times to use your dang SymbolToString on those property keys but it doesn't actually do anything!!!!!

    --create a dust particle effect that spawns dust particles where the camera looks (this effect is borrowed from S4)
    local fxDust1 = AgentCreate("myFX_dust1", "fx_camDustMotes.prop", Vector(0,0,0), Vector(0,0,0), kScene, false, false);
    local fxDust1_props = AgentGetRuntimeProperties(fxDust1); --get the properties of the particle system, since we want to modify it.
    Custom_SetPropertyBySymbol(fxDust1_props, "689599953923669477", true); --enable emitter
    Custom_SetPropertyBySymbol(fxDust1_props, "4180975590232535326", 0.011); --particle size
    Custom_SetPropertyBySymbol(fxDust1_props, "2137029241144994061", 0.5); --particle count
    Custom_SetPropertyBySymbol(fxDust1_props, "907461805036530086", 0.55); --particle speed
    Custom_SetPropertyBySymbol(fxDust1_props, "459837671211266514", 0.2); --rain random size
    Custom_SetPropertyBySymbol(fxDust1_props, "2293817456966484758", 2.0); --rain diffuse intensity
    
    --create a leaves particle effect that spawns leaves particles where the camera looks (this effect is borrowed from S4)
    local fxLeaves1 = AgentCreate("myFX_leaves1", "fx_camLeaves.prop", Vector(0,0,0), Vector(0,0,0), kScene, false, false);
    local fxLeaves1_props = AgentGetRuntimeProperties(fxLeaves1); --get the properties of the particle system, since we want to modify it.
    Custom_SetPropertyBySymbol(fxLeaves1_props, "689599953923669477", true); --enable emitter
    Custom_SetPropertyBySymbol(fxLeaves1_props, "4180975590232535326", 0.121); --particle size
    Custom_SetPropertyBySymbol(fxLeaves1_props, "2137029241144994061", 27.0); --particle count
    Custom_SetPropertyBySymbol(fxLeaves1_props, "907461805036530086", 1.35); --particle speed
    Custom_SetPropertyBySymbol(fxLeaves1_props, "459837671211266514", 0.5); --rain random size
    Custom_SetPropertyBySymbol(fxLeaves1_props, "2293817456966484758", 1.0); --rain diffuse intensity
end

--relights the new enviorment so that it actually looks nice and is presentable
Scene_RelightScene = function()
    --remeber that we didn't delete every single light in the scene?
    --well now we need them because when creating new lights, by default their lighting groups (which basically mean what objects in the scene the lights will actually affect)
    --are not assigned (or at the very least, are not set to a value that affects the main lighting group of all objects in the scene)
    --and unfortunately the actual value is some kind of userdata object, so to get around that, we use an existing light as our crutch
    --and grab the actual group values/data from that object so that we can actually properly create our own lights that actually affect the scene
    
    --find the original sunlight in the scene
    local envlight  = AgentFindInScene("light_DIR", kScene);
    local envlight_props = AgentGetRuntimeProperties(envlight);
    local envlight_groupEnabled = PropertyGet(envlight_props, "EnvLight - Enabled Group");
    local envlight_groups = PropertyGet(envlight_props, "EnvLight - Groups");
    
    --find the original sky light in the scene (note telltale dev, why do you use a light source for the skybox when you could've just had the sky be an (emmissive/unlit) shader?)
    local skyEnvlight  = AgentFindInScene("light_amb_sky", kScene);
    local skyEnvlight_props = AgentGetRuntimeProperties(skyEnvlight);
    local skyEnvlight_groupEnabled = PropertyGet(skyEnvlight_props, "EnvLight - Enabled Group");
    local skyEnvlight_groups = PropertyGet(skyEnvlight_props, "EnvLight - Groups");
    
    --the main prop (like a prefab) file for a generic light
    local envlight_prop = "module_env_light.prop";
    
    --calculate some new colors
    local sunColor     = RGBColor(255, 230, 198, 255);
    local ambientColor = RGBColor(108, 150, 225, 255);
    local skyColor     = RGBColor(0, 80, 255, 255);
    local fogColor     = Desaturate_RGBColor(skyColor, 0.7);
    
    --adjust the colors a bit (yes there is a lot of tweaks... would be easier if we had a level editor... but we dont yet)
    skyColor = Desaturate_RGBColor(skyColor, 0.2);
    fogColor = Multiplier_RGBColor(fogColor, 2.8);
    fogColor = Desaturate_RGBColor(fogColor, 0.45);
    sunColor = Desaturate_RGBColor(sunColor, 0.15);
    skyColor = Desaturate_RGBColor(skyColor, 0.2);
    sunColor = Desaturate_RGBColor(sunColor, 0.15);
    ambientColor = Desaturate_RGBColor(ambientColor, 0.35);
    ambientColor = Multiplier_RGBColor(ambientColor, 1.8);
    
    --set the alpha value of the fog color to be fully opaque
    local finalFogColor = Color(fogColor.r, fogColor.g, fogColor.b, 1.0);
    
    --change the properties of the fog
    Custom_AgentSetProperty("module_environment", "Env - Fog Color", finalFogColor, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Fog Start Distance", 3.25, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Fog Height", 2.85, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Fog Density", 0.525, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Fog Max Opacity", 1, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Fog Enabled", true, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Enabled", true, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Enabled on High", true, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Enabled on Medium", true, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Enabled on Low", true, kScene);
    Custom_AgentSetProperty("module_environment", "Env - Priority", 1000, kScene);
    
    --create our sunlight and set the properties accordingly
    local myLight_Sun = AgentCreate("myLight_Sun", envlight_prop, Vector(0,0,0), Vector(40, -175), kScene, false, false);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Type", 2, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Intensity", 12, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Enlighten Intensity", 0.0, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Radius", 1, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Distance Falloff", 1, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Spot Angle Inner", 5, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Spot Angle Outer", 45, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Color", sunColor, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Enabled Group", envlight_groupEnabled, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Groups", envlight_groups, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Shadow Type", 2, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Wrap", 0.0, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - Shadow Quality", 3, kScene);
    Custom_AgentSetProperty("myLight_Sun", "EnvLight - HBAO Participation Type", 1, kScene);

    --ambient light foliage
    Custom_AgentSetProperty("light_Amb_foliage", "EnvLight - Intensity", 1, kScene);
    Custom_AgentSetProperty("light_Amb_foliage", "EnvLight - Color", sunColor, kScene);
    
    --sky light/color
    Custom_AgentSetProperty("light_amb_sky", "EnvLight - Intensity", 4, kScene);
    Custom_AgentSetProperty("light_amb_sky", "EnvLight - Color", skyColor, kScene);
    
    --create a spotlight that emulates the sundisk in the sky
    local myLight_SkySun = AgentCreate("myLight_SkySun", envlight_prop, Vector(0,0,0), Vector(-54, 5, 0), kScene, false, false);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Type", 1, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Intensity", 55, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Enlighten Intensity", 0.0, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Radius", 2555, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Distance Falloff", 1, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Spot Angle Inner", 5, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Spot Angle Outer", 25, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Color", sunColor, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Enabled Group", skyEnvlight_groupEnabled, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Groups", skyEnvlight_groups, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Shadow Type", 0, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Wrap", 0.0, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - Shadow Quality", 0, kScene);
    Custom_AgentSetProperty("myLight_SkySun", "EnvLight - HBAO Participation Type", 1, kScene);

    --remove original sun since we created our own and only needed it for getting the correct lighting groups.
    Custom_RemoveAgent("light_DIR", kScene);

    --modify the scene post processing
    Custom_AgentSetProperty(agent_name_scene, "FX anti-aliasing", true, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Sharp Shadows Enabled", true, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Ambient Occlusion Enabled", true, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Intensity", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap White Point", 8.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Black Point", 0.005, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Filmic Toe Intensity", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Filmic Shoulder Intensity", 0.75, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Type", 2, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Filmic Pivot", 0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Tonemap Filmic Shoulder Intensity", 0.8, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Enabled", true, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Intensity", 1.5, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Radius", 0.75, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Max Radius Percent", 0.5, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Max Distance", 35.5, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Distance Falloff", 0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "HBAO Hemisphere Bias", -0.2, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Bloom Threshold", -0.35, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Bloom Intensity", 0.10, kScene);
    Custom_AgentSetProperty(agent_name_scene, "Ambient Color", ambientColor, kScene);
    Custom_AgentSetProperty(agent_name_scene, "Shadow Color", RGBColor(0, 0, 0, 0), kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Vignette Tint Enabled", true, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Vignette Tint", RGBColor(0, 0, 0, 255), kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Vignette Falloff", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Vignette Center", 0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Vignette Corners", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Saturation", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Reflection Intensity Shadow", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Reflection Intensity", 1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Shadow Max Distance", 20.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Dynamic Shadow Max Distance", 25.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Shadow Position Offset Bias", 0.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Shadow Depth Bias", -1.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Shadow Auto Depth Bounds", false, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Shadow Light Bleed Reduction", 0.8, kScene);
    Custom_AgentSetProperty(agent_name_scene, "LightEnv Shadow Moment Bias", 0.0, kScene);
    Custom_AgentSetProperty(agent_name_scene, "Specular Multiplier Enabled", true, kScene);
    Custom_AgentSetProperty(agent_name_scene, "Specular Color Multiplier", 55, kScene);
    Custom_AgentSetProperty(agent_name_scene, "Specular Intensity Multiplier", 1, kScene);
    Custom_AgentSetProperty(agent_name_scene, "Specular Exponent Multiplier", 1, kScene);
    Custom_AgentSetProperty(agent_name_scene, "FX Noise Scale", 1, kScene);
end

--|||||||||||||||||||||||||||||||||||||||||||||| CUTSCENE SETUP ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| CUTSCENE SETUP ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| CUTSCENE SETUP ||||||||||||||||||||||||||||||||||||||||||||||
--now starting to get into the actual juice...
--this section contains a bunch of setup functions that are basically here to get things ready for use when we need them during the actual cutscene itself.

--creates a camera that will be used for the cutscene (yes usually you create multiple but I haven't wrapped my head around how your camera layer stack system works telltale!)
Cutscene_CreateCutsceneCamera = function()
    --generic camera prop (prefab) asset
    local cam_prop = "module_camera.prop";
    
    --set a default position/rotation for the camera. (in theory this doesn't matter, but if the script somehow breaks during update the camera will stay in this position).
    local newPosition = Vector(0,15,0);
    local newRotation = Vector(90,0,0);
    
    --instaniate our cutscene camera object
    local cameraAgent = AgentCreate(agent_name_cutsceneCamera, cam_prop, newPosition, newRotation, kScene, false, false);
    
    --set the clipping planes of the camera (in plain english, how close the camera can see objects, and how far the camera can see)
    --if the near is set too high we start loosing objects in the foreground.
    --if the far is set to low we will only see part or no skybox at all
    Custom_AgentSetProperty(agent_name_cutsceneCamera, "Clip Plane - Far", 2500, kScene);
    Custom_AgentSetProperty(agent_name_cutsceneCamera, "Clip Plane - Near", 0.05, kScene);

    --bulk remove the original cameras that were in the scene
    Custom_RemovingAgentsWithPrefix(kScene, "cam_");

    --push our new current camera to the scene camera layer stack (since we basically removed all of the original cameras just the line before this)
    CameraPush(agent_name_cutsceneCamera);
end

--create our soundtrack for the cutscene
Cutscene_CreateSoundtrack = function()
    --play the soundtrack file
    local controller_sound_soundtrack = SoundPlay("soundtrack3.wav");
    
    --set it to loop
    ControllerSetLooping(controller_sound_soundtrack, true)
end

--sets up our cutscene objects
Cutscene_SetupCutsceneContent = function()
    --find the character objects in the scene, we are going to need them during the cutscene so we need to get them (you could also get them during update but that wouldn't be performance friendly)
    agent_clementine = AgentFindInScene("Clementine", kScene);
    agent_christa = AgentFindInScene("Christa", kScene);
    agent_omid = AgentFindInScene("Omid", kScene);

    ----------------------------------------------------------------
    --set up animations
    --note: there is a lot of commented out lines here, I'm purposefully keeping them in to show that you have to find the right animation to your liking.
    --but also there are tons of other animations and stuff that you can play
    
    --play a walk animation on our characters
    controller_animation_clementineWalk = PlayAnimation(agent_clementine, "sk56_clementine_walk.anm");
    --controller_animation_clementineWalk = PlayAnimation(agent_clementine, "sk54_wd200GM_walkHoldGun.anm");
    --controller_animation_clementineWalk = PlayAnimation(agent_clementine, "sk56_action_clementineGuiltRidden.anm");
    controller_animation_christaWalk = PlayAnimation(agent_christa, "sk56_clementine200_walk.anm");
    controller_animation_omidWalk = PlayAnimation(agent_omid, "sk54_lee_walk.anm");
    
    --play some eye dart animations on clem (so her eyeballs are not completely static)
    --controller_animation_clementineEyesDarting = PlayAnimation(agent_clementine, "clementine_face_eyesDartsA_add.anm");
    controller_animation_clementineEyesDarting = PlayAnimation(agent_clementine, "clementine_face_eyesDartsB_add.anm");
    --controller_animation_clementineEyesDarting = PlayAnimation(agent_clementine, "clementine_face_eyesDartsC_add.anm");

    --controller_animation_clementineEyesLookUp = PlayAnimation(agent_clementine, "clementine_face_blink_add.anm");
    --controller_animation_clementineHeadLookUp = PlayAnimation(agent_clementine, "clementine_headGesture_lookUp_add.anm");
    --controller_animation_clementineHeadLookDown = PlayAnimation(agent_clementine, "clementine_headGesture_lookDown_add.anm");

    --set clems facial expression (for these chores they are nice in that they only need to be called once and they basically (stick))
    controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toSadA.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toSadB.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toSadC.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toSadD.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toCryingA.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toFearA.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toFearB.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toHappyA.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toHappyB.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toNormalA.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toNormalB.chore");
    --controller_chore_clementineEmotion = ChorePlayOnAgent(agent_clementine, "sk56_clementine_toThinkingA.chore");

    --set some of our animations to loop
    ControllerSetLooping(controller_animation_clementineWalk, true);
    ControllerSetLooping(controller_animation_christaWalk, true);
    ControllerSetLooping(controller_animation_omidWalk, true);
    --ControllerSetLooping(controller_animation_clementineBlink, false);
    ControllerSetLooping(controller_animation_clementineEyesDarting, true);

    --set inital character positions
    --note: important to say that once we play the walking animations the engine likes to move them to world origin since most animations end up actually moving the root object.
    --so we need to play the animations first and then move the characters to where we need them.
    --they will move from their spots but we will fix this later when we lock their position in place.
    Custom_SetAgentWorldPosition("Clementine", Vector(0, 0, 0), kScene);
    Custom_SetAgentWorldPosition("Christa", Vector(-0.75, 0, 3), kScene);
    Custom_SetAgentWorldPosition("Omid", Vector(0.75, 0, 3), kScene);
end

--|||||||||||||||||||||||||||||||||||||||||||||| CUTSCENE UPDATE ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| CUTSCENE UPDATE ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| CUTSCENE UPDATE ||||||||||||||||||||||||||||||||||||||||||||||

--proceudal handheld animation
--worth noting that while it does work, its definetly not perfect and jumps around more than I'd like.
--if the values are kept low then it works fine
Cutscene_UpdateHandheldCameraValues = function()
    --update the tick rate by 1
    camera_handheld_tick = camera_handheld_tick + 1;
    
    --if we reached the max update tick rate, time to calculate a new shake position/rotation (this only gets called once during update until we hit the max update level again)
    if (camera_handheld_tick > camera_handheld_updateLevel) then
        --calculate a random rotation for the shake
        local newRotShakeX = math.random(-camera_handheld_rot_strength, camera_handheld_rot_strength);
        local newRotShakeY = math.random(-camera_handheld_rot_strength, camera_handheld_rot_strength);
        local newRotShakeZ = math.random(-camera_handheld_rot_strength, camera_handheld_rot_strength);
        --local newRotShakeZ = 0;
        
        --calculate a random position for the shake
        local newPosShakeX = math.random(-camera_handheld_pos_strength, camera_handheld_pos_strength);
        local newPosShakeY = math.random(-camera_handheld_pos_strength, camera_handheld_pos_strength);
        local newPosShakeZ = math.random(-camera_handheld_pos_strength, camera_handheld_pos_strength);
    
        --combine the corresponding values into vectors and assign them to the desired rot/pos
        camera_handheld_desiredRot = Vector(newRotShakeX, newRotShakeY, newRotShakeZ);
        camera_handheld_desiredPos = Vector(newPosShakeX, newPosShakeY, newPosShakeZ);
        
        --reset the tick counter
        camera_handheld_tick = 0;
    end
    
    --meanwhile, if we haven't reached our max update tick rate
    --lets use this to our advantage and start gradually matching the current position/rotation of the shake to the desired over time.
    
    --linear interpolation
    --camera_handheld_currentRot = Custom_VectorLerp(camera_handheld_currentRot, camera_handheld_desiredRot, GetFrameTime() * camera_handheld_rot_lerpFactor);
    --camera_handheld_currentPos = Custom_VectorLerp(camera_handheld_currentPos, camera_handheld_desiredPos, GetFrameTime() * camera_handheld_pos_lerpFactor);
    
    --smoothstep interpolation
    camera_handheld_currentRot = Custom_VectorSmoothstep(camera_handheld_currentRot, camera_handheld_desiredRot, GetFrameTime() * camera_handheld_rot_lerpFactor);
    camera_handheld_currentPos = Custom_VectorSmoothstep(camera_handheld_currentPos, camera_handheld_desiredPos, GetFrameTime() * camera_handheld_pos_lerpFactor);
end

--moves the enviorment
--note: the reason we move the enviorment and not the characters is due to floating point precison...
--in english: since we keep moving infinitely basically, the larger the distances are and we will eventually start to see some serious glitches
--so to avoid that, we can instead keep everything in place but move the enviorment, and it will actually look like the characters are walking through the enviorment
--and the camera is moving. its all movie magic!
--note to self: need to find perhaps a better way to reset the enviormnet position so we don't see the single frame in which is jumps back
Cutscene_UpdateScrollEnviorment = function()
    --increment the enviorment z position by the scroll speed.
    enviorment_scroll_positionZ = enviorment_scroll_positionZ + enviorment_scroll_speed;
    
    --if the z position is beyond the max position that we set, move the enviorment back to the starting point
    if (enviorment_scroll_positionZ > enviorment_scroll_maxPositionZ) then
        enviorment_scroll_positionZ = 0;
    end
    
    --if we are on these specific shot number, then reset the enviorment position (otherwise mid shot the enviorment will reset back and it will ruin the illusion)
    --and also make sure that when we are on the new shot that we are just starting on it (sequence_currentTimer == 0) so this gets called only once
    if (sequence_currentShotIndex == 3) and (sequence_currentTimer <= 1) then --clem pov
        enviorment_scroll_positionZ = 0;
    end
    
    if (sequence_currentShotIndex == 5) and (sequence_currentTimer <= 1) then --birds eye view 
        enviorment_scroll_positionZ = 0;
    end
    
    if (sequence_currentShotIndex == 6) and (sequence_currentTimer <= 1) then --wide shot
        enviorment_scroll_positionZ = 0;
    end

    --create our new positions for both the enviorment and the grass that we created earlier
    local newTilePosition = Vector(1.35, 0, -34 - enviorment_scroll_positionZ);
    local newGrassPosition = Vector(0, -0.05, 6 - enviorment_scroll_positionZ);

    --set the positions on our enviorment groups to the new calculated positions
    Custom_SetAgentWorldPosition("env_tile", newTilePosition, kScene);
    Custom_SetAgentWorldPosition("procedualGrassGroup", newGrassPosition, kScene);
end

--this function is important and is responsible for setting the current shot that we are on
Cutscene_UpdateSequence = function()

    --while our shot index is less than the total amount of clips in the sequence (meaning that we are not on the last clip, and if we are then there are no more clips so this if block won't be exectuted)
    if(sequence_currentShotIndex <= sequence_maxClips) then
    
        --increment our time
        sequence_currentTimer = sequence_currentTimer + 1;
    
        --get the current clip data
        
        --calculate the variable name according to the shot index that we are on
        local sequenceClipVariableName = "clip" .. tostring(sequence_currentShotIndex);
        
        --get the clip from the sequence
        currentSequence_clip = sequence_clips[sequenceClipVariableName];

        --get the clip data we need
        currentSequence_clipInfo_duration = currentSequence_clip["shotDuration"];
        currentSequence_clipInfo_angleIndex = currentSequence_clip["angleIndex"];

        --calculate the variable name for the angle that the current shot we are on referneces
        local angleVariableName = "angle" .. tostring(currentSequence_clipInfo_angleIndex);
        
        --get the angle object that the clip references
        currentSequence_angle = sequence_cameraAngles[angleVariableName];

        --if our timer is past the duration of the current shot, move on to the next shot
        if (sequence_currentTimer > currentSequence_clipInfo_duration) then
            --increment the shot index since we reached the end of the current clip that we are on
            sequence_currentShotIndex = sequence_currentShotIndex + 1;
            sequence_currentTimer = 0; --reset the time for the next clip
        end

        --get the angle information
        local angleInfo_fov = currentSequence_angle["FieldOfView"];
        local angleInfo_pos = currentSequence_angle["CameraPosition"];
        local angleInfo_rot = currentSequence_angle["CameraRotation"];
        
        --add our handheld camera shake to the angle position/rotation
        angleInfo_rot = angleInfo_rot + camera_handheld_currentRot;
        angleInfo_pos = angleInfo_pos + camera_handheld_currentPos;
        
        --apply the data to the camera
        Custom_AgentSetProperty(agent_name_cutsceneCamera, "Field Of View", angleInfo_fov, kScene);
        Custom_SetAgentWorldPosition(agent_name_cutsceneCamera, angleInfo_pos, kScene);
        Custom_SetAgentWorldRotation(agent_name_cutsceneCamera, angleInfo_rot, kScene);
    end
    
end

--this locks the characters in place for every frame
--the reason being that 99% of telltale animations move the root object of the player
--and when the animation reaches the end of its clip it rests back to zero.
--this is a problem when looping because the characters will constantly jump back, move forward, and then jump back
--so we lock them in place to avoid that happening and ruining the illusion that we are creating.
Cutscene_UpdateLockCharacterPositions = function()
    --get the world position of our characters
    local clementineWorldPos = AgentGetWorldPos(agent_clementine);
    local christaWorldPos = AgentGetWorldPos(agent_christa);
    local omidWorldPos = AgentGetWorldPos(agent_omid);

    --scale these vectors according to the animation velocity that the root object is being animated to move at
    local clementineLockedPos = VectorScale(Vector(0,0,1.0), AgentGetForwardAnimVelocity(agent_clementine));
    local christaLockedPos = VectorScale(Vector(0,0,1.0), AgentGetForwardAnimVelocity(agent_christa));
    local omidLockedPos = VectorScale(Vector(0,0,1.0), AgentGetForwardAnimVelocity(agent_omid));

    --offset positions that will be applied after they are locked in
    local clementineOffsetPos = Vector(0, 0, 0);
    local christaOffsetPos = Vector(-0.45, 0, 2.85);
    local omidOffsetPos = Vector(0.65, 0, 3);
    
    --combine the locked position with our offsets
    local finalClementinePos = VectorAdd(clementineLockedPos, clementineOffsetPos);
    local finalChristaPos = VectorAdd(christaLockedPos, christaOffsetPos);
    local finalOmidPos = VectorAdd(omidLockedPos, omidOffsetPos);
    
    --set these final position values on our characters
    Custom_SetAgentPosition("Clementine", finalClementinePos, kScene);
    Custom_SetAgentPosition("Christa", finalChristaPos, kScene);
    Custom_SetAgentPosition("Omid", finalOmidPos, kScene);
end

--this plays blinking animations for clementine
Cutscene_UpdateClementineBlinks = function()
    --increment the time value for our blinks
    tick_animation_clementine_blink = tick_animation_clementine_blink + 1;

    --when we waiting long enough for a blink according to the max tick, its time to blink
    if(tick_animation_clementine_blink > maxTick_animation_clementine_blink) then
        --play the animation (additive, meaning that the animation gets [added] ontop of any other animations we play on the character)
        controller_animation_clementineBlink = PlayAnimation(agent_clementine, "clementine_face_blink_add.anm");
        
        --don't loop it
        ControllerSetLooping(controller_animation_clementineBlink, false);
        
        --reset the time value so we can blink again later
        tick_animation_clementine_blink = 0.0;
    end
end

--this function is responsible for character (acting) within the cutscene.
--its not coded in a perfect way admittedly but the way it works basically is that
--for each shot, when we reach a very specific time value, we play an animation so that way the animation basically plays once.
--we will have issues if we are not careful because this function runs every single frame, so we need to make sure that when we play animations it only happens effectively once
--and doesn't cause issues where animations keep adding up and contorting the character, or they will effectively (freeze) in play because they keep resetting the clip to play a new animation
Cutscene_UpdateCharacterActing = function()
    if (sequence_currentShotIndex == 1) then --first sequence shot (up at trees)

        --have clem look up
        if (sequence_currentTimer > 10) then
            controller_animation_clementineHeadLookUp = PlayAnimation(agent_clementine, "wd200GM_headGesture_lookUp_add.anm");
        end
        
        --force clem to look up
        if (sequence_currentTimer > 17) then
            ControllerSetTimeScale(controller_animation_clementineHeadLookUp, 0.0);
        end
        
    elseif (sequence_currentShotIndex == 2) then --meduim shot

        --make have a sad expression
        if (sequence_currentTimer == 1) then
            controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toSadA", agent_clementine, nil, nil);
        end
        
        --pause her eye movement so she looks forward steadily for a bit
        if (sequence_currentTimer == 80) then
            ControllerPause(controller_animation_clementineEyesDarting)
            ControllerSetTimeScale(controller_animation_clementineHeadLookUp, 1.0);
        end
        
        --play the eye darting again
        if (sequence_currentTimer == 140) then
            ControllerPlay(controller_animation_clementineEyesDarting)
        end
        
        --have her scratch her head
        if (sequence_currentTimer == 180) then
            PlayAnimation(agent_clementine, "sk54_wD200GMDefaultB_scratchHead_add.anm");
        end
        
        --have her expression change to normal as she looks forward after finishing scratching her head
        if (sequence_currentTimer == 230) then
            controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toNormalA", agent_clementine, nil, nil);
            ControllerPause(controller_animation_clementineEyesDarting)
        end
        
        --change her expression to sad
        if (sequence_currentTimer == 350) then
            controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toSadA", agent_clementine, nil, nil);
        end
        
    elseif (sequence_currentShotIndex == 3) then --clem pov with christa and omid
    
        --have omid turn and look back at clem briefly
        if (sequence_currentTimer == 50) then
            PlayAnimation(agent_omid, "sk55_wd200GM_lookBehindRight_add.anm");
        end 
        
        --have christa turn her head back a bit implying shes checking omids rection to clem behind them
        if (sequence_currentTimer == 80) then
            PlayAnimation(agent_christa, "wd200GM_headGesture_lookLeft_add.anm");
        end 

    elseif (sequence_currentShotIndex == 5) then --closeup shot

        --change clems expression to sad
        if (sequence_currentTimer == 1) then
            controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toSadA", agent_clementine, nil, nil);
            ControllerPlay(controller_animation_clementineEyesDarting)
        end
        
        --pause her eye darting and have her look down for a bit
        if (sequence_currentTimer == 80) then
            ControllerPause(controller_animation_clementineEyesDarting)
            controller_animation_clementineHeadLookDown = PlayAnimation(agent_clementine, "wd200GM_headGesture_lookDown_add.anm");
        end
        
        --when she brings her head back up, change her expression to a normal one
        if (sequence_currentTimer == 120) then
            controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toNormalA", agent_clementine, nil, nil);
        end
        
        --then after some time contemplating, change her expression to a happy one
        if (sequence_currentTimer == 230) then
            controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toHappyA", agent_clementine, nil, nil);
        end
        
    end
end

--when the cutscene reaches the end of the sequence, execute the finish cutscene level script
Cutscene_OnCutsceneFinish = function()
    
    --if the current shot number we are on is beyond the maximum amount of clips in the sequence (means that we are done)
    if (sequence_currentShotIndex > sequence_maxClips) then
        --exectue this finish level script
        dofile("FinishCutsceneLevel.lua");
    end
    
end

--main level script, this function gets called when the scene loads
--its important we call everything here and set up everything so our work doesn't go to waste
FirstCutsceneLevel = function()
    ----------------------------------------------------------------
    --scene setup (call all of our scene setup functions)
    Scene_CleanUpOriginalScene(); --clean up and remove everything we don't need from the original scene
    Scene_CreateEnviorment(); --create our own new cutscene enviorment
    Scene_AddProcedualGrass(); --add additional grass/detail to the new cutscene enviorment
    Scene_AddAdditionalParticleEffects(); --add additional particle effects to the new cutscene enviorment to make it more lively
    Scene_RelightScene(); --after creating our enviorment, we will now adjust/create the lighting for the scene.

    --cutscene setup (start calling our cutscene setup functions)
    Cutscene_CreateSoundtrack(); --start playing our custom soundtrack and have it loop

    --if we are not in freecam mode, go ahead and create the cutscene camera
    if (MODE_FREECAM == false) then
        Cutscene_CreateCutsceneCamera(); --create our cutscene camera in the scene
    end

    Cutscene_SetupCutsceneContent();
    HideCusorInGame(); --hide the cursor during the cutscene
    
    ----------------------------------------------------------------
    --cutscene update functions (these run every single frame, and this is where the magic happens)
    
    --add all of our update functions, and these will run for every single frame that is rendered
    Callback_OnPostUpdate:Add(Cutscene_UpdateSequence);
    Callback_OnPostUpdate:Add(Cutscene_UpdateHandheldCameraValues);
    Callback_OnPostUpdate:Add(Cutscene_UpdateScrollEnviorment);
    Callback_OnPostUpdate:Add(Cutscene_UpdateLockCharacterPositions);
    Callback_OnPostUpdate:Add(Cutscene_UpdateClementineBlinks);
    Callback_OnPostUpdate:Add(Cutscene_UpdateCharacterActing);
    Callback_OnPostUpdate:Add(Cutscene_OnCutsceneFinish);
    
    --add depth of field
    Callback_OnPostUpdate:Add(PerformAutofocusDOF);
    
    ----------------------------------------------------------------
    --if freecam mode is not enabled, then don't continue on
    if (MODE_FREECAM == false) then
        do return end --the function will not continue past this point if freecam is disabled (we don't want our development tools interferring with the cutscene)
    end

    ----------------------------------------------------------------
    --CUTSCENE DEVELOPMENT
    --if freecam is enabled, these functions are run
    
    --commented out on purpose, but when the scene starts this prints all of the scene agents to a text file that is saved in the game directory.
    --Custom_PrintSceneListToTXT(kScene, "truckStopBathroom201.txt");

    --remove the DOF because it interferes with UI
    Callback_OnPostUpdate:Remove(PerformAutofocusDOF);
       
    --create our free camera and our cutscene dev tools
    Custom_CutsceneDev_CreateFreeCamera();
    Custom_CutsceneDev_InitalizeCutsceneTools();

    --add these development update functions, and have them run every frame
    Callback_OnPostUpdate:Add(Custom_CutsceneDev_UpdateFreeCamera);
    Callback_OnPostUpdate:Add(Custom_CutsceneDev_UpdateCutsceneTools_Input);
    Callback_OnPostUpdate:Add(Custom_CutsceneDev_UpdateCutsceneTools_Main);
end

--open the scene with this script
SceneOpen(kScene, kScript)
