using System.Text.Json.Nodes;
using CocEnglish.Progress.Application;
using CocEnglish.Shared.Errors;
using CocEnglish.Shared.Persistence;
using CocEnglish.Shared.Security;
using Xunit;

namespace CocEnglish.Progress.Tests;

public sealed class ProgressEconomyTests
{
    [Fact]
    public async Task Shop_ReusedLedgerIdentityCannotDebitAgainEvenWithoutHttpReceipt()
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 500;
        var app = new ProgressShop();
        await store.TransactAsync((tx, ct) => app.BuyAsync(tx, "alice", new("timer_boost", 1, "shop-v1"), "same", ct));
        var commits = driver.Commits;
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.BuyAsync(tx, "alice", new("timer_boost", 1, "shop-v1"), "same", ct)));
        Assert.Equal("IDEMPOTENCY_CONFLICT", error.Code);
        Assert.Equal("LEDGER_ROW_EXISTS", error.Details.Text("reason"));
        Assert.Equal(commits, driver.Commits);
        Assert.Equal(450, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
        Assert.Equal(1, driver.Rows[("p_inventory", CanonicalWire.RowId("p_inventory", "alice", "timer_boost"))].Number("quantity"));
    }

    [Theory]
    [InlineData(19, false, false)]
    [InlineData(20, true, false)]
    [InlineData(50, true, true)]
    public async Task Shop_CatalogAvailabilityUsesExactPriceBoundary(long gems, bool freeze, bool refill)
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = gems;
        var catalog = await store.TransactAsync((tx, ct) => new ProgressShop().ListAsync(tx, "alice", ct));
        Assert.Equal(freeze, catalog.Items.Single(i => i.ItemId == "streak_freeze").Available);
        Assert.Equal(refill, catalog.Items.Single(i => i.ItemId == "energy_refill").Available);
    }

    [Fact]
    public async Task Shop_TimerActivationKeepsItsFiveMinuteOneMultiplierPolicy()
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 50;
        var app = new ProgressShop();
        await store.TransactAsync((tx, ct) => app.BuyAsync(tx, "alice", new("timer_boost", 1, "shop-v1"), "buy", ct));
        var result = await store.TransactAsync((tx, ct) => app.ActivateAsync(tx, "alice", "timer_boost", "activate", ct));
        Assert.Equal("TIMER_BOOST", result.Kind);
        Assert.Equal(1, result.Multiplier);
        Assert.Equal(TimeSpan.FromMinutes(5), result.EndsAt - result.StartsAt);
        Assert.Equal(0, result.Inventory.Quantity);
    }

    [Theory]
    [InlineData("expired", "STREAK_REPAIR_EXPIRED")]
    [InlineData("wrong-day", "STREAK_REPAIR_EXPIRED")]
    [InlineData("balance", "INSUFFICIENT_GEMS")]
    [InlineData("no-item", "ITEM_UNAVAILABLE")]
    public async Task Shop_InvalidRepairLeavesWalletAndOfferUnchanged(string scenario, string code)
    {
        var (driver, store) = await Fixture();
        var row = driver.Rows[("p_rewards", Id("p_rewards"))];
        row["lostStreak"] = 5; row["lostStreakDay"] = scenario == "expired" ? "2026-10-31" : "2026-11-01";
        var day = scenario == "wrong-day" ? "2026-11-02" : row.Text("lostStreakDay")!;
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressShop().RepairAsync(tx, "alice", new(day, scenario == "no-item" ? "ITEM" : "GEMS"), "key", ct)));
        Assert.Equal(code, error.Code);
        Assert.Equal(1, driver.Commits);
        Assert.Equal(20, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
        Assert.Equal(5, driver.Rows[("p_rewards", Id("p_rewards"))].Number("lostStreak"));
    }
    [Fact]
    public async Task Shop_CatalogProjectsWalletCapacityAndOwnInventoryWithoutWrites()
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 200;
        driver.Rows[("p_rewards", Id("p_rewards"))]["currentStreak"] = 365;
        driver.Rows[("p_rewards", Id("p_rewards"))]["freezeSlots"] = 4;
        driver.Rows[("p_inventory", "own")] = new() { ["userId"] = "alice", ["itemId"] = "xp_boost_15", ["quantity"] = 3, ["expiresAt"] = "2026-12-01T00:00:00.000Z" };
        driver.Rows[("p_inventory", "foreign")] = new() { ["userId"] = "bob", ["itemId"] = "timer_boost", ["quantity"] = 99 };
        var shop = await store.TransactAsync((tx, ct) => new ProgressShop().ListAsync(tx, "alice", ct));
        Assert.Equal("shop-v1", shop.CatalogVersion);
        Assert.Equal(200, shop.Gems);
        Assert.Equal(new[] { "streak_freeze", "streak_repair", "xp_boost_15", "timer_boost", "energy_refill", "weekend_amulet" }, shop.Items.Select(i => i.ItemId));
        Assert.Equal(new long[] { 20, 100, 100, 50, 50, 150 }, shop.Items.Select(i => i.PriceGems));
        Assert.Equal(new long?[] { null, null, 15, 5, null, null }, shop.Items.Select(i => i.DurationMinutes));
        Assert.Equal(5, shop.Items[0].MaxOwned);
        Assert.Equal(4, shop.Items[0].Owned);
        Assert.True(shop.Items[0].Available);
        Assert.False(shop.Items[2].Available);
        Assert.True(shop.Items[4].Available);
        Assert.False(shop.Items[5].Available);
        Assert.Equal(3, Assert.Single(shop.Inventory).Quantity);
        Assert.Equal(DateTimeOffset.Parse("2026-12-01T00:00:00Z"), shop.Inventory[0].ExpiresAt);
        Assert.Equal(1, driver.Commits);
    }

    [Theory]
    [InlineData("streak_freeze", 2, 40, 2, false)]
    [InlineData("streak_repair", 1, 100, 0, false)]
    [InlineData("xp_boost_15", 2, 200, 0, false)]
    [InlineData("timer_boost", 1, 50, 0, false)]
    [InlineData("energy_refill", 1, 50, 0, true)]
    public async Task Shop_PurchaseDebitsOneWalletAndCommitsInventoryOrEnergyEvent(string item, long quantity, long spent, long slots, bool energy)
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 200;
        var result = await store.TransactAsync((tx, ct) => new ProgressShop().BuyAsync(tx, "alice", new(item, quantity, "shop-v1"), "purchase-key", ct));
        Assert.Equal(200 - spent, result.Gems);
        Assert.Equal(spent, result.GemsSpent);
        Assert.Equal(quantity, result.Quantity);
        Assert.Equal(slots, result.FreezeSlots);
        Assert.Equal(energy, result.EnergyGrantPending);
        Assert.Equal(1, driver.Rows[("p_rewards", Id("p_rewards"))].Number("revision"));
        var ledger = driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "alice", result.OperationId, "SHOP"))];
        Assert.Equal(-spent, ledger.Number("gemsDelta"));
        Assert.Equal(item, ledger.Text("rewardIdentity"));
        if (item == "streak_freeze")
        {
            Assert.Null(result.Inventory);
            Assert.Equal(quantity, Assert.Single(driver.Rows, p => p.Key.Table == "p_freeze_ledger").Value.Number("slotDelta"));
        }
        else if (energy)
        {
            Assert.Null(result.Inventory);
            var outbox = Assert.Single(driver.Rows, p => p.Key.Table == "p_outbox").Value;
            Assert.Equal("energy.granted.v1", outbox.Text("type"));
            var payload = JsonNode.Parse(outbox.Text("payloadJson")!)!.AsObject();
            Assert.Equal(result.OperationId, payload.Text("operationId"));
            Assert.Equal("alice", payload.Text("userId"));
            Assert.Equal("SHOP", payload.Text("reason"));
            Assert.True(payload.Flag("refillToCapacity"));
            Assert.Null(payload["amount"]);
        }
        else Assert.Equal(quantity, result.Inventory!.Quantity);
    }

    [Theory]
    [InlineData("version", "ITEM_UNAVAILABLE")]
    [InlineData("unknown", "ITEM_UNAVAILABLE")]
    [InlineData("amulet", "ITEM_UNAVAILABLE")]
    [InlineData("capacity", "FREEZE_CAPACITY")]
    [InlineData("held", "ITEM_UNAVAILABLE")]
    [InlineData("balance", "INSUFFICIENT_GEMS")]
    [InlineData("refill-quantity", "ITEM_UNAVAILABLE")]
    public async Task Shop_RejectedPurchaseDoesNotDebitOrCreateLedger(string scenario, string code)
    {
        var (driver, store) = await Fixture();
        var item = scenario switch { "unknown" => "unknown", "amulet" => "weekend_amulet", "capacity" => "streak_freeze", "refill-quantity" => "energy_refill", _ => "xp_boost_15" };
        if (scenario == "capacity") driver.Rows[("p_rewards", Id("p_rewards"))]["freezeSlots"] = 2;
        if (scenario == "held") driver.Rows[("p_inventory", CanonicalWire.RowId("p_inventory", "alice", item))] = new() { ["userId"] = "alice", ["itemId"] = item, ["quantity"] = 3 };
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressShop().BuyAsync(tx, "alice", new(item, scenario == "refill-quantity" ? 2 : 1, scenario == "version" ? "old" : "shop-v1"), "key", ct)));
        Assert.Equal(code, error.Code);
        Assert.Equal(1, driver.Commits);
        Assert.Equal(20, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
        Assert.Single(driver.Rows, p => p.Key.Table == "p_reward_ledger");
    }

    [Fact]
    public async Task Shop_ActivationConsumesInventoryAndStacksAfterSameKindWindow()
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 200;
        var app = new ProgressShop();
        await store.TransactAsync((tx, ct) => app.BuyAsync(tx, "alice", new("xp_boost_15", 2, "shop-v1"), "buy", ct));
        driver.Rows[("p_boosts", "expired")] = new() { ["userId"] = "alice", ["kind"] = "XP_BOOST", ["endsAt"] = "2026-11-03T23:29:59.999Z" };
        var first = await store.TransactAsync((tx, ct) => app.ActivateAsync(tx, "alice", "xp_boost_15", "one", ct));
        Assert.Equal(DateTimeOffset.Parse("2026-11-03T23:30:00Z"), first.StartsAt);
        Assert.Equal(DateTimeOffset.Parse("2026-11-03T23:45:00Z"), first.EndsAt);
        Assert.Equal(2, first.Multiplier);
        Assert.Equal(1, first.Inventory.Quantity);
        var second = await store.TransactAsync((tx, ct) => app.ActivateAsync(tx, "alice", "xp_boost_15", "two", ct));
        Assert.Equal(first.EndsAt, second.StartsAt);
        Assert.Equal(DateTimeOffset.Parse("2026-11-04T00:00:00Z"), second.EndsAt);
        Assert.Equal(0, second.Inventory.Quantity);
        Assert.Equal(0, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
        var commits = driver.Commits;
        Assert.Equal("ITEM_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.ActivateAsync(tx, "alice", "xp_boost_15", "three", ct)))).Code);
        Assert.Equal(commits, driver.Commits);
    }

    [Theory]
    [InlineData("GEMS", 2, "2026-11-03", 7, 100, "2026-10-28")]
    [InlineData("ITEM", 0, "2026-10-31", 5, 200, "2026-10-27")]
    public async Task Shop_RepairAtTwoDayBoundaryRestoresRunAndConsumesSelectedPayment(string payment, long current, string last, long restored, long gems, string start)
    {
        var (driver, store) = await Fixture();
        var wallet = driver.Rows[("p_rewards", Id("p_rewards"))];
        wallet["gems"] = 200; wallet["lostStreak"] = 5; wallet["lostStreakDay"] = "2026-11-01"; wallet["currentStreak"] = current; wallet["lastQualifiedDay"] = last; wallet["bestStreak"] = 10;
        driver.Rows[("p_inventory", CanonicalWire.RowId("p_inventory", "alice", "streak_repair"))] = new() { ["userId"] = "alice", ["itemId"] = "streak_repair", ["quantity"] = 1, ["expiresAt"] = null };
        var app = new ProgressShop();
        var result = await store.TransactAsync((tx, ct) => app.RepairAsync(tx, "alice", new("2026-11-01", payment), "repair", ct));
        var stored = driver.Rows[("p_rewards", Id("p_rewards"))];
        Assert.Equal(restored, stored.Number("currentStreak"));
        Assert.Equal(start, stored.Text("streakStartDay"));
        Assert.Equal(10, stored.Number("bestStreak"));
        Assert.Equal(0, stored.Number("lostStreak"));
        Assert.Null(stored["lostStreakDay"]);
        Assert.Equal(gems, result.Gems);
        Assert.Equal(1, stored.Number("revision"));
        Assert.Equal(payment == "ITEM" ? 0 : 1, driver.Rows[("p_inventory", CanonicalWire.RowId("p_inventory", "alice", "streak_repair"))].Number("quantity"));
        var commits = driver.Commits;
        Assert.Equal("STREAK_REPAIR_EXPIRED", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => app.RepairAsync(tx, "alice", new("2026-11-01", payment), "again", ct)))).Code);
        Assert.Equal(commits, driver.Commits);
    }
    [Fact]
    public async Task ChestClaim_PersistsOneOutcomeAndReplaysLedgerCreditEvenWhenCurrentWalletChanges()
    {
        var (driver, store) = await Fixture();
        var quest = Quest("daily_correct", "DAY", "2026-11-03", 15, 15);
        driver.Rows[("p_quests", quest.Id)] = quest.Row;
        var app = new ProgressEconomy();
        var first = await store.TransactAsync((tx, ct) => app.ClaimQuestAsync(tx, "alice", "daily_correct", "2026-11-03", true, ct));
        var chest = Assert.IsType<CocEnglish.Contracts.QuestChestResponse>(first.Chest);
        Assert.Matches("^ch1_[0-9a-f]{24}$", chest.ReceiptId);
        Assert.Contains(chest.Gems, new long[] { 5, 10, 20, 40 });
        Assert.Equal(20 + chest.Gems, first.Gems);
        Assert.Equal(chest.ReceiptId, driver.Rows[("p_quests", quest.Id)].Text("claimOperationId"));
        var ledgerId = CanonicalWire.RowId("p_reward_ledger", "alice", chest.ReceiptId, "QUEST");
        Assert.Equal(chest.Gems, driver.Rows[("p_reward_ledger", ledgerId)].Number("gemsDelta"));
        var commits = driver.Commits;
        var repeat = await store.TransactAsync((tx, ct) => app.ClaimQuestAsync(tx, "alice", "daily_correct", "2026-11-03", false, ct));
        Assert.Equal(chest.ReceiptId, repeat.Chest!.ReceiptId);
        Assert.Equal(chest.Tiers, repeat.Chest.Tiers);
        Assert.Equal(first.Gems, repeat.Gems);
        Assert.Equal(commits, driver.Commits);
        // A historical credited amount is authoritative, rather than re-priced from today's template.
        driver.Rows[("p_reward_ledger", ledgerId)]["gemsDelta"] = 7;
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 1;
        var historical = await store.TransactAsync((tx, ct) => app.ClaimQuestAsync(tx, "alice", "daily_correct", "2026-11-03", true, ct));
        Assert.Equal(1, historical.Gems);
        Assert.Equal(7, historical.Chest!.Gems);
        Assert.Equal(chest.ReceiptId, historical.Chest.ReceiptId);
        Assert.Equal(commits, driver.Commits);
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("wrong-user")]
    [InlineData("wrong-kind")]
    [InlineData("wrong-quest")]
    [InlineData("zero")]
    [InlineData("fraction")]
    [InlineData("unsafe")]
    public async Task ChestClaim_RejectsMissingOrCorruptCreditedLedgerWithoutChangingState(string fault)
    {
        var (driver, store) = await Fixture();
        const string operation = "ch1_000000000000000000000000";
        var quest = Quest("daily_lessons", "DAY", "2026-11-03", 2, 2);
        quest.Row["claimed"] = true; quest.Row["claimOperationId"] = operation;
        driver.Rows[("p_quests", quest.Id)] = quest.Row;
        if (fault != "missing")
        {
            var ledger = new JsonObject { ["eventId"] = operation, ["completionId"] = operation, ["userId"] = "alice", ["rewardIdentity"] = "daily_lessons", ["kind"] = "QUEST", ["gemsDelta"] = 40 };
            switch (fault)
            {
                case "wrong-user": ledger["userId"] = "bob"; break;
                case "wrong-kind": ledger["kind"] = "FREEZE"; break;
                case "wrong-quest": ledger["rewardIdentity"] = "daily_review"; break;
                case "zero": ledger["gemsDelta"] = 0; break;
                case "fraction": ledger["gemsDelta"] = 1.5; break;
                case "unsafe": ledger["gemsDelta"] = 9007199254740992L; break;
            }
            driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "alice", operation, "QUEST"))] = ledger;
        }
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressEconomy().ClaimQuestAsync(tx, "alice", "daily_lessons", "2026-11-03", true, ct)));
        Assert.Equal("INTERNAL_ERROR", error.Code);
        Assert.Equal("CHEST_LEDGER_MISSING_OR_INVALID", error.Details.Text("reason"));
        Assert.Equal(1, driver.Commits);
        Assert.Equal(20, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
    }

    [Theory]
    [InlineData("ADULT", true)]
    [InlineData("CHILD", false)]
    public async Task Quest_PublicActivityRequiresOptedInAdult(string ageBand, bool visible)
    {
        var (driver, store) = await Fixture();
        var profile = driver.Rows[("p_profiles", Id("p_profiles"))];
        profile["publicOptIn"] = true; profile["ageBand"] = ageBand;
        var quest = Quest("daily_review", "DAY", "2026-11-03", 1, 1);
        driver.Rows[("p_quests", quest.Id)] = quest.Row;
        await store.TransactAsync((tx, ct) => new ProgressEconomy().ClaimQuestAsync(tx, "alice", "daily_review", "2026-11-03", false, ct));
        Assert.Equal(visible, Assert.Single(driver.Rows, p => p.Key.Table == "p_activity").Value.Flag("visible"));
    }

    [Theory]
    [InlineData("missing")]
    [InlineData("deleted")]
    [InlineData("tombstone")]
    public async Task Economy_RejectsUnavailableProfilesWithoutWalletEffects(string state)
    {
        var (driver, store) = await Fixture();
        if (state == "missing") driver.Rows.Remove(("p_profiles", Id("p_profiles")));
        if (state == "deleted") driver.Rows[("p_profiles", Id("p_profiles"))]["deletedAt"] = "2026-11-01T00:00:00.000Z";
        if (state == "tombstone") driver.Rows[("p_deletions", Id("p_deletions"))] = new() { ["userId"] = "alice" };
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressEconomy().BuyFreezeAsync(tx, "alice", "key", ct)))).Code);
        Assert.Equal("PROFILE_UNAVAILABLE", (await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressEconomy().ClaimQuestAsync(tx, "alice", "daily_review", "2026-11-03", true, ct)))).Code);
        Assert.Equal(1, driver.Commits);
        Assert.Equal(20, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
    }
    [Fact]
    public async Task Freeze_ExactPriceDebitsWalletAndWritesBothLedgersInSameTransaction()
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_profiles", Id("p_profiles"))]["learningZone"] = "Asia/Ho_Chi_Minh";
        var result = await store.TransactAsync((tx, ct) => new ProgressEconomy().BuyFreezeAsync(tx, "alice", "key", ct));
        Assert.Equal(0, result.Gems);
        Assert.Equal(1, result.FreezeSlots);
        Assert.Equal(1, result.Revision);
        Assert.Equal(0, result.StudyXp);
        Assert.Equal(0, result.LeagueXp);
        var operation = CanonicalWire.RowId("operation", "freeze-buy", "alice", "key");
        var freeze = driver.Rows[("p_freeze_ledger", CanonicalWire.RowId("p_freeze_ledger", "alice", operation))];
        Assert.Equal(-20, freeze.Number("gemsDelta"));
        Assert.Equal(1, freeze.Number("slotDelta"));
        Assert.Equal("BUY", freeze.Text("action"));
        Assert.Null(freeze["day"]);
        var ledger = driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "alice", operation, "FREEZE"))];
        Assert.Equal("2026-11-04", ledger.Text("learningDay"));
        Assert.Equal("2026-11-02", ledger.Text("leagueWeek"));
        Assert.Equal("streak_freeze", ledger.Text("rewardIdentity"));
        Assert.Equal(operation, ledger.Text("eventId"));
        Assert.Equal(-20, ledger.Number("gemsDelta"));
        Assert.Equal(new[] { "p_freeze_ledger", "p_reward_ledger", "p_rewards" }, driver.LastWrites.Select(w => w.Table).Order(StringComparer.Ordinal));
    }

    [Theory]
    [InlineData(364, 1, true)]
    [InlineData(364, 2, false)]
    [InlineData(365, 2, true)]
    [InlineData(365, 4, true)]
    [InlineData(365, 5, false)]
    [InlineData(400, 6, false)]
    public async Task Freeze_UsesStoredStreakForCapacityAtSocietyBoundary(int streak, int slots, bool allowed)
    {
        var (driver, store) = await Fixture();
        var wallet = driver.Rows[("p_rewards", Id("p_rewards"))];
        wallet["currentStreak"] = streak; wallet["freezeSlots"] = slots;
        var commits = driver.Commits;
        if (allowed)
            Assert.Equal(slots + 1, (await store.TransactAsync((tx, ct) => new ProgressEconomy().BuyFreezeAsync(tx, "alice", "key", ct))).FreezeSlots);
        else
        {
            var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressEconomy().BuyFreezeAsync(tx, "alice", "key", ct)));
            Assert.Equal("FREEZE_CAPACITY", error.Code);
            Assert.Equal(slots, error.Details.Number("freezeSlots"));
            Assert.Equal(commits, driver.Commits);
            Assert.Equal(20, wallet.Number("gems"));
        }
    }

    [Fact]
    public async Task Freeze_InsufficientFundsDoesNotCreateAnyLedgerOrMutateWallet()
    {
        var (driver, store) = await Fixture();
        driver.Rows[("p_rewards", Id("p_rewards"))]["gems"] = 19;
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressEconomy().BuyFreezeAsync(tx, "alice", "key", ct)));
        Assert.Equal("INSUFFICIENT_GEMS", error.Code);
        Assert.Equal(20, error.Details.Number("required"));
        Assert.Equal(1, driver.Commits);
        Assert.Equal(19, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
        Assert.DoesNotContain(driver.Rows, p => p.Key.Table == "p_freeze_ledger");
    }

    [Fact]
    public async Task Quest_ClaimsOldCompletedPeriodOnceWithLedgerAndPrivateActivity()
    {
        var (driver, store) = await Fixture();
        var quest = Quest("daily_lessons", "DAY", "2020-01-01", 2, 2);
        driver.Rows[("p_quests", quest.Id)] = quest.Row;
        var app = new ProgressEconomy();
        var result = await store.TransactAsync((tx, ct) => app.ClaimQuestAsync(tx, "alice", "daily_lessons", "2020-01-01", false, ct));
        Assert.Equal(25, result.Gems);
        Assert.Equal(1, result.Revision);
        Assert.True(driver.Rows[("p_quests", quest.Id)].Flag("claimed"));
        var operation = CanonicalWire.RowId("operation", "quest-claim", "alice", "DAY", "2020-01-01", "daily_lessons");
        var ledger = driver.Rows[("p_reward_ledger", CanonicalWire.RowId("p_reward_ledger", "alice", operation, "QUEST"))];
        Assert.Equal(5, ledger.Number("gemsDelta"));
        Assert.Equal(0, ledger.Number("studyXpDelta"));
        Assert.Equal("2026-11-03", ledger.Text("learningDay"));
        var activity = driver.Rows[("p_activity", CanonicalWire.RowId("p_activity", operation))];
        Assert.False(activity.Flag("visible"));
        Assert.Equal("Completed the daily lessons quest", activity.Text("publicSummary"));
        var commits = driver.Commits;
        var replay = await store.TransactAsync((tx, ct) => app.ClaimQuestAsync(tx, "alice", "daily_lessons", "2020-01-01", true, ct));
        Assert.Equal(25, replay.Gems);
        Assert.Null(replay.Chest);
        Assert.Equal(commits, driver.Commits);
    }

    [Fact]
    public async Task MonthlyQuest_GrantsOneBadgeAndNoGemsEvenWithChestUpgrade()
    {
        var (driver, store) = await Fixture();
        var quest = Quest("monthly_active_days", "MONTH", "2026-11", 20, 20);
        driver.Rows[("p_quests", quest.Id)] = quest.Row;
        var result = await store.TransactAsync((tx, ct) => new ProgressEconomy().ClaimQuestAsync(tx, "alice", "monthly_active_days", "2026-11", true, ct));
        Assert.Equal(20, result.Gems);
        Assert.Null(result.Chest);
        var badge = Assert.Single(driver.Rows, p => p.Key.Table == "p_achievements").Value;
        Assert.Equal("monthly_2026_11", badge.Text("achievementId"));
        Assert.Equal(0, badge.Number("tier"));
        Assert.Single(driver.Rows, p => p.Key.Table == "p_reward_ledger"); // initial credit only
    }

    [Theory]
    [InlineData("unknown", "2026-11-03", "NOT_FOUND")]
    [InlineData("daily_lessons", "2026-11", "VALIDATION_ERROR")]
    [InlineData("daily_lessons", "2026-11-03", "VALIDATION_ERROR")]
    public async Task Quest_InvalidOrIncompleteClaimsNeverCommit(string questId, string period, string code)
    {
        var (driver, store) = await Fixture();
        var error = await Assert.ThrowsAsync<ServiceException>(() => store.TransactAsync((tx, ct) => new ProgressEconomy().ClaimQuestAsync(tx, "alice", questId, period, false, ct)));
        Assert.Equal(code, error.Code);
        Assert.Equal(1, driver.Commits);
        Assert.Equal(20, driver.Rows[("p_rewards", Id("p_rewards"))].Number("gems"));
    }

    private static string Id(string table) => CanonicalWire.RowId(table, "alice");
    private static (string Id, JsonObject Row) Quest(string questId, string period, string key, long metric, long target) =>
        (CanonicalWire.RowId("p_quests", "alice", period, key, questId), new() { ["userId"] = "alice", ["questId"] = questId, ["period"] = period, ["periodKey"] = key, ["target"] = target, ["metricValue"] = metric, ["claimed"] = false, ["claimOperationId"] = null });
    private static async Task<(Driver Driver, OwnerStore Store)> Fixture()
    {
        var driver = new Driver();
        var store = new OwnerStore(driver, new Clock());
        await store.TransactAsync((tx, ct) => new ProgressWrites().InitializeProfileAsync(tx, "alice", ct));
        return (driver, store);
    }
    private sealed class Clock : TimeProvider { public override DateTimeOffset GetUtcNow() => DateTimeOffset.Parse("2026-11-03T23:30:00Z"); }
    private sealed class Driver : IRowDriver
    {
        public string Owner => "progress";
        public bool Configured => true;
        public int Commits { get; private set; }
        public IReadOnlyList<RowWrite> LastWrites { get; private set; } = [];
        public Dictionary<(string Table, string Id), JsonObject> Rows { get; } = [];
        public Task<RowDocument?> ReadAsync(string table, string id, CancellationToken ct) => Task.FromResult(Rows.TryGetValue((table, id), out var row) ? new RowDocument(id, row.DeepClone().AsObject(), "v1") : null);
        public Task<IReadOnlyList<RowDocument>> ListAsync(string table, RowQuery query, CancellationToken ct) => Task.FromResult<IReadOnlyList<RowDocument>>(Rows.Where(p => p.Key.Table == table &&
            (query.Where is null || query.Where.All(q => p.Value[q.Key]?.ToString() == q.Value?.ToString())) &&
            (query.GreaterThanEqual is null || query.GreaterThanEqual.All(q => StringComparer.Ordinal.Compare(p.Value[q.Key]?.ToString(), q.Value?.ToString()) >= 0)) &&
            (query.LessThan is null || query.LessThan.All(q => StringComparer.Ordinal.Compare(p.Value[q.Key]?.ToString(), q.Value?.ToString()) < 0)))
            .Select(p => new RowDocument(p.Key.Id, p.Value.DeepClone().AsObject(), "v1")).ToArray());
        public Task<long> CountAsync(string table, IReadOnlyDictionary<string, object?> where, CancellationToken ct) => throw new NotSupportedException();
        public Task CommitAsync(IReadOnlyList<RowWrite> writes, IReadOnlyList<(string Table, string Id, RowDocument? Document)> reads, CancellationToken ct)
        {
            Commits++; LastWrites = writes;
            foreach (var write in writes) Rows[(write.Table, write.Id)] = write.Data!.DeepClone().AsObject();
            return Task.CompletedTask;
        }
    }
}
