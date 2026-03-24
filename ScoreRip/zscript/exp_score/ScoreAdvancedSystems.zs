extend class EXPScoreEventHandler
{
    private Actor eliteMonsterActors[3];
    private Actor eliteAuraActors[3];
    private int eliteKillCount[MAXPLAYERS];

    private String styleEventQueueText[MAXPLAYERS * 10];
    private int styleEventQueueStartTic[MAXPLAYERS * 10];

    private bool mapContractsReady;
    private int mapContractType[3];
    private int mapContractTarget[3];
    private int mapContractReward[3];
    private bool mapContractDone[MAXPLAYERS * 3];

    private Name shopSpecialTypes[3];
    private int shopSpecialDiscounts[3];
    private bool shopSpecialsReady;

    private clearscope int GetContractFlatIndex(int playerNumber, int slot)
    {
        return (playerNumber * 3) + slot;
    }

    private clearscope int GetStyleEventFlatIndex(int playerNumber, int slot)
    {
        return (playerNumber * 10) + slot;
    }

    private void ResetAdvancedAllRuntime()
    {
        ResetAdvancedMapRuntime();
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            ResetAdvancedPlayerRuntime(i);
        }
    }

    private void ResetAdvancedMapRuntime()
    {
        mapContractsReady = false;
        shopSpecialsReady = false;

        for (int i = 0; i < 3; i++)
        {
            if (eliteAuraActors[i] != null)
            {
                eliteAuraActors[i].Destroy();
            }
            eliteMonsterActors[i] = null;
            eliteAuraActors[i] = null;
            mapContractType[i] = -1;
            mapContractTarget[i] = 0;
            mapContractReward[i] = 0;
            shopSpecialTypes[i] = 'None';
            shopSpecialDiscounts[i] = 0;
        }

        for (int i = 0; i < MAXPLAYERS * 3; i++)
        {
            mapContractDone[i] = false;
        }
    }

    private void ResetAdvancedPlayerRuntime(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        eliteKillCount[playerNumber] = 0;
        for (int slot = 0; slot < 10; slot++)
        {
            int flatEvent = GetStyleEventFlatIndex(playerNumber, slot);
            styleEventQueueText[flatEvent] = "";
            styleEventQueueStartTic[flatEvent] = 0;
        }

        for (int slot = 0; slot < 3; slot++)
        {
            mapContractDone[GetContractFlatIndex(playerNumber, slot)] = false;
        }
    }

    private void SetupContractSlot(int slot, int contractType)
    {
        mapContractType[slot] = contractType;
        switch (contractType)
        {
        case 0:
            mapContractTarget[slot] = 25;
            if (mapTotalMonsters > 0 && mapContractTarget[slot] > mapTotalMonsters)
            {
                mapContractTarget[slot] = mapTotalMonsters;
                if (mapContractTarget[slot] < 5)
                {
                    mapContractTarget[slot] = 5;
                }
            }
            mapContractReward[slot] = 600;
            break;
        case 1:
            mapContractTarget[slot] = 3;
            if (mapTotalSecrets > 0 && mapContractTarget[slot] > mapTotalSecrets)
            {
                mapContractTarget[slot] = mapTotalSecrets;
            }
            mapContractReward[slot] = 700;
            break;
        case 2:
            mapContractTarget[slot] = 12;
            mapContractReward[slot] = 800;
            break;
        case 3:
            mapContractTarget[slot] = 1;
            mapContractReward[slot] = 900;
            break;
        case 4:
            mapContractTarget[slot] = 180;
            mapContractReward[slot] = 850;
            break;
        case 5:
            mapContractTarget[slot] = 8;
            mapContractReward[slot] = 750;
            break;
        default:
            mapContractTarget[slot] = 10000;
            mapContractReward[slot] = 700;
            break;
        }
    }

    private play void EnsureMapContractsReady()
    {
        if (mapContractsReady || gamestate != GS_LEVEL)
        {
            return;
        }

        int pool[7];
        int poolCount = 0;
        pool[poolCount++] = 0;
        if (mapTotalSecrets > 0)
        {
            pool[poolCount++] = 1;
        }
        pool[poolCount++] = 2;
        pool[poolCount++] = 3;
        pool[poolCount++] = 4;
        pool[poolCount++] = 5;
        pool[poolCount++] = 6;

        for (int slot = 0; slot < 3; slot++)
        {
            if (poolCount <= 0)
            {
                SetupContractSlot(slot, 0);
                continue;
            }

            int pick = Random(0, poolCount - 1);
            int contractType = pool[pick];
            pool[pick] = pool[poolCount - 1];
            poolCount--;
            SetupContractSlot(slot, contractType);
        }

        mapContractsReady = true;
    }

    private clearscope String GetContractTypeName(int contractType)
    {
        switch (contractType)
        {
        case 0: return "KILL";
        case 1: return "SECRET";
        case 2: return "COMBO";
        case 3: return "ELITE";
        case 4: return "STYLE";
        case 5: return "NO HIT";
        default: return "GAIN";
        }
    }

    private play int GetContractProgress(int playerNumber, int contractType)
    {
        switch (contractType)
        {
        case 0: return mapKillsByPlayer[playerNumber];
        case 1: return mapSecretsByPlayer[playerNumber];
        case 2: return mapBestComboByPlayer[playerNumber];
        case 3: return eliteKillCount[playerNumber];
        case 4:
            if (playerLastStylePercent[playerNumber] < 100) { return 100; }
            return playerLastStylePercent[playerNumber];
        case 5: return playerNoHitKills[playerNumber];
        default:
            int gain = playerScoreCache[playerNumber] - mapStartScore[playerNumber];
            if (gain < 0) { gain = 0; }
            return gain;
        }
    }

    private ui int GetContractProgressUI(int playerNumber, int contractType)
    {
        switch (contractType)
        {
        case 0: return mapKillsByPlayer[playerNumber];
        case 1: return mapSecretsByPlayer[playerNumber];
        case 2: return mapBestComboByPlayer[playerNumber];
        case 3: return eliteKillCount[playerNumber];
        case 4:
            if (playerLastStylePercent[playerNumber] < 100) { return 100; }
            return playerLastStylePercent[playerNumber];
        case 5: return playerNoHitKills[playerNumber];
        default:
            int gain = playerScoreCache[playerNumber] - mapStartScore[playerNumber];
            if (gain < 0) { gain = 0; }
            return gain;
        }
    }

    private ui String GetContractValueTextUI(int playerNumber, int slot)
    {
        if (slot < 0 || slot >= 3 || !mapContractsReady)
        {
            return "";
        }

        int contractType = mapContractType[slot];
        int target = mapContractTarget[slot];
        int reward = mapContractReward[slot];
        int progress = GetContractProgressUI(playerNumber, contractType);
        if (progress > target) { progress = target; }

        int flat = GetContractFlatIndex(playerNumber, slot);
        String status = mapContractDone[flat] ? "DONE" : String.Format("%d/%d", progress, target);
        return String.Format("%s %s +%d", GetContractTypeName(contractType), status, reward);
    }

    private play void CheckContractsForPlayer(PlayerPawn player, int playerNumber)
    {
        { CVar cv = CVar.FindCVar('score_contracts_enabled'); if (cv != null && !cv.GetBool()) { return; } }
        if (!IsValidPlayerNumber(playerNumber) || player == null)
        {
            return;
        }

        EnsureMapContractsReady();
        for (int slot = 0; slot < 3; slot++)
        {
            int flat = GetContractFlatIndex(playerNumber, slot);
            if (mapContractDone[flat])
            {
                continue;
            }

            int progress = GetContractProgress(playerNumber, mapContractType[slot]);
            if (progress < mapContractTarget[slot])
            {
                continue;
            }

            mapContractDone[flat] = true;
            int oldScore = GetScore(player);
            ApplyScoreDelta(player, playerNumber, mapContractReward[slot], "TASK");
            GrantPendingRewards(player, playerNumber);
            CheckPrestigeProgress(player, playerNumber);
            NotifyRankUp(playerNumber, oldScore, GetScore(player));
            PushStyleEvent(playerNumber, "TASK COMPLETE");
            if (GetUserBoolPlay(playerNumber, 'score_contracts_sounds_enable', true))
            {
                // Count completed contracts
                int doneCount = 0;
                for (int cs = 0; cs < 3; cs++)
                {
                    if (mapContractDone[GetContractFlatIndex(playerNumber, cs)]) { doneCount++; }
                }
                if (doneCount >= 3)
                {
                    S_StartSound("score/contracts/done", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 0.9, ATTN_NONE);
                }
                else
                {
                    S_StartSound("score/contracts/task", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 0.8, ATTN_NONE);
                }
            }
        }
    }

    private play void PushStyleEvent(int playerNumber, String text)
    {
        if (!IsValidPlayerNumber(playerNumber) || text == "")
        {
            return;
        }

        for (int slot = 0; slot < 9; slot++)
        {
            int dst = GetStyleEventFlatIndex(playerNumber, slot);
            int src = GetStyleEventFlatIndex(playerNumber, slot + 1);
            styleEventQueueText[dst] = styleEventQueueText[src];
            styleEventQueueStartTic[dst] = styleEventQueueStartTic[src];
        }

        int last = GetStyleEventFlatIndex(playerNumber, 9);
        styleEventQueueText[last] = text;
        styleEventQueueStartTic[last] = level.time;
    }

    private ui Font GetContractsFontUI()
    {
        int fontSize = GetUserIntUI('score_contracts_font_size', 0);
        if (fontSize <= 0)
        {
            return SmallFont;
        }
        if (fontSize == 1)
        {
            return NewSmallFont;
        }
        return BigFont;
    }

    private ui Font GetStyleEventsFontUI()
    {
        int fontSize = GetUserIntUI('score_styleevents_font_size', 0);
        if (fontSize <= 0)
        {
            return SmallFont;
        }
        if (fontSize == 1)
        {
            return NewSmallFont;
        }
        return BigFont;
    }

    private ui int GetContractLineColorUI(int slot)
    {
        switch (slot)
        {
        case 0: return GetUIColorFromCVar('score_contracts_color_1', 3);
        case 1: return GetUIColorFromCVar('score_contracts_color_2', 3);
        default: return GetUIColorFromCVar('score_contracts_color_3', 3);
        }
    }

    private ui int GetStyleEventLineColorUI(int lineIndex)
    {
        switch (lineIndex)
        {
        case 0: return GetUIColorFromCVar('score_styleevents_color_1', 7);
        case 1: return GetUIColorFromCVar('score_styleevents_color_2', 7);
        case 2: return GetUIColorFromCVar('score_styleevents_color_3', 7);
        case 3: return GetUIColorFromCVar('score_styleevents_color_4', 7);
        case 4: return GetUIColorFromCVar('score_styleevents_color_5', 7);
        case 5: return GetUIColorFromCVar('score_styleevents_color_6', 7);
        case 6: return GetUIColorFromCVar('score_styleevents_color_7', 7);
        case 7: return GetUIColorFromCVar('score_styleevents_color_8', 7);
        case 8: return GetUIColorFromCVar('score_styleevents_color_9', 7);
        default: return GetUIColorFromCVar('score_styleevents_color_10', 7);
        }
    }

    private ui int GetContractsReservedHeightUI()
    {
        if (!GetUserBoolUI('score_contracts_show', true) || !mapContractsReady)
        {
            return 0;
        }

        Font contractsFont = GetContractsFontUI();
        int lineStep = GetUserIntUI('score_contracts_line_spacing', 12);
        if (lineStep < 8) { lineStep = 8; }
        if (lineStep > 32) { lineStep = 32; }

        int minStep = contractsFont.GetHeight() + 1;
        if (lineStep < minStep) { lineStep = minStep; }

        double scale = GetUIScaleUI('score_contracts_scale', 100);
        return int(((3 * lineStep) + 6) * scale + 0.5);
    }

    private ui int GetStyleEventsVisibleCountUI(int playerNumber)
    {
        if (!GetUserBoolUI('score_styleevents_show', true))
        {
            return 0;
        }

        int maxLines = GetUserIntUI('score_styleevents_lines', 4);
        if (maxLines < 1) { maxLines = 1; }
        if (maxLines > 10) { maxLines = 10; }

        int duration = GetUserIntUI('score_styleevents_duration_tics', 175);
        if (duration < 35) { duration = 35; }
        if (duration > 1400) { duration = 1400; }

        int printed = 0;
        for (int slot = 9; slot >= 0; slot--)
        {
            int flat = GetStyleEventFlatIndex(playerNumber, slot);
            if (styleEventQueueText[flat] == "")
            {
                continue;
            }
            if ((styleEventQueueStartTic[flat] + duration) < level.time)
            {
                continue;
            }
            printed++;
            if (printed >= maxLines)
            {
                break;
            }
        }
        return printed;
    }

    private ui int GetStyleEventsReservedHeightUI(int playerNumber)
    {
        int visible = GetStyleEventsVisibleCountUI(playerNumber);
        if (visible <= 0)
        {
            return 0;
        }

        Font eventFont = GetStyleEventsFontUI();
        int step = eventFont.GetHeight() + 1;
        if (step < 11) { step = 11; }

        double scale = GetUIScaleUI('score_styleevents_scale', 100);
        return int(((visible * step) + 4) * scale + 0.5);
    }

    private ui void DrawContractsUI(int playerNumber)
    {
        if (!GetUserBoolUI('score_contracts_show', true) || !mapContractsReady)
        {
            return;
        }

        Font contractsFont = GetContractsFontUI();
        int lineStep = GetUserIntUI('score_contracts_line_spacing', 12);
        if (lineStep < 8) { lineStep = 8; }
        if (lineStep > 32) { lineStep = 32; }

        int minStep = contractsFont.GetHeight() + 1;
        if (lineStep < minStep) { lineStep = minStep; }

        double scale = GetUIScaleUI('score_contracts_scale', 100);
        int scaledLineStep = int((lineStep * scale) + 0.5);
        if (scaledLineStep < 1) { scaledLineStep = 1; }

        int marginX = GetUserIntUI('score_contracts_right_margin', 0);
        if (marginX < 0) { marginX = 0; }
        int marginY = GetUserIntUI('score_contracts_top_margin', 8);
        if (marginY < 0) { marginY = 0; }

        int corner = GetCornerUI('score_contracts_corner');
        bool isRight = (corner == 1 || corner == 3);
        bool isBottom = (corner == 2 || corner == 3);

        int labelWidth = contractsFont.StringWidth("TASK 3");
        int valueWidth = 0;
        for (int slot = 0; slot < 3; slot++)
        {
            int w = contractsFont.StringWidth(GetContractValueTextUI(playerNumber, slot));
            if (w > valueWidth)
            {
                valueWidth = w;
            }
        }

        int valueGap = 8;
        int blockWidth = int(((labelWidth + valueGap + valueWidth) * scale) + 0.5);
        int blockHeight = 3 * scaledLineStep;

        int x = isRight ? (Screen.GetWidth() - blockWidth - marginX) : marginX;
        int y = isBottom ? (Screen.GetHeight() - marginY - blockHeight) : marginY;
        if (x < 0) { x = 0; }
        if (y < 0) { y = 0; }

        int xDraw = int((x / scale) + 0.5);
        int yDraw = int((y / scale) + 0.5);
        int valueX = xDraw + labelWidth + valueGap;

        BeginScaleTransformUI(scale);
        for (int slot = 0; slot < 3; slot++)
        {
            int color = GetContractLineColorUI(slot);
            DrawHudLine(contractsFont, color, xDraw, valueX, yDraw + (slot * lineStep), String.Format("TASK %d", slot + 1), GetContractValueTextUI(playerNumber, slot));
        }
        EndScaleTransformUI();
    }

    private ui void DrawStyleEventsUI(int playerNumber)
    {
        if (!GetUserBoolUI('score_styleevents_show', true))
        {
            return;
        }

        int maxLines = GetUserIntUI('score_styleevents_lines', 4);
        if (maxLines < 1) { maxLines = 1; }
        if (maxLines > 10) { maxLines = 10; }

        int marginX = GetUserIntUI('score_styleevents_right_margin', 0);
        if (marginX < 0) { marginX = 0; }
        int marginY = GetUserIntUI('score_styleevents_top_margin', 8);
        if (marginY < 0) { marginY = 0; }

        int corner = GetCornerUI('score_styleevents_corner');
        bool isRight = (corner == 1 || corner == 3);
        bool isBottom = (corner == 2 || corner == 3);

        int reserved = 0;
        if (GetUserBoolUI('score_contracts_show', true) && GetCornerUI('score_contracts_corner') == corner)
        {
            reserved = GetContractsReservedHeightUI();
        }

        int duration = GetUserIntUI('score_styleevents_duration_tics', 175);
        if (duration < 35) { duration = 35; }
        if (duration > 1400) { duration = 1400; }

        Font eventFont = GetStyleEventsFontUI();
        double scale = GetUIScaleUI('score_styleevents_scale', 100);
        int step = eventFont.GetHeight() + 1;
        if (step < 11) { step = 11; }
        int scaledStep = int((step * scale) + 0.5);
        if (scaledStep < 1) { scaledStep = 1; }

        int anchorX = isRight ? (Screen.GetWidth() - marginX) : marginX;
        if (anchorX < 0) { anchorX = 0; }
        int baseY = isBottom ? (Screen.GetHeight() - marginY - scaledStep - reserved) : (marginY + reserved);
        if (baseY < 0) { baseY = 0; }

        BeginScaleTransformUI(scale);
        int printed = 0;
        for (int slot = 9; slot >= 0; slot--)
        {
            int flat = GetStyleEventFlatIndex(playerNumber, slot);
            String lineText = styleEventQueueText[flat];
            if (lineText == "")
            {
                continue;
            }
            if ((styleEventQueueStartTic[flat] + duration) < level.time)
            {
                continue;
            }

            int y = isBottom ? (baseY - (printed * scaledStep)) : (baseY + (printed * scaledStep));
            if (y < 0)
            {
                break;
            }

            int lineX = anchorX;
            if (isRight)
            {
                lineX = anchorX - int((eventFont.StringWidth(lineText) * scale) + 0.5);
            }
            if (lineX < 0) { lineX = 0; }

            int drawX = int((lineX / scale) + 0.5);
            int drawY = int((y / scale) + 0.5);
            Screen.DrawText(eventFont, GetStyleEventLineColorUI(printed), drawX, drawY, lineText);
            printed++;
            if (printed >= maxLines)
            {
                break;
            }
        }
        EndScaleTransformUI();
    }

    private play bool IsEligibleEliteMonster(Actor thing)
    {
        if (thing == null || !thing.bIsMonster || thing.bFriendly || PlayerPawn(thing) != null)
        {
            return false;
        }

        return thing.health > 0;
    }

    private play int FindEliteSlot(Actor thing)
    {
        for (int i = 0; i < 3; i++)
        {
            if (eliteMonsterActors[i] == thing)
            {
                return i;
            }
        }
        return -1;
    }

    private play bool IsEliteMonster(Actor thing)
    {
        return FindEliteSlot(thing) >= 0;
    }

    private play void TryAssignEliteMonster(Actor thing)
    {
        { CVar cv = CVar.FindCVar('score_elite_enabled'); if (cv != null && !cv.GetBool()) { return; } }
        if (!IsEligibleEliteMonster(thing) || IsEliteMonster(thing))
        {
            return;
        }

        int activeCount = 0;
        for (int i = 0; i < 3; i++)
        {
            if (eliteMonsterActors[i] != null && eliteMonsterActors[i].health > 0)
            {
                activeCount++;
            }
        }

        if (activeCount >= 3)
        {
            return;
        }

        if (Random(0, 99) > 11)
        {
            return;
        }

        for (int i = 0; i < 3; i++)
        {
            if (eliteMonsterActors[i] != null && eliteMonsterActors[i].health > 0)
            {
                continue;
            }

            eliteMonsterActors[i] = thing;
            Actor aura = Actor.Spawn("EXPEliteAura", thing.pos + (0, 0, thing.height * 0.5), ALLOW_REPLACE);
            if (aura != null)
            {
                aura.target = thing;
            }
            eliteAuraActors[i] = aura;
            break;
        }
    }

    private play void UpdateEliteMonsterAuras()
    {
        for (int i = 0; i < 3; i++)
        {
            Actor monster = eliteMonsterActors[i];
            Actor aura = eliteAuraActors[i];

            if (monster == null || monster.health <= 0)
            {
                if (aura != null)
                {
                    aura.Destroy();
                }
                eliteMonsterActors[i] = null;
                eliteAuraActors[i] = null;
                continue;
            }

            if (aura == null)
            {
                aura = Actor.Spawn("EXPEliteAura", monster.pos + (0, 0, monster.height * 0.5), ALLOW_REPLACE);
                if (aura != null)
                {
                    aura.target = monster;
                }
                eliteAuraActors[i] = aura;
            }

            if (aura != null)
            {
                aura.SetOrigin(monster.pos + (0, 0, monster.height * 0.5), false);
            }
        }
    }

    private play bool IsExcludedEliteLoot(Name t)
    {
        // Ключи
        if (t == 'RedCard' || t == 'BlueCard' || t == 'YellowCard') { return true; }
        if (t == 'RedSkull' || t == 'BlueSkull' || t == 'YellowSkull') { return true; }
        // Минимальные бонусы здоровья/брони (1 единица)
        if (t == 'HealthBonus' || t == 'ArmorBonus') { return true; }
        return false;
    }

    private play Name GetRandomEliteLootType()
    {
        if (shopItemTypes.Size() > 0)
        {
            for (int tries = 0; tries < 16; tries++)
            {
                int index = Random(0, shopItemTypes.Size() - 1);
                if (index >= 0 && index < shopItemTypes.Size() && shopItemTypes[index] != 'None')
                {
                    if (!IsExcludedEliteLoot(shopItemTypes[index]))
                    {
                        return shopItemTypes[index];
                    }
                }
            }
        }

        switch (Random(0, 5))
        {
        case 0: return 'Stimpack';
        case 1: return 'Medikit';
        case 2: return 'ClipBox';
        case 3: return 'ShellBox';
        case 4: return 'ArmorBonus';
        default: return 'Berserk';
        }
    }

    private play void DropEliteLoot(Actor victim)
    {
        if (victim == null)
        {
            return;
        }

        PrimeShopCatalogOnce();
        Name lootType = GetRandomEliteLootType();
        if (lootType == 'None')
        {
            return;
        }

        Actor.Spawn(lootType, victim.pos + (0, 0, victim.height * 0.35), ALLOW_REPLACE);
    }

    private play void HandleAdvancedKill(PlayerPawn killer, Actor victim, int playerNumber, bool barrelStyleKill, int stylePercent)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        bool eliteKill = IsEliteMonster(victim);
        if (eliteKill)
        {
            eliteKillCount[playerNumber]++;
            DropEliteLoot(victim);
            PushStyleEvent(playerNumber, "ELITE KILL");
        }

        if (barrelStyleKill)
        {
            PushStyleEvent(playerNumber, "BARREL");
        }

        if (playerMultiKillCount[playerNumber] >= 3)
        {
            PushStyleEvent(playerNumber, "MULTIKILL");
        }

        if (playerWeaponSwapThisKill[playerNumber])
        {
            PushStyleEvent(playerNumber, "WEAPON SWAP");
        }

        if (playerNoHitKills[playerNumber] > 0 && (playerNoHitKills[playerNumber] % 5) == 0)
        {
            PushStyleEvent(playerNumber, "NO HIT");
        }

        if (stylePercent >= 250)
        {
            PushStyleEvent(playerNumber, "SSS");
        }

        // Multikill escalation
        if (playerMultiKillCount[playerNumber] == 3)
        {
            PushStyleEvent(playerNumber, "TRIPLE KILL");
        }
        else if (playerMultiKillCount[playerNumber] == 4)
        {
            PushStyleEvent(playerNumber, "QUAD KILL");
        }
        else if (playerMultiKillCount[playerNumber] >= 5)
        {
            PushStyleEvent(playerNumber, "MASSACRE");
        }

        // No-hit streak milestones
        if (playerNoHitKills[playerNumber] == 3)
        {
            PushStyleEvent(playerNumber, "UNTOUCHABLE");
        }
        else if (playerNoHitKills[playerNumber] == 10)
        {
            PushStyleEvent(playerNumber, "INVINCIBLE");
        }

        // Weapon swap chain
        if (playerWeaponSwapChain[playerNumber] >= 3)
        {
            PushStyleEvent(playerNumber, "STYLE CHAIN");
        }

        // Elite kill count milestones
        if (eliteKill && eliteKillCount[playerNumber] > 0 && (eliteKillCount[playerNumber] % 3) == 0)
        {
            PushStyleEvent(playerNumber, "ELITE HUNTER");
        }

        // Combo milestones
        if (playerComboCount[playerNumber] == 3)
        {
            PushStyleEvent(playerNumber, "COMBO x3");
        }
        else if (playerComboCount[playerNumber] == 5)
        {
            PushStyleEvent(playerNumber, "COMBO x5");
            PushStyleEvent(playerNumber, "ON FIRE");
        }
        else if (playerComboCount[playerNumber] == 10)
        {
            PushStyleEvent(playerNumber, "COMBO x10");
            PushStyleEvent(playerNumber, "RAMPAGE");
        }
        else if (playerComboCount[playerNumber] == 20)
        {
            PushStyleEvent(playerNumber, "COMBO x20");
            PushStyleEvent(playerNumber, "GODLIKE");
        }

        CheckContractsForPlayer(killer, playerNumber);
    }

    private play void EnsureShopSpecialsReady()
    {
        if (shopSpecialsReady || shopItemTypes.Size() <= 0)
        {
            return;
        }

        int picked[3];
        for (int i = 0; i < 3; i++) { picked[i] = -1; }
        int discounts[3];
        discounts[0] = 15;
        discounts[1] = 25;
        discounts[2] = 40;

        for (int slot = 0; slot < 3; slot++)
        {
            for (int tries = 0; tries < 24; tries++)
            {
                int index = Random(0, shopItemTypes.Size() - 1);
                bool used = false;
                for (int j = 0; j < slot; j++)
                {
                    if (picked[j] == index)
                    {
                        used = true;
                        break;
                    }
                }
                if (used)
                {
                    continue;
                }

                picked[slot] = index;
                shopSpecialTypes[slot] = shopItemTypes[index];
                shopSpecialDiscounts[slot] = discounts[slot];
                break;
            }
        }

        shopSpecialsReady = true;
    }

    private play int GetShopSpecialDiscountValue(Name itemType)
    {
        for (int i = 0; i < 3; i++)
        {
            if (shopSpecialTypes[i] == itemType)
            {
                return shopSpecialDiscounts[i];
            }
        }
        return 0;
    }

    private ui int GetShopSpecialDiscountValueUI(Name itemType)
    {
        for (int i = 0; i < 3; i++)
        {
            if (shopSpecialTypes[i] == itemType)
            {
                return shopSpecialDiscounts[i];
            }
        }
        return 0;
    }

    private play int GetShopSpecialDiscountForCatalogIndex(int catalogIndex)
    {
        if (catalogIndex < 0 || catalogIndex >= shopItemTypes.Size())
        {
            return 0;
        }
        return GetShopSpecialDiscountValue(shopItemTypes[catalogIndex]);
    }

    private ui int GetShopSpecialDiscountForCatalogIndexUI(int catalogIndex)
    {
        if (catalogIndex < 0 || catalogIndex >= shopItemTypes.Size())
        {
            return 0;
        }
        return GetShopSpecialDiscountValueUI(shopItemTypes[catalogIndex]);
    }

    private play int GetShopPriceForCatalogIndex(int catalogIndex)
    {
        if (catalogIndex < 0 || catalogIndex >= shopItemPrices.Size())
        {
            return 0;
        }

        int basePrice = shopItemPrices[catalogIndex];
        int discount = GetShopSpecialDiscountForCatalogIndex(catalogIndex);
        if (discount <= 0)
        {
            return basePrice;
        }

        int finalPrice = basePrice - int((basePrice * discount) / 100);
        if (finalPrice < 1)
        {
            finalPrice = 1;
        }
        return finalPrice;
    }

    private ui int GetShopPriceForCatalogIndexUI(int catalogIndex)
    {
        if (catalogIndex < 0 || catalogIndex >= shopItemPrices.Size())
        {
            return 0;
        }

        int basePrice = shopItemPrices[catalogIndex];
        int discount = GetShopSpecialDiscountForCatalogIndexUI(catalogIndex);
        if (discount <= 0)
        {
            return basePrice;
        }

        int finalPrice = basePrice - int((basePrice * discount) / 100);
        if (finalPrice < 1)
        {
            finalPrice = 1;
        }
        return finalPrice;
    }
}
