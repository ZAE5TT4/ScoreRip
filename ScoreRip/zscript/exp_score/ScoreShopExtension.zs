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

    ui int shopCursorX[MAXPLAYERS];
    ui int shopCursorY[MAXPLAYERS];
    ui int shopSelectedCategory[MAXPLAYERS];
    ui int shopSelectedPage[MAXPLAYERS];
    ui int shopSelectedRow[MAXPLAYERS];
    ui int shopLastInputTic[MAXPLAYERS];

    override void OnRegister()
    {
        IsUiProcessor = false;
        RequireMouse = false;
        ResetShopAllRuntime();
    }

    override void WorldThingSpawned(WorldEvent e)
    {
        RegisterShopCatalogThing(e.Thing);
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
            return true;
        }
        if (keyText == "s")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            MoveShopSelectionUI(playerNumber, 1);
            return true;
        }
        if (keyText == "a")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopCategoryUI(playerNumber, -1);
            return true;
        }
        if (keyText == "d")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopCategoryUI(playerNumber, 1);
            return true;
        }
        if (keyText == "q")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopPageUI(playerNumber, -1);
            return true;
        }
        if (keyText == "e")
        {
            if (!CanProcessShopInputUI(playerNumber, 8)) return true;
            AdvanceShopPageUI(playerNumber, 1);
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

        if (!AnyShopOpen())
        {
            IsUiProcessor = false;
            RequireMouse = false;
        }
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

    private play void RefreshShopCatalogForPlayer(int playerNumber)
    {
        RegisterPlayerShopInventory(playerNumber);
        ScanWorldShopItems();
    }

    private play void ScanWorldShopItems()
    {
        Actor mo;
        ThinkerIterator thinker = ThinkerIterator.Create("Actor", Thinker.STAT_DEFAULT);

        while ((mo = Actor(thinker.Next())))
        {
            RegisterShopCatalogThing(mo);
        }
    }

    private play void RegisterShopCatalogThing(Actor thing)
    {
        Inventory item = Inventory(thing);
        if (item == null)
        {
            return;
        }

        if (item.Owner != null)
        {
            return;
        }

        RegisterShopCatalogItem(item);
    }

    private play void RegisterShopCatalogItem(Inventory item)
    {
        if (!EXPScoreShopRules.IsShopCandidate(item))
        {
            return;
        }

        Name itemType = item.GetClassName();
        if (itemType == 'None')
        {
            return;
        }

        for (int i = 0; i < shopItemTypes.Size(); i++)
        {
            if (shopItemTypes[i] == itemType)
            {
                return;
            }
        }

        String displayName = EXPScoreShopRules.GetDisplayName(item);
        if (displayName == "")
        {
            displayName = String.Format("%s", item.GetClassName());
        }

        int category = EXPScoreShopRules.GetCategory(item);
        int price = EXPScoreShopRules.GetAutoPrice(item);
        if (price < 1)
        {
            price = 1;
        }

        shopItemTypes.Push(itemType);
        shopItemDisplayNames.Push(displayName);
        shopItemCategories.Push(category);
        shopItemPrices.Push(price);
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

        vector3 spawnPos = (player.pos.x + 48.0, player.pos.y, player.pos.z + 20.0);
        Actor spawnedPickup = Actor.Spawn(itemType, spawnPos);
        if (spawnedPickup == null)
        {
            SetShopMessage(playerNumber, String.Format("Can't spawn %s", displayName));
            return;
        }

        ApplyScoreDelta(player, playerNumber, -price, "BUY");
        SyncPlayerCaches(playerNumber);
        SetShopMessage(playerNumber, String.Format("Bought %s -%d", displayName, price));

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
            if (shopItemCategories[i] == category)
            {
                count++;
            }
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
            if (shopItemCategories[i] != category)
            {
                continue;
            }

            if (seen == wanted)
            {
                return i;
            }
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
        int    fontOff = fontH / 8;  // коррекция: текст визуально выше центра
        int    btnH  = fontH + 14;
        int    btnGap = 10;
        int    bottomY = panelY + panelH - btnH - btnGap;

        // Ширины кнопок — идентично DrawShopOverlayUI
        int btnPrevW  = int(fnt.StringWidth("PREV")      * sc) + 28;
        int btnNextW  = int(fnt.StringWidth("NEXT")      * sc) + 28;
        int btnCloseW = int(fnt.StringWidth("ESC CLOSE") * sc) + 28;

        int btnCloseX = panelX + panelW - btnCloseW - 14;
        int btnNextX  = btnCloseX - btnNextW - 10;
        int btnPrevX  = btnNextX  - btnPrevW - 10;

        // Кнопки
        if (PointInRectUI(cursorX, cursorY, btnCloseX, bottomY, btnCloseW, btnH))
        {
            EventHandler.SendNetworkEvent("scorerip_shop_close");
            return;
        }
        if (PointInRectUI(cursorX, cursorY, btnPrevX, bottomY, btnPrevW, btnH))
        {
            AdvanceShopPageUI(playerNumber, -1);
            return;
        }
        if (PointInRectUI(cursorX, cursorY, btnNextX, bottomY, btnNextW, btnH))
        {
            AdvanceShopPageUI(playerNumber, 1);
            return;
        }

        // Вкладки
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
                return;
            }
        }

        // Строки товаров
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
                return;
            }
        }
    }


    private ui void DrawShopOverlayUI(int playerNumber)
    {
        if (!GetUserBoolUI('score_shop_enabled', true))
        {
            return;
        }

        ClampShopSelectionUI(playerNumber);

        int sw = Screen.GetWidth();
        int sh = Screen.GetHeight();

        double sc    = 2.0;
        Font   fnt   = BigFont;
        int    fontH  = int(fnt.GetHeight() * sc);
        int    fontOff = fontH / 8;  // коррекция: текст визуально выше центра

        // ── Панель ────────────────────────────────────────────────────────────
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

        int titleColor  = Font.FindFontColor("Gold");
        int accentColor = Font.FindFontColor("LightBlue");
        int textColor   = Font.FindFontColor("White");
        int mutedColor  = Font.FindFontColor("Gray");
        int redColor    = Font.FindFontColor("Red");
        int greenColor  = Font.FindFontColor("LightGreen");

        // ── Фон + рамка панели ────────────────────────────────────────────────
        Screen.Dim(0x000000, 0.62, 0, 0, sw, sh);
        Screen.Dim(0x080406, alpha + 0.15, panelX, panelY, panelW, panelH);
        Screen.DrawThickLine(panelX,          panelY,          panelX + panelW, panelY,          2.0, 0xAA2020, 255);
        Screen.DrawThickLine(panelX,          panelY + panelH, panelX + panelW, panelY + panelH, 2.0, 0xAA2020, 255);
        Screen.DrawThickLine(panelX,          panelY,          panelX,          panelY + panelH, 2.0, 0xAA2020, 255);
        Screen.DrawThickLine(panelX + panelW, panelY,          panelX + panelW, panelY + panelH, 2.0, 0xAA2020, 255);

        // ── Шапка ─────────────────────────────────────────────────────────────
        int headerH  = fontH + 16;
        int headerTY = panelY + (headerH - fontH) / 2 + fontOff;  // текст по центру шапки
        Screen.Dim(0x2A0808, 0.92, panelX + 2, panelY + 2, panelW - 4, headerH - 2);
        Screen.DrawThickLine(panelX + 2, panelY + headerH, panelX + panelW - 2, panelY + headerH, 2.0, 0xCC3030, 220);
        Screen.DrawText(fnt, titleColor, panelX + 18, headerTY, "SCORE SHOP", DTA_ScaleX, sc, DTA_ScaleY, sc);
        String scoreText = String.Format("SCORE: %d", playerScoreCache[playerNumber]);
        int    scoreW    = int(fnt.StringWidth(scoreText) * sc);
        Screen.DrawText(fnt, accentColor, panelX + panelW - scoreW - 18, headerTY, scoreText, DTA_ScaleX, sc, DTA_ScaleY, sc);

        // ── Константы макета ──────────────────────────────────────────────────
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
        // Увеличено до 12 строк по умолчанию
        int rows        = GetShopVisibleRowsUI();

        // ── Вкладки ───────────────────────────────────────────────────────────
        for (int category = 0; category < 6; category++)
        {
            int  tabY      = tabsY + (category * (tabH + tabGap));
            bool active    = (category == shopSelectedCategory[playerNumber]);
            int  itemCount = GetShopItemCountForCategory(category);

            if (active)
            {
                Screen.Dim(0x5A1818, 0.84, tabsX, tabY, tabW, tabH);
                // Все 4 стороны — как у выделенного товара
                Screen.DrawThickLine(tabsX,          tabY,        tabsX,          tabY + tabH, 5.0, 0xFF3030, 255);
                Screen.DrawThickLine(tabsX,          tabY,        tabsX + tabW,   tabY,        1.5, 0xCC2020, 200);
                Screen.DrawThickLine(tabsX,          tabY + tabH, tabsX + tabW,   tabY + tabH, 1.5, 0xCC2020, 200);
                Screen.DrawThickLine(tabsX + tabW,   tabY,        tabsX + tabW,   tabY + tabH, 1.5, 0xCC2020, 200);
            }
            else
            {
                Screen.Dim(0x110A0A, 0.55, tabsX, tabY, tabW, tabH);
            }

            String catName  = EXPScoreShopRules.GetCategoryName(category).MakeUpper();
            String countStr = String.Format("(%d)", itemCount);
            int    cntW     = int(fnt.StringWidth(countStr) * sc);
            int    tabTextY = tabY + (tabH - fontH) / 2 + fontOff;

            Screen.DrawText(fnt, active ? redColor : mutedColor,   tabsX + 14,               tabTextY, catName,  DTA_ScaleX, sc, DTA_ScaleY, sc);
            Screen.DrawText(fnt, active ? titleColor : mutedColor, tabsX + tabW - cntW - 12, tabTextY, countStr, DTA_ScaleX, sc, DTA_ScaleY, sc);
        }

        // Вертикальный разделитель
        Screen.DrawThickLine(itemsX - 8, tabsY, itemsX - 8, bottomY - 4, 1.0, 0x662020, 160);

        // ── Заголовок списка ──────────────────────────────────────────────────
        int pageCount       = GetShopPageCount(shopSelectedCategory[playerNumber], rows);
        int totalInCategory = GetShopItemCountForCategory(shopSelectedCategory[playerNumber]);
        int listHdrTY       = itemsY + (listHeaderH - fontH) / 2 + fontOff;  // текст по центру заголовка

        Screen.Dim(0x1A0808, 0.70, itemsX, itemsY, itemsW, listHeaderH);
        Screen.DrawThickLine(itemsX, itemsY + listHeaderH, itemsX + itemsW, itemsY + listHeaderH, 1.5, 0x882020, 180);

        String catTitle = EXPScoreShopRules.GetCategoryName(shopSelectedCategory[playerNumber]).MakeUpper();
        Screen.DrawText(fnt, titleColor, itemsX + 8, listHdrTY, catTitle, DTA_ScaleX, sc, DTA_ScaleY, sc);

        String pageInfo = String.Format("PAGE %d/%d", shopSelectedPage[playerNumber] + 1, pageCount);
        int    piW      = int(fnt.StringWidth(pageInfo) * sc);
        Screen.DrawText(fnt, accentColor, itemsX + itemsW / 2 - piW / 2, listHdrTY, pageInfo, DTA_ScaleX, sc, DTA_ScaleY, sc);

        String totalInfo = String.Format("%d ITEMS", totalInCategory);
        int    tiW       = int(fnt.StringWidth(totalInfo) * sc);
        Screen.DrawText(fnt, mutedColor, itemsX + itemsW - tiW - 8, listHdrTY, totalInfo, DTA_ScaleX, sc, DTA_ScaleY, sc);

        // ── Список товаров ────────────────────────────────────────────────────
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
                    Screen.Dim(0x5A1818, 0.84, itemsX, rowY, itemsW, rowH);
                    Screen.DrawThickLine(itemsX,          rowY,        itemsX,          rowY + rowH, 5.0, 0xFF3030, 255);
                    Screen.DrawThickLine(itemsX,          rowY,        itemsX + itemsW, rowY,        1.5, 0xCC2020, 200);
                    Screen.DrawThickLine(itemsX,          rowY + rowH, itemsX + itemsW, rowY + rowH, 1.5, 0xCC2020, 200);
                    Screen.DrawThickLine(itemsX + itemsW, rowY,        itemsX + itemsW, rowY + rowH, 1.5, 0xCC2020, 200);
                }
                else if ((row % 2) == 0)
                {
                    Screen.Dim(0x0C0808, 0.42, itemsX, rowY, itemsW, rowH);
                }

                String itemName   = shopItemDisplayNames[catalogIndex];
                int    itemPrice  = shopItemPrices[catalogIndex];
                bool   canAfford  = (playerScoreCache[playerNumber] >= itemPrice);
                String priceText  = String.Format("%d", itemPrice);
                int    priceColor = canAfford ? greenColor : redColor;
                int    priceW     = int(fnt.StringWidth(priceText) * sc);
                int    priceX     = itemsX + itemsW - priceW - 14;
                String rowNum     = String.Format("%d.", row + 1);
                int    numW       = int(fnt.StringWidth(rowNum) * sc);
                int    textY      = rowY + (rowH - fontH) / 2 + fontOff;

                Screen.DrawText(fnt, mutedColor, itemsX + 8, textY, rowNum, DTA_ScaleX, sc, DTA_ScaleY, sc);

                Screen.SetClipRect(itemsX + numW + 18, rowY, priceX - (itemsX + numW + 22), rowH);
                Screen.DrawText(fnt, selected ? titleColor : textColor, itemsX + numW + 18, textY, itemName, DTA_ScaleX, sc, DTA_ScaleY, sc);
                Screen.ClearClipRect();

                Screen.DrawText(fnt, priceColor, priceX, textY, priceText, DTA_ScaleX, sc, DTA_ScaleY, sc);
                Screen.SetClipRect(itemsX, listTop, itemsW, listAreaH);
            }
            Screen.ClearClipRect();
        }

        // ── Уведомление — левее и выше кнопок ────────────────────────────────
        if (shopMessageExpireTic[playerNumber] > level.time && shopMessage[playerNumber] != "")
        {
            String msg  = shopMessage[playerNumber];
            int    msgW = int(fnt.StringWidth(msg) * sc);
            int    msgX = itemsX + 14;
            int    msgY = bottomY - fontH - 20;
            Screen.Dim(0x200000, 0.85, msgX - 10, msgY - 6, msgW + 20, fontH + 12);
            Screen.DrawThickLine(msgX - 10, msgY - 6,          msgX + msgW + 10, msgY - 6,          1.5, 0xFF3030, 230);
            Screen.DrawThickLine(msgX - 10, msgY + fontH + 6,  msgX + msgW + 10, msgY + fontH + 6,  1.5, 0xFF3030, 230);
            Screen.DrawThickLine(msgX - 10, msgY - 6,          msgX - 10,        msgY + fontH + 6,  1.5, 0xFF3030, 230);
            Screen.DrawThickLine(msgX + msgW + 10, msgY - 6,   msgX + msgW + 10, msgY + fontH + 6,  1.5, 0xFF3030, 230);
            Screen.DrawText(fnt, titleColor, msgX, msgY, msg, DTA_ScaleX, sc, DTA_ScaleY, sc);
        }

        // ── Кнопки ────────────────────────────────────────────────────────────
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

        Screen.Dim(0x141414, 0.74, btnPrevX,  bottomY, btnPrevW,  btnH);
        Screen.Dim(0x141414, 0.74, btnNextX,  bottomY, btnNextW,  btnH);
        Screen.Dim(0x2A1010, 0.82, btnCloseX, bottomY, btnCloseW, btnH);

        Screen.DrawThickLine(btnPrevX,             bottomY,        btnPrevX + btnPrevW,   bottomY,        1.5, 0x886030, 210);
        Screen.DrawThickLine(btnPrevX,             bottomY + btnH, btnPrevX + btnPrevW,   bottomY + btnH, 1.5, 0x886030, 210);
        Screen.DrawThickLine(btnPrevX,             bottomY,        btnPrevX,              bottomY + btnH, 1.5, 0x886030, 210);
        Screen.DrawThickLine(btnPrevX + btnPrevW,  bottomY,        btnPrevX + btnPrevW,   bottomY + btnH, 1.5, 0x886030, 210);

        Screen.DrawThickLine(btnNextX,             bottomY,        btnNextX + btnNextW,   bottomY,        1.5, 0x886030, 210);
        Screen.DrawThickLine(btnNextX,             bottomY + btnH, btnNextX + btnNextW,   bottomY + btnH, 1.5, 0x886030, 210);
        Screen.DrawThickLine(btnNextX,             bottomY,        btnNextX,              bottomY + btnH, 1.5, 0x886030, 210);
        Screen.DrawThickLine(btnNextX + btnNextW,  bottomY,        btnNextX + btnNextW,   bottomY + btnH, 1.5, 0x886030, 210);

        Screen.DrawThickLine(btnCloseX,             bottomY,        btnCloseX + btnCloseW, bottomY,        1.5, 0xCC2020, 230);
        Screen.DrawThickLine(btnCloseX,             bottomY + btnH, btnCloseX + btnCloseW, bottomY + btnH, 1.5, 0xCC2020, 230);
        Screen.DrawThickLine(btnCloseX,             bottomY,        btnCloseX,             bottomY + btnH, 1.5, 0xCC2020, 230);
        Screen.DrawThickLine(btnCloseX + btnCloseW, bottomY,        btnCloseX + btnCloseW, bottomY + btnH, 1.5, 0xCC2020, 230);

        Screen.DrawText(fnt, textColor, btnPrevX  + (btnPrevW  - int(fnt.StringWidth(prevLabel)  * sc)) / 2, bottomY + textOffY, prevLabel,  DTA_ScaleX, sc, DTA_ScaleY, sc);
        Screen.DrawText(fnt, textColor, btnNextX  + (btnNextW  - int(fnt.StringWidth(nextLabel)  * sc)) / 2, bottomY + textOffY, nextLabel,  DTA_ScaleX, sc, DTA_ScaleY, sc);
        Screen.DrawText(fnt, redColor,  btnCloseX + (btnCloseW - int(fnt.StringWidth(closeLabel) * sc)) / 2, bottomY + textOffY, closeLabel, DTA_ScaleX, sc, DTA_ScaleY, sc);

        // Подсказка — на уровне кнопок, но чуть ниже текста кнопок
        Screen.DrawText(fnt, mutedColor, panelX + 16, bottomY + textOffY + 4, "ENTER=BUY  W/S=ROW  A/D=TAB  Q/E=PAGE", DTA_ScaleX, sc, DTA_ScaleY, sc);
    }
}
