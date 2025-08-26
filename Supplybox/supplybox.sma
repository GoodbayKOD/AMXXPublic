#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <json>
#include <xs>
#include <supplybox>

#define Enable_Reapi        false
#define Enable_Logs         true
#define nullptr             0

#define g_pMaxPlayers       MaxClients
#define g_szPrefix          "[AMXX]"

#define InfoTarget_Class    "info_target"
#define Button_Class        "func_button"
#define SupplyBox_Class     "supplybox"

#define TASK_SPAWN          1218148431

// Macros
#define is_user_valid_alive(%1)			(1 <= %1 <= g_pMaxPlayers && is_user_alive(%1))

// Constant values
const MAX_SUPPLY = 50; // Max supply in map
const Float:ICON_UP_OFFSET = 12.0;
const Float:ICON_SCALE = 1.2;

// Resources
new const Box_Model[]           = "models/gkod/supplybox.mdl";
new const Box_Sprite_Icon[]     = "sprites/gkod/icon_supplybox.spr";
new const Box_Sprite_Button[]   = "sprites/gkod/e_button.spr";
new const Box_Sound_Pickup[]    = "gkod/supplybox_pickup.wav";
new const Box_Sound_Arrive[]    = "gkod/supplybox_arrive.wav";

// Submodel stuff
new const Box_Names[m_SupplyBoxBody][] =
{
    "Normal",
    "Halloween",
    "Military",
    "New Year",
    "Purple",
    "Xmas",
    "Orange",
    "Cone"
}
new g_iBoxSelected;

// Box related
new Float:g_vBoxOrigin[MAX_SUPPLY][3], g_pBoxBody[MAX_SUPPLY];
new g_iBoxCount;

// Current Map Name
new g_szCurrentMap[32];

// Forwards
new g_fBoxAward;

// Cvars
new Float:g_vSpawnTime;
new g_vGrabButton;

// Vectors
new Float:g_vOrigin[3], Float:g_vPlane[3], Float:g_vStart[3], 
Float:g_vEnd[3], Float:g_vOffset[3], Float:g_vForward[3], Float:g_vGoal[3];
new g_hTrace;

// Sprite
new g_pSupplyIcon, g_pSupplyButton, g_pLaserBeam;

// Message ID's
new g_msgTextMsg;

#if Enable_Reapi
#include <reapi>
#endif

/*================================================================================
 [Plugin Data]
=================================================================================*/

public plugin_natives()
{
    register_native("Supplybox_TrySpawn", "native_supplybox_spawn");
}

public plugin_precache()
{
    // Get current map name
    get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));
    strtolower(g_szCurrentMap);

    // Precache resources
    g_pSupplyIcon   = precache_model(Box_Sprite_Icon);
    g_pSupplyButton = precache_model(Box_Sprite_Button);
    g_pLaserBeam    = precache_model("sprites/laserbeam.spr");

    precache_model(Box_Model);
    precache_sound(Box_Sound_Pickup);
    precache_sound(Box_Sound_Arrive);

    // Forwards
    // SupplyBox_OnAward(const pPlayer, iReward, szMessage[]);
    g_fBoxAward = CreateMultiForward("SupplyBox_OnAward", ET_CONTINUE, FP_CELL, FP_CELL, FP_ARRAY);
}

public plugin_init()
{
    // You change this = you're gay
    register_plugin("SupplyBox", "1.0", "Goodbay");

    // Admin cmd
    register_clcmd("sb", "clcmd_box", ADMIN_IMMUNITY);
    register_clcmd("sb_menu", "show_menu_supplybox");

    // HAM ÑAM ÑAM
    RegisterHam(Ham_Use, Button_Class, "fw_SupplyBox_Use", true);

    new pGrab;

    // Cvars
    bind_pcvar_num((pGrab = create_cvar("sb_grab_button", "0", FCVAR_NONE, "Only can grab the boxes with E button", true, 0.0, true, 1.0)), g_vGrabButton);
    hook_cvar_change(pGrab, "cvar_grab_button");
    bind_pcvar_float(create_cvar("sb_spawn_time", "1.0", FCVAR_NONE, "Spawn time after load file", true, 1.0), g_vSpawnTime);

    // Try load the file data
    Box_Load();

    // Think in case of not use reapi
    #if !defined _reapi_included
        register_think(SupplyBox_Class, "fw_SupplyBox_Think");
        register_touch(SupplyBox_Class, "*", "fw_SupplyBox_Touch");
    #endif

    g_msgTextMsg = get_user_msgid("TextMsg");
    g_hTrace = create_tr2();
}

