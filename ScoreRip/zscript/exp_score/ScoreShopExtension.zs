extend class EXPScoreEventHandler
{
    private Array<Name> shopItemTypes;
    private Array<String> shopItemDisplayNames;
    private Array<int> shopItemCategories;
    private Array<int> shopItemPrices;
    private bool shopOpen[MAXPLAYERS];
    private String shopMessage[MAXPLAYERS];
    private int shopMessageExpireTic[MAXPLAYERS];
    private int shopOpenTic[MAXPLAYERS];
    private int shopLastBuyTic[MAXPLAYERS];

    ui int shopCursorX[MAXPLAYERS];
    ui int shopCursorY[MAXPLAYERS];
    ui int shopSelectedCategory[MAXPLAYERS];
    ui int shopShaderCounter[MAXPLAYERS];
    ui int shopSelectedPage[MAXPLAYERS];
    ui int shopSelectedRow[MAXPLAYERS];
    ui int shopLastInputTic[MAXPLAYERS];
    private bool shopCatalogPrimed;
    private int shopCatalogNextRescanTic;
    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
        ResetShopStateRuntime();
        RestoreCatalogFromCVar();
    }

    private void SaveCatalogToCVar()
    {
        CVar cv = CVar.FindCVar('score_shop_catalog_save');
        if (cv == null) { return; }
        String s = "";
        for (int i = 0; i < shopItemTypes.Size(); i++)
        {
            if (s.Length() > 3800) { break; }
            if (i > 0) { s = s .. ":"; }
            s = s .. String.Format("%s~%d~%d",
                shopItemTypes[i],
                shopItemCategories[i],
                shopItemPrices[i]);
        }
        cv.SetString(s);
    }

    private void RestoreCatalogFromCVar()
    {
        CVar cv = CVar.FindCVar('score_shop_catalog_save');
        if (cv == null) { return; }
        String data = cv.GetString();
        if (data.Length() < 3) { return; }
        Array<String> entries;
        data.Split(entries, ":", TOK_SKIPEMPTY);
        for (int i = 0; i < entries.Size(); i++)
        {
            Array<String> parts;
            entries[i].Split(parts, "~", TOK_SKIPEMPTY);
            if (parts.Size() < 3) { continue; }
            if (!EXPScoreShopRules.IsShopCandidateClassName(parts[0])) { continue; }
            Name itemType = parts[0];
            if (itemType == 'None') { continue; }
            bool already = false;
            for (int j = 0; j < shopItemTypes.Size(); j++)
            {
                if (shopItemTypes[j] == itemType) { already = true; break; }
            }
            if (already) { continue; }
            int cat   = parts[1].ToInt();
            int price = parts[2].ToInt();
            if (price < 1) { price = 1; }
            shopItemTypes.Push(itemType);
            shopItemDisplayNames.Push(EXPScoreShopRules.GetDisplayNameFromClassName(parts[0]));
            shopItemCategories.Push(cat);
            shopItemPrices.Push(price);
        }
    }

    private play void PrimeShopCatalogOnce()
    {
        if (shopCatalogPrimed)
        {
            return;
        }

        ScanWorldShopItems();
        SaveCatalogToCVar();
        shopCatalogPrimed = true;
        shopCatalogNextRescanTic = level.time + 35;
    }

    private play void TickShopCatalogQueue()
    {
        if (gamestate != GS_LEVEL)
        {
            return;
        }

        if (!shopCatalogPrimed)
        {
            PrimeShopCatalogOnce();
            return;
        }

        if (level.time < shopCatalogNextRescanTic)
        {
            return;
        }

        shopCatalogNextRescanTic = level.time + 35;
        int oldCount = shopItemTypes.Size();
        ScanWorldShopItems();
        if (shopItemTypes.Size() != oldCount)
        {
            SaveCatalogToCVar();
        }
    }

    void ClearShopCatalog()
    {
        shopItemTypes.Clear();
        shopItemDisplayNames.Clear();
        shopItemCategories.Clear();
        shopItemPrices.Clear();
    }

    private void ResetShopStateRuntime()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            shopOpen[i] = false;
            shopOpenTic[i] = 0;
            shopMessage[i] = "";
            shopMessageExpireTic[i] = 0;
            shopLastBuyTic[i] = 0;
        }
        IsUiProcessor = false;
        RequireMouse = false;
    }

    private ui bool CanProcessShopInputUI(int playerNumber, int cooldown)
    {
        if (level.time < shopLastInputTic[playerNumber] + cooldown)
        {
            return false;
        }

        shopLastInputTic[playerNumber] = level.time;
        return true;
    }

    override bool UiProcess(UiEvent e)
    {
        int playerNumber = GetUIPlayerNumber();
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS || !IsShopOpenUI(playerNumber))
        {
            return false;
        }

        bool handled = false;

        if (e.MouseX != 0 || e.MouseY != 0)
        {
            shopCursorX[playerNumber] = e.MouseX;
            shopCursorY[playerNumber] = e.MouseY;
            ClampShopCursorUI(playerNumber);
            handled = true;
        }

        if (e.KeyChar == 27)
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            EventHandler.SendNetworkEvent("scorerip_shop_close");
            return true;
        }

        if (e.KeyChar == 13 || e.KeyChar == 32)
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            TryBuySelectedShopItemUI(playerNumber);
            return true;
        }

        if (e.Type == UiEvent.Type_LButtonDown)
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            HandleShopClickUI(playerNumber);
            return true;
        }
        if (e.Type == UiEvent.Type_RButtonDown)
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            EventHandler.SendNetworkEvent("scorerip_shop_close");
            return true;
        }

        String keyText = e.KeyString.MakeLower();
        if (keyText == "w")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            MoveShopSelectionUI(playerNumber, -1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return true;
        }
        if (keyText == "s")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            MoveShopSelectionUI(playerNumber, 1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return true;
        }
        if (keyText == "a")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopCategoryUI(playerNumber, -1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return true;
        }
        if (keyText == "d")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopCategoryUI(playerNumber, 1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return true;
        }
        if (keyText == "q")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopPageUI(playerNumber, -1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return true;
        }
        if (keyText == "e")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopPageUI(playerNumber, 1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return true;
        }

        return handled;
    }
    override bool InputProcess(InputEvent e)
    {
        return false;
    }

    override void UiTick()
    {
        TickShaderCountersUI();

        int playerNumber = GetUIPlayerNumber();
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS || !IsShopOpenUI(playerNumber))
        {
            return;
        }

        if (shopLastInputTic[playerNumber] == 0)
        {
            shopLastInputTic[playerNumber] = -1000;
        }

        if (shopOpenTic[playerNumber] > 0 && level.time <= shopOpenTic[playerNumber] + 2)
        {
            shopCursorX[playerNumber] = Screen.GetWidth() / 2;
            shopCursorY[playerNumber] = Screen.GetHeight() / 2;
            shopLastInputTic[playerNumber] = -1000;
        }

        ClampShopCursorUI(playerNumber);
        ClampShopSelectionUI(playerNumber);

        shopShaderCounter[playerNumber] = 18;

    }

    private ui void TickShaderCountersUI()
    {
        int pn = GetUIPlayerNumber();
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (!IsShopOpenUI(i) && shopShaderCounter[i] > 0)
            {
                shopShaderCounter[i] -= 3;
                if (shopShaderCounter[i] < 0) { shopShaderCounter[i] = 0; }
            }
        }

        if (pn >= 0 && pn < MAXPLAYERS && PlayerInGame[pn])
        {
            PlayerInfo p = players[pn];
            if (!IsShopOpenUI(pn))
            {
                if (shopShaderCounter[pn] > 0 && GetUserBoolUI('score_shop_shader_enable', true))
                {
                    Shader.SetUniform1i(p, "shopshader", "shopOpen", 0);
                    Shader.SetUniform1i(p, "shopshader", "shopCounter", shopShaderCounter[pn]);
                    Shader.SetEnabled(p, "shopshader", true);
                }
                else
                {
                    Shader.SetEnabled(p, "shopshader", false);
                }
            }
        }
    }

    override void NetworkProcess(ConsoleEvent e)
    {
        if (e.Name ~== "scorerip_shop_toggle")
        {
            ToggleShopForPlayer(e.Player);
            return;
        }

        if (e.Name ~== "scorerip_shop_close")
        {
            CloseShopForPlayer(e.Player);
            return;
        }

        if (e.Name ~== "scorerip_shop_choice")
        {
            if (GetUserBoolPlay(e.Player, 'score_shop_sounds_enable', true))
            {
                S_StartSound("score/shop/choice", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 0.7, ATTN_NONE);
            }
            return;
        }

        if (e.Name ~== "scorerip_shop_buy")
        {
            if (e.Args.Size() > 0)
            {
                BuyShopItemForPlayer(e.Player, e.Args[0]);
            }
        }
    }

    private void ResetShopAllRuntime()
    {
        shopItemTypes.Clear();
        shopItemDisplayNames.Clear();
        shopItemCategories.Clear();
        shopItemPrices.Clear();

        for (int i = 0; i < MAXPLAYERS; i++)
        {
            shopOpen[i] = false;
            shopOpenTic[i] = 0;
            shopMessage[i] = "";
            shopMessageExpireTic[i] = 0;
            shopLastBuyTic[i] = 0;
        }

        IsUiProcessor = false;
        RequireMouse = false;
    }

    private void ResetShopMapRuntime()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            shopOpen[i] = false;
            shopOpenTic[i] = 0;
            shopMessage[i] = "";
            shopMessageExpireTic[i] = 0;
            shopLastBuyTic[i] = 0;
        }

        IsUiProcessor = false;
        RequireMouse = false;
    }

    private void ResetShopPlayerRuntime(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        shopOpen[playerNumber] = false;
        shopOpenTic[playerNumber] = 0;
        shopMessage[playerNumber] = "";
        shopMessageExpireTic[playerNumber] = 0;

        if (!AnyShopOpen())
        {
            IsUiProcessor = false;
            RequireMouse = false;
        }
    }

    private play void ToggleShopForPlayer(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber) || !PlayerInGame[playerNumber])
        {
            return;
        }

        if (!GetUserBoolPlay(playerNumber, 'score_shop_enabled', true))
        {
            shopOpen[playerNumber] = false;
            IsUiProcessor = false;
            RequireMouse = false;
            return;
        }

        if (gamestate != GS_LEVEL)
        {
            shopOpen[playerNumber] = false;
            IsUiProcessor = false;
            RequireMouse = false;
            return;
        }

        PlayerPawn player = PlayerPawn(players[playerNumber].mo);
        if (player == null || player.health <= 0)
        {
            shopOpen[playerNumber] = false;
            IsUiProcessor = false;
            RequireMouse = false;
            return;
        }

        if (shopOpen[playerNumber])
        {
            CloseShopForPlayer(playerNumber);
            return;
        }

        RefreshShopCatalogForPlayer(playerNumber);
        EnsureShopSpecialsReady();
        shopOpen[playerNumber] = true;
        shopOpenTic[playerNumber] = level.time;
        IsUiProcessor = true;
        RequireMouse = true;

    }

    private play void CloseShopForPlayer(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        shopOpen[playerNumber] = false;
        SaveCatalogToCVar();
        if (GetUserBoolPlay(playerNumber, 'score_shop_sounds_enable', true))
        {
            S_StartSound("score/shop/exit", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 1.0, ATTN_NONE);
        }

        if (!AnyShopOpen())
        {
            IsUiProcessor = false;
            RequireMouse = false;
        }
    }

    private play void RefreshShopCatalogForPlayer(int playerNumber)
    {
        RegisterPlayerShopInventory(playerNumber);
        ScanWorldShopItems();
    }
    private play void RegisterPlayerShopInventory(int playerNumber)
    {
        if (!IsValidPlayerNumber(playerNumber) || !PlayerInGame[playerNumber])
        {
            return;
        }

        PlayerPawn player = PlayerPawn(players[playerNumber].mo);
        if (player == null)
        {
            return;
        }

        Inventory inv = Inventory(player.Inv);
        while (inv != null)
        {
            RegisterShopCatalogItem(inv);
            inv = Inventory(inv.Inv);
        }

        if (player.player != null && player.player.ReadyWeapon != null)
        {
            RegisterShopCatalogItem(player.player.ReadyWeapon);
        }
    }

    private play void ScanWorldShopItems()
    {
        if (shopItemTypes.Size() >= 200) { return; }
        Actor mo;
        ThinkerIterator thinker = ThinkerIterator.Create("Inventory", Thinker.STAT_DEFAULT);
        int scanned = 0;
        while ((mo = Actor(thinker.Next())) && scanned < 150 && shopItemTypes.Size() < 200)
        {
            scanned++;
            RegisterShopCatalogThing(mo);
        }
    }

    private play void RegisterShopCatalogThing(Actor thing)
    {
        if (thing == null) { return; }
        Inventory item = Inventory(thing);
        if (item == null) { return; }
        if (item.Owner != null) { return; }
        if (item.GetClass() == null) { return; }
        RegisterShopCatalogItem(item);
    }

    private play void RegisterShopCatalogItem(Inventory item)
    {
        if (shopItemTypes.Size() >= 200) { return; }

        if (!EXPScoreShopRules.IsShopCandidate(item))
        {
            return;
        }

        Name itemType = item.GetClassName();
        if (itemType == 'None')
        {
            return;
        }

        String clsLow = String.Format("%s", itemType).MakeLower();
        if (clsLow == "basicarmor"    ||
            clsLow == "hexenarmor"    ||
            clsLow == "armoritem"     ||
            clsLow == "greenmana"     ||
            clsLow == "bluemana"      ||
            clsLow == "manaitem"      ||
            clsLow == "weaponpiece"   ||
            clsLow == "weaponholder"  ||
            clsLow == "fakeinventory")
        {
            return;
        }
        if (clsLow.IndexOf("neverselect") >= 0 ||
            clsLow.IndexOf("selected")   >= 0  ||
            clsLow.IndexOf("isplayer")   >= 0  ||
            clsLow.IndexOf("isnot")      >= 0  ||
            clsLow.IndexOf("loaded")     >= 0  ||
            clsLow.IndexOf("cantdo")     >= 0  ||
            clsLow.IndexOf("sae_")       >= 0  ||
            clsLow.IndexOf("_cam")       >= 0  ||
            clsLow.IndexOf("deathcam")   >= 0  ||
            clsLow.IndexOf("extcam")     >= 0  ||
            clsLow.IndexOf("spawner")    >= 0  ||
            clsLow.IndexOf("checker")    >= 0  ||
            clsLow.IndexOf("detector")   >= 0  ||
            clsLow.IndexOf("dropper")    >= 0  ||
            clsLow.IndexOf("dummy")      >= 0  ||
            clsLow.IndexOf("helper")     >= 0  ||
            clsLow.IndexOf("handler")    >= 0  ||
            clsLow.IndexOf("manager")    >= 0  ||
            clsLow.IndexOf("counter")    >= 0  ||
            clsLow.IndexOf("timer")      >= 0  ||
            clsLow.IndexOf("trigger")    >= 0  ||
            clsLow.IndexOf("flag")       >= 0  ||
            clsLow.IndexOf("token")      >= 0  ||
            clsLow.IndexOf("marker")     >= 0)
        {
            return;
        }

        for (int i = 0; i < shopItemTypes.Size(); i++)
        {
            if (shopItemTypes[i] == itemType) { return; }
        }

        String displayName = EXPScoreShopRules.GetDisplayName(item);
        if (displayName == "")
        {
            return;
        }

        int category = EXPScoreShopRules.GetCategory(item);
        int price    = EXPScoreShopRules.GetAutoPrice(item);
        if (price < 1) { price = 1; }

        shopItemTypes.Push(itemType);
        shopItemDisplayNames.Push(displayName);
        shopItemCategories.Push(category);
        shopItemPrices.Push(price);
        if ((shopItemTypes.Size() % 3) == 0) { SaveCatalogToCVar(); }
    }

    private play void BuyShopItemForPlayer(int playerNumber, int catalogIndex)
    {
        if (!IsValidPlayerNumber(playerNumber) || !PlayerInGame[playerNumber])
        {
            return;
        }

        if (catalogIndex < 0 || catalogIndex >= shopItemTypes.Size())
        {
            return;
        }

        PlayerPawn player = PlayerPawn(players[playerNumber].mo);
        if (player == null || player.health <= 0)
        {
            return;
        }

        if (catalogIndex >= shopItemPrices.Size() || catalogIndex >= shopItemTypes.Size()) { return; }
        int price = shopItemPrices[catalogIndex];
        int score = GetScore(player);
        String displayName = shopItemDisplayNames[catalogIndex];
        Name itemType = shopItemTypes[catalogIndex];

        if (score < price)
        {
            SetShopMessage(playerNumber, String.Format("Need %d more score", price - score));
            return;
        }

        if (itemType == 'None')
        {
            SetShopMessage(playerNumber, "Item type missing");
            return;
        }

        double spawnDist = 48.0;
        double spawnX = player.pos.x + cos(player.angle) * spawnDist;
        double spawnY = player.pos.y + sin(player.angle) * spawnDist;
        double spawnZ = player.pos.z + player.height * 0.55;
        vector3 spawnPos = (spawnX, spawnY, spawnZ);
        Actor spawnedPickup = Actor.Spawn(itemType, spawnPos);
        if (spawnedPickup == null)
        {
            SetShopMessage(playerNumber, String.Format("Can't spawn %s", displayName));
            return;
        }

        ApplyScoreDelta(player, playerNumber, -price, "BUY");
        SyncPlayerCaches(playerNumber);
        SetShopMessage(playerNumber, String.Format("Bought %s -%d", displayName, price));
        shopLastBuyTic[playerNumber] = level.time;
        if (GetUserBoolPlay(playerNumber, 'score_shop_sounds_enable', true))
        {
            S_StartSound("score/shop/buy", CHAN_AUTO, CHANF_UI|CHANF_LOCAL, 1.0, ATTN_NONE);
        }

        if (GetUserBoolPlay(playerNumber, 'score_log_score_events', true))
        {
            Console.Printf("P%d BUY %s -%d (%d)\n", playerNumber + 1, displayName, price, playerScoreCache[playerNumber]);
        }
    }

    private play void SetShopMessage(int playerNumber, String text)
    {
        if (!IsValidPlayerNumber(playerNumber))
        {
            return;
        }

        shopMessage[playerNumber] = text;
        shopMessageExpireTic[playerNumber] = level.time + 175;
    }

    private play bool AnyShopOpen()
    {
        for (int i = 0; i < MAXPLAYERS; i++)
        {
            if (shopOpen[i])
            {
                return true;
            }
        }

        return false;
    }
    private ui bool IsShopOpenUI(int playerNumber)
    {
        if (playerNumber < 0 || playerNumber >= MAXPLAYERS)
        {
            return false;
        }

        if (gamestate != GS_LEVEL)
        {
            return false;
        }

        if (!GetUserBoolUI('score_shop_enabled', true))
        {
            return false;
        }

        return shopOpen[playerNumber];
    }

    private ui int GetShopVisibleRowsUI()
    {
        int rows = GetUserIntUI('score_shop_rows', 12);
        if (rows < 4)  { rows = 4; }
        if (rows > 16) { rows = 16; }
        return rows;
    }

    private ui int GetShopItemCountForCategory(int category)
    {
        int count = 0;
        for (int i = 0; i < shopItemCategories.Size(); i++)
        {
            if (shopItemCategories[i] == category) { count++; }
        }
        return count;
    }

    private ui int GetShopPageCount(int category, int rowsPerPage)
    {
        int count = GetShopItemCountForCategory(category);
        if (count <= 0)
        {
            return 1;
        }

        int pages = count / rowsPerPage;
        if ((count % rowsPerPage) != 0)
        {
            pages++;
        }
        if (pages < 1)
        {
            pages = 1;
        }
        return pages;
    }

    private ui int GetShopVisibleCountOnPage(int category, int page, int rowsPerPage)
    {
        int count = GetShopItemCountForCategory(category);
        int start = page * rowsPerPage;
        if (count <= 0 || start >= count)
        {
            return 0;
        }

        int remaining = count - start;
        if (remaining > rowsPerPage)
        {
            remaining = rowsPerPage;
        }
        return remaining;
    }

    private ui int GetShopCatalogIndexForVisibleRow(int category, int page, int row, int rowsPerPage)
    {
        int wanted = (page * rowsPerPage) + row;
        int seen = 0;
        for (int i = 0; i < shopItemCategories.Size(); i++)
        {
            if (shopItemCategories[i] != category) { continue; }
            if (seen == wanted) { return i; }
            seen++;
        }
        return -1;
    }

    private ui int FindFirstAvailableShopCategoryUI()
    {
        for (int i = 0; i < 6; i++)
        {
            if (GetShopItemCountForCategory(i) > 0)
            {
                return i;
            }
        }
        return 0;
    }

    private ui int FindAdjacentAvailableShopCategoryUI(int currentCategory, int direction)
    {
        int current = currentCategory + direction;
        if (current < 0) current = 5;
        if (current > 5) current = 0;
        return current;
    }

    private ui void ClampShopCursorUI(int playerNumber)
    {
        int x = shopCursorX[playerNumber];
        int y = shopCursorY[playerNumber];

        if (x < 0) x = 0;
        if (y < 0) y = 0;
        if (x > Screen.GetWidth() - 1) x = Screen.GetWidth() - 1;
        if (y > Screen.GetHeight() - 1) y = Screen.GetHeight() - 1;

        shopCursorX[playerNumber] = x;
        shopCursorY[playerNumber] = y;
    }

    private ui void ClampShopSelectionUI(int playerNumber)
    {
        int category = shopSelectedCategory[playerNumber];
        int page = shopSelectedPage[playerNumber];
        int row = shopSelectedRow[playerNumber];

        int rows = GetShopVisibleRowsUI();
        int pages = GetShopPageCount(category, rows);
        if (page < 0) page = 0;
        if (page >= pages) page = pages - 1;
        if (page < 0) page = 0;

        int visibleCount = GetShopVisibleCountOnPage(category, page, rows);
        if (visibleCount <= 0)
        {
            row = 0;
        }
        else
        {
            if (row < 0) row = 0;
            if (row >= visibleCount) row = visibleCount - 1;
        }

        shopSelectedCategory[playerNumber] = category;
        shopSelectedPage[playerNumber] = page;
        shopSelectedRow[playerNumber] = row;
    }

    private ui void AdvanceShopCategoryUI(int playerNumber, int direction)
    {
        shopSelectedCategory[playerNumber] = FindAdjacentAvailableShopCategoryUI(shopSelectedCategory[playerNumber], direction);
        shopSelectedPage[playerNumber] = 0;
        shopSelectedRow[playerNumber] = 0;
        ClampShopSelectionUI(playerNumber);
    }

    private ui void AdvanceShopPageUI(int playerNumber, int direction)
    {
        int page = shopSelectedPage[playerNumber] + direction;
        int rows = GetShopVisibleRowsUI();
        int pages = GetShopPageCount(shopSelectedCategory[playerNumber], rows);
        if (page < 0) page = 0;
        if (page >= pages) page = pages - 1;
        shopSelectedPage[playerNumber] = page;
        ClampShopSelectionUI(playerNumber);
    }

    private ui void MoveShopSelectionUI(int playerNumber, int direction)
    {
        int row = shopSelectedRow[playerNumber] + direction;
        int page = shopSelectedPage[playerNumber];
        int rows = GetShopVisibleRowsUI();
        int visibleCount = GetShopVisibleCountOnPage(shopSelectedCategory[playerNumber], page, rows);

        if (visibleCount <= 0)
        {
            shopSelectedRow[playerNumber] = 0;
            return;
        }

        if (row < 0)
        {
            if (page > 0)
            {
                page--;
                visibleCount = GetShopVisibleCountOnPage(shopSelectedCategory[playerNumber], page, rows);
                row = visibleCount - 1;
            }
            else
            {
                row = 0;
            }
        }
        else if (row >= visibleCount)
        {
            int pages = GetShopPageCount(shopSelectedCategory[playerNumber], rows);
            if (page + 1 < pages)
            {
                page++;
                row = 0;
            }
            else
            {
                row = visibleCount - 1;
            }
        }

        shopSelectedPage[playerNumber] = page;
        shopSelectedRow[playerNumber] = row;
    }

    private ui void TryBuySelectedShopItemUI(int playerNumber)
    {
        ClampShopSelectionUI(playerNumber);
        int rows = GetShopVisibleRowsUI();
        int catalogIndex = GetShopCatalogIndexForVisibleRow(shopSelectedCategory[playerNumber], shopSelectedPage[playerNumber], shopSelectedRow[playerNumber], rows);
        if (catalogIndex >= 0)
        {
            EventHandler.SendNetworkEvent("scorerip_shop_buy", catalogIndex);
        }
    }

    private ui bool PointInRectUI(int px, int py, int x, int y, int w, int h)
    {
        return px >= x && py >= y && px < (x + w) && py < (y + h);
    }

    private ui void HandleShopClickUI(int playerNumber)
    {
        int sw = Screen.GetWidth();
        int sh = Screen.GetHeight();

        int panelW = int(sw * 0.92);
        int panelH = int(sh * 0.90);
        if (panelW < 700)    panelW = 700;
        if (panelH < 520)    panelH = 520;
        if (panelW > sw - 4) panelW = sw - 4;
        if (panelH > sh - 4) panelH = sh - 4;
        int panelX = (sw - panelW) / 2;
        int panelY = (sh - panelH) / 2;

        int cursorX = shopCursorX[playerNumber];
        int cursorY = shopCursorY[playerNumber];

        if (!PointInRectUI(cursorX, cursorY, panelX, panelY, panelW, panelH))
        {
            return;
        }

        double sc    = 2.0;
        Font   fnt   = BigFont;
        int    fontH  = int(fnt.GetHeight() * sc);
        int    fontOff = fontH / 8;
        double pulsePhase = (level.time % 35) / 35.0;
        int    pulse      = int(128.0 + 100.0 * sin(pulsePhase * 360.0));
        double pulseAlpha = 0.70 + 0.18 * sin(pulsePhase * 360.0);
        int    btnH  = fontH + 14;
        int    btnGap = 10;
        int    bottomY = panelY + panelH - btnH - btnGap;

        int btnPrevW  = int(fnt.StringWidth("PREV")      * sc) + 28;
        int btnNextW  = int(fnt.StringWidth("NEXT")      * sc) + 28;
        int btnCloseW = int(fnt.StringWidth("ESC CLOSE") * sc) + 28;

        int btnCloseX = panelX + panelW - btnCloseW - 14;
        int btnNextX  = btnCloseX - btnNextW - 10;
        int btnPrevX  = btnNextX  - btnPrevW - 10;

        if (PointInRectUI(cursorX, cursorY, btnCloseX, bottomY, btnCloseW, btnH))
        {
            EventHandler.SendNetworkEvent("scorerip_shop_close");
            return;
        }
        if (PointInRectUI(cursorX, cursorY, btnPrevX, bottomY, btnPrevW, btnH))
        {
            AdvanceShopPageUI(playerNumber, -1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return;
        }
        if (PointInRectUI(cursorX, cursorY, btnNextX, bottomY, btnNextW, btnH))
        {
            AdvanceShopPageUI(playerNumber, 1);
            EventHandler.SendNetworkEvent("scorerip_shop_choice");
            return;
        }

        int headerH = fontH + 16;
        int tabsX   = panelX + 14;
        int tabsY   = panelY + headerH + 10;
        int tabW    = int(panelW * 0.24);
        if (tabW < 220) tabW = 220;
        int tabH    = fontH + 16;
        int tabGap  = 6;

        for (int category = 0; category < 6; category++)
        {
            int tabY = tabsY + (category * (tabH + tabGap));
            if (PointInRectUI(cursorX, cursorY, tabsX, tabY, tabW, tabH))
            {
                shopSelectedCategory[playerNumber] = category;
                shopSelectedPage[playerNumber]     = 0;
                shopSelectedRow[playerNumber]      = 0;
                ClampShopSelectionUI(playerNumber);
                EventHandler.SendNetworkEvent("scorerip_shop_choice");
                return;
            }
        }

        int itemsX      = tabsX + tabW + 14;
        int itemsY      = tabsY;
        int itemsW      = (panelX + panelW - 14) - itemsX;
        int listHeaderH = fontH + 12;
        int listTop     = itemsY + listHeaderH;
        int rowH        = fontH + 14;
        int rows        = GetShopVisibleRowsUI();

        for (int row = 0; row < rows; row++)
        {
            int catalogIndex = GetShopCatalogIndexForVisibleRow(shopSelectedCategory[playerNumber], shopSelectedPage[playerNumber], row, rows);
            if (catalogIndex < 0) { break; }

            int rowY = listTop + (row * (rowH + 4));
            if (PointInRectUI(cursorX, cursorY, itemsX, rowY, itemsW, rowH))
            {
                shopSelectedRow[playerNumber] = row;
                EventHandler.SendNetworkEvent("scorerip_shop_buy", catalogIndex);
                EventHandler.SendNetworkEvent("scorerip_shop_choice");
                return;
            }
        }
    }

    private ui int GetShopRGBByPreset(int preset)
    {
        switch (preset)
        {
        case 0: return 0xC8A03A;
        case 1: return 0x2FA84A;
        case 2: return 0xB03030;
        case 3: return 0x4A8FD8;
        case 4: return 0xF1F1F1;
        case 5: return 0xD4C246;
        case 6: return 0x3058B0;
        case 7: return 0xD47C28;
        case 8: return 0x6E6E6E;
        case 9: return 0x8A6E52;
        case 10: return 0x402020;
        case 11: return 0x000000;
        default: return 0xC8A03A;
        }
    }

    private ui int GetShopRGBFromCVar(Name cvarName, int defaultPreset)
    {
        return GetShopRGBByPreset(GetUserIntUI(cvarName, defaultPreset));
    }

    private ui Font GetShopFontUI()
    {
        int sz = GetUserIntUI('score_shop_font_size', 0);
        if (sz == 1) { return Font.FindFont("BigFont"); }
        if (sz == 2) { return Font.FindFont("BigFont"); }
        return BigFont;
    }

    private ui void DrawShopOverlayUI(int playerNumber)
    {
        if (!GetUserBoolUI('score_shop_enabled', true))
        {
            return;
        }

        ClampShopSelectionUI(playerNumber);

        DrawScoreHudInShopUI(playerNumber);

        int flashDur = 22;
        int flashAge = level.time - shopLastBuyTic[playerNumber];
        if (shopLastBuyTic[playerNumber] > 0 && flashAge >= 0 && flashAge < flashDur)
        {
            int fsw = Screen.GetWidth();
            int fsh = Screen.GetHeight();
            double ft = 1.0 - (double(flashAge) / double(flashDur));
            double ftSoft = ft * ft;
            int flashAlpha = int(ftSoft * 100);
            Screen.Dim(0xFF2020, flashAlpha / 255.0, 0, 0, fsw, fsh);
        }

        PlayerInfo p = players[playerNumber];
        if (GetUserBoolUI('score_shop_shader_enable', true))
        {
            Shader.SetUniform1i(p, "shopshader", "shopOpen", 1);
            Shader.SetUniform1i(p, "shopshader", "shopCounter", shopShaderCounter[playerNumber]);
            Shader.SetEnabled(p, "shopshader", true);
        }
        else
        {
            Shader.SetEnabled(p, "shopshader", false);
        }

        int sw = Screen.GetWidth();
        int sh = Screen.GetHeight();

        double sc     = 2.0;
        Font   fnt    = BigFont;
        int    fontH  = int(fnt.GetHeight() * sc);
        int    fontOff = fontH / 8;
        double pulsePhase = (level.time % 35) / 35.0;
        double pulseAlpha = 0.68 + 0.20 * sin(pulsePhase * 360.0);
        int panelW = int(sw * 0.92);
        int panelH = int(sh * 0.90);
        if (panelW < 700)    panelW = 700;
        if (panelH < 520)    panelH = 520;
        if (panelW > sw - 4) panelW = sw - 4;
        if (panelH > sh - 4) panelH = sh - 4;
        int panelX = (sw - panelW) / 2;
        int panelY = (sh - panelH) / 2;

        int alphaPercent = GetUserIntUI('score_shop_panel_alpha', 55);
        if (alphaPercent < 0)   alphaPercent = 0;
        if (alphaPercent > 100) alphaPercent = 100;
        double alpha = alphaPercent / 100.0;
        int titleColor  = GetUIColorFromCVar('score_shop_color_title',    0);
        int accentColor = GetUIColorFromCVar('score_shop_color_accent',   3);
        int textColor   = GetUIColorFromCVar('score_shop_color_text',     4);
        int mutedColor  = GetUIColorFromCVar('score_shop_color_muted',    8);
        int redColor    = Font.FindFontColor("Red");
        int greenColor  = GetUIColorFromCVar('score_shop_color_price_ok', 1);
        int orangeColor = Font.FindFontColor("Orange");
        int priceNoColor = GetUIColorFromCVar('score_shop_color_price_no', 2);
        int panelBgRgb   = GetShopRGBFromCVar('score_shop_color_panel_bg', 10);
        int panelSideRgb = GetShopRGBFromCVar('score_shop_color_panel_side', 2);
        int borderRgb    = GetShopRGBFromCVar('score_shop_color_border', 2);
        int headerBgRgb  = GetShopRGBFromCVar('score_shop_color_header_bg', 10);
        int headerLineRgb = GetShopRGBFromCVar('score_shop_color_header_line', 2);
        int selectBgRgb  = GetShopRGBFromCVar('score_shop_color_select_bg', 2);
        int rowBgRgb     = GetShopRGBFromCVar('score_shop_color_row_bg', 10);
        int buttonBgRgb  = GetShopRGBFromCVar('score_shop_color_button_bg', 8);
        int tabActiveTextColor = GetUIColorFromCVar('score_shop_color_tab_active_text', 2);
        int closeTextColor = GetUIColorFromCVar('score_shop_color_close_text', 2);
        Screen.Dim(0x000000, 0.65, 0, 0, sw, sh);
        Screen.Dim(panelBgRgb, alpha + 0.18, panelX, panelY, panelW, panelH);
        Screen.Dim(panelSideRgb, 0.30, panelX, panelY, 6, panelH);
        Screen.Dim(panelSideRgb, 0.30, panelX + panelW - 6, panelY, 6, panelH);
        Screen.DrawThickLine(panelX,          panelY,          panelX + panelW, panelY,          2.5, borderRgb, 255);
        Screen.DrawThickLine(panelX,          panelY + panelH, panelX + panelW, panelY + panelH, 2.5, borderRgb, 255);
        Screen.DrawThickLine(panelX,          panelY,          panelX,          panelY + panelH, 2.5, borderRgb, 255);
        Screen.DrawThickLine(panelX + panelW, panelY,          panelX + panelW, panelY + panelH, 2.5, borderRgb, 255);
        int headerH  = fontH + 16;
        int headerTY = panelY + (headerH - fontH) / 2 + fontOff;
        Screen.Dim(headerBgRgb, 0.95, panelX + 2, panelY + 2, panelW - 4, headerH - 2);
        Screen.DrawThickLine(panelX + 2, panelY + headerH, panelX + panelW - 2, panelY + headerH, 2.0, headerLineRgb, 220);

        Screen.DrawText(fnt, titleColor, panelX + 18, headerTY, "SCORE SHOP", DTA_ScaleX, sc, DTA_ScaleY, sc);
        String scoreText = String.Format("SCORE: %d", playerScoreCache[playerNumber]);
        int    scoreW    = int(fnt.StringWidth(scoreText) * sc);
        Screen.DrawText(fnt, accentColor, panelX + panelW - scoreW - 18, headerTY, scoreText, DTA_ScaleX, sc, DTA_ScaleY, sc);
        int btnH    = fontH + 14;
        int btnGap  = 10;
        int bottomY = panelY + panelH - btnH - btnGap;

        int tabsX  = panelX + 14;
        int tabsY  = panelY + headerH + 10;
        int tabW   = int(panelW * 0.24);
        if (tabW < 220) tabW = 220;
        int tabH   = fontH + 16;
        int tabGap = 6;

        int itemsX      = tabsX + tabW + 14;
        int itemsY      = tabsY;
        int itemsW      = (panelX + panelW - 14) - itemsX;
        int listHeaderH = fontH + 12;
        int listTop     = itemsY + listHeaderH;
        int rowH        = fontH + 14;
        int rows        = GetShopVisibleRowsUI();
        for (int category = 0; category < 6; category++)
        {
            int  tabY      = tabsY + (category * (tabH + tabGap));
            bool active    = (category == shopSelectedCategory[playerNumber]);
            int  itemCount = GetShopItemCountForCategory(category);

            if (active)
            {
                Screen.Dim(selectBgRgb, pulseAlpha, tabsX, tabY, tabW, tabH);
                Screen.DrawThickLine(tabsX + 2,    tabY,        tabsX + 2,    tabY + tabH, 5.0, borderRgb, 255);
                Screen.DrawThickLine(tabsX,        tabY,        tabsX + tabW, tabY,        1.5, borderRgb, 200);
                Screen.DrawThickLine(tabsX,        tabY + tabH, tabsX + tabW, tabY + tabH, 1.5, borderRgb, 200);
                Screen.DrawThickLine(tabsX + tabW, tabY,        tabsX + tabW, tabY + tabH, 1.5, borderRgb, 200);
            }
            else
            {
                Screen.Dim(panelBgRgb, 0.65, tabsX, tabY, tabW, tabH);
                Screen.DrawThickLine(tabsX + tabW, tabY, tabsX + tabW, tabY + tabH, 1.0, borderRgb, 120);
            }

            String catName  = EXPScoreShopRules.GetCategoryName(category).MakeUpper();
            String countStr = String.Format("(%d)", itemCount);
            int    cntW     = int(fnt.StringWidth(countStr) * sc);
            int    tabTextY = tabY + (tabH - fontH) / 2 + fontOff;

            Screen.DrawText(fnt, active ? tabActiveTextColor : mutedColor,   tabsX + 14,               tabTextY, catName,  DTA_ScaleX, sc, DTA_ScaleY, sc);
            Screen.DrawText(fnt, active ? titleColor : mutedColor, tabsX + tabW - cntW - 12, tabTextY, countStr, DTA_ScaleX, sc, DTA_ScaleY, sc);
        }
        Screen.DrawThickLine(itemsX - 8, tabsY, itemsX - 8, bottomY - 4, 1.5, borderRgb, 220);
        int pageCount       = GetShopPageCount(shopSelectedCategory[playerNumber], rows);
        int totalInCategory = GetShopItemCountForCategory(shopSelectedCategory[playerNumber]);
        int listHdrTY       = itemsY + (listHeaderH - fontH) / 2 + fontOff;

        Screen.Dim(headerBgRgb, 0.75, itemsX, itemsY, itemsW, listHeaderH);
        Screen.DrawThickLine(itemsX, itemsY + listHeaderH, itemsX + itemsW, itemsY + listHeaderH, 1.5, borderRgb, 220);

        String catTitle = EXPScoreShopRules.GetCategoryName(shopSelectedCategory[playerNumber]).MakeUpper();
        Screen.DrawText(fnt, titleColor, itemsX + 8, listHdrTY, catTitle, DTA_ScaleX, sc, DTA_ScaleY, sc);

        String pageInfo = String.Format("PAGE %d/%d", shopSelectedPage[playerNumber] + 1, pageCount);
        int    piW      = int(fnt.StringWidth(pageInfo) * sc);
        Screen.DrawText(fnt, accentColor, itemsX + itemsW / 2 - piW / 2, listHdrTY, pageInfo, DTA_ScaleX, sc, DTA_ScaleY, sc);

        String totalInfo = String.Format("%d ITEMS", totalInCategory);
        int    tiW       = int(fnt.StringWidth(totalInfo) * sc);
        Screen.DrawText(fnt, mutedColor, itemsX + itemsW - tiW - 8, listHdrTY, totalInfo, DTA_ScaleX, sc, DTA_ScaleY, sc);
        if (totalInCategory <= 0)
        {
            Screen.DrawText(fnt, mutedColor, itemsX + 14, listTop + 14, "NO ITEMS IN THIS CATEGORY", DTA_ScaleX, sc, DTA_ScaleY, sc);
        }
        else
        {
            int listAreaH = (rows * (rowH + 4)) + 4;
            Screen.SetClipRect(itemsX, listTop, itemsW, listAreaH);
            for (int row = 0; row < rows; row++)
            {
                int catalogIndex = GetShopCatalogIndexForVisibleRow(shopSelectedCategory[playerNumber], shopSelectedPage[playerNumber], row, rows);
                if (catalogIndex < 0) { break; }

                int  rowY     = listTop + (row * (rowH + 4));
                bool selected = (row == shopSelectedRow[playerNumber]);

                if (selected)
                {
                    Screen.Dim(selectBgRgb, pulseAlpha, itemsX, rowY, itemsW, rowH);
                    Screen.DrawThickLine(itemsX + 2,      rowY,        itemsX + 2,      rowY + rowH, 5.0, borderRgb, 255);
                    Screen.DrawThickLine(itemsX,          rowY,        itemsX + itemsW, rowY,        1.5, borderRgb, 200);
                    Screen.DrawThickLine(itemsX,          rowY + rowH, itemsX + itemsW, rowY + rowH, 1.5, borderRgb, 200);
                    Screen.DrawThickLine(itemsX + itemsW, rowY,        itemsX + itemsW, rowY + rowH, 1.5, borderRgb, 200);
                }
                else if ((row % 2) == 0)
                {
                    Screen.Dim(rowBgRgb, 0.45, itemsX, rowY, itemsW, rowH);
                }

                if (catalogIndex >= shopItemDisplayNames.Size()) { break; }
                String itemName   = shopItemDisplayNames[catalogIndex];
                int    itemPrice  = GetShopPriceForCatalogIndexUI(catalogIndex);
                int    specialPct = GetShopSpecialDiscountForCatalogIndexUI(catalogIndex);
                bool   canAfford  = (playerScoreCache[playerNumber] >= itemPrice);
                String priceText  = specialPct > 0 ? String.Format("%d -%d%%", itemPrice, specialPct) : String.Format("%d", itemPrice);
                int    priceColor = specialPct > 0 ? orangeColor : (canAfford ? greenColor : priceNoColor);
                int    priceW     = int(fnt.StringWidth(priceText) * sc);
                int    priceX     = itemsX + itemsW - priceW - 14;
                String rowNum     = String.Format("%d.", row + 1);
                int    numW       = int(fnt.StringWidth(rowNum) * sc);
                int    textOffX   = 8;
                int    textY      = rowY + (rowH - fontH) / 2 + fontOff;

                Screen.DrawText(fnt, mutedColor, itemsX + textOffX, textY, rowNum, DTA_ScaleX, sc, DTA_ScaleY, sc);

                Screen.SetClipRect(itemsX + textOffX + numW + 8, rowY, priceX - (itemsX + textOffX + numW + 12), rowH);
                Screen.DrawText(fnt, selected ? titleColor : textColor, itemsX + textOffX + numW + 8, textY, itemName, DTA_ScaleX, sc, DTA_ScaleY, sc);
                Screen.ClearClipRect();

                Screen.DrawText(fnt, priceColor, priceX, textY, priceText, DTA_ScaleX, sc, DTA_ScaleY, sc);
                Screen.SetClipRect(itemsX, listTop, itemsW, listAreaH);
            }
            Screen.ClearClipRect();
        }
        if (shopMessageExpireTic[playerNumber] > level.time && shopMessage[playerNumber] != "")
        {
            String msg   = shopMessage[playerNumber];
            int    msgW  = int(fnt.StringWidth(msg) * sc);
            int    msgX  = itemsX + 14;
            int    msgBoxH = fontH + 16;
            int    msgBoxY = bottomY - msgBoxH - 14;
            int    msgTY   = msgBoxY + (msgBoxH - fontH) / 2 + fontOff;
            Screen.Dim(headerBgRgb, 0.88, msgX - 10, msgBoxY, msgW + 20, msgBoxH);
            Screen.DrawThickLine(msgX - 10, msgBoxY,            msgX + msgW + 10, msgBoxY,            1.5, borderRgb, 230);
            Screen.DrawThickLine(msgX - 10, msgBoxY + msgBoxH,  msgX + msgW + 10, msgBoxY + msgBoxH,  1.5, borderRgb, 230);
            Screen.DrawThickLine(msgX - 10, msgBoxY,            msgX - 10,        msgBoxY + msgBoxH,  1.5, borderRgb, 230);
            Screen.DrawThickLine(msgX + msgW + 10, msgBoxY,     msgX + msgW + 10, msgBoxY + msgBoxH,  1.5, borderRgb, 230);
            Screen.DrawText(fnt, titleColor, msgX, msgTY, msg, DTA_ScaleX, sc, DTA_ScaleY, sc);
        }
        String prevLabel  = "PREV";
        String nextLabel  = "NEXT";
        String closeLabel = "ESC CLOSE";
        int    btnPrevW   = int(fnt.StringWidth(prevLabel)  * sc) + 28;
        int    btnNextW   = int(fnt.StringWidth(nextLabel)  * sc) + 28;
        int    btnCloseW  = int(fnt.StringWidth(closeLabel) * sc) + 28;

        int btnCloseX = panelX + panelW - btnCloseW - 14;
        int btnNextX  = btnCloseX - btnNextW - 10;
        int btnPrevX  = btnNextX  - btnPrevW - 10;
        int textOffY  = (btnH - fontH) / 2 + fontOff;

        Screen.Dim(buttonBgRgb, 0.74, btnPrevX,  bottomY, btnPrevW,  btnH);
        Screen.Dim(buttonBgRgb, 0.74, btnNextX,  bottomY, btnNextW,  btnH);
        Screen.Dim(selectBgRgb, 0.82, btnCloseX, bottomY, btnCloseW, btnH);

        Screen.DrawThickLine(btnPrevX,             bottomY,        btnPrevX + btnPrevW,   bottomY,        1.5, borderRgb, 210);
        Screen.DrawThickLine(btnPrevX,             bottomY + btnH, btnPrevX + btnPrevW,   bottomY + btnH, 1.5, borderRgb, 210);
        Screen.DrawThickLine(btnPrevX,             bottomY,        btnPrevX,              bottomY + btnH, 1.5, borderRgb, 210);
        Screen.DrawThickLine(btnPrevX + btnPrevW,  bottomY,        btnPrevX + btnPrevW,   bottomY + btnH, 1.5, borderRgb, 210);

        Screen.DrawThickLine(btnNextX,             bottomY,        btnNextX + btnNextW,   bottomY,        1.5, borderRgb, 210);
        Screen.DrawThickLine(btnNextX,             bottomY + btnH, btnNextX + btnNextW,   bottomY + btnH, 1.5, borderRgb, 210);
        Screen.DrawThickLine(btnNextX,             bottomY,        btnNextX,              bottomY + btnH, 1.5, borderRgb, 210);
        Screen.DrawThickLine(btnNextX + btnNextW,  bottomY,        btnNextX + btnNextW,   bottomY + btnH, 1.5, borderRgb, 210);

        Screen.DrawThickLine(btnCloseX,             bottomY,        btnCloseX + btnCloseW, bottomY,        1.5, borderRgb, 230);
        Screen.DrawThickLine(btnCloseX,             bottomY + btnH, btnCloseX + btnCloseW, bottomY + btnH, 1.5, borderRgb, 230);
        Screen.DrawThickLine(btnCloseX,             bottomY,        btnCloseX,             bottomY + btnH, 1.5, borderRgb, 230);
        Screen.DrawThickLine(btnCloseX + btnCloseW, bottomY,        btnCloseX + btnCloseW, bottomY + btnH, 1.5, borderRgb, 230);

        Screen.DrawText(fnt, textColor, btnPrevX  + (btnPrevW  - int(fnt.StringWidth(prevLabel)  * sc)) / 2, bottomY + textOffY, prevLabel,  DTA_ScaleX, sc, DTA_ScaleY, sc);
        Screen.DrawText(fnt, textColor, btnNextX  + (btnNextW  - int(fnt.StringWidth(nextLabel)  * sc)) / 2, bottomY + textOffY, nextLabel,  DTA_ScaleX, sc, DTA_ScaleY, sc);
        Screen.DrawText(fnt, closeTextColor,  btnCloseX + (btnCloseW - int(fnt.StringWidth(closeLabel) * sc)) / 2, bottomY + textOffY, closeLabel, DTA_ScaleX, sc, DTA_ScaleY, sc);

        Screen.DrawText(fnt, mutedColor, panelX + 16, bottomY + textOffY, "ENTER=BUY  W/S=ROW  A/D=TAB  Q/E=PAGE", DTA_ScaleX, sc, DTA_ScaleY, sc);
    }

    private ui void DrawScoreHudInShopUI(int playerNumber)
    {
        if (!GetUserBoolUI('score_hud_show', true))
        {
            return;
        }

        int score   = playerScoreCache[playerNumber];
        int tier    = playerTierCache[playerNumber];
        int combo   = playerComboCount[playerNumber];
        int comboLeft = playerComboTimeLeft[playerNumber];
        int prestige  = playerPrestigeCache[playerNumber];
        int nextReward = EXPRewardRules.GetThresholdForTier(tier);
        int remaining  = nextReward - score;
        if (remaining < 0) { remaining = 0; }

        Font hudFont = GetHudFontUI();
        String scoreValue   = String.Format("%d", score);
        String nextValue    = nextReward < 0 ? "MAX" : String.Format("%d", remaining);
        String rankValue    = EXPScoreRules.GetRankNameForScore(score);
        int styleShown      = playerLastStylePercent[playerNumber];
        if (styleShown < 1) { styleShown = 100; }
        String styleGrade   = GetStyleGradeLabel(styleShown);
        String styleValue   = String.Format("%d%% %s", styleShown, styleGrade);
        String prestigeValue = String.Format("%d", prestige);

        int comboShown = combo;
        if (comboShown < 1) { comboShown = 1; }
        int comboSeconds = (comboLeft + 34) / 35;
        if (comboSeconds < 0) { comboSeconds = 0; }
        String comboValue = comboLeft > 0 ? String.Format("x%d (%d)", comboShown, comboSeconds) : "x1";

        int scoreColor   = GetUIColorFromCVar('score_hud_color_score',   0);
        int nextColor    = GetUIColorFromCVar('score_hud_color_next',    0);
        int rankColor    = GetUIColorFromCVar('score_hud_color_rank',    0);
        int comboColor   = GetUIColorFromCVar('score_hud_color_combo',   1);
        int styleColor   = GetUIColorFromCVar('score_hud_color_style',   1);
        int prestigeColor = GetUIColorFromCVar('score_hud_color_prestige', 0);

        int lineStep = GetUserIntUI('score_hud_line_spacing', 12);
        if (lineStep < 8)  { lineStep = 8; }
        if (lineStep > 28) { lineStep = 28; }
        int minStep = hudFont.GetHeight() + 1;
        if (lineStep < minStep) { lineStep = minStep; }

        double hudScale = GetUIScaleUI('score_hud_scale', 100);
        int scaledLineStep = int((lineStep * hudScale) + 0.5);
        if (scaledLineStep < 1) { scaledLineStep = 1; }

        int marginX = GetUserIntUI('score_hud_right_margin', 0);
        if (marginX < 0) { marginX = 0; }
        int marginY = GetUserIntUI('score_hud_top_margin', 0);
        if (marginY < 0) { marginY = 0; }

        int corner = GetCornerUI('score_hud_corner');
        bool isRight  = (corner == 1 || corner == 3);
        bool isBottom = (corner == 2 || corner == 3);

        bool showNext    = GetUserBoolUI('score_hud_show_next',    true);
        bool showRank    = GetUserBoolUI('score_hud_show_rank',    true);
        bool showCombo   = GetUserBoolUI('score_hud_show_combo',   true);
        bool showStyle   = GetUserBoolUI('score_hud_show_style',   true);
        bool showPrestige = GetUserBoolUI('score_hud_show_prestige', true) && GetUserBoolUI('score_prestige_enabled', true);

        int lineCount = 1;
        if (showNext)    { lineCount++; }
        if (showRank)    { lineCount++; }
        if (showCombo)   { lineCount++; }
        if (showStyle)   { lineCount++; }
        if (showPrestige){ lineCount++; }

        int labelWidth = hudFont.StringWidth("PRESTIGE");
        int valueWidth = hudFont.StringWidth(scoreValue);
        int w;
        w = hudFont.StringWidth(nextValue);    if (showNext    && w > valueWidth) { valueWidth = w; }
        w = hudFont.StringWidth(rankValue);    if (showRank    && w > valueWidth) { valueWidth = w; }
        w = hudFont.StringWidth(comboValue);   if (showCombo   && w > valueWidth) { valueWidth = w; }
        w = hudFont.StringWidth(styleValue);   if (showStyle   && w > valueWidth) { valueWidth = w; }
        w = hudFont.StringWidth(prestigeValue);if (showPrestige && w > valueWidth) { valueWidth = w; }

        int valueGap      = 8;
        int hudBlockWidth  = int(((labelWidth + valueGap + valueWidth) * hudScale) + 0.5);
        int hudBlockHeight = lineCount * scaledLineStep;

        int x = isRight  ? (Screen.GetWidth()  - hudBlockWidth  - marginX) : marginX;
        int y = isBottom ? (Screen.GetHeight()  - marginY - hudBlockHeight) : (marginY + 8);
        if (x < 0) { x = 0; }
        if (y < 0) { y = 0; }

        int xDraw  = int((x / hudScale) + 0.5);
        int yDraw  = int((y / hudScale) + 0.5);
        int valueX = xDraw + labelWidth + valueGap;
        int lineIndex = 0;

        BeginScaleTransformUI(hudScale);

        DrawHudLine(hudFont, scoreColor,   xDraw, valueX, yDraw + (lineIndex * lineStep), "SCORE",   scoreValue);   lineIndex++;
        if (showNext)    { DrawHudLine(hudFont, nextColor,    xDraw, valueX, yDraw + (lineIndex * lineStep), "NEXT",    nextValue);    lineIndex++; }
        if (showRank)    { DrawHudLine(hudFont, rankColor,    xDraw, valueX, yDraw + (lineIndex * lineStep), "RANK",    rankValue);    lineIndex++; }
        if (showCombo)   { DrawHudLine(hudFont, comboColor,   xDraw, valueX, yDraw + (lineIndex * lineStep), "COMBO",   comboValue);   lineIndex++; }
        if (showStyle)   { DrawHudLine(hudFont, styleColor,   xDraw, valueX, yDraw + (lineIndex * lineStep), "STYLE",   styleValue);   lineIndex++; }
        if (showPrestige){ DrawHudLine(hudFont, prestigeColor, xDraw, valueX, yDraw + (lineIndex * lineStep), "PRESTIGE", prestigeValue); }

        EndScaleTransformUI();
    }
}








