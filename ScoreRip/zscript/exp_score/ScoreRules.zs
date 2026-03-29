class EXPScoreRules : Object
{
    static int GetScoreForKill(Actor victim, PlayerPawn killer, int comboPercent, int stylePercent)
    {
        if (victim == null || killer == null || !victim.bIsMonster)
        {
            return 0;
        }

        if (IsExcludedMonster(victim))
        {
            return 0;
        }

        int score = GetEnemyBaseScore(victim);
        score = ApplyPercent(score, GetWeaponPercent(killer));
        score = ApplyPercent(score, comboPercent);
        score = ApplyPercent(score, stylePercent);

        if (score < 1)
        {
            score = 1;
        }

        return score;
    }

    static bool IsExcludedMonster(Actor victim)
    {
        if (victim == null)
        {
            return false;
        }

        Name cls = victim.GetClassName();
        String clsText = String.Format("%s", cls).MakeLower();

        if (clsText.IndexOf("bootsmearer") >= 0)
        {
            return true;
        }

        return false;
    }

    static bool IsUnknownEnemy(Actor victim)
    {
        if (victim == null || !victim.bIsMonster)
        {
            return false;
        }

        if (victim.bBoss || victim is "Cyberdemon" || victim is "SpiderMastermind") { return false; }
        if (victim is "Archvile" || victim is "BaronOfHell" || victim is "Fatso" || victim is "Revenant") { return false; }
        if (victim is "Cacodemon" || victim is "HellKnight" || victim is "PainElemental" || victim is "Arachnotron") { return false; }
        if (victim is "DoomImp" || victim is "Demon" || victim is "Spectre" || victim is "LostSoul") { return false; }
        if (victim is "ZombieMan" || victim is "ShotgunGuy" || victim is "ChaingunGuy" || victim is "WolfensteinSS") { return false; }

        return true;
    }

    static int GetEnemyBaseScore(Actor victim)
    {
        if (victim.bBoss || victim is "Cyberdemon" || victim is "SpiderMastermind")
        {
            return 700;
        }

        if (victim is "Archvile" || victim is "BaronOfHell" || victim is "Fatso" || victim is "Revenant")
        {
            return 320;
        }

        if (victim is "Cacodemon" || victim is "HellKnight" || victim is "PainElemental" || victim is "Arachnotron")
        {
            return 220;
        }

        if (victim is "DoomImp" || victim is "Demon" || victim is "Spectre" || victim is "LostSoul")
        {
            return 130;
        }

        if (victim is "ZombieMan" || victim is "ShotgunGuy" || victim is "ChaingunGuy" || victim is "WolfensteinSS")
        {
            return 90;
        }

        return 100;
    }

    static int ApplyPercent(int value, int percent)
    {
        if (value <= 0)
        {
            return 0;
        }

        if (percent < 1)
        {
            percent = 1;
        }

        return (value * percent + 50) / 100;
    }

    static int GetWeaponPercent(PlayerPawn killer)
    {
        if (killer.player == null || killer.player.ReadyWeapon == null)
        {
            return 100;
        }

        let weapon = killer.player.ReadyWeapon;

        if (weapon is "Fist")
        {
            if (killer.FindInventory("PowerStrength") != null)
            {
                return 190;
            }

            return 165;
        }

        if (weapon is "Chainsaw")
        {
            return 150;
        }

        if (weapon is "Pistol")
        {
            return 100;
        }

        if (weapon is "Shotgun")
        {
            return 120;
        }

        if (weapon is "SuperShotgun")
        {
            return 135;
        }

        if (weapon is "Chaingun")
        {
            return 110;
        }

        if (weapon is "RocketLauncher")
        {
            return 105;
        }

        if (weapon is "PlasmaRifle")
        {
            return 95;
        }

        if (weapon is "BFG9000")
        {
            return 85;
        }

        return 100;
    }

    static String GetWeaponDisplayName(PlayerPawn killer)
    {
        if (killer == null || killer.player == null || killer.player.ReadyWeapon == null)
        {
            return "Unknown";
        }

        let weapon = killer.player.ReadyWeapon;

        if (weapon is "Fist") { return "Fist"; }
        if (weapon is "Chainsaw") { return "Chainsaw"; }
        if (weapon is "Pistol") { return "Pistol"; }
        if (weapon is "Shotgun") { return "Shotgun"; }
        if (weapon is "SuperShotgun") { return "Super Shotgun"; }
        if (weapon is "Chaingun") { return "Chaingun"; }
        if (weapon is "RocketLauncher") { return "Rocket Launcher"; }
        if (weapon is "PlasmaRifle") { return "Plasma Rifle"; }
        if (weapon is "BFG9000") { return "BFG9000"; }

        return String.Format("%s", weapon.GetClassName());
    }

    static String GetEnemyDisplayName(Actor victim)
    {
        if (victim == null)
        {
            return "Unknown";
        }

        if (victim is "ZombieMan") { return "Zombieman"; }
        if (victim is "ShotgunGuy") { return "Shotgun Guy"; }
        if (victim is "ChaingunGuy") { return "Chaingunner"; }
        if (victim is "WolfensteinSS") { return "SS"; }
        if (victim is "DoomImp") { return "Imp"; }
        if (victim is "Demon") { return "Demon"; }
        if (victim is "Spectre") { return "Spectre"; }
        if (victim is "LostSoul") { return "Lost Soul"; }
        if (victim is "Cacodemon") { return "Cacodemon"; }
        if (victim is "HellKnight") { return "Hell Knight"; }
        if (victim is "BaronOfHell") { return "Baron"; }
        if (victim is "Revenant") { return "Revenant"; }
        if (victim is "Fatso") { return "Mancubus"; }
        if (victim is "Arachnotron") { return "Arachnotron"; }
        if (victim is "PainElemental") { return "Pain Elemental"; }
        if (victim is "Archvile") { return "Arch-vile"; }
        if (victim is "SpiderMastermind") { return "Spider Mastermind"; }
        if (victim is "Cyberdemon") { return "Cyberdemon"; }

        return String.Format("%s", victim.GetClassName());
    }

    static int GetRankIndexForScore(int score)
    {
        int preset = score_rank_preset;
        if (preset < 0 || preset > 2)
        {
            preset = 0;
        }

        return GetRankIndexByPreset(score, preset);
    }

    static int GetRankIndexByPreset(int score, int preset)
    {
        if (score <= 0)
        {
            return 0;
        }

        for (int i = 79; i >= 1; i--)
        {
            if (score >= GetRankThreshold(preset, i))
            {
                return i;
            }
        }

        return 0;
    }

    static int GetRankThreshold(int preset, int rankIndex)
    {
        if (rankIndex <= 0)
        {
            return 0;
        }

        if (rankIndex > 79)
        {
            rankIndex = 79;
        }

        int a;
        int b;

        switch (preset)
        {
        case 1: 
            a = 78;
            b = 620;
            break;

        case 2: 
            a = 220;
            b = 1600;
            break;

        default: 
            a = 110;
            b = 850;
            break;
        }

        return (rankIndex * rankIndex * a) + (rankIndex * b);
    }

    static int GetPrestigeRequirement()
    {
        int preset = score_rank_preset;
        if (preset < 0 || preset > 2)
        {
            preset = 0;
        }

        return GetRankThreshold(preset, 79) + GetRankThreshold(preset, 20);
    }

    static String GetRankNameByIndex(int rankIndex)
    {
        if (rankIndex < 0)
        {
            rankIndex = 0;
        }
        if (rankIndex > 79)
        {
            rankIndex = 79;
        }

        switch (rankIndex)
        {
        case 0: return "Recruit";
        case 1: return "Scout";
        case 2: return "Trooper";
        case 3: return "Hunter";
        case 4: return "Stalker";
        case 5: return "Slayer";
        case 6: return "Butcher";
        case 7: return "Reaper";
        case 8: return "Ravager";
        case 9: return "Warlord";
        case 10: return "Overkiller";
        case 11: return "Exterminator";
        case 12: return "Nightbane";
        case 13: return "Dreadnought";
        case 14: return "Hellbreaker";
        case 15: return "Doombringer";
        case 16: return "Annihilator";
        case 17: return "Harbinger";
        case 18: return "Cataclysm";
        case 19: return "DoomLord";
        case 20: return "Apex Doom";
        case 21: return "Infernal Apex";
        case 22: return "Eternal Slayer";
        case 23: return "Mythic Reaper";
        case 24: return "Omega Exec";
        case 25: return "God Carnage";
        case 26: return "Planetbreaker";
        case 27: return "End of Hell";
        case 28: return "Prime Doom";
        case 29: return "Eternal Prime";
        case 30: return "Unholy Legend";
        case 31: return "Final Judg.";
        case 32: return "Armageddon";
        case 33: return "Doom Eternal";
        case 34: return "Chaos Monarch";
        case 35: return "Absolute Doom";
        case 36: return "Void Herald";
        case 37: return "Rift Hunter";
        case 38: return "Abyss Walker";
        case 39: return "Hell Marshal";
        case 40: return "Inferno Warden";
        case 41: return "Catastrophe King";
        case 42: return "Nether Tyrant";
        case 43: return "Doom Vanguard";
        case 44: return "Eclipse Reaper";
        case 45: return "Starbreaker";
        case 46: return "Oblivion Knight";
        case 47: return "Apex Harrower";
        case 48: return "Thunder Scourge";
        case 49: return "Dread Emperor";
        case 50: return "Ruin Architect";
        case 51: return "Infernal Regent";
        case 52: return "Nightmare Crown";
        case 53: return "Rift Sovereign";
        case 54: return "Chaos Executor";
        case 55: return "Hell Dominion";
        case 56: return "Endless Wrath";
        case 57: return "Doom Oracle";
        case 58: return "Quantum Butcher";
        case 59: return "Crimson Nemesis";
        case 60: return "Omega Sovereign";
        case 61: return "Titan Ravager";
        case 62: return "Cosmic Reaper";
        case 63: return "Catacomb King";
        case 64: return "Final Eclipse";
        case 65: return "Eternal Overlord";
        case 66: return "Doom Ascendant";
        case 67: return "Empyreal Slayer";
        case 68: return "Void Monarch";
        case 69: return "Astral Doom";
        case 70: return "Oblivion Prime";
        case 71: return "Celestial Tyrant";
        case 72: return "Ultra Cataclysm";
        case 73: return "Apex Transcendent";
        case 74: return "Beyond Ruin";
        case 75: return "Singularity Lord";
        case 76: return "Infinity Reaper";
        case 77: return "Last Harbinger";
        case 78: return "Supreme Doom";
        case 79: return "Transcendent";
        default: return "Transcendent";
        }
    }

    static String GetRankNameForScore(int score)
    {
        return GetRankNameByIndex(GetRankIndexForScore(score));
    }
}


