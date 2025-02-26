#if defined _supplybox_included
	#endinput
#endif
#define _supplybox_included

const MAX_REWARD_PERCENT = 20;

/**
 *	Called when the award function is called (Grab the box)
 *
 * @param pPlayer		Client index
 * @param iReward		Box reward (random_num(1, MAX_REWARD_PERCENT))
 * @param szMessage		Message in print when grab the box
 *
 * @return 			PLUGIN_CONTINUE function will continue
 *                  		PLUGIN_HANDLED or higher to block print, message, sound and entity remove
 *
*/
forward SupplyBox_OnAward(const pPlayer, iReward, szMessage[124]);

/**
 *	Spawn a box in the Origin
 *
 * @param vOrigin		Spawn origin
 * @param iReward		Reward id of the spawned box
 *
 * @return 			True if the entity spawned, false otherwise
 *
*/

native Supplybox_TrySpawn(const Float:vOrigin[], const iReward);
