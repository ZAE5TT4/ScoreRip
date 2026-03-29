class EXPScoreStatusScreen : DoomStatusScreen
{
    private bool newRecordSoundPlayed;
    private bool newRecordSoundArmed;
    private int newRecordSoundDelay;

    override void initStats()
    {
        Super.initStats();
        newRecordSoundPlayed = false;
        newRecordSoundArmed = false;
        newRecordSoundDelay = 0;
    }

    override void updateStats()
    {
        Super.updateStats();

        if (newRecordSoundPlayed || !newRecordSoundArmed)
        {
            return;
        }

        if (newRecordSoundDelay > 0)
        {
            newRecordSoundDelay--;
            return;
        }

        if (!GetNewRecordSoundCVar())
        {
            newRecordSoundPlayed = true;
            return;
        }

        PlaySound("score/newrecord");
        S_StartSound("score/newrecord", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 2.0, ATTN_NONE);
        newRecordSoundPlayed = true;
    }

    override void drawStats(void)
    {
        Super.drawStats();

        if (!GetShowSummaryCVar())
        {
            return;
        }

        let handler = EXPScoreEventHandler.GetInstance();
        if (handler == null || !handler.HasSummary())
        {
            return;
        }

        int playerNumber = me;
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            playerNumber = handler.GetSummaryBestPlayerIndex();
        }

        Font f = generic_ui ? NewSmallFont : SmallFont;
        int color = Font.FindFontColor("Red");
        int accent = Font.FindFontColor("Red");
        int step = 14;

        int gain = handler.GetSummaryGain(playerNumber);
        String gainPrefix = gain >= 0 ? "+" : "";
        int finalScore = handler.GetSummaryFinalScore(playerNumber);
        int bestCombo = handler.GetSummaryBestCombo(playerNumber);
        bool hasNewRecord = handler.GetSummaryNewRecord(playerNumber);
        if (bestCombo < 1)
        {
            bestCombo = 1;
        }

        int startY = 108;
        int xShift = 100;
        int leftX = -60 + xShift;
        int rightX = 100 + xShift;
        DrawText(f, color, leftX, startY + (step * 0), String.Format("GAIN: %s%d", gainPrefix, gain), false, true);
        DrawText(f, color, leftX, startY + (step * 1), String.Format("SCORE: %d", finalScore), false, true);
        DrawText(f, color, leftX, startY + (step * 2), String.Format("BEST COMBO: x%d", bestCombo), false, true);

        DrawText(f, color, rightX, startY + (step * 0), String.Format("RANK: %s", EXPScoreRules.GetRankNameForScore(finalScore)), false, true);
        DrawText(f, color, rightX, startY + (step * 1), String.Format("PRESTIGE: %d", handler.GetSummaryPrestige(playerNumber)), false, true);

        if (hasNewRecord)
        {
            DrawText(f, accent, rightX, startY + (step * 2), "NEW RECORD!", false, true);
        }

        if (hasNewRecord && !newRecordSoundPlayed && !newRecordSoundArmed && sp_state >= 2)
        {
            newRecordSoundArmed = true;
            newRecordSoundDelay = 0;
        }
    }

    private int GetCVarPlayerNumber()
    {
        int playerNumber = me;
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            playerNumber = ConsolePlayer;
        }

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

    private bool GetShowSummaryCVar()
    {
        int playerNumber = GetCVarPlayerNumber();
        if (playerNumber < 0)
        {
            return true;
        }

        let cv = CVar.GetCVar('score_show_endmap_summary', players[playerNumber]);
        if (cv == null)
        {
            return true;
        }

        return cv.GetBool();
    }

    private bool GetNewRecordSoundCVar()
    {
        int playerNumber = GetCVarPlayerNumber();
        if (playerNumber < 0)
        {
            return true;
        }

        let cv = CVar.GetCVar('score_newrecord_sound', players[playerNumber]);
        if (cv == null)
        {
            return true;
        }

        return cv.GetBool();
    }
}