/*================================================================================
 [Client Commands]
=================================================================================*/

public clcmd_box(const pPlayer)
{
    Math_GetAimOrigin(pPlayer, g_vOrigin, 32.0);
    Entity_TryBoxSpawn(g_vOrigin, random_num(0, 12));
}

/*================================================================================
 [CVar Hooks]
=================================================================================*/

public cvar_grab_button(pCvar, const szOldValue[], const szNewValue[])
{
    if(!g_iBoxCount)
        return; 

    remove_entity_name(SupplyBox_Class);
    Box_Spawn_Coords();
}

/*================================================================================
 [Menu]
=================================================================================*/

public show_menu_supplybox(const pPlayer)
{
    if(!is_user_connected(pPlayer))
        return PLUGIN_HANDLED;

    new hMenu = menu_create("SupplyBox^n\dby Goodbay", "menu_supplybox"), szMenu[24];

    formatex(szMenu, charsmax(szMenu), "Box Type:\y %s", Box_Names[g_iBoxSelected]);
    menu_additem(hMenu, szMenu);

    menu_additem(hMenu, "Create Point \y(POS)");
    menu_additem(hMenu, "Delete Nearly Point^n");

    menu_additem(hMenu, "Save");
    
    menu_display(pPlayer, hMenu);
    return PLUGIN_HANDLED;
}

public menu_supplybox(const pPlayer, const pMenu, const pKey)
{
    if(pKey == MENU_EXIT || !is_user_connected(pPlayer))
    {
        menu_destroy(pMenu);
        return PLUGIN_HANDLED;
    }

    switch(pKey)
    {
        case 0:
        {
            static i, iCurrentBox, iNextBox, iMaxBoxes;
            iCurrentBox 	= g_iBoxSelected;
            iNextBox 		= iCurrentBox;
            iMaxBoxes       = sizeof(Box_Names);
            
            for(i = iCurrentBox + 1; i <= iMaxBoxes; i++)
            {
                // Restart
                if(i >= iMaxBoxes)
                    i = nullptr;

                // Break if do a circle
                if(iCurrentBox == i)
                    break;

                iNextBox = i;
                break;
            }

            // No changes if is the same
            if(iNextBox != iCurrentBox)
            {
                menu_destroy(pMenu);

                // Save next
                g_pBoxBody[g_iBoxCount] = g_iBoxSelected = iNextBox;
                client_print_color(pPlayer, print_team_default, "^4%s^1 Box type is:^3 %s", g_szPrefix, Box_Names[iNextBox]);

                show_menu_supplybox(pPlayer)
                return PLUGIN_HANDLED; 
            }
        }
        case 1:
        {
            // Get the aim end trace from the player and save it in the array
            Math_GetAimOrigin(pPlayer, g_vBoxOrigin[g_iBoxCount]);
            client_print_color(pPlayer, print_team_default, "^4%s^1 Created point^4 n°%d", g_szPrefix, ++g_iBoxCount);

            // Update
            g_pBoxBody[g_iBoxCount] = g_iBoxSelected;
        }
        case 2:
        {
            new Float:fMinDistance = 999999.0;
            new Float:fDistance;
            new i, j, iClosest = -1;

            entity_get_vector(pPlayer, EV_VEC_origin, g_vOrigin);

            // Iter in the box count
            for(i = 0; i < g_iBoxCount; i++) 
            {
                // Get the distance between player origin and box origin
                fDistance = get_distance_f(g_vOrigin, g_vBoxOrigin[i]);

                // The distance obtained is less than the declared
                if(fDistance < fMinDistance) 
                {
                    // Update the minimum
                    fMinDistance = fDistance;
                    iClosest = i;
                }
            }

            // Only if a point was scored
            if(iClosest != -1)
            {
                // Shift the points to fill the gap
                for(j = iClosest; j < g_iBoxCount - 1; j++)
                    xs_vec_copy(g_vBoxOrigin[j], g_vBoxOrigin[j + 1]);

                client_print_color(pPlayer, print_team_default, "^4%s^1 Deleted point^4 n°%d", g_szPrefix, iClosest + 1);

                // Decreased
                g_iBoxCount--;
            }
            else
            {
                // No point created
                client_print_color(pPlayer, print_team_default, "^4%s^1 There's no point nearby", g_szPrefix);
            }
        }
        case 3:
        {
            // Save the box coords
            if(Box_Save())
            {
                // A print if the save work correctly
                client_print_color(pPlayer, print_team_default, "^4%s^1 Config Saved", g_szPrefix);
            }
        }
    }

    menu_display(pPlayer, pMenu);
    return PLUGIN_HANDLED;
}

