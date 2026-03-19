class EXPScoreEventHandler : EventHandler
{
    private int playerScoreCache[MAXPLAYERS];
    private int playerTierCache[MAXPLAYERS];
    private int playerComboCount[MAXPLAYERS];
    private int playerNoHitKills[MAXPLAYERS];
    private int playerLastKillTic[MAXPLAYERS];
    private int playerComboTimeLeft[MAXPLAYERS];
    private int playerPrestigeCache[MAXPLAYERS];
    private int playerLastStylePercent[MAXPLAYERS];
    private Name playerLastWeaponClass[MAXPLAYERS];
    private int playerWeaponRepeatCount[MAXPLAYERS];
    private bool playerWeaponSwapThisKill[MAXPLAYERS];
    private int playerWeaponSwapChain[MAXPLAYERS];
    private int playerMultiKillCount[MAXPLAYERS];
    private int playerMultiKillExpireTic[MAXPLAYERS];
    private int playerLastWeaponStyleTic[MAXPLAYERS];
    private Actor trackedBarrelActors[128];
    private int trackedBarrelOwners[128];
    private int trackedBarrelExpireTics[128];

    private bool mapKillBonusGiven[MAXPLAYERS];
    private bool mapSecretBonusGiven[MAXPLAYERS];
    private bool mapItemBonusGiven[MAXPLAYERS];
    private int lastFoundSecretsCount;
    private int mapStartScore[MAXPLAYERS];
    private int mapKillsByPlayer[MAXPLAYERS];
    private int mapSecretsByPlayer[MAXPLAYERS];
    private int mapBestComboByPlayer[MAXPLAYERS];
    private bool mapPlayerSeen[MAXPLAYERS];
    private int mapTotalMonsters;
    private int mapTotalSecrets;
    private int mapTotalItems;
    private int mapKilledMonstersSnapshot;
    private int mapFoundSecretsSnapshot;
    private int mapFoundItemsSnapshot;
    private int mapLevelTimeSnapshot;
    private int pendingScoreDelta[MAXPLAYERS];

    private int summaryGain[MAXPLAYERS];
    private int summaryKills[MAXPLAYERS];
    private int summarySecrets[MAXPLAYERS];
    private int summaryBestCombo[MAXPLAYERS];
    private int summaryFinalScore[MAXPLAYERS];
    private int summaryPrestige[MAXPLAYERS];
    private bool summaryNewRecord[MAXPLAYERS];
    private bool summaryReady;
    private String summaryMapName;

    private Array<String> recordMapNames;
    private Array<int> recordMapBestGain;

    private String killFeedTextWithWeapon[10];
    private String killFeedTextNoWeapon[10];
    private int killFeedStartTic[10];
    static ui EXPScoreEventHandler GetInstance()
    {
        class<StaticEventHandler> handlerClass = "EXPScoreEventHandler";
        return EXPScoreEventHandler(EventHandler.Find(handlerClass));
    }

    override void NewGame()
    {
        ResetAllRuntime();
    }

    override void WorldLoaded(WorldEvent e)
    {

        if (gamestate == GS_LEVEL)
        {
            ResetMapRuntime(false);
        }
    }

    override void WorldUnloaded(WorldEvent e)
    {
        ApplyOutstandingMapBonuses();
        BuildMapSummary();
    }
    override void PlayerDisconnected(PlayerEvent e)
    {
        if (e.PlayerNumber >= 0 && e.PlayerNumber < MAXPLAYERS)
        {
            ResetPlayerRuntime(e.PlayerNumber);
        }
    }

    override void PlayerEntered(PlayerEvent e)
    {
        SyncPlayerCaches(e.PlayerNumber);
        ResetPlayerCombatState(e.PlayerNumber);
        if (IsValidPlayerNumber(e.PlayerNumber))
        {
            mapPlayerSeen[e.PlayerNumber] = true;
        }

        if (IsValidPlayerNumber(e.PlayerNumber) && PlayerInGame[e.PlayerNumber])
        {
            PlayerPawn player = PlayerPawn(players[e.PlayerNumber].mo);
            if (player != null)
            {
                ApplyQueuedScore(player, e.PlayerNumber);
                mapStartScore[e.PlayerNumber] = GetScore(player);
                mapBestComboByPlayer[e.PlayerNumber] = 1;
            }
        }
    }

    override void WorldThingDamaged(WorldEvent e)
    {
        RegisterBarrelActivatorFromDamage(e);
        PlayerPawn victim = PlayerPawn(e.Thing);
        if (victim == null || victim.player == null)
        {
            return;
        }

        int playerNumber = victim.PlayerNumber();
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        playerNoHitKills[playerNumber] = 0;
        if (playerLastStylePercent[playerNumber] > 100)
        {
            playerLastStylePercent[playerNumber] -= 15;
            if (playerLastStylePercent[playerNumber] < 100)
            {
                playerLastStylePercent[playerNumber] = 100;
            }
        }
    }
    override void WorldThingDied(WorldEvent e)
    {
        if (gamestate == GS_TITLELEVEL)
        {
            return;
        }

        if (e.Thing != null && e.Thing.bIsMonster && level.killed_monsters > mapKilledMonstersSnapshot)
        {
            mapKilledMonstersSnapshot = level.killed_monsters;
        }

        if (HandlePlayerDeathPenalty(e))
        {
            return;
        }

        PlayerPawn killer = ResolvePlayerKiller(e);
        if (killer == null)
        {
            return;
        }

        int playerNumber = killer.PlayerNumber();
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        if (e.Thing == null || !e.Thing.bIsMonster)
        {
            return;
        }

        int oldScore = GetScore(killer);

        int prevCombo = playerComboCount[playerNumber];
        int prevLastKillTic = playerLastKillTic[playerNumber];
        int prevComboTimeLeft = playerComboTimeLeft[playerNumber];
        int prevNoHitKills = playerNoHitKills[playerNumber];
        int prevMapBestCombo = mapBestComboByPlayer[playerNumber];
        int prevStylePercent = playerLastStylePercent[playerNumber];
        Name prevWeaponClass = playerLastWeaponClass[playerNumber];
        int prevWeaponRepeatCount = playerWeaponRepeatCount[playerNumber];
        bool prevWeaponSwapped = playerWeaponSwapThisKill[playerNumber];
        int prevWeaponSwapChain = playerWeaponSwapChain[playerNumber];
        int prevMultiKillCount = playerMultiKillCount[playerNumber];
        int prevMultiKillExpireTic = playerMultiKillExpireTic[playerNumber];
        int prevLastWeaponStyleTic = playerLastWeaponStyleTic[playerNumber];

        UpdateComboState(playerNumber);
        playerNoHitKills[playerNumber]++;

        Name currentWeaponClass = GetReadyWeaponClass(killer);
        UpdateWeaponStyleState(playerNumber, currentWeaponClass);
        UpdateMultiKillState(playerNumber);
        bool barrelStyleKill = IsBarrelStyleKill(e, playerNumber);

        int comboPercent = GetComboPercent(playerNumber);
        int stylePercent = GetStylePercent(killer, e.Thing, playerNumber, currentWeaponClass, barrelStyleKill);
        stylePercent = SmoothStyleTransition(playerNumber, stylePercent);

        int points = EXPScoreRules.GetScoreForKill(e.Thing, killer, comboPercent, stylePercent);
        if (points <= 0)
        {

            playerComboCount[playerNumber] = prevCombo;
            playerLastKillTic[playerNumber] = prevLastKillTic;
            playerComboTimeLeft[playerNumber] = prevComboTimeLeft;
            playerNoHitKills[playerNumber] = prevNoHitKills;
            mapBestComboByPlayer[playerNumber] = prevMapBestCombo;
            playerLastStylePercent[playerNumber] = prevStylePercent;
            playerLastWeaponClass[playerNumber] = prevWeaponClass;
            playerWeaponRepeatCount[playerNumber] = prevWeaponRepeatCount;
            playerWeaponSwapThisKill[playerNumber] = prevWeaponSwapped;
            playerWeaponSwapChain[playerNumber] = prevWeaponSwapChain;
            playerMultiKillCount[playerNumber] = prevMultiKillCount;
            playerMultiKillExpireTic[playerNumber] = prevMultiKillExpireTic;
            playerLastWeaponStyleTic[playerNumber] = prevLastWeaponStyleTic;
            return;
        }
        mapKillsByPlayer[playerNumber]++;
        PlaySSSRankSoundIfNeeded(killer, playerNumber, prevStylePercent, stylePercent);
        playerLastStylePercent[playerNumber] = stylePercent;
        ApplyScoreDelta(killer, playerNumber, points, "");
        GrantPendingRewards(killer, playerNumber);
        CheckPrestigeProgress(killer, playerNumber);
        NotifyRankUp(playerNumber, oldScore, GetScore(killer));
        PushKillFeedEntry(playerNumber, killer, e.Thing, points, barrelStyleKill);

        UpdateLevelSnapshots();
        CheckMapBonusesForPlayer(killer, playerNumber);
        SyncPlayerCaches(playerNumber);
    }

    override void WorldTick()
    {
        if (gamestate == GS_TITLELEVEL)
        {
            return;
        }
        CheckSecretDiscoveryBonuses();

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (!PlayerInGame[i])
            {
                continue;
            }

            mapPlayerSeen[i] = true;
            PlayerPawn player = PlayerPawn(players[i].mo);
            if (player == null)
            {
                continue;
            }
            CheckComboTimeout(i);
            CheckMapBonusesForPlayer(player, i);
            SyncPlayerCaches(i);
        }

        if (gamestate == GS_LEVEL)
        {
            UpdateLevelSnapshots();
            UpdateLiveMapSummarySnapshot();
        }
        else if (!summaryReady && gamestate == GS_INTERMISSION)
        {
            BuildMapSummary();
        }
    }

    override void RenderOverlay(RenderEvent e)
    {

        if (gamestate == GS_TITLELEVEL)
        {
            return;
        }
        int playerNumber = ConsolePlayer;
        bool hasLivePlayer = playerNumber >= 0 && playerNumber < MAXPLAYERS && PlayerInGame[playerNumber];

        if (!hasLivePlayer)
        {
            return;
        }

        if (hasLivePlayer && GetUserBoolUI('score_hud_show', true))
        {
            int score = playerScoreCache[playerNumber];
            int tier = playerTierCache[playerNumber];
            int combo = playerComboCount[playerNumber];
            int comboLeft = playerComboTimeLeft[playerNumber];
            int prestige = playerPrestigeCache[playerNumber];
            int nextReward = EXPRewardRules.GetThresholdForTier(tier);
            int remaining = nextReward - score;
            if (remaining < 0)
            {
                remaining = 0;
            }

            Font hudFont = GetHudFontUI();
            String scoreValue = String.Format("%d", score);
            String nextValue = nextReward < 0 ? "MAX" : String.Format("%d", remaining);
            String rankValue = EXPScoreRules.GetRankNameForScore(score);
            int styleShown = playerLastStylePercent[playerNumber];
            if (styleShown < 1) { styleShown = 100; }
            String styleGrade = GetStyleGradeLabel(styleShown);
            String styleValue = String.Format("%d%% %s", styleShown, styleGrade);
            String prestigeValue = String.Format("%d", prestige);

            int comboShown = combo;
            if (comboShown < 1)
            {
                comboShown = 1;
            }

            int comboSeconds = (comboLeft + 34) / 35;
            if (comboSeconds < 0)
            {
                comboSeconds = 0;
            }

            String comboValue = comboLeft > 0 ? String.Format("x%d (%d)", comboShown, comboSeconds) : "x1";
            int scoreColor = GetUIColorFromCVar('score_hud_color_score', 0);
            int nextColor = GetUIColorFromCVar('score_hud_color_next', 0);
            int rankColor = GetUIColorFromCVar('score_hud_color_rank', 0);
            int comboColor = GetUIColorFromCVar('score_hud_color_combo', 1);
            int styleColor = GetUIColorFromCVar('score_hud_color_style', 1);
            int prestigeColor = GetUIColorFromCVar('score_hud_color_prestige', 0);
            int lineStep = GetUserIntUI('score_hud_line_spacing', 12);
            if (lineStep < 8) { lineStep = 8; }
            if (lineStep > 28) { lineStep = 28; }
            int minStep = hudFont.GetHeight() + 1;
            if (lineStep < minStep) { lineStep = minStep; }

            double hudScale = GetUIScaleUI('score_hud_scale', 100);
            int scaledLineStep = int((lineStep * hudScale) + 0.5);
            if (scaledLineStep < 1) { scaledLineStep = 1; }
            int marginX = GetUserIntUI('score_hud_right_margin', 0);
            if (marginX < 0)
            {
                marginX = 0;
            }

            int marginY = GetUserIntUI('score_hud_top_margin', 0);
            if (marginY < 0)
            {
                marginY = 0;
            }

            int corner = GetCornerUI('score_hud_corner');

            bool isRight = (corner == 1 || corner == 3);
            bool isBottom = (corner == 2 || corner == 3);

            bool showNext = GetUserBoolUI('score_hud_show_next', true);
            bool showRank = GetUserBoolUI('score_hud_show_rank', true);
            bool showCombo = GetUserBoolUI('score_hud_show_combo', true);
            bool showStyle = GetUserBoolUI('score_hud_show_style', true);
            bool showPrestige = GetUserBoolUI('score_hud_show_prestige', true) && GetUserBoolUI('score_prestige_enabled', true);

            int lineCount = 1;
            if (showNext) { lineCount++; }
            if (showRank) { lineCount++; }
            if (showCombo) { lineCount++; }
            if (showStyle) { lineCount++; }
            if (showPrestige) { lineCount++; }

            int labelWidth = hudFont.StringWidth("PRESTIGE");
            int valueWidth = hudFont.StringWidth(scoreValue);
            int w = hudFont.StringWidth(nextValue); if (showNext && w > valueWidth) { valueWidth = w; }
            w = hudFont.StringWidth(rankValue); if (showRank && w > valueWidth) { valueWidth = w; }
            w = hudFont.StringWidth(comboValue); if (showCombo && w > valueWidth) { valueWidth = w; }
            w = hudFont.StringWidth(styleValue); if (showStyle && w > valueWidth) { valueWidth = w; }
            w = hudFont.StringWidth(prestigeValue); if (showPrestige && w > valueWidth) { valueWidth = w; }

            int valueGap = 8;
            int hudBlockWidth = int(((labelWidth + valueGap + valueWidth) * hudScale) + 0.5);
            int hudBlockHeight = lineCount * scaledLineStep;

            int x = isRight ? (Screen.GetWidth() - hudBlockWidth - marginX) : marginX;
            int y = isBottom ? (Screen.GetHeight() - marginY - hudBlockHeight) : (marginY + 8);

            if (x < 0) { x = 0; }
            if (y < 0) { y = 0; }

            int xDraw = int((x / hudScale) + 0.5);
            int yDraw = int((y / hudScale) + 0.5);
            int valueX = xDraw + labelWidth + valueGap;
            int lineIndex = 0;

            BeginScaleTransformUI(hudScale);

            DrawHudLine(hudFont, scoreColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "SCORE", scoreValue);
            lineIndex++;

            if (showNext)
            {
                DrawHudLine(hudFont, nextColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "NEXT", nextValue);
                lineIndex++;
            }

            if (showRank)
            {
                DrawHudLine(hudFont, rankColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "RANK", rankValue);
                lineIndex++;
            }

            if (showCombo)
            {
                DrawHudLine(hudFont, comboColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "COMBO", comboValue);
                lineIndex++;
            }

            if (showStyle)
            {
                DrawHudLine(hudFont, styleColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "STYLE", styleValue);
                lineIndex++;
            }

            if (showPrestige)
            {
                DrawHudLine(hudFont, prestigeColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "PRESTIGE", prestigeValue);
            }

            EndScaleTransformUI();
        }

        if (hasLivePlayer && GetUserBoolUI('score_killfeed_show', true))
        {
            DrawKillFeed();
        }

    }

    override void RenderUnderlay(RenderEvent e)
    {
    }

    private ui void DrawIntermissionSummaryOverlay()
    {
        if (!GetUserBoolUI('score_show_endmap_summary', true))
        {
            return;
        }

        if (!summaryReady)
        {
            return;
        }

        int playerNumber = GetSummaryBestPlayerIndex();
        if (ConsolePlayer >= 0 && ConsolePlayer < MAXPLAYERS)
        {
            playerNumber = ConsolePlayer;
        }

        DrawEndMapSummary(playerNumber);
    }

    private ui void DrawHudLine(Font font, int color, int xLabel, int xValue, int y, String label, String value)
    {
        Screen.DrawText(font, color, xLabel, y, label);
        Screen.DrawText(font, color, xValue, y, value);
    }

    private ui int GetUIColorFromCVar(Name cvarName, int defaultPreset)
    {
        int preset = GetUserIntUI(cvarName, defaultPreset);
        return GetUIColorByPreset(preset);
    }

    private ui int GetKillFeedLineColorUI(int lineIndex)
    {
        switch (lineIndex)
        {
        case 0: return GetUIColorFromCVar('score_killfeed_color_1', 3);
        case 1: return GetUIColorFromCVar('score_killfeed_color_2', 3);
        case 2: return GetUIColorFromCVar('score_killfeed_color_3', 3);
        case 3: return GetUIColorFromCVar('score_killfeed_color_4', 3);
        case 4: return GetUIColorFromCVar('score_killfeed_color_5', 3);
        case 5: return GetUIColorFromCVar('score_killfeed_color_6', 3);
        case 6: return GetUIColorFromCVar('score_killfeed_color_7', 3);
        case 7: return GetUIColorFromCVar('score_killfeed_color_8', 3);
        case 8: return GetUIColorFromCVar('score_killfeed_color_9', 3);
        default: return GetUIColorFromCVar('score_killfeed_color_10', 3);
        }
    }

    private ui int GetUIColorByPreset(int preset)
    {
        switch (preset)
        {
        case 0: return Font.FindFontColor("Gold");
        case 1: return Font.FindFontColor("Green");
        case 2: return Font.FindFontColor("Red");
        case 3: return Font.FindFontColor("LightBlue");
        case 4: return Font.FindFontColor("White");
        case 5: return Font.FindFontColor("Yellow");
        case 6: return Font.FindFontColor("Blue");
        case 7: return Font.FindFontColor("Orange");
        case 8: return Font.FindFontColor("Gray");
        case 9: return Font.FindFontColor("Tan");
        case 10: return Font.FindFontColor("Brick");
        default: return Font.FindFontColor("Gold");
        }
    }

    private ui double GetUIScaleUI(Name cvarName, int defaultPercent)
    {
        int percent = GetUserIntUI(cvarName, defaultPercent);
        if (percent < 50) { percent = 50; }
        if (percent > 300) { percent = 300; }
        return percent / 100.0;
    }

    private ui void BeginScaleTransformUI(double scale)
    {
        if (scale == 1.0)
        {
            return;
        }

        let t = new("Shape2DTransform");
        t.Scale((scale, scale));
        Screen.SetTransform(t);
    }

    private ui void EndScaleTransformUI()
    {
        let identity = new("Shape2DTransform");
        Screen.SetTransform(identity);
    }

    private ui Font GetHudFontUI()
    {
        int fontSize = GetUserIntUI('score_hud_font_size', 0);
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

    private ui Font GetKillFeedFontUI()
    {
        int fontSize = GetUserIntUI('score_killfeed_font_size', 0);
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

    private ui int GetHudReservedHeightUI()
    {
        Font hudFont = GetHudFontUI();
        int lineStep = GetUserIntUI('score_hud_line_spacing', 12);
        if (lineStep < 8) { lineStep = 8; }
        if (lineStep > 28) { lineStep = 28; }

        int minStep = hudFont.GetHeight() + 1;
        if (lineStep < minStep) { lineStep = minStep; }

        int lineCount = 1;
        if (GetUserBoolUI('score_hud_show_next', true)) { lineCount++; }
        if (GetUserBoolUI('score_hud_show_rank', true)) { lineCount++; }
        if (GetUserBoolUI('score_hud_show_combo', true)) { lineCount++; }
        if (GetUserBoolUI('score_hud_show_style', true)) { lineCount++; }
        if (GetUserBoolUI('score_hud_show_prestige', true) && GetUserBoolUI('score_prestige_enabled', true)) { lineCount++; }

        double hudScale = GetUIScaleUI('score_hud_scale', 100);
        return int(((lineCount * lineStep) + 8) * hudScale + 0.5);
    }

    private void ResetAllRuntime()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            ResetPlayerRuntime(i);
            summaryGain[i] = 0;
            summaryKills[i] = 0;
            summarySecrets[i] = 0;
            summaryBestCombo[i] = 1;
            summaryFinalScore[i] = 0;
            summaryPrestige[i] = 0;
            summaryNewRecord[i] = false;
        }

        summaryReady = false;
        summaryMapName = "";

        recordMapNames.Clear();
        recordMapBestGain.Clear();
        ClearKillFeed();
        ClearTrackedBarrelOwners();
    }

    private void ResetMapRuntime(bool clearSummary)
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            mapKillBonusGiven[i] = false;
            mapSecretBonusGiven[i] = false;
            mapItemBonusGiven[i] = false;
            mapPlayerSeen[i] = false;
            ResetPlayerCombatState(i);
            mapStartScore[i] = 0;
            mapKillsByPlayer[i] = 0;
            mapSecretsByPlayer[i] = 0;
            mapBestComboByPlayer[i] = 1;
            if (clearSummary)
            {
                summaryGain[i] = 0;
                summaryKills[i] = 0;
                summarySecrets[i] = 0;
                summaryBestCombo[i] = 1;
                summaryFinalScore[i] = 0;
                summaryPrestige[i] = 0;
                summaryNewRecord[i] = false;
            }
        }

        if (clearSummary)
        {
            summaryReady = false;
            summaryMapName = String.Format("%s", level.mapname);
        }
        mapTotalMonsters = level.total_monsters;
        mapTotalSecrets = level.total_secrets;
        mapTotalItems = level.total_items;
        mapKilledMonstersSnapshot = level.killed_monsters;
        mapFoundSecretsSnapshot = level.found_secrets;
        mapFoundItemsSnapshot = level.found_items;
        mapLevelTimeSnapshot = level.time;
        lastFoundSecretsCount = level.found_secrets;
        ClearKillFeed();
        ClearTrackedBarrelOwners();
    }

    private void ResetPlayerRuntime(int playerNumber)
    {
        playerScoreCache[playerNumber] = 0;
        playerTierCache[playerNumber] = 0;
        playerPrestigeCache[playerNumber] = 0;
        mapKillBonusGiven[playerNumber] = false;
        mapSecretBonusGiven[playerNumber] = false;
        mapItemBonusGiven[playerNumber] = false;
        pendingScoreDelta[playerNumber] = 0;
        playerLastStylePercent[playerNumber] = 100;
        playerLastWeaponClass[playerNumber] = 'None';
        playerWeaponRepeatCount[playerNumber] = 0;
        playerWeaponSwapThisKill[playerNumber] = false;
        playerWeaponSwapChain[playerNumber] = 0;
        playerMultiKillCount[playerNumber] = 0;
        playerMultiKillExpireTic[playerNumber] = 0;
        playerLastWeaponStyleTic[playerNumber] = -1;
        ResetPlayerCombatState(playerNumber);
    }

    private void ResetPlayerCombatState(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        playerComboCount[playerNumber] = 0;
        playerNoHitKills[playerNumber] = 0;
        playerLastKillTic[playerNumber] = 0;
        playerComboTimeLeft[playerNumber] = 0;
        playerLastStylePercent[playerNumber] = 100;
        playerLastWeaponClass[playerNumber] = 'None';
        playerWeaponRepeatCount[playerNumber] = 0;
        playerWeaponSwapThisKill[playerNumber] = false;
        playerWeaponSwapChain[playerNumber] = 0;
        playerMultiKillCount[playerNumber] = 0;
        playerMultiKillExpireTic[playerNumber] = 0;
        playerLastWeaponStyleTic[playerNumber] = -1;
    }

    private ui void DrawEndMapSummary(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return;
        }

        Font f = SmallFont;
        int color = Font.FindFontColor("Red");
        int accent = Font.FindFontColor("Red");
        int step = 14;

        int gain = summaryGain[playerNumber];
        String gainPrefix = gain >= 0 ? "+" : "";
        int finalScore = summaryFinalScore[playerNumber];
        int bestCombo = summaryBestCombo[playerNumber];
        if (bestCombo < 1)
        {
            bestCombo = 1;
        }

        int startY = 108;
        int xShift = 100;
        int leftX = -60 + xShift;
        int rightX = 100 + xShift;

        Screen.DrawText(f, color, leftX, startY + (step * 0), String.Format("GAIN: %s%d", gainPrefix, gain));
        Screen.DrawText(f, color, leftX, startY + (step * 1), String.Format("SCORE: %d", finalScore));
        Screen.DrawText(f, color, leftX, startY + (step * 2), String.Format("BEST COMBO: x%d", bestCombo));

        Screen.DrawText(f, color, rightX, startY + (step * 0), String.Format("RANK: %s", EXPScoreRules.GetRankNameForScore(finalScore)));
        Screen.DrawText(f, color, rightX, startY + (step * 1), String.Format("PRESTIGE: %d", summaryPrestige[playerNumber]));

        if (summaryNewRecord[playerNumber])
        {
            Screen.DrawText(f, accent, rightX, startY + (step * 2), "NEW RECORD!");
        }
    }

    private play void UpdateLiveMapSummarySnapshot()
    {
        summaryMapName = String.Format("%s", level.mapname);
        summaryReady = true;

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            summaryKills[i] = mapKillsByPlayer[i];
            summarySecrets[i] = mapSecretsByPlayer[i];
            summaryBestCombo[i] = mapBestComboByPlayer[i];
            if (summaryBestCombo[i] < 1)
            {
                summaryBestCombo[i] = 1;
            }

            int finalScore = playerScoreCache[i];
            int prestige = playerPrestigeCache[i];
            int gain = finalScore - mapStartScore[i];

            summaryGain[i] = gain;
            summaryFinalScore[i] = finalScore;
            summaryPrestige[i] = prestige;
        }
    }

    private ui int FindSummaryPlayerIndex()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (summaryKills[i] > 0 || summarySecrets[i] > 0 || summaryGain[i] != 0 || summaryFinalScore[i] > 0)
            {
                return i;
            }
        }

        return 0;
    }

    private play void CheckSecretDiscoveryBonuses()
    {
        int currentSecrets = level.found_secrets;
        if (currentSecrets <= lastFoundSecretsCount)
        {
            return;
        }

        int gained = currentSecrets - lastFoundSecretsCount;
        lastFoundSecretsCount = currentSecrets;
        if (currentSecrets > mapFoundSecretsSnapshot)
        {
            mapFoundSecretsSnapshot = currentSecrets;
        }

        if (gained <= 0 || score_secret_found_bonus <= 0)
        {
            return;
        }

        int points = gained * score_secret_found_bonus;

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (!PlayerInGame[i])
            {
                continue;
            }

            mapPlayerSeen[i] = true;
            PlayerPawn player = PlayerPawn(players[i].mo);
            if (player == null)
            {
                continue;
            }
            mapSecretsByPlayer[i] += gained;
            int oldScore = GetScore(player);
            ApplyScoreDelta(player, i, points, "SEC");
            GrantPendingRewards(player, i);
            CheckPrestigeProgress(player, i);
            NotifyRankUp(i, oldScore, GetScore(player));
        }
    }

    private ui void DrawKillFeed()
    {
        int maxLines = GetUserIntUI('score_killfeed_lines', 5);
        if (maxLines < 1)
        {
            maxLines = 1;
        }
        if (maxLines > 10)
        {
            maxLines = 10;
        }

        int marginX = GetUserIntUI('score_killfeed_right_margin', 0);
        if (marginX < 0)
        {
            marginX = 0;
        }

        int marginY = GetUserIntUI('score_killfeed_top_margin', 44);
        if (marginY < 0)
        {
            marginY = 0;
        }

        int corner = GetCornerUI('score_killfeed_corner');

        bool isRight = (corner == 1 || corner == 3);
        bool isBottom = (corner == 2 || corner == 3);

        int hudReserved = 0;
        if (GetUserBoolUI('score_hud_show', true))
        {
            int hudCorner = GetCornerUI('score_hud_corner');
            if (hudCorner == corner)
            {
                hudReserved = GetHudReservedHeightUI();
            }
        }

        int anchorX = isRight ? (Screen.GetWidth() - marginX) : marginX;
        if (anchorX < 0) { anchorX = 0; }

        int duration = GetUserIntUI('score_killfeed_duration_tics', 175);
        if (duration < 35)
        {
            duration = 35;
        }
        if (duration > 1400)
        {
            duration = 1400;
        }

        Font feedFont = GetKillFeedFontUI();
        bool showWeapon = GetUserBoolUI('score_killfeed_show_weapon', true);
        double feedScale = GetUIScaleUI('score_killfeed_scale', 100);
        int printed = 0;
        int step = feedFont.GetHeight() + 1;
        if (step < 11) { step = 11; }
        int scaledStep = int((step * feedScale) + 0.5);
        if (scaledStep < 1) { scaledStep = 1; }
        int baseY = isBottom ? (Screen.GetHeight() - marginY - scaledStep - hudReserved) : (marginY + hudReserved);
        if (baseY < 0) { baseY = 0; }

        BeginScaleTransformUI(feedScale);

        for (int i = 9; i >= 0; i--)
        {
            if ((killFeedStartTic[i] + duration) < level.time)
            {
                continue;
            }

            String lineText = showWeapon ? killFeedTextWithWeapon[i] : killFeedTextNoWeapon[i];
            if (lineText == "")
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
                lineX = anchorX - int((feedFont.StringWidth(lineText) * feedScale) + 0.5);
            }
            if (lineX < 0) { lineX = 0; }

            int lineColor = GetKillFeedLineColorUI(printed);
            int drawX = int((lineX / feedScale) + 0.5);
            int drawY = int((y / feedScale) + 0.5);
            Screen.DrawText(feedFont, lineColor, drawX, drawY, lineText);
            printed++;

            if (printed >= maxLines)
            {
                break;
            }
        }
        EndScaleTransformUI();
    }

    private void PushKillFeedEntry(int playerNumber, PlayerPawn killer, Actor victim, int points, bool barrelStyleKill)
    {
        if (!IsValidPlayerNumber(playerNumber) || points <= 0)
        {
            return;
        }

        int combo = playerComboCount[playerNumber];
        if (combo < 1)
        {
            combo = 1;
        }

        String victimName = EXPScoreRules.GetEnemyDisplayName(victim);
        String weaponName = EXPScoreRules.GetWeaponDisplayName(killer);
        String lineWithWeapon;
        String lineNoWeapon;

        if (barrelStyleKill)
        {
            lineWithWeapon = String.Format("P%d %s > Barrel -> %s +%d", playerNumber + 1, weaponName, victimName, points);
            lineNoWeapon = String.Format("P%d Barrel -> %s +%d", playerNumber + 1, victimName, points);
        }
        else
        {
            lineWithWeapon = String.Format("P%d %s -> %s +%d", playerNumber + 1, weaponName, victimName, points);
            lineNoWeapon = String.Format("P%d %s +%d", playerNumber + 1, victimName, points);
        }

        if (combo > 1)
        {
            lineWithWeapon = String.Format("%s x%d", lineWithWeapon, combo);
            lineNoWeapon = String.Format("%s x%d", lineNoWeapon, combo);
        }

        PushKillFeedText(lineWithWeapon, lineNoWeapon);
    }

    private void PushKillFeedText(String lineWithWeapon, String lineNoWeapon)
    {
        if (lineWithWeapon == "" && lineNoWeapon == "")
        {
            return;
        }

        for (int i = 0; i < 9; i++)
        {
            killFeedTextWithWeapon[i] = killFeedTextWithWeapon[i + 1];
            killFeedTextNoWeapon[i] = killFeedTextNoWeapon[i + 1];
            killFeedStartTic[i] = killFeedStartTic[i + 1];
        }

        killFeedTextWithWeapon[9] = lineWithWeapon;
        killFeedTextNoWeapon[9] = lineNoWeapon;
        killFeedStartTic[9] = level.time;
    }

    private void ClearKillFeed()
    {
        for (int i = 0; i < 10; i++)
        {
            killFeedTextWithWeapon[i] = "";
            killFeedTextNoWeapon[i] = "";
            killFeedStartTic[i] = 0;
        }
    }

    private ui int GetUIPlayerNumber()
    {
        int playerNumber = ConsolePlayer;
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            playerNumber = 0;
        }

        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return -1;
        }

        return playerNumber;
    }

    private ui bool GetUserBoolUI(Name cvarName, bool defaultValue)
    {
        int playerNumber = GetUIPlayerNumber();
        if (playerNumber < 0)
        {
            return defaultValue;
        }

        let cv = CVar.GetCVar(cvarName, players[playerNumber]);
        if (cv == null)
        {
            return defaultValue;
        }

        return cv.GetBool();
    }

    private ui int GetCornerUI(Name localCornerCvar)
    {
        int corner;

        if (GetUserBoolUI('score_ui_use_global_corner', true))
        {
            corner = GetUserIntUI('score_ui_corner', 0);
        }
        else
        {
            corner = GetUserIntUI(localCornerCvar, 0);
        }

        if (corner < 0 || corner > 3)
        {
            corner = 0;
        }

        return corner;
    }

    private ui int GetUserIntUI(Name cvarName, int defaultValue)
    {
        int playerNumber = GetUIPlayerNumber();
        if (playerNumber < 0)
        {
            return defaultValue;
        }

        let cv = CVar.GetCVar(cvarName, players[playerNumber]);
        if (cv == null)
        {
            return defaultValue;
        }

        return cv.GetInt();
    }

    private play void SyncPlayerCaches(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS || !PlayerInGame[playerNumber])
        {
            return;
        }

        PlayerPawn player = PlayerPawn(players[playerNumber].mo);
        if (player == null)
        {
            return;
        }

        playerScoreCache[playerNumber] = GetScore(player);
        playerTierCache[playerNumber] = GetRewardTier(player);
        playerPrestigeCache[playerNumber] = GetPrestige(player);

        if (mapStartScore[playerNumber] == 0 && level.time <= TICRATE)
        {
            mapStartScore[playerNumber] = playerScoreCache[playerNumber];
        }
    }

    private bool IsValidPlayerNumber(int playerNumber)
    {
        return playerNumber >= 0 && playerNumber < MAXPLAYERS;
    }

    private bool HasMapParticipation(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return false;
        }

        if (PlayerInGame[playerNumber])
        {
            return true;
        }

        if (mapPlayerSeen[playerNumber])
        {
            return true;
        }

        if (mapKillsByPlayer[playerNumber] > 0 || mapSecretsByPlayer[playerNumber] > 0)
        {
            return true;
        }

        if (playerScoreCache[playerNumber] != 0 || mapStartScore[playerNumber] != 0)
        {
            return true;
        }

        return false;
    }

    private void UpdateComboState(int playerNumber)
    {
        int window = score_combo_window_tics;
        if (window < 1)
        {
            window = 1;
        }

        if (playerLastKillTic[playerNumber] > 0 && (level.time - playerLastKillTic[playerNumber]) <= window)
        {
            playerComboCount[playerNumber]++;
        }
        else
        {
            playerComboCount[playerNumber] = 1;
        }

        playerLastKillTic[playerNumber] = level.time;
        playerComboTimeLeft[playerNumber] = window;

        if (playerComboCount[playerNumber] > mapBestComboByPlayer[playerNumber])
        {
            mapBestComboByPlayer[playerNumber] = playerComboCount[playerNumber];
        }
    }

    private void CheckComboTimeout(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber) || playerComboCount[playerNumber] <= 0)
        {
            return;
        }

        int window = score_combo_window_tics;
        if (window < 1)
        {
            window = 1;
        }

        if ((level.time - playerLastKillTic[playerNumber]) > window)
        {
            playerComboCount[playerNumber] = 0;
            playerComboTimeLeft[playerNumber] = 0;
            playerLastStylePercent[playerNumber] = 100;
            playerLastWeaponClass[playerNumber] = 'None';
            playerWeaponRepeatCount[playerNumber] = 0;
            playerWeaponSwapThisKill[playerNumber] = false;
            playerWeaponSwapChain[playerNumber] = 0;
            playerMultiKillCount[playerNumber] = 0;
            playerMultiKillExpireTic[playerNumber] = 0;
            playerLastWeaponStyleTic[playerNumber] = -1;
        }
        else
        {
            int left = window - (level.time - playerLastKillTic[playerNumber]);
            if (left < 0)
            {
                left = 0;
            }

            playerComboTimeLeft[playerNumber] = left;
        }
    }

    private int GetComboPercent(int playerNumber)
    {
        int step = score_combo_step_percent;
        if (step < 0)
        {
            step = 0;
        }

        int maxPercent = score_combo_max_percent;
        if (maxPercent < 100)
        {
            maxPercent = 100;
        }

        int combo = playerComboCount[playerNumber];
        if (combo < 1)
        {
            return 100;
        }

        int result = 100 + ((combo - 1) * step);
        if (result > maxPercent)
        {
            result = maxPercent;
        }

        return result;
    }

    private int GetStylePercent(PlayerPawn killer, Actor victim, int playerNumber, Name currentWeaponClass, bool barrelStyleKill)
    {
        int stylePercent = 100;

        if (victim != null && score_close_range_bonus_percent > 0 && score_close_range_distance > 0)
        {
            if (killer.Distance2D(victim) <= score_close_range_distance)
            {
                stylePercent += score_close_range_bonus_percent;
            }
        }

        int noHitNeed = score_nohit_kills;
        if (noHitNeed < 1)
        {
            noHitNeed = 1;
        }

        if (score_nohit_bonus_percent > 0 && playerNoHitKills[playerNumber] >= noHitNeed)
        {
            stylePercent += score_nohit_bonus_percent;
        }

        if (barrelStyleKill && score_style_barrel_bonus_percent > 0)
        {
            stylePercent += score_style_barrel_bonus_percent;
        }

        if (score_style_weapon_swap_bonus_percent > 0 && playerWeaponSwapThisKill[playerNumber])
        {
            int chain = playerWeaponSwapChain[playerNumber];
            if (chain < 1) { chain = 1; }
            stylePercent += score_style_weapon_swap_bonus_percent * chain;
        }

        int repeatStep = score_style_repeat_penalty_step;
        if (repeatStep < 0)
        {
            repeatStep = 0;
        }

        if (repeatStep > 0 && currentWeaponClass != 'None')
        {
            int repeatCount = playerWeaponRepeatCount[playerNumber];
            int repeatStartKill = score_style_repeat_start_kill;
            if (repeatStartKill < 2)
            {
                repeatStartKill = 2;
            }

            if (repeatCount >= repeatStartKill)
            {
                int penaltyStacks = repeatCount - repeatStartKill + 1;
                int penalty = penaltyStacks * repeatStep;
                int penaltyMax = score_style_repeat_penalty_max;
                if (penaltyMax > 0 && penalty > penaltyMax)
                {
                    penalty = penaltyMax;
                }
                stylePercent -= penalty;
            }
        }

        stylePercent += GetMultiKillStyleBonus(playerMultiKillCount[playerNumber]);

        if (stylePercent < 1)
        {
            stylePercent = 1;
        }

        return stylePercent;
    }

    private int SmoothStyleTransition(int playerNumber, int computedStyle)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return computedStyle;
        }

        int prevStyle = playerLastStylePercent[playerNumber];
        if (prevStyle < 100)
        {
            prevStyle = 100;
        }

        if (computedStyle >= prevStyle)
        {
            return computedStyle;
        }

        if (playerComboTimeLeft[playerNumber] <= 0)
        {
            return computedStyle;
        }

        int maxDropPerKill = 20;
        int minAllowed = prevStyle - maxDropPerKill;
        if (minAllowed < 100)
        {
            minAllowed = 100;
        }

        if (computedStyle < minAllowed)
        {
            return minAllowed;
        }

        return computedStyle;
    }

    private play void PlaySSSRankSoundIfNeeded(PlayerPawn player, int playerNumber, int prevStylePercent, int newStylePercent)
    {
        if (player == null || !IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        if (prevStylePercent >= 210 || newStylePercent < 210)
        {
            return;
        }

        if (!GetUserBoolPlay(playerNumber, 'score_sss_sound', true))
        {
            return;
        }

        int index = Random(0, 7);
        player.A_StartSound(String.Format("score/sss%d", index), CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
    }

    private int GetMultiKillStyleBonus(int multiKillCount)
    {
        int b2 = score_style_multikill_bonus2;
        int b3 = score_style_multikill_bonus3;
        int b4 = score_style_multikill_bonus4;

        if (b2 < 0) { b2 = 0; }
        if (b3 < 0) { b3 = 0; }
        if (b4 < 0) { b4 = 0; }

        if (multiKillCount >= 4)
        {
            return b4;
        }

        if (multiKillCount == 3)
        {
            return b3;
        }

        if (multiKillCount == 2)
        {
            return b2;
        }

        return 0;
    }

    private Name GetReadyWeaponClass(PlayerPawn killer)
    {
        if (killer == null || killer.player == null || killer.player.ReadyWeapon == null)
        {
            return 'None';
        }

        return killer.player.ReadyWeapon.GetClassName();
    }

    private void UpdateWeaponStyleState(int playerNumber, Name weaponClass)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        if (weaponClass == 'None')
        {
            playerWeaponSwapThisKill[playerNumber] = false;
            return;
        }

        int nowTic = level.time;
        Name prevWeaponClass = playerLastWeaponClass[playerNumber];

        if (prevWeaponClass == weaponClass && playerLastWeaponStyleTic[playerNumber] == nowTic)
        {
            return;
        }

        bool swapped = prevWeaponClass != 'None' && prevWeaponClass != weaponClass;

        if (prevWeaponClass == weaponClass)
        {
            playerWeaponRepeatCount[playerNumber]++;
            playerWeaponSwapChain[playerNumber] = 0;
        }
        else
        {
            playerWeaponRepeatCount[playerNumber] = 1;
            if (swapped)
            {
                playerWeaponSwapChain[playerNumber]++;
            }
        }

        playerLastWeaponClass[playerNumber] = weaponClass;
        playerWeaponSwapThisKill[playerNumber] = swapped;
        playerLastWeaponStyleTic[playerNumber] = nowTic;
    }

    private void UpdateMultiKillState(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        int window = score_style_multikill_window_tics;
        if (window < 1)
        {
            window = 1;
        }

        if (playerMultiKillExpireTic[playerNumber] >= level.time)
        {
            playerMultiKillCount[playerNumber]++;
        }
        else
        {
            playerMultiKillCount[playerNumber] = 1;
        }

        playerMultiKillExpireTic[playerNumber] = level.time + window;
    }

    private ui String GetStyleGradeLabel(int stylePercent)
    {
        if (stylePercent >= 210) { return "SSS"; }
        if (stylePercent >= 180) { return "SS"; }
        if (stylePercent >= 155) { return "S"; }
        if (stylePercent >= 135) { return "A"; }
        if (stylePercent >= 115) { return "B"; }
        if (stylePercent >= 100) { return "C"; }
        if (stylePercent >= 85) { return "D"; }
        return "E";
    }

    private play bool HandlePlayerDeathPenalty(WorldEvent e)
    {
        if (e.Thing == null || e.Thing.player == null)
        {
            return false;
        }

        PlayerPawn victim = PlayerPawn(e.Thing);
        if (victim == null)
        {
            return true;
        }

        int playerNumber = victim.PlayerNumber();
        if (!IsValidPlayerNumber(playerNumber))
        {
            return true;
        }

        ResetPlayerCombatState(playerNumber);

        return true;
    }
    private play void ApplyOutstandingMapBonuses()
    {
        UpdateLevelSnapshots();

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (!HasMapParticipation(i))
            {
                continue;
            }

            PlayerPawn player = PlayerPawn(players[i].mo);
            CheckMapBonusesForPlayer(player, i);

            if (player != null)
            {
                SyncPlayerCaches(i);
            }
        }
    }

    private void UpdateLevelSnapshots()
    {
        if (level.total_monsters > mapTotalMonsters) { mapTotalMonsters = level.total_monsters; }
        if (level.total_secrets > mapTotalSecrets) { mapTotalSecrets = level.total_secrets; }
        if (level.total_items > mapTotalItems) { mapTotalItems = level.total_items; }
        if (level.killed_monsters > mapKilledMonstersSnapshot) { mapKilledMonstersSnapshot = level.killed_monsters; }
        if (level.found_secrets > mapFoundSecretsSnapshot) { mapFoundSecretsSnapshot = level.found_secrets; }
        if (level.found_items > mapFoundItemsSnapshot) { mapFoundItemsSnapshot = level.found_items; }
        if (level.time > mapLevelTimeSnapshot) { mapLevelTimeSnapshot = level.time; }
    }
    private play void CheckMapBonusesForPlayer(PlayerPawn player, int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        int totalMonsters = mapTotalMonsters;
        int totalSecrets = mapTotalSecrets;
        int totalItems = mapTotalItems;
        int killedMonsters = mapKilledMonstersSnapshot;
        int foundSecrets = mapFoundSecretsSnapshot;
        int foundItems = mapFoundItemsSnapshot;

        if (level.total_monsters > totalMonsters) { totalMonsters = level.total_monsters; }
        if (level.total_secrets > totalSecrets) { totalSecrets = level.total_secrets; }
        if (level.total_items > totalItems) { totalItems = level.total_items; }
        if (level.killed_monsters > killedMonsters) { killedMonsters = level.killed_monsters; }
        if (level.found_secrets > foundSecrets) { foundSecrets = level.found_secrets; }
        if (level.found_items > foundItems) { foundItems = level.found_items; }

        bool killsDone = (totalMonsters > 0) && (killedMonsters >= totalMonsters);
        bool secretsDone = (totalSecrets > 0) && (foundSecrets >= totalSecrets);
        bool itemsDone = (totalItems > 0) && (foundItems >= totalItems);

        int killBonus = score_bonus_kills100;
        if (killBonus <= 0) { killBonus = 1200; }

        int secretBonus = score_bonus_secrets100;
        if (secretBonus <= 0) { secretBonus = 900; }

        int itemBonus = score_bonus_items100;
        if (itemBonus <= 0) { itemBonus = 800; }

        if (!mapKillBonusGiven[playerNumber] && killsDone)
        {
            mapKillBonusGiven[playerNumber] = true;
            AwardMapBonusForPlayer(player, playerNumber, killBonus, "K100");
        }

        if (!mapSecretBonusGiven[playerNumber] && secretsDone)
        {
            mapSecretBonusGiven[playerNumber] = true;
            AwardMapBonusForPlayer(player, playerNumber, secretBonus, "S100");
        }

        if (!mapItemBonusGiven[playerNumber] && itemsDone)
        {
            mapItemBonusGiven[playerNumber] = true;
            AwardMapBonusForPlayer(player, playerNumber, itemBonus, "I100");
        }
    }

    private play void AwardMapBonusForPlayer(PlayerPawn player, int playerNumber, int amount, String reason)
    {
        if (!IsValidPlayerNumber(playerNumber) || amount == 0)
        {
            return;
        }

        int oldScore = playerScoreCache[playerNumber];
        if (player != null)
        {
            oldScore = GetScore(player);
        }
        ApplyScoreDelta(player, playerNumber, amount, reason);

        if (player != null)
        {
            GrantPendingRewards(player, playerNumber);
            CheckPrestigeProgress(player, playerNumber);
            NotifyRankUp(playerNumber, oldScore, GetScore(player));
            PlayMapBonusSound(player, playerNumber, reason);
        }
    }

    private play void PlayMapBonusSound(PlayerPawn player, int playerNumber, String reason)
    {
        if (player == null || !IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        if (reason == "K100")
        {
            if (GetUserBoolPlay(playerNumber, 'score_sound_kills100', true))
            {
                player.A_StartSound("score/kills100", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
            }
            return;
        }

        if (reason == "I100")
        {
            if (GetUserBoolPlay(playerNumber, 'score_sound_items100', true))
            {
                player.A_StartSound("score/items100", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
            }
            return;
        }

        if (reason == "S100")
        {
            if (GetUserBoolPlay(playerNumber, 'score_sound_secrets100', true))
            {
                player.A_StartSound("score/secrets100", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
            }
        }
    }

    private play void ApplyScoreDelta(PlayerPawn player, int playerNumber, int delta, String reason)
    {
        if (!IsValidPlayerNumber(playerNumber) || delta == 0)
        {
            return;
        }

        int oldScore = playerScoreCache[playerNumber];
        if (player != null)
        {
            oldScore = GetScore(player);
        }
        int applied = delta;

        if (delta > 0)
        {
            if (player != null)
            {
                ScriptUtil.GiveInventory(player, 'EXPScoreToken', delta);
            }
            else
            {
                pendingScoreDelta[playerNumber] += delta;
            }
        }
        else
        {
            if (player == null)
            {
                return;
            }

            int removeAmount = -delta;
            if (removeAmount > oldScore)
            {
                removeAmount = oldScore;
            }

            if (removeAmount <= 0)
            {
                return;
            }

            let scoreToken = player.FindInventory('EXPScoreToken');
            if (scoreToken == null)
            {
                return;
            }

            scoreToken.Amount -= removeAmount;
            applied = -removeAmount;
        }

        if (player != null)
        {
            playerScoreCache[playerNumber] = GetScore(player);
            playerTierCache[playerNumber] = GetRewardTier(player);
            playerPrestigeCache[playerNumber] = GetPrestige(player);
        }
        else
        {
            int updated = playerScoreCache[playerNumber] + applied;
            if (updated < 0) { updated = 0; }
            playerScoreCache[playerNumber] = updated;
        }

        if (reason != "")
        {
            if (!GetUserBoolPlay(playerNumber, 'score_log_score_events', true))
            {
                return;
            }

            String deltaText = String.Format("%d", applied);
            if (applied > 0)
            {
                deltaText = String.Format("+%d", applied);
            }

            Console.Printf("P%d %s %s %d\n", playerNumber + 1, reason, deltaText, playerScoreCache[playerNumber]);
        }
    }

    private play void ApplyQueuedScore(PlayerPawn player, int playerNumber)
    {
        if (player == null || !IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        int queued = pendingScoreDelta[playerNumber];
        if (queued <= 0)
        {
            return;
        }

        int oldScore = GetScore(player);
        ScriptUtil.GiveInventory(player, 'EXPScoreToken', queued);
        pendingScoreDelta[playerNumber] = 0;

        playerScoreCache[playerNumber] = GetScore(player);
        playerTierCache[playerNumber] = GetRewardTier(player);
        playerPrestigeCache[playerNumber] = GetPrestige(player);

        GrantPendingRewards(player, playerNumber);
        CheckPrestigeProgress(player, playerNumber);
        NotifyRankUp(playerNumber, oldScore, GetScore(player));
    }
    private play int GetScore(PlayerPawn player)
    {
        return GetTokenAmount(player, 'EXPScoreToken');
    }

    private play int GetRewardTier(PlayerPawn player)
    {
        return GetTokenAmount(player, 'EXPRewardTierToken');
    }

    private play int GetPrestige(PlayerPawn player)
    {
        return GetTokenAmount(player, 'EXPPrestigeToken');
    }

    private play int GetTokenAmount(PlayerPawn player, Name tokenName)
    {
        if (player == null)
        {
            return 0;
        }

        let inv = player.FindInventory(tokenName);
        if (inv == null)
        {
            return 0;
        }

        return inv.Amount;
    }

    private play void GrantPendingRewards(PlayerPawn player, int playerNumber)
    {
        if (player == null || !IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        int score = GetScore(player);
        int tier = GetRewardTier(player);
        int earnedTiers = 0;

        while (true)
        {
            int threshold = EXPRewardRules.GetThresholdForTier(tier);
            if (threshold < 0 || score < threshold)
            {
                break;
            }

            EXPRewardRules.GiveTierReward(player, tier);
            tier++;
            earnedTiers++;
        }

        if (earnedTiers > 0)
        {
            ScriptUtil.GiveInventory(player, 'EXPRewardTierToken', earnedTiers);
            playerTierCache[playerNumber] = tier;
        }
    }

    private play void CheckPrestigeProgress(PlayerPawn player, int playerNumber)
    {
        if (player == null || !IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        if (!GetUserBoolPlay(playerNumber, 'score_prestige_enabled', true))
        {
            return;
        }

        int requirement = EXPScoreRules.GetPrestigeRequirement();
        if (requirement <= 0)
        {
            return;
        }

        let scoreToken = player.FindInventory('EXPScoreToken');
        if (scoreToken == null)
        {
            return;
        }

        int loops = 0;
        while (scoreToken.Amount >= requirement && loops < 100)
        {
            scoreToken.Amount -= requirement;
            ScriptUtil.GiveInventory(player, 'EXPPrestigeToken', 1);

            let tierToken = player.FindInventory('EXPRewardTierToken');
            if (tierToken != null)
            {
                tierToken.Amount = 0;
            }

            loops++;
        }

        if (loops > 0)
        {
            playerScoreCache[playerNumber] = GetScore(player);
            playerTierCache[playerNumber] = GetRewardTier(player);
            playerPrestigeCache[playerNumber] = GetPrestige(player);

            if (GetUserBoolPlay(playerNumber, 'score_log_score_events', true))
            {
                Console.Printf("P%d PRE %d\n", playerNumber + 1, playerPrestigeCache[playerNumber]);
            }

            if (GetUserBoolPlay(playerNumber, 'score_prestige_sound', true))
            {
                player.A_StartSound("score/prestige", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
            }
        }
    }

    private play void NotifyRankUp(int playerNumber, int oldScore, int newScore)
    {
        int oldRank = EXPScoreRules.GetRankIndexForScore(oldScore);
        int newRank = EXPScoreRules.GetRankIndexForScore(newScore);
        if (newRank <= oldRank)
        {
            return;
        }

        if (GetUserBoolPlay(playerNumber, 'score_log_score_events', true))
        {
            Console.Printf("P%d R %s\n", playerNumber + 1, EXPScoreRules.GetRankNameByIndex(newRank));
        }

        if (GetUserBoolPlay(playerNumber, 'score_rankup_sound', true))
        {
            PlayerPawn player = PlayerPawn(players[playerNumber].mo);
            if (player != null)
            {
                player.A_StartSound("score/newrank", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
            }
        }
    }

    private play bool GetUserBoolPlay(int playerNumber, Name cvarName, bool defaultValue)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS || !PlayerInGame[playerNumber])
        {
            return defaultValue;
        }

        let cv = CVar.GetCVar(cvarName, players[playerNumber]);
        if (cv == null)
        {
            return defaultValue;
        }

        return cv.GetBool();
    }

    private PlayerPawn GetPlayerPawnByNumber(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber) || !PlayerInGame[playerNumber])
        {
            return null;
        }

        return PlayerPawn(players[playerNumber].mo);
    }

    private void RegisterBarrelActivatorFromDamage(WorldEvent e)
    {
        if (e.Thing == null || !IsTrackedBarrelActor(e.Thing))
        {
            return;
        }

        PlayerPawn activator = TryGetOwningPlayerPawn(e.DamageSource);
        if (activator == null)
        {
            activator = TryGetOwningPlayerPawn(e.Inflictor);
        }

        if (activator == null)
        {
            return;
        }

        int playerNumber = activator.PlayerNumber();
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        RegisterTrackedBarrelOwner(e.Thing, playerNumber);
    }

    private bool IsTrackedBarrelActor(Actor thing)
    {
        if (thing == null)
        {
            return false;
        }

        String className = String.Format("%s", thing.GetClassName()).MakeLower();
        return thing is "ExplosiveBarrel" || className.IndexOf("barrel") >= 0;
    }

    private void RegisterTrackedBarrelOwner(Actor barrel, int playerNumber)
    {
        if (barrel == null || !IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        int emptySlot = -1;
        int expireTic = level.time + (35 * 8);
        for (int i = 0; i < 128; i++)
        {
            if (trackedBarrelActors[i] == barrel)
            {
                trackedBarrelOwners[i] = playerNumber;
                trackedBarrelExpireTics[i] = expireTic;
                return;
            }

            if (emptySlot < 0 && (trackedBarrelActors[i] == null || trackedBarrelExpireTics[i] < level.time))
            {
                emptySlot = i;
            }
        }

        if (emptySlot >= 0)
        {
            trackedBarrelActors[emptySlot] = barrel;
            trackedBarrelOwners[emptySlot] = playerNumber;
            trackedBarrelExpireTics[emptySlot] = expireTic;
        }
    }

    private void ClearTrackedBarrelOwners()
    {
        for (int i = 0; i < 128; i++)
        {
            trackedBarrelActors[i] = null;
            trackedBarrelOwners[i] = -1;
            trackedBarrelExpireTics[i] = 0;
        }
    }

    private int GetTrackedBarrelOwner(Actor source)
    {
        if (source == null)
        {
            return -1;
        }

        for (int i = 0; i < 128; i++)
        {
            if (trackedBarrelActors[i] == null)
            {
                continue;
            }

            if (trackedBarrelExpireTics[i] < level.time)
            {
                trackedBarrelActors[i] = null;
                trackedBarrelOwners[i] = -1;
                trackedBarrelExpireTics[i] = 0;
                continue;
            }

            if (trackedBarrelActors[i] == source)
            {
                return trackedBarrelOwners[i];
            }
        }

        return -1;
    }

    private bool IsPlayerOwnedBarrelSource(Actor source, int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber) || source == null)
        {
            return false;
        }

        if (GetTrackedBarrelOwner(source) == playerNumber)
        {
            return true;
        }

        if (source.master != null && GetTrackedBarrelOwner(source.master) == playerNumber)
        {
            return true;
        }

        if (source.tracer != null && GetTrackedBarrelOwner(source.tracer) == playerNumber)
        {
            return true;
        }

        if (source.target != null && GetTrackedBarrelOwner(source.target) == playerNumber)
        {
            return true;
        }

        return false;
    }

    private bool IsBarrelStyleKill(WorldEvent e, int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return false;
        }

        if (IsPlayerOwnedBarrelSource(e.DamageSource, playerNumber) || IsPlayerOwnedBarrelSource(e.Inflictor, playerNumber))
        {
            return true;
        }

        if (e.Thing != null)
        {
            if (IsPlayerOwnedBarrelSource(e.Thing.DamageSource, playerNumber) || IsPlayerOwnedBarrelSource(e.Thing.target, playerNumber))
            {
                return true;
            }
        }

        return false;
    }

    private PlayerPawn ResolvePlayerKiller(WorldEvent e)
    {

        let killer = TryGetOwningPlayerPawn(e.DamageSource);
        if (killer != null)
        {
            return killer;
        }

        killer = TryGetOwningPlayerPawn(e.Inflictor);
        if (killer != null)
        {
            return killer;
        }

        if (e.Thing != null)
        {

            killer = TryGetOwningPlayerPawn(e.Thing.DamageSource);
            if (killer != null)
            {
                return killer;
            }

            killer = TryGetOwningPlayerPawn(e.Thing.target);
            if (killer != null)
            {
                return killer;
            }
        }

        return null;
    }

    private PlayerPawn TryGetOwningPlayerPawn(Actor source)
    {
        if (source == null)
        {
            return null;
        }

        if (source.player != null)
        {
            return PlayerPawn(source);
        }

        if (source.master != null && source.master.player != null)
        {
            return PlayerPawn(source.master);
        }

        if (source.tracer != null && source.tracer.player != null)
        {
            return PlayerPawn(source.tracer);
        }

        PlayerPawn barrelOwner = GetPlayerPawnByNumber(GetTrackedBarrelOwner(source));
        if (barrelOwner != null)
        {
            return barrelOwner;
        }

        barrelOwner = GetPlayerPawnByNumber(GetTrackedBarrelOwner(source.master));
        if (barrelOwner != null)
        {
            return barrelOwner;
        }

        barrelOwner = GetPlayerPawnByNumber(GetTrackedBarrelOwner(source.tracer));
        if (barrelOwner != null)
        {
            return barrelOwner;
        }

        barrelOwner = GetPlayerPawnByNumber(GetTrackedBarrelOwner(source.target));
        if (barrelOwner != null)
        {
            return barrelOwner;
        }

        String sourceClass = String.Format("%s", source.GetClassName()).MakeLower();
        bool isPuffLike = sourceClass.IndexOf("puff") >= 0;
        if ((source.bMissile || isPuffLike) && source.target != null && source.target.player != null)
        {
            return PlayerPawn(source.target);
        }

        return null;
    }

    private play void BuildMapSummary()
    {
        ApplyOutstandingMapBonuses();
        summaryMapName = String.Format("%s", level.mapname);
        summaryReady = true;

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            summaryGain[i] = 0;
            summaryKills[i] = mapKillsByPlayer[i];
            summarySecrets[i] = mapSecretsByPlayer[i];
            summaryBestCombo[i] = mapBestComboByPlayer[i];
            if (summaryBestCombo[i] < 1)
            {
                summaryBestCombo[i] = 1;
            }

            summaryFinalScore[i] = playerScoreCache[i];
            summaryPrestige[i] = playerPrestigeCache[i];
            summaryNewRecord[i] = false;

            int finalScore = summaryFinalScore[i];
            int prestige = summaryPrestige[i];

            if (PlayerInGame[i])
            {
                PlayerPawn player = PlayerPawn(players[i].mo);
                if (player != null)
                {
                    finalScore = GetScore(player);
                    prestige = GetPrestige(player);
                }
            }

            int gain = finalScore - mapStartScore[i];
            summaryGain[i] = gain;
            summaryFinalScore[i] = finalScore;
            summaryPrestige[i] = prestige;

            bool hasRunData = (mapKillsByPlayer[i] > 0) || (mapSecretsByPlayer[i] > 0) || (gain != 0);
            if (hasRunData)
            {
                bool isRecord = UpdateMapRecord(summaryMapName, gain);
                summaryNewRecord[i] = isRecord;
                if (isRecord && GetUserBoolPlay(i, 'score_log_score_events', true))
                {
                    Console.Printf("P%d REC %d\n", i + 1, gain);
                }

                if (isRecord && GetUserBoolPlay(i, 'score_newrecord_sound', true))
                {
                    PlayerPawn soundPlayer = null;
                    if (PlayerInGame[i])
                    {
                        soundPlayer = PlayerPawn(players[i].mo);
                    }

                    if (soundPlayer != null)
                    {
                        soundPlayer.A_StartSound("score/newrecord", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
                    }
                }
            }
        }

    }

    private bool UpdateMapRecord(String mapName, int gain)
    {
        int idx = FindMapRecordIndex(mapName);
        if (idx < 0)
        {
            recordMapNames.Push(mapName);
            recordMapBestGain.Push(gain);
            return true;
        }

        if (gain > recordMapBestGain[idx])
        {
            recordMapBestGain[idx] = gain;
            return true;
        }

        return false;
    }

    private int FindMapRecordIndex(String mapName)
    {
        for (int i = 0; i < recordMapNames.Size(); i++)
        {
            if (recordMapNames[i] == mapName)
            {
                return i;
            }
        }

        return -1;
    }

    ui int GetSummaryGain(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return 0;
        }
        return summaryGain[playerNumber];
    }

    ui int GetSummaryKills(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return 0;
        }
        return summaryKills[playerNumber];
    }

    ui int GetSummarySecrets(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return 0;
        }
        return summarySecrets[playerNumber];
    }

    ui int GetSummaryBestCombo(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return 1;
        }
        return summaryBestCombo[playerNumber];
    }

    ui int GetSummaryFinalScore(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return 0;
        }
        return summaryFinalScore[playerNumber];
    }

    ui int GetSummaryPrestige(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return 0;
        }
        return summaryPrestige[playerNumber];
    }

    ui bool GetSummaryNewRecord(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return false;
        }
        return summaryNewRecord[playerNumber];
    }

    ui bool HasSummary()
    {
        return summaryReady;
    }

    ui String GetSummaryMapName()
    {
        return summaryMapName;
    }

    ui int GetSummaryBestPlayerIndex()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (summaryKills[i] > 0 || summarySecrets[i] > 0 || summaryGain[i] != 0 || summaryFinalScore[i] > 0)
            {
                return i;
            }
        }

        return 0;
    }
}

