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
For sequencing I have a basic psudeo timeline objects. 
You will see those in the script and they go by the names of [sequence_clips] and [sequence_cameraAngles].
There are a few more but to elaborate on but I'll go over how this sequencing system works. 
Also worth noting that we don't have a chore editor yet, so have to make do with lua scripting at the moment.

1. For the sequencing we have a time sequence value variable that gets incremented 1 every single frame. - (could I have actually grabbed the game time? yes, that does exist however I did it this way first and it worked... in a newer version of this psudeo system I will definetly try to attempt to use it)
2. This time sequence variable is [sequence_currentTimer] and it basically acts as our psudeo playhead. - (but not quite with the way I coded it and you'll see later)
3. [sequence_clips] contains an array of clip objects, these will be accessed sequentially as the scene goes on.
4. [sequence_cameraAngles] contains an array of camera angle objects.
5. The camera angles are referenced by the sequence clips by the variable [angleIndex] inside the clip object. - (normally I geuss you would include this camera data inside the clip object, however I kept it seperate because we often in cinema cut back to shots thta have these angles)
6. For the current clip that we are on, the object also has a [shotDuration] field which obviously tells us how long the shot will last.
7. When the playhead value [sequence_currentTimer] reaches the end of the current clip [shotDuration].
8. we then move on to the next shot in the sequence by incrementing [sequence_currentShotIndex] and by also resetting [sequence_currentTimer] back to zero. - (Yes, you could change it so [sequence_currentTimer] keeps counting as the game goes on, or again also use the actual game time value which we have access to, but this is the way I did it first :P but also didn't really want to deal with very long numbers)
9. when we do that, now our current clip is the next shot in the sequence, and this cycle repeats until the sequence effectively ends.
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
require("FCM_Scene_PrepareLevel.lua");

--|||||||||||||||||||||||||||||||||||||||||||||| SCRIPT VARIABLES ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| SCRIPT VARIABLES ||||||||||||||||||||||||||||||||||||||||||||||
--|||||||||||||||||||||||||||||||||||||||||||||| SCRIPT VARIABLES ||||||||||||||||||||||||||||||||||||||||||||||

--main level variables
local kScript = "FirstCutsceneLevel"; --dont touch (the name of this script and also the name of the level function at the bottom of the script, which will be called as soon as this scene opens)
local kScene = "adv_truckStopBathroom"; --dont touch (the name of the scene asset file)
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
local agent_name_cutsceneCameraParent = "myCutsceneCameraParent"; --cutscene camera parent agent name
local agent_clementine = nil; --dont touch (reference to clementine agent object in the scene, its nil now but will be assigned later)
local agent_christa = nil; --dont touch (reference to christa agent object in the scene, its nil now but will be assigned later)
local agent_omid = nil; --dont touch (reference to omid agent object in the scene, its nil now but will be assigned later)

--controller variables (these just store a reference to the animations/chores that are playing during the cutscene)
local controller_animation_clementineWalk = nil; --dont touch
local controller_animation_christaWalk = nil; --dont touch
local controller_animation_omidWalk = nil; --dont touch

--update tick variables for clementine additive blinking animation
local maxTick_animation_clementine_blink = 2.0; --the (duration) that clem has her eyes open before she blinks
local tick_animation_clementine_blink = 0.0; --dont touch (main tick blink variable, this gets incremented 1 every frame and resets when we reach the maxtick for blink)

--enviorment scrolling variables
local enviorment_scroll_positionZ = 0; --dont touch (the main z position that gets incremented every frame by the scroll speed)
local enviorment_scroll_speed = 0.65; --the speed at which the enviorment will scroll/move

--proceudal handheld animation variables
local camera_handheld_currentRot = Vector(0, 0, 0);
local camera_handheld_currentPos = Vector(0, 0, 0);
local cutscene_handheld_x_level1 = 0;
local cutscene_handheld_x_level2 = 0;
local cutscene_handheld_x_level3 = 0;
local cutscene_handheld_x_level4 = 0;
local cutscene_handheld_y_level1 = 0;
local cutscene_handheld_y_level2 = 0;
local cutscene_handheld_y_level3 = 0;
local cutscene_handheld_y_level4 = 0;
local cutscene_handheld_z_level1 = 0;
local cutscene_handheld_z_level2 = 0;
local cutscene_handheld_z_level3 = 0;
local cutscene_handheld_z_level4 = 0;

--current sequence variables
local currentSequence_clip = nil; --dont touch (the current clip object that we are on)
local currentSequence_clipInfo_duration = nil; --dont touch (the duration of the shot)
local currentSequence_clipInfo_angleIndex = nil; --dont touch (the chosen angle item index for the shot)
local currentSequence_angle = nil; --dont touch (the actual angle object the clip references)

--main sequence variables
local sequence_maxClips = 6; --the maximum amount of clips in the sequence
local sequence_currentShotIndex = 1; --dont touch (the current shot index that are are on)
local sequence_currentTimer = 0; --dont touch (update tick that gets incremented 1 every frame and resets when we reach the end of the current shot duration)
local sequence_timePrecision = 1; --0 = 1 second, 1 = 0.1 or 1/10th of a second (NOTE: CHANGING THIS LATER WILL AFFECT YOUR EXISTING TIMED STUFF)
local sequence_prevEngineTotalTime = 0; --dont touch
local sequence_prevEngineFrameNumberDifference = 0; --dont touch

--this variable is an array that will contain our (clips)
local sequence_clips = 
{
    clip1 = 
    {
        angleIndex = 1,
        shotDuration = 90
    },
    clip2 = 
    {
        angleIndex = 2,
        shotDuration = 75
    },
    clip3 = 
    {
        angleIndex = 4,
        shotDuration = 60
    },
    clip4 = 
    {
        angleIndex = 12,
        shotDuration = 100
    },
    clip5 = 
    {
        angleIndex = 9,
        shotDuration = 80
    },
    clip6 = 
    {
        angleIndex = 10,
        shotDuration = 130
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
    CursorHide(true); --hide the cursor
    CursorEnable(true); --enable cusor functionality
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
    local cameraParentAgent = AgentCreate(agent_name_cutsceneCameraParent, "group.prop", newPosition, newRotation, kScene, false, false);

    AgentAttach(cameraAgent, cameraParentAgent);
    AgentSetPos(cameraAgent, Vector(0,0,0));
    AgentSetRot(cameraAgent, Vector(0,0,0));
    
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
    local controller_sound_soundtrack = SoundPlay("assets_music_soundtrack1.wav");
    
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
--procedual handheld camera animation (adds a bit of extra life and motion to the camera throughout the sequence)
Cutscene_UpdateHandheldCameraValues = function()
    local totalShakeAmount = 0.55;

    ------------------------------------------
    cutscene_handheld_x_level1 = cutscene_handheld_x_level1 + (GetFrameTime() * 2.0);
    cutscene_handheld_x_level2 = cutscene_handheld_x_level2 + (GetFrameTime() * 5.0);
    cutscene_handheld_x_level3 = cutscene_handheld_x_level3 + (GetFrameTime() * 3.5);
    cutscene_handheld_x_level4 = cutscene_handheld_x_level4 + (GetFrameTime() * 12.0);
    
    local level1_x = math.sin(cutscene_handheld_x_level1) * 0.3;
    local level2_x = math.sin(cutscene_handheld_x_level2) * 0.25;
    local level3_x = math.sin(cutscene_handheld_x_level3) * 0.15;
    local level4_x = math.sin(cutscene_handheld_x_level4) * 0.05;

    local totalX = level1_x - level2_x + level3_x + level4_x;
    totalX = totalX * totalShakeAmount;

    ------------------------------------------
    cutscene_handheld_y_level1 = cutscene_handheld_y_level1 + (GetFrameTime() * 2.0);
    cutscene_handheld_y_level2 = cutscene_handheld_y_level2 + (GetFrameTime() * 4.5);
    cutscene_handheld_y_level3 = cutscene_handheld_y_level3 + (GetFrameTime() * 3.5);
    cutscene_handheld_y_level4 = cutscene_handheld_y_level4 + (GetFrameTime() * 12.5);
    
    local level1_y = math.sin(cutscene_handheld_y_level1) * 0.3;
    local level2_y = math.sin(cutscene_handheld_y_level2) * 0.25;
    local level3_y = math.sin(cutscene_handheld_y_level3) * 0.15;
    local level4_y = math.sin(cutscene_handheld_y_level4) * 0.05;

    local totalY = level1_y + level2_y - level3_y - level4_y;
    totalY = totalY * totalShakeAmount;

    ------------------------------------------
    cutscene_handheld_z_level1 = cutscene_handheld_z_level1 + (GetFrameTime() * 1.5);
    cutscene_handheld_z_level2 = cutscene_handheld_z_level2 + (GetFrameTime() * 4.0);
    cutscene_handheld_z_level3 = cutscene_handheld_z_level3 + (GetFrameTime() * 3.5);
    cutscene_handheld_z_level4 = cutscene_handheld_z_level4 + (GetFrameTime() * 10.5);
    
    local level1_z = math.sin(cutscene_handheld_z_level1) * 0.15;
    local level2_z = math.sin(cutscene_handheld_z_level2) * 0.1;
    local level3_z = math.sin(cutscene_handheld_z_level3) * 0.05;
    local level4_z = math.sin(cutscene_handheld_z_level4) * 0.01;

    local totalZ = level1_z - level2_z + level3_z - level4_z;
    totalZ = totalZ * totalShakeAmount;

    ------------------------------------------
    camera_handheld_currentRot = Vector(totalX, totalY, totalZ);

    Custom_SetAgentPosition(agent_name_cutsceneCamera, camera_handheld_currentPos, kScene);
    Custom_SetAgentRotation(agent_name_cutsceneCamera, camera_handheld_currentRot, kScene);
end

--moves the enviorment
--note: the reason we move the enviorment and not the characters is due to floating point precison...
--in english: since we keep moving infinitely basically, the larger the distances are and we will eventually start to see some serious glitches
--so to avoid that, we can instead keep everything in place but move the enviorment, and it will actually look like the characters are walking through the enviorment
--and the camera is moving. its all movie magic!
--note to self: need to find perhaps a better way to reset the enviormnet position so we don't see the single frame in which is jumps back
Cutscene_UpdateScrollEnviorment = function()
    --increment the enviorment z position by the scroll speed.
    enviorment_scroll_positionZ = enviorment_scroll_positionZ + (enviorment_scroll_speed * GetFrameTime());

    --if we are on these specific shot number, then reset the enviorment position (otherwise mid shot the enviorment will reset back and it will ruin the illusion)
    --and also make sure that when we are on the new shot that we are just starting on it (sequence_currentTimer == 0) so this gets called only once
    if (sequence_currentShotIndex == 3) and (sequence_currentTimer <= 1) then --clem pov
        RenderDelay(1);
        enviorment_scroll_positionZ = 0;
    end
    
    if (sequence_currentShotIndex == 5) and (sequence_currentTimer <= 1) then --birds eye view 
        RenderDelay(1);
        enviorment_scroll_positionZ = 0;
    end
    
    if (sequence_currentShotIndex == 6) and (sequence_currentTimer <= 1) then --wide shot
        RenderDelay(1);
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
    
        --local incrementSequnceTimer = sequence_engineRealTime % 60;
        --local inverseFrameTime = 1.0 / GetFrameTime();
        --local frameTime = GetFrameTime();
        --GetFrameNumber();
        --GetFrameTime();
        --GetAverageFrameTime();
        --GetTotalTime();

        local totalEngineTime_rounded = tonumber(string.format("%." .. sequence_timePrecision .. "f", GetTotalTime()));
        local engineTimeDifference = math.abs(totalEngineTime_rounded - sequence_prevEngineTotalTime);
        local engineFrameNumberDifference = math.abs(GetFrameNumber() - sequence_prevEngineFrameNumberDifference);

        if(engineTimeDifference > 0) then
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
                --improvement: do a render delay so we don't see things jump around on the frame that we switch to a new shot
                --RenderDelay(1);

                --increment the shot index since we reached the end of the current clip that we are on
                sequence_currentShotIndex = sequence_currentShotIndex + 1;
                sequence_currentTimer = 0; --reset the time for the next clip
            end

            --get the angle information
            local angleInfo_fov = currentSequence_angle["FieldOfView"];
            local angleInfo_pos = currentSequence_angle["CameraPosition"];
            local angleInfo_rot = currentSequence_angle["CameraRotation"];
        
            --add our handheld camera shake to the angle position/rotation
            angleInfo_rot = angleInfo_rot;
            angleInfo_pos = angleInfo_pos;
        
            --apply the data to the camera
            Custom_AgentSetProperty(agent_name_cutsceneCamera, "Field Of View", angleInfo_fov, kScene);
            Custom_SetAgentWorldPosition(agent_name_cutsceneCameraParent, angleInfo_pos, kScene);
            Custom_SetAgentWorldRotation(agent_name_cutsceneCameraParent, angleInfo_rot, kScene);

            sequence_prevEngineTotalTime = totalEngineTime_rounded;
            sequence_prevEngineFrameNumberDifference = GetFrameNumber();
        end
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
    tick_animation_clementine_blink = tick_animation_clementine_blink + GetFrameTime();

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
local controller_animation_clementineBlink = nil; --dont touch
local controller_animation_clementineEyesLookUp = nil; --dont touch
local controller_animation_clementineEyesLookDown = nil; --dont touch
local controller_animation_clementineEyesDarting = nil; --dont touch
local controller_animation_clementineHeadLookUp = nil; --dont touch
local controller_animation_clementineHeadLookDown = nil; --dont touch
local controller_chore_clementineEmotion = nil; --dont touch
local controller_animation_scratch = nil; --dont touch

Cutscene_UpdateCharacterActing = function()
    if (sequence_currentShotIndex == 1) then --first sequence shot (up at trees)

        --have clem look up
        if (sequence_currentTimer > 3) then
            if(ControllerIsPlaying(controller_animation_clementineHeadLookUp) == false) then
                controller_animation_clementineHeadLookUp = PlayAnimation(agent_clementine, "wd200GM_headGesture_lookUp_add.anm");
                ControllerSetLooping(controller_animation_clementineBlink, false);
            end
        end
        
        --force clem to look up
        if (sequence_currentTimer > 4) then
            if(ControllerIsPlaying(controller_animation_clementineHeadLookUp) == false) then
                ControllerSetTimeScale(controller_animation_clementineHeadLookUp, 0.0);
            end
        end
        
    elseif (sequence_currentShotIndex == 2) then --meduim shot

        --make have a sad expression
        if (sequence_currentTimer > 0) then
            if(ControllerIsPlaying(controller_chore_clementineEmotion) == false) then
                controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toSadA", agent_clementine, nil, nil);
                ControllerSetLooping(controller_chore_clementineEmotion, false);
            end
        end
        
        --pause her eye movement so she looks forward steadily for a bit
        if (sequence_currentTimer > 10) then
            if(ControllerIsPaused(controller_animation_clementineEyesDarting) == false) then
                ControllerPause(controller_animation_clementineEyesDarting)
                ControllerSetTimeScale(controller_animation_clementineHeadLookUp, 1.0);
            end
        end
        
        --play the eye darting again
        if (sequence_currentTimer == 19) then
            if(ControllerIsPlaying(controller_animation_clementineEyesDarting) == false) then
                ControllerPlay(controller_animation_clementineEyesDarting)
                ControllerSetLooping(controller_animation_clementineEyesDarting, false);
            end
        end
        
        --have her scratch her head
        if (sequence_currentTimer > 30) then
            if(ControllerIsPlaying(controller_animation_scratch) == false) then
                controller_animation_scratch = PlayAnimation(agent_clementine, "sk54_wD200GMDefaultB_scratchHead_add.anm");
                ControllerSetLooping(controller_animation_scratch, false);
            end
        end
        
        --have her expression change to normal as she looks forward after finishing scratching her head
        if (sequence_currentTimer == 230) then
            --controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toNormalA", agent_clementine, nil, nil);
            --ControllerPause(controller_animation_clementineEyesDarting)
        end
        
        --change her expression to sad
        if (sequence_currentTimer == 350) then
            --controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toSadA", agent_clementine, nil, nil);
        end
        
    elseif (sequence_currentShotIndex == 3) then --clem pov with christa and omid
    
        --have omid turn and look back at clem briefly
        if (sequence_currentTimer == 50) then
            --PlayAnimation(agent_omid, "sk55_wd200GM_lookBehindRight_add.anm");
        end 
        
        --have christa turn her head back a bit implying shes checking omids rection to clem behind them
        if (sequence_currentTimer == 80) then
            --PlayAnimation(agent_christa, "wd200GM_headGesture_lookLeft_add.anm");
        end 

    elseif (sequence_currentShotIndex == 5) then --closeup shot

        --change clems expression to sad
        if (sequence_currentTimer == 1) then
            --controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toSadA", agent_clementine, nil, nil);
            --ControllerPlay(controller_animation_clementineEyesDarting)
        end
        
        --pause her eye darting and have her look down for a bit
        if (sequence_currentTimer == 80) then
            --ControllerPause(controller_animation_clementineEyesDarting)
            --controller_animation_clementineHeadLookDown = PlayAnimation(agent_clementine, "wd200GM_headGesture_lookDown_add.anm");
        end
        
        --when she brings her head back up, change her expression to a normal one
        if (sequence_currentTimer == 120) then
            --controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toNormalA", agent_clementine, nil, nil);
        end
        
        --then after some time contemplating, change her expression to a happy one
        if (sequence_currentTimer == 230) then
            --controller_chore_clementineEmotion = Custom_ChorePlayOnAgent("sk56_clementine_toHappyA", agent_clementine, nil, nil);
        end
        
    end
end

--when the cutscene reaches the end of the sequence, execute the finish cutscene level script
Cutscene_OnCutsceneFinish = function()
    
    --if the current shot number we are on is beyond the maximum amount of clips in the sequence (means that we are done)
    if (sequence_currentShotIndex > sequence_maxClips) then
        OverlayShow("ui_loadingScreen.overlay", true);

        --exectue this finish level script
        dofile("FCM_Scene_FinishCutsceneLevel.lua");
    end
    
end

--main level script, this function gets called when the scene loads
--its important we call everything here and set up everything so our work doesn't go to waste
FirstCutsceneLevel = function()
    ----------------------------------------------------------------
    --scene setup (call all of our scene setup functions)
    Scene_CleanUpOriginalScene(kScene); --clean up and remove everything we don't need from the original scene
    Scene_CreateEnviorment(kScene); --create our own new cutscene enviorment
    Scene_AddProcedualGrass(kScene); --add additional grass/detail to the new cutscene enviorment
    Scene_AddAdditionalParticleEffects(kScene); --add additional particle effects to the new cutscene enviorment to make it more lively
    Scene_RelightScene(kScene, agent_name_scene); --after creating our enviorment, we will now adjust/create the lighting for the scene.

    ----------------------------------------------------------------
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
    --CUTSCENE DEVELOPMENT

    --if freecam mode is not enabled, then don't continue on
    if (MODE_FREECAM == false) then
        do return end --the function will not continue past this point if freecam is disabled (we don't want our development tools interferring with the cutscene)
    end
    
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
SceneOpen(kScene, kScript);