/*================================================================================
 [Box Forwards]
=================================================================================*/

public fw_SupplyBox_Touch(const pEntity, const pToucher, const szParam[])
{
    // Check if is a player and is alivep
    if(!is_user_valid_alive(pToucher) || g_vGrabButton)
        return;

    Box_Grab(pEntity, pToucher);
}

public fw_SupplyBox_Use(const pEntity, pCaller, pActivator, use_type, Float:fValue)
{
    // Not active
    if(!g_vGrabButton)
        return HAM_IGNORED;

    // Check classname
    if(!FClassnameIs(pEntity, SupplyBox_Class))
        return HAM_IGNORED;

    // Grab Bv
    Box_Grab(pEntity, pCaller);
    return HAM_IGNORED;
}

public Box_Grab(const pEntity, const pPlayer)
{
    static szMessage[124], iReturn;
    szMessage[0] = EOS;
    iReturn = PLUGIN_CONTINUE;

    // Execute the forward
    ExecuteForward(g_fBoxAward, iReturn, pPlayer, random_num(1, MAX_REWARD_PERCENT), PrepareArray(szMessage, charsmax(szMessage), 1));

    // Can block the function with PLUGIN_HANDLED return (Maybe you don't want to delete the entity)
    if(iReturn != PLUGIN_CONTINUE)
        return;

    // Message when grab
    if(szMessage[0] != EOS)
        client_print_color(pPlayer, print_team_default, "^4%s^1 %s", g_szPrefix, szMessage);

    // Grab sound
    emit_sound(pEntity, CHAN_ITEM, Box_Sound_Pickup, VOL_NORM, ATTN_NORM, nullptr, PITCH_NORM);
    remove_entity(pEntity);
}

public fw_SupplyBox_Think(const pEntity)
{
    if(!is_valid_ent(pEntity))
        return;

    static i, Float:fGameTime;
    fGameTime = get_gametime();

    entity_get_vector(pEntity, EV_VEC_origin, g_vOrigin);

    // Add offset
    g_vOrigin[2] += 10.0;

    for(i = 1; i <= g_pMaxPlayers; i++)
    {
        // Can be dead
        if(!is_user_connected(i))
            continue;

        entity_get_vector(i, EV_VEC_origin, g_vEnd);

        if(Math_WallInPoints(g_vEnd, g_vOrigin, pEntity, IGNORE_MONSTERS))
        {
            // Show the icon to the player
            Server_DrawSprite(i, g_vOrigin, g_pSupplyIcon, ICON_SCALE);
        }
    }

    // E button option
    if(g_vGrabButton)
    {
        // Add the offset
        g_vOrigin[2] += ICON_UP_OFFSET;
        GameFX_Sprite(g_pSupplyButton, g_vOrigin, 1, 255);
    }

    entity_set_float(pEntity, EV_FL_nextthink, fGameTime + 0.1);
}

