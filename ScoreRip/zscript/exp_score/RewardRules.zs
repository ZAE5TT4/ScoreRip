class EXPRewardRules : Object
{
    static int GetThresholdForTier(int tier)
    {
        switch (tier)
        {
        case 0: return 600;
        case 1: return 1400;
        case 2: return 2600;
        case 3: return 4200;
        case 4: return 6200;
        case 5: return 8600;
        case 6: return 11500;
        case 7: return 14900;
        case 8: return 18800;
        case 9: return 23200;
        case 10: return 28100;
        case 11: return 33500;
        default: return 33500 + ((tier - 11) * 6500);
        }
    }

    static play void GiveTierReward(PlayerPawn player, int tier)
    {
        if (player == null)
        {
            return;
        }

        String rewardText = "";

        switch (tier)
        {
        case 0:
            Give(player, 'Stimpack', 2);
            Give(player, 'Clip', 20);
            rewardText = "Stm2 Clip20";
            break;

        case 1:
            Give(player, 'Medikit', 1);
            Give(player, 'Shell', 12);
            rewardText = "Med1 Sh12";
            break;

        case 2:
            Give(player, 'GreenArmor', 1);
            Give(player, 'ClipBox', 1);
            rewardText = "GArm1 ClipBox1";
            break;

        case 3:
            Give(player, 'ShellBox', 1);
            Give(player, 'ArmorBonus', 10);
            rewardText = "ShellBox1 AB10";
            break;

        case 4:
            Give(player, 'RocketAmmo', 4);
            Give(player, 'Cell', 40);
            rewardText = "Rkt4 Cell40";
            break;

        case 5:
            Give(player, 'BackpackItem', 1);
            Give(player, 'Medikit', 1);
            rewardText = "Pack1 Med1";
            break;

        case 6:
            Give(player, 'BlueArmor', 1);
            Give(player, 'RocketBox', 1);
            rewardText = "BArm1 RktBox1";
            break;

        case 7:
            Give(player, 'CellPack', 1);
            Give(player, 'ShellBox', 1);
            rewardText = "CellPack1 ShellBox1";
            break;

        case 8:
            Give(player, 'Soulsphere', 1);
            Give(player, 'RocketAmmo', 6);
            rewardText = "Soul1 Rkt6";
            break;

        case 9:
            Give(player, 'Megasphere', 1);
            Give(player, 'CellPack', 1);
            rewardText = "Mega1 CellPack1";
            break;

        case 10:
            Give(player, 'InvulnerabilitySphere', 1);
            Give(player, 'RocketBox', 1);
            rewardText = "Invul1 RktBox1";
            break;

        case 11:
            Give(player, 'Soulsphere', 1);
            Give(player, 'Megasphere', 1);
            Give(player, 'CellPack', 1);
            rewardText = "Soul1 Mega1 CellPack1";
            break;

        default:
            rewardText = GiveEndlessReward(player, tier - 12);
            break;
        }

        AnnounceReward(player, tier, rewardText);
    }

    static play String GiveEndlessReward(PlayerPawn player, int cycleIndex)
    {
        int cycle = cycleIndex % 4;
        if (cycle < 0)
        {
            cycle = 0;
        }

        switch (cycle)
        {
        case 0:
            Give(player, 'Soulsphere', 1);
            Give(player, 'CellPack', 1);
            Give(player, 'RocketBox', 1);
            return "Soul1 CellPack1 RktBox1";

        case 1:
            Give(player, 'Megasphere', 1);
            Give(player, 'ShellBox', 1);
            return "Mega1 ShellBox1";

        case 2:
            Give(player, 'InvulnerabilitySphere', 1);
            Give(player, 'CellPack', 1);
            return "Invul1 CellPack1";

        case 3:
            Give(player, 'Berserk', 1);
            Give(player, 'BlueArmor', 1);
            Give(player, 'RocketBox', 1);
            return "Bers1 BArm1 RktBox1";
        }

        return "";
    }

    static play void AnnounceReward(PlayerPawn player, int tier, String rewardText)
    {
        if (rewardText == "")
        {
            return;
        }

        if (!IsRewardGainShown(player))
        {
            return;
        }

        if (!IsConsoleLogEnabled(player))
        {
            return;
        }

        int playerNumber = player.PlayerNumber() + 1;
        Console.Printf("P%d T%d %s\n", playerNumber, tier + 1, rewardText);
    }

    static play bool IsRewardGainShown(PlayerPawn player)
    {
        if (player == null || player.player == null)
        {
            return true;
        }

        let cv = CVar.GetCVar('score_show_reward_gain', player.player);
        if (cv == null)
        {
            return true;
        }

        return cv.GetBool();
    }

    static play bool IsConsoleLogEnabled(PlayerPawn player)
    {
        if (player == null || player.player == null)
        {
            return true;
        }

        let cv = CVar.GetCVar('score_log_score_events', player.player);
        if (cv == null)
        {
            return true;
        }

        return cv.GetBool();
    }

    static play void Give(PlayerPawn player, Name itemName, int amount)
    {
        if (amount <= 0)
        {
            return;
        }

        ScriptUtil.GiveInventory(player, itemName, amount);
    }
}
