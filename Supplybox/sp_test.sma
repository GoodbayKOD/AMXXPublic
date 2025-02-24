#include <amxmodx>
#include <cstrike>
#include <fun>

// Add the respective inc
#include <supplybox>

// Using the forward
public SupplyBox_OnAward(const pPlayer, iReward, szMessage[124])
{
    switch(iReward)
    {
        case 1: // Here gives armor
        {
            cs_set_user_armor(pPlayer, 100, CS_ARMOR_VESTHELM);

            formatex(szMessage, charsmax(szMessage), "You grabbed ^4 Armor ^1from the box");
        }
        case 3: // Here a money
        {
            new iMoney = random_num(1500, 2500);

            cs_set_user_money(pPlayer, cs_get_user_money(pPlayer) + iMoney);

            formatex(szMessage, charsmax(szMessage), "You grabbed^4 $%d ^1from the box", iMoney);
        }
        case 5: // Here a weapon
        {
            give_item(pPlayer, "weapon_ak47");

            cs_set_user_bpammo(pPlayer, CSW_AK47, 200);

            formatex(szMessage, charsmax(szMessage), "You grabbed a^4 AK-47 ^1from the box");
        }
        default:
        {
            // Nothing...
            formatex(szMessage, charsmax(szMessage), "The box no have a shit");
        }
    }

    client_print(pPlayer, print_chat, "SupplyBox_OnAward Executed");
}