/*================================================================================
 [Box Functions]
=================================================================================*/

public Box_Load()
{
    // Get the config directory and format it
    new szConfig[42], szPath[127];
    get_configsdir(szConfig, charsmax(szConfig));
    formatex(szPath, charsmax(szPath), "%s/maps/%s_supplybox.json", szConfig, g_szCurrentMap);

    // If exist, try parse the file
    if(file_exists(szPath))
    {
        new JSON:jFile = json_parse(szPath, true);

        // Invalid
        if(jFile == Invalid_JSON || !json_is_array(jFile))
            return 0;

        new i, JSON:jObject;
        new szValue[42], szPosition[3][12];

        // Iter in the array items
        for(i = 0; i < json_array_get_count(jFile); i++)
        {
            // Get the first and most important string. If it's empty iter to the next
            json_object_get_string((jObject = json_array_get_value(jFile, i)), "supplybox.coords", szValue, charsmax(szValue));

            // Null string
            if(szValue[0] == EOS)
            {
                // Next
                json_free(jObject);
                continue;
            }
            
            // Parse the vector
            parse(szValue, szPosition[0], charsmax(szPosition[]), szPosition[1], charsmax(szPosition[]), szPosition[2], charsmax(szPosition[]));

            // Convert to float into the vector
            g_vBoxOrigin[g_iBoxCount][0] = str_to_float(szPosition[0]);
            g_vBoxOrigin[g_iBoxCount][1] = str_to_float(szPosition[1]);
            g_vBoxOrigin[g_iBoxCount][2] = str_to_float(szPosition[2]);

            // Get the reward id and free the object
            g_pBoxBody[g_iBoxCount] = json_object_get_number(jObject, "supplybox.body");
            json_free(jObject);
            
            // Max Reached
            if(++g_iBoxCount >= MAX_SUPPLY)
            {
                #if Enable_Logs
                    log_amx("Reached Limit of Loaded SupplyBoxes");
                #endif

                break;
            }
        }

        // and release the parser
        json_free(jFile);
    }

    // If loaded a point, make spawn
    if(g_iBoxCount)
        set_task(g_vSpawnTime, "Box_Spawn_Coords", TASK_SPAWN);

    #if Enable_Logs
        log_amx("Loaded Supplybox Spawns: %d", g_iBoxCount);
    #endif

    return 1;
}

public Box_Save()
{
    new szDirectory[24], filepath[127], szBuffer[124];
    new JSON:jFile, JSON:jObject, i;

    // Parser the file if exist
    jFile = json_parse(filepath, true);

    // In case the file doesn't exist
    if(jFile == Invalid_JSON)
        jFile = json_init_array();

    // Iterate into the spawn counts
    for(i = 0; i < g_iBoxCount; i++)
    {
        // Format vector
        formatex(szBuffer, charsmax(szBuffer), "%.2f %.2f %.2f", g_vBoxOrigin[i][0], g_vBoxOrigin[i][1], g_vBoxOrigin[i][2]);
        server_print(szBuffer);

        // Append
        jObject = json_init_object();
        json_array_append_value(jFile, jObject);

        // Add
        json_object_set_string(jObject, "supplybox.coords", szBuffer);
        json_object_set_number(jObject, "supplybox.body", g_pBoxBody[i]);
    }

    // Format the path
    get_configsdir(szDirectory, charsmax(szDirectory));
    formatex(filepath, charsmax(filepath), "%s/maps/%s_supplybox.json", szDirectory, g_szCurrentMap);

    // Serialized (Save)
    json_serial_to_file(jFile, filepath, true);
    json_free(jFile);
    return true;
}

