#include <amxmodx>
#include <hamsandwich>
#include <engine>
#include <fakemeta>
#include <cstrike>

#define m_flNextAttack 83
#define TASK_REMOVE 243224

new const Dash_Sound[] = "sound/valorant/dash.mp3";
new const Dash_Model[] = "models/valorant/v_jett_dash.mdl";

const Float:DASH_VALUE = 670.0;
const Float:JUMP_VALUE = 184.0;
const Float:DASH_DELAY = 1.0;

const IN_MOVE = IN_FORWARD | IN_BACK | IN_MOVERIGHT | IN_MOVELEFT

enum
{
    Anim_Right = 0,
    Anim_Left,
    Anim_Forward,
    Anim_Back
}

#define flag_get(%1,%2) 	            	(%1 & (1 << (%2 & 31)))
#define flag_set(%1,%2)                 	%1 |= (1 << (%2 & 31))
#define flag_unset(%1,%2)               	%1 &= ~(1 << (%2 & 31))

new g_bIsJett;
new Float:g_vPlane[3], Float:g_vVelocity[3], Float:g_vForward[3];
new Float:g_fNextDash[33];

public plugin_precache()
{
    precache_generic(Dash_Sound);
    precache_model(Dash_Model);
}

public plugin_init()
{
    register_plugin("Dash movement", "1.0", "Goodbay");

    RegisterHam(Ham_Spawn, "player", "fw_Player_Spawn_Post", true);

    register_forward(FM_CmdStart, "fw_CmdStart_Post", true);
}

public fw_Player_Spawn_Post(const pPlayer)
{
    if(!is_user_alive(pPlayer))
        return;

    flag_unset(g_bIsJett, pPlayer);

    new szPlayerModel[32];
    cs_get_user_model(pPlayer, szPlayerModel, charsmax(szPlayerModel));

    // No tiene el model artic
    if(!equal(szPlayerModel, "arctic"))
        return;

    flag_set(g_bIsJett, pPlayer);
}

public fw_CmdStart_Post(const pPlayer, uc_handle)
{
    if(!is_user_alive(pPlayer))
        return FMRES_IGNORED;

    // Not jet
    if(!flag_get(g_bIsJett, pPlayer))
       return FMRES_IGNORED;

    static iButton, iOldButtons, Float:fGameTime;
    iButton     = get_uc(uc_handle, UC_Buttons);
    iOldButtons = entity_get_int(pPlayer, EV_INT_oldbuttons);

    // Touching E and isn't holding
    if((iButton & IN_USE) && !(iOldButtons & IN_USE) && (iButton & IN_MOVE))
    {
        if(g_fNextDash[pPlayer] >= (fGameTime = get_gametime()))
            return FMRES_IGNORED;

        new iAnim, Float:fDelay;

        if(iButton & IN_BACK)
        {
            iAnim = Anim_Back;
            fDelay = 0.8;

            // Pa tra
            entity_get_vector(pPlayer, EV_VEC_angles, g_vPlane);
            Math_Dash(pPlayer, g_vPlane, -DASH_VALUE);
        }
        else if(iButton & IN_FORWARD)
        {
            iAnim = Anim_Forward;
            fDelay = 0.8;

            // Pa delante
            entity_get_vector(pPlayer, EV_VEC_angles, g_vPlane);
            Math_Dash(pPlayer, g_vPlane, DASH_VALUE);
        }
        else if(iButton & IN_MOVERIGHT)
        {
            iAnim = Anim_Right;
            fDelay = 0.8;

            // Pal lao
            entity_get_vector(pPlayer, EV_VEC_angles, g_vPlane);
            g_vPlane[1] -= 90.0;
            Math_Dash(pPlayer, g_vPlane, DASH_VALUE);
        }
        else if(iButton & IN_MOVELEFT)
        {
            iAnim = Anim_Left;
            fDelay = 1.0;

            // Pal otro lao
            entity_get_vector(pPlayer, EV_VEC_angles, g_vPlane);
            g_vPlane[1] += 90.0;
            Math_Dash(pPlayer, g_vPlane, DASH_VALUE);
        }

        set_pdata_float(pPlayer, m_flNextAttack, fDelay);
        entity_set_string(pPlayer, EV_SZ_viewmodel, Dash_Model);

        Player_WeaponAnim(pPlayer, iAnim);
        Player_PlayMP3(pPlayer, Dash_Sound);

        remove_task(TASK_REMOVE + pPlayer);
        set_task(fDelay, "Player_RemoveModel", TASK_REMOVE + pPlayer);

        g_fNextDash[pPlayer] = fGameTime + DASH_DELAY;
    }

    return FMRES_IGNORED;
}

public Player_RemoveModel(const taskid)
{
    new pPlayer = taskid - TASK_REMOVE;

    if(!is_user_alive(pPlayer))
        return;

    ExecuteHamB(Ham_Item_Deploy, cs_get_user_weapon_entity(pPlayer));
}

stock Math_Dash(const pEntity, const Float:vAngle[3], const Float:fSpeed)
{
    entity_get_vector(pEntity, EV_VEC_velocity, g_vVelocity);

    // Forward angle
    angle_vector(vAngle, ANGLEVECTOR_FORWARD, g_vForward);

    g_vVelocity[0] = g_vForward[0] * fSpeed;
    g_vVelocity[1] = g_vForward[1] * fSpeed;
    g_vVelocity[2] = JUMP_VALUE;

    entity_set_vector(pEntity, EV_VEC_velocity, g_vVelocity);
}

stock Player_WeaponAnim(const pPlayer, const iAnim)
{
	// Play anim now
	entity_set_int(pPlayer, EV_INT_weaponanim, iAnim);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, pPlayer);
	write_byte(iAnim);
	write_byte(0);
	message_end();
}

stock Player_PlayMP3(const pPlayer, const szSound[])
    client_cmd(pPlayer, "mp3 play ^"%s^"", szSound);
