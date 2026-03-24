class EXPScoreShopRules : Object
{
    static bool HasValidShopPresentation(Inventory item)
    {
        if (item == null)
        {
            return false;
        }

        if (item.SpawnState == null || !item.SpawnState.ValidateSpriteFrame())
        {
            return false;
        }

        return true;
    }

    static bool IsForeignBuiltinItem(Inventory item, String clsText, String tagText)
    {
        if (item == null)
        {
            return false;
        }

        if (item is "HereticWeapon" || item is "FighterWeapon" || item is "ClericWeapon" || item is "MageWeapon")
        {
            return true;
        }

        if (item is "Mana1" || item is "Mana2" || item is "Mana3" || item is "ArtiBoostMana")
        {
            return true;
        }

        if (item is "GoldWandAmmo" || item is "GoldWandHefty" ||
            item is "CrossbowAmmo" || item is "CrossbowHefty" ||
            item is "MaceAmmo" || item is "MaceHefty" ||
            item is "BlasterAmmo" || item is "BlasterHefty" ||
            item is "SkullRodAmmo" || item is "SkullRodHefty" ||
            item is "PhoenixRodAmmo" || item is "PhoenixRodHefty")
        {
            return true;
        }

        if (item is "Gauntlets" || item is "GoldWand" || item is "Crossbow" || item is "Mace" ||
            item is "Blaster" || item is "SkullRod" || item is "PhoenixRod" || item is "FWeapFist" ||
            item is "MWeapWand")
        {
            return true;
        }

        if (clsText == "hexenarmor" || clsText == "armoritem" || clsText == "weaponpiece" || clsText == "weaponholder")
        {
            return true;
        }

        if (clsText.IndexOf("goldwand") >= 0 || clsText.IndexOf("crossbow") >= 0 || clsText.IndexOf("skullrod") >= 0 ||
            clsText.IndexOf("phoenixrod") >= 0 || clsText.IndexOf("blaster") >= 0 || clsText.IndexOf("maceammo") >= 0 ||
            clsText.IndexOf("mana") >= 0 || clsText.IndexOf("gauntlet") >= 0 || clsText.IndexOf("hellstaff") >= 0 ||
            clsText.IndexOf("etherealarrow") >= 0 || clsText.IndexOf("wandcrystal") >= 0 || clsText.IndexOf("claworb") >= 0 ||
            clsText.IndexOf("flameorb") >= 0 || clsText.IndexOf("macesphere") >= 0 || clsText.IndexOf("brassknuckles") >= 0)
        {
            return true;
        }

        if (tagText.IndexOf("green mana") >= 0 || tagText.IndexOf("blue mana") >= 0 || tagText.IndexOf("mace sphere") >= 0 ||
            tagText.IndexOf("ethereal arrow") >= 0 || tagText.IndexOf("wand crystal") >= 0 || tagText.IndexOf("flame orb") >= 0 ||
            tagText.IndexOf("hellstaff rune") >= 0 || tagText.IndexOf("claw orb") >= 0 || tagText.IndexOf("brass knuckles") >= 0)
        {
            return true;
        }

        return false;
    }

    static bool IsShopCandidate(Inventory item)
    {
        if (item == null)
        {
            return false;
        }

        if (!HasValidShopPresentation(item))
        {
            return false;
        }

        if (item is "EXPScoreToken" || item is "EXPRewardTierToken" || item is "EXPPrestigeToken")
        {
            return false;
        }

        String clsText = String.Format("%s", item.GetClassName()).MakeLower();
        String tagText = item.GetTag("").MakeLower();
        if (clsText == "" || clsText == "inventory")
        {
            return false;
        }

        if (IsForeignBuiltinItem(item, clsText, tagText))
        {
            return false;
        }

        if (clsText.IndexOf("token") >= 0 || clsText.IndexOf("key") >= 0)
        {
            return false;
        }

        if (clsText.IndexOf("puzzle") >= 0 || clsText.IndexOf("quest") >= 0)
        {
            return false;
        }

        if (clsText.IndexOf("marker") >= 0 || clsText.IndexOf("counter") >= 0)
        {
            return false;
        }

        if (clsText.IndexOf("bootsmearer") >= 0)
        {
            return false;
        }

        return true;
    }

    static bool IsShopCandidateClassName(String className)
    {
        String clsText = className.MakeLower();
        if (clsText == "" || clsText == "inventory")
        {
            return false;
        }

        if (clsText == "hexenarmor" || clsText == "armoritem" || clsText == "weaponpiece" || clsText == "weaponholder")
        {
            return false;
        }

        if (clsText.IndexOf("goldwand") >= 0 || clsText.IndexOf("crossbow") >= 0 || clsText.IndexOf("skullrod") >= 0 ||
            clsText.IndexOf("phoenixrod") >= 0 || clsText.IndexOf("blaster") >= 0 || clsText.IndexOf("maceammo") >= 0 ||
            clsText.IndexOf("mana") >= 0 || clsText.IndexOf("gauntlet") >= 0 || clsText.IndexOf("hellstaff") >= 0 ||
            clsText.IndexOf("etherealarrow") >= 0 || clsText.IndexOf("wandcrystal") >= 0 || clsText.IndexOf("claworb") >= 0 ||
            clsText.IndexOf("flameorb") >= 0 || clsText.IndexOf("macesphere") >= 0 || clsText.IndexOf("brassknuckles") >= 0 ||
            clsText.IndexOf("hereticweapon") >= 0 || clsText.IndexOf("fighterweapon") >= 0 || clsText.IndexOf("clericweapon") >= 0 ||
            clsText.IndexOf("mageweapon") >= 0 || clsText.IndexOf("fweapfist") >= 0 || clsText.IndexOf("mweapwand") >= 0)
        {
            return false;
        }

        if (clsText.IndexOf("token") >= 0 || clsText.IndexOf("key") >= 0)
        {
            return false;
        }

        if (clsText.IndexOf("puzzle") >= 0 || clsText.IndexOf("quest") >= 0)
        {
            return false;
        }

        if (clsText.IndexOf("marker") >= 0 || clsText.IndexOf("counter") >= 0 || clsText.IndexOf("bootsmearer") >= 0)
        {
            return false;
        }

        return true;
    }

    static int GetCategory(Inventory item)
    {
        if (item == null)
        {
            return 5;
        }

        String clsText = String.Format("%s", item.GetClassName()).MakeLower();
        String tagText = item.GetTag("").MakeLower();

        if (Weapon(item) != null)
        {
            return 0;
        }

        if (Ammo(item) != null)
        {
            return 3;
        }

        if (clsText.IndexOf("backpack") >= 0 || tagText.IndexOf("backpack") >= 0)
        {
            return 3;
        }

        if (clsText.IndexOf("armor") >= 0 || tagText.IndexOf("armor") >= 0 || clsText.IndexOf("helmet") >= 0 || tagText.IndexOf("helmet") >= 0)
        {
            return 2;
        }

        if (clsText.IndexOf("sphere") >= 0 || tagText.IndexOf("sphere") >= 0)
        {
            return 4;
        }

        if (clsText.IndexOf("berserk") >= 0 || clsText.IndexOf("invul") >= 0 || clsText.IndexOf("invis") >= 0 || clsText.IndexOf("lightamp") >= 0 || clsText.IndexOf("liteamp") >= 0 || clsText.IndexOf("blur") >= 0)
        {
            return 4;
        }

        if (clsText.IndexOf("power") >= 0 || tagText.IndexOf("power") >= 0)
        {
            return 4;
        }

        if (clsText.IndexOf("stim") >= 0 || clsText.IndexOf("med") >= 0 || clsText.IndexOf("health") >= 0 || clsText.IndexOf("patch") >= 0 || clsText.IndexOf("kit") >= 0 || clsText.IndexOf("bandage") >= 0)
        {
            return 1;
        }

        if (tagText.IndexOf("health") >= 0 || tagText.IndexOf("med") >= 0 || tagText.IndexOf("stim") >= 0)
        {
            return 1;
        }

        if (PowerupGiver(item) != null)
        {
            return 4;
        }

        return 5;
    }

    static String GetCategoryName(int category)
    {
        switch (category)
        {
        case 0: return "Weapons";
        case 1: return "Health";
        case 2: return "Armor";
        case 3: return "Ammo";
        case 4: return "Powerups";
        default: return "Misc";
        }
    }

    static String GetDisplayNameFromClassName(String className)
    {
        if (className == "")
        {
            return "Unknown";
        }

        return className;
    }
    static String GetDisplayName(Inventory item)
    {
        if (item == null)
        {
            return "Unknown";
        }

        String tag = item.GetTag("");
        if (tag != "")
        {
            return tag;
        }

        return String.Format("%s", item.GetClassName());
    }

    static int GetAutoPrice(Inventory item)
    {
        if (item == null)
        {
            return 100;
        }

        int category = GetCategory(item);
        String clsText = String.Format("%s", item.GetClassName()).MakeLower();
        String tagText = item.GetTag("").MakeLower();

        switch (category)
        {
        case 0:
            if (clsText.IndexOf("bfg") >= 0 || tagText.IndexOf("bfg") >= 0) return 9000;
            if (clsText.IndexOf("plasma") >= 0 || tagText.IndexOf("plasma") >= 0) return 4200;
            if (clsText.IndexOf("rocket") >= 0 || tagText.IndexOf("rocket") >= 0) return 3200;
            if (clsText.IndexOf("super") >= 0 || tagText.IndexOf("super") >= 0) return 2600;
            if (clsText.IndexOf("chain") >= 0 || tagText.IndexOf("chaingun") >= 0) return 2100;
            if (clsText.IndexOf("shotgun") >= 0 || tagText.IndexOf("shotgun") >= 0) return 1800;
            if (clsText.IndexOf("saw") >= 0 || tagText.IndexOf("chainsaw") >= 0) return 1400;
            if (clsText.IndexOf("pistol") >= 0 || clsText.IndexOf("fist") >= 0) return 800;
            return 2600;

        case 1:
            if (clsText.IndexOf("mega") >= 0 || tagText.IndexOf("mega") >= 0) return 5200;
            if (clsText.IndexOf("soul") >= 0 || tagText.IndexOf("soul") >= 0) return 3200;
            if (clsText.IndexOf("med") >= 0 || tagText.IndexOf("med") >= 0) return 260;
            if (clsText.IndexOf("stim") >= 0 || tagText.IndexOf("stim") >= 0) return 120;
            if (clsText.IndexOf("bonus") >= 0 || tagText.IndexOf("bonus") >= 0) return 50;
            return 300;

        case 2:
            if (clsText.IndexOf("blue") >= 0 || tagText.IndexOf("blue") >= 0) return 2200;
            if (clsText.IndexOf("green") >= 0 || tagText.IndexOf("green") >= 0) return 1400;
            if (clsText.IndexOf("bonus") >= 0 || clsText.IndexOf("helmet") >= 0 || tagText.IndexOf("bonus") >= 0) return 60;
            return 900;

        case 3:
            if (clsText.IndexOf("backpack") >= 0 || tagText.IndexOf("backpack") >= 0) return 1200;
            if (clsText.IndexOf("cellpack") >= 0 || clsText.IndexOf("cell box") >= 0) return 650;
            if (clsText.IndexOf("cell") >= 0 || tagText.IndexOf("cell") >= 0) return 170;
            if (clsText.IndexOf("rocketbox") >= 0 || clsText.IndexOf("rocket box") >= 0) return 560;
            if (clsText.IndexOf("rocket") >= 0 || tagText.IndexOf("rocket") >= 0) return 180;
            if (clsText.IndexOf("shellbox") >= 0 || clsText.IndexOf("shell box") >= 0) return 390;
            if (clsText.IndexOf("shell") >= 0 || tagText.IndexOf("shell") >= 0) return 110;
            if (clsText.IndexOf("clipbox") >= 0 || tagText.IndexOf("ammo box") >= 0) return 320;
            if (clsText.IndexOf("clip") >= 0 || tagText.IndexOf("clip") >= 0) return 80;
            return 180;

        case 4:
            if (clsText.IndexOf("invul") >= 0 || tagText.IndexOf("invul") >= 0) return 7000;
            if (clsText.IndexOf("mega") >= 0 || tagText.IndexOf("mega") >= 0) return 5200;
            if (clsText.IndexOf("berserk") >= 0 || tagText.IndexOf("berserk") >= 0) return 2300;
            if (clsText.IndexOf("invis") >= 0 || clsText.IndexOf("blur") >= 0 || tagText.IndexOf("invis") >= 0) return 1800;
            if (clsText.IndexOf("lightamp") >= 0 || clsText.IndexOf("liteamp") >= 0) return 1200;
            if (clsText.IndexOf("sphere") >= 0 || tagText.IndexOf("sphere") >= 0) return 3600;
            return 2600;
        }

        if (clsText.IndexOf("artifact") >= 0 || tagText.IndexOf("artifact") >= 0)
        {
            return 2200;
        }

        return 900;
    }
}