public Box_Spawn_Coords()
{
    new i;

    for(; i < g_iBoxCount; i++)
    {
        // Try spawn
        if(Entity_TryBoxSpawn(g_vBoxOrigin[i], g_pBoxBody[i]) && Enable_Logs)
        {
            // Logs
            server_print("Box spawned in: %.2f %.2f %.2f", g_vBoxOrigin[i][0], g_vBoxOrigin[i][1], g_vBoxOrigin[i][2]);
        }
    }

    // Arrive sound & print
    client_cmd(nullptr, "spk ^"%s^"", Box_Sound_Arrive);
    client_print_center(nullptr, "Supplybox Arrive !!");
}

/*================================================================================
 [Natives]
=================================================================================*/

public native_supplybox_spawn(const pPluginID, const iParams)
{
    new Float:vOrigin[3];
    get_array_f(1, vOrigin, 3);
    
    if(Entity_TryBoxSpawn(vOrigin, get_param(2)))
        return true;

    return false;
}

/*================================================================================
 [Stocks]
=================================================================================*/

stock Entity_TryBoxSpawn(const Float:vOrigin[3], const iBody)
{
    new pEntity = create_entity((g_vGrabButton ? Button_Class : InfoTarget_Class));

    if(pEntity)
    {
        entity_set_string(pEntity, EV_SZ_classname, SupplyBox_Class);
        entity_set_model(pEntity, Box_Model);

        entity_set_int(pEntity, EV_INT_solid, SOLID_TRIGGER);
        entity_set_int(pEntity, EV_INT_movetype, MOVETYPE_TOSS);

        entity_set_origin(pEntity, vOrigin);

        entity_set_int(pEntity, EV_INT_body, iBody);
        entity_set_float(pEntity, EV_FL_nextthink, get_gametime() + 0.1);

        #if defined _reapi_included
            SetTouch(pEntity, "fw_SupplyBox_Touch");
            SetThink(pEntity, "fw_SupplyBox_Think");
        #endif
    }

    return pEntity;
}

stock Server_DrawSprite(const pPlayer, const Float:vOrigin[3], const iSprite, const Float:fScale = 1.0)
{
	// Obtain the point of origin of the crosshairs
	entity_get_vector(pPlayer, EV_VEC_origin, g_vStart);
	entity_get_vector(pPlayer, EV_VEC_view_ofs, g_vPlane);
	xs_vec_add(g_vStart, g_vPlane, g_vStart);

	// Max distance
	if(xs_vec_distance(g_vStart, vOrigin) > 99999.0)
		return false;

	engfunc(EngFunc_TraceLine, g_vStart, vOrigin, IGNORE_MONSTERS, pPlayer, g_hTrace);
	get_tr2(g_hTrace, TR_vecEndPos, g_vEnd);

	xs_vec_sub(vOrigin, g_vStart, g_vGoal);
	xs_vec_normalize(g_vGoal, g_vGoal);

	// Distance to point
	new Float:fDistance = xs_vec_distance(g_vStart, g_vEnd) - 10.0;
	xs_vec_mul_scalar(g_vGoal, fDistance, g_vGoal);
	xs_vec_add(g_vStart, g_vGoal, g_vEnd);

    // Draw sprite
	GameFX_Sprite(iSprite, g_vEnd, floatround(2.0 * floatmax(fDistance / xs_vec_distance(g_vStart, vOrigin), 0.5) * fScale), 255, MSG_PVS, pPlayer);
	return true;
}

stock Math_GetAimOrigin(const pPlayer, Float:vOutput[3], const Float:fOffset = 0.0)
{
    // Point of sight
    entity_get_vector(pPlayer, EV_VEC_origin, g_vOrigin);
    entity_get_vector(pPlayer, EV_VEC_view_ofs, g_vPlane);

    xs_vec_add(g_vOrigin, g_vPlane, g_vStart);

    entity_get_vector(pPlayer, EV_VEC_v_angle, g_vPlane);
    angle_vector(g_vPlane, ANGLEVECTOR_FORWARD, g_vForward);

    // To forward
    xs_vec_add_scaled(g_vStart, g_vForward, 9999.0, g_vEnd);

    // Trace
    engfunc(EngFunc_TraceLine, g_vStart, g_vEnd, DONT_IGNORE_MONSTERS, pPlayer, g_hTrace);
    get_tr2(g_hTrace, TR_vecEndPos, g_vEnd);

    // Add offset
    if(fOffset > 0)
    {
        get_tr2(g_hTrace, TR_vecPlaneNormal, g_vOffset);
        xs_vec_add_scaled(g_vEnd, g_vOffset, fOffset, g_vEnd);
    }

    vOutput = g_vEnd;
    GameFX_DrawLaser(g_vStart[0], g_vStart[1], g_vStart[2], vOutput[0], vOutput[1], vOutput[2], {255, 255, 255}, 200);
    return 1;
}

stock Math_WallInPoints(const Float:vStart[3], const Float:vEnd[3], const pIgnore, const pTraceSize)
{
	engfunc(EngFunc_TraceLine, vStart, vEnd, pTraceSize, pIgnore, g_hTrace);

	static Float:vEndPos[3];
	get_tr2(g_hTrace, TR_vecEndPos, vEndPos);

	return floatround(get_distance_f(vEnd, vEndPos));
}

stock GameFX_Sprite(const iSprite, const Float:vOrigin[3], const iScale, const iAlpha, const MSG_CHANNEL = MSG_PVS, const pPlayer = nullptr)
{
	message_begin_f(MSG_CHANNEL, SVC_TEMPENTITY, vOrigin, pPlayer);
	write_byte(TE_SPRITE); 					// TE id
	write_coord_f(vOrigin[0]); 				// x
	write_coord_f(vOrigin[1]); 				// y
	write_coord_f(vOrigin[2]); 				// z
	write_short(iSprite); 		            // sprite index
	write_byte(iScale); 					// scale
	write_byte(iAlpha); 					// brightness
	message_end();
}

stock GameFX_DrawLaser(Float:vStart1, Float:vStart2, Float:vStart3, Float:vEnd1, Float:vEnd2, Float:vEnd3, const iColors[3], iAlpha = 200, pPlayer = 0)
{
	message_begin_f((pPlayer ? MSG_ONE_UNRELIABLE : MSG_BROADCAST), SVC_TEMPENTITY, .player = pPlayer);
	write_byte(TE_BEAMPOINTS)
	write_coord_f(vStart1) // x
	write_coord_f(vStart2) // y
	write_coord_f(vStart3) // z
	write_coord_f(vEnd1) // x axis
	write_coord_f(vEnd2) // y axis
	write_coord_f(vEnd3) // z axis
	write_short(g_pLaserBeam) // sprite
	write_byte(0)			// starting frame
	write_byte(0)			// frame rate in 0.1's
	write_byte(10)		// life in 0.1's
	write_byte(10)		// line width in 0.1's
	write_byte(0)		// noise
	write_byte(iColors[0])		// R
	write_byte(iColors[1])		// G
	write_byte(iColors[2])		// B
	write_byte(iAlpha)		// brightness
	write_byte(10)		// scroll speed in 0.1's
	message_end()
}

// Fix for the nosteam Bv
stock client_print_center(const pPlayer, const szMessage[], any:...)
{
    new szFormat[512];
    vformat(szFormat, charsmax(szFormat), szMessage, 3);

    message_begin(!pPlayer ? MSG_BROADCAST : MSG_ONE_UNRELIABLE, g_msgTextMsg, .player = pPlayer);
    write_byte(print_center);
    write_string(szFormat);
    message_end();
}

#if !defined _reapi_included
stock bool:FClassnameIs(const entityIndex, const className[])
{
    new entityClass[32];
    entity_get_string(entityIndex, EV_SZ_classname, entityClass, charsmax(entityClass));

    return bool:(equal(entityClass, className));
}
#endif

public plugin_end()
{
    free_tr2(g_hTrace);
}
