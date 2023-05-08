#[test_only]
module seapad::tokenomic_test {
    use sui::test_scenario::{Scenario, take_shared};
    use sui::test_scenario;
    use sui::clock;
    use sui::clock::Clock;
    use seapad::tokenomic;
    use seapad::tokenomic::{TAdminCap, TokenomicPie, addFund};
    use sui::coin;
    use sui::tx_context::TxContext;
    use seapad::version::{Version};
    use std::vector;
    use seapad::version;


    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND2: address = @0xC0FFFF;
    const TOTAL_SUPPLY: u64 = 100000000;
    const TWO_HOURS_IN_MS: u64 = 2 * 3600000;
    const ONE_HOURS_IN_MS: u64 = 3600000;

    const MONTH_IN_MS: u64 = 2592000000;
    const TEN_YEARS_IN_MS: u64 = 311040000000;

    const TGE_ONE_MONTH_MS: u64 = 2592000000;

    struct XCOIN has drop {}

    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;

    fun init_fund_for_test<COIN>(_admin: &TAdminCap,
                                 pie: &mut TokenomicPie<COIN>,
                                 tge_ms: u64,
                                 sclock: &Clock,
                                 version: &mut Version,
                                 ctx: &mut TxContext) {
        addFund(_admin,
            pie,
            @seedFund,
            b"Seed Fund",
            VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            tge_ms,
            0,
            coin::mint_for_testing<COIN>(TOTAL_SUPPLY / 10, ctx),
            500,
            18 * MONTH_IN_MS,
            sclock,
            version,
            vector::empty<u64>(),
            vector::empty<u64>(),
            ctx
        );

        addFund(_admin,
            pie,
            @privateFund,
            b"Private Fund",
            VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            tge_ms,
            1 * MONTH_IN_MS,
            coin::mint_for_testing(TOTAL_SUPPLY * 12 / 100, ctx),
            1000,
            12 * MONTH_IN_MS,
            sclock,
            version,
            vector::empty<u64>(),
            vector::empty<u64>(),
            ctx
        );

        let times = vector::empty<u64>();
        vector::push_back(&mut times, 2*TGE_ONE_MONTH_MS); //1m --> 2m!
        vector::push_back(&mut times, 3*TGE_ONE_MONTH_MS);
        vector::push_back(&mut times, 4*TGE_ONE_MONTH_MS);

        let percents = vector::empty<u64>();
        vector::push_back(&mut percents, 3500);
        vector::push_back(&mut percents, 3000);
        vector::push_back(&mut percents, 3000);

        addFund(_admin,
            pie,
            @publicFund,
            b"Public Fund",
            VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            tge_ms,
            0,
            coin::mint_for_testing<COIN>(TOTAL_SUPPLY / 10, ctx),
            500,
            0,
            sclock,
            version,
            times,
            percents,
            ctx
        );


        addFund(_admin,
            pie,
            @foundationFund,
            b"Foundation Fund",
            VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            tge_ms,
            MONTH_IN_MS,
            coin::mint_for_testing<COIN>(TOTAL_SUPPLY / 10, ctx),
            500,
            0,
            sclock,
            version,
            times,
            percents,
            ctx
        );

        addFund(_admin,
            pie,
            @marketingFund,
            b"Marketing Fund",
            VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            tge_ms,
            MONTH_IN_MS,
            coin::mint_for_testing<COIN>(TOTAL_SUPPLY / 10, ctx),
            500,
            0,
            sclock,
            version,
            times,
            percents,
            ctx
        );
    }

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }

    fun create_clock_time(addr: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, addr);
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
    }

    fun init_env(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));
        version::initForTest(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);
        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdminCap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);

        tokenomic::init_tokenomic<XCOIN>(&ecoAdmin,
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TGE_ONE_MONTH_MS,
            &clock,
            &mut version,
            ctx);

        test_scenario::next_tx(scenario, ADMIN);
        let pie = test_scenario::take_shared<TokenomicPie<XCOIN>>(scenario);
        init_fund_for_test(&ecoAdmin,
            &mut pie,
            clock::timestamp_ms(&clock) + TGE_ONE_MONTH_MS,
            &clock,
            &mut version,
            test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_to_sender(scenario, ecoAdmin);
        test_scenario::return_shared(version);
        test_scenario::return_shared(pie);
    }


    #[test]
    #[expected_failure(abort_code = tokenomic::ERR_NO_FUND)]
    fun test_claim_no_fund() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut clock, 9 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_TGE_NOT_STARTED)]
    fun test_linear_unlock_first_before_tge_must_failed() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(
            tokenomic::getFundVestingAvailable(&pie, @seedFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100),
            1
        );

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_TGE_NOT_STARTED)]
    fun test_milestone_unlock_first_before_tge_must_failed() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @publicFund);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }


    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_TGE_NOT_STARTED)]
    fun test_milestone_unlock_first_cliff_onemonth_before_tge_must_failed() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @foundationFund);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_TGE_NOT_STARTED)]
    fun test_before_tge_must_failed2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS - 1);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(
            tokenomic::getFundVestingAvailable(&pie, @seedFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100),
            1
        );

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_TGE_NOT_STARTED)]
    fun test_milestone_cliff_onemonth_before_tge_must_failed2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @foundationFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS - 1);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_TGE_NOT_STARTED)]
    fun test_milestone_before_tge_must_failed2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @publicFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS - 1);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_unlock_first_cliff_zero_claim_multiple() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);
        assert!(clock::timestamp_ms(&clock) == 0, 10000);

        assert!(tokenomic::getPieTotalSupply(&pie) == TOTAL_SUPPLY, 1);
        assert!(tokenomic::getPieTotalSharePercent(&pie) <= 10000, 1);

        assert!(tokenomic::getFundUnlockPercent(&pie, @seedFund) == 500, 1);
        assert!(tokenomic::getFundTotal(&pie, @seedFund) == (TOTAL_SUPPLY / 10), 1);
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == 0, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @seedFund) == TOTAL_SUPPLY / 10, 1);

        assert!(tokenomic::getPieTgeTimeMs(&pie) == TGE_ONE_MONTH_MS, 10000);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(
            tokenomic::getFundVestingAvailable(&pie, @seedFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100),
            1
        );

        clock::increment_for_testing(&mut clock, 9 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == 105 * TOTAL_SUPPLY / 2000, 1);
        assert!(
            tokenomic::getFundVestingAvailable(&pie, @seedFund) == TOTAL_SUPPLY / 10 - 105 * TOTAL_SUPPLY / 2000,
            1
        );

        clock::increment_for_testing(&mut clock, 9 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == TOTAL_SUPPLY / 10, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @seedFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_unlock_first_cliff_zero_claim_multiple() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @publicFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100), 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == 40 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == TOTAL_SUPPLY / 10 - 40 * TOTAL_SUPPLY / 1000, 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == 70 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == TOTAL_SUPPLY / 10 - 70 * TOTAL_SUPPLY / 1000, 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_unlock_first_cliff_onemonth_claim_multiple() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @foundationFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100), 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 40 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - 40 * TOTAL_SUPPLY / 1000, 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 70 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - 70 * TOTAL_SUPPLY / 1000, 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_COIN)]
    fun test_milestone_cliff_first_cliff_onemonth_claim_multiple_nocoin() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @marketingFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100), 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_cliff_first_cliff_onemonth_claim_multiple() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @marketingFund);
        clock::increment_for_testing(&mut clock, 2*TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == 40 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == TOTAL_SUPPLY / 10 - 40 * TOTAL_SUPPLY / 1000, 1);

        // clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        // tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        // assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 40 * TOTAL_SUPPLY / 1000 , 1);
        // assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - 40 * TOTAL_SUPPLY / 1000, 1);
        //
        // clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        // tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        // assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 70 * TOTAL_SUPPLY / 1000 , 1);
        // assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - 70 * TOTAL_SUPPLY / 1000, 1);
        //
        // clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        // tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        // assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        // assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }
    #[test]
    fun test_milestone_cliff_first_cliff_onemonth_claim_multiple2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @marketingFund);
        clock::increment_for_testing(&mut clock, 2*TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == 40 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == TOTAL_SUPPLY / 10 - 40 * TOTAL_SUPPLY / 1000, 1);

        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == 70 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == TOTAL_SUPPLY / 10 - 70 * TOTAL_SUPPLY / 1000, 1);


        clock::increment_for_testing(&mut clock,  MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_cliff_first_cliff_zero_claim_overtime() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @marketingFund);
        clock::increment_for_testing(&mut clock, 7*TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == TOTAL_SUPPLY / 10 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_unlock_first_cliff_zero_claim_overtime() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @publicFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100), 1);

        clock::increment_for_testing(&mut clock,  3*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_unlock_first_cliff_onemonth_claim_overtime() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @foundationFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == TOTAL_SUPPLY * 5 / (10 * 100), 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == TOTAL_SUPPLY / 10 - TOTAL_SUPPLY * 5 / (10 * 100), 1);

        clock::increment_for_testing(&mut clock,  3*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @foundationFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @foundationFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_milestone_unlock_first_cliff_zero_claim_overtime2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @publicFund);

        clock::increment_for_testing(&mut clock,  5*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = tokenomic::ERR_NO_MORE_COIN)]
    fun test_milestone_unlock_first_cliff_zero_claim_nomore() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @publicFund);

        clock::increment_for_testing(&mut clock,  4*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @publicFund) == 100 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @publicFund) == 0, 1);

        clock::increment_for_testing(&mut clock, 4*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = tokenomic::ERR_NO_MORE_COIN)]
    fun test_milestone_cliff_first_cliff_zero_claim_nomore() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @marketingFund);

        clock::increment_for_testing(&mut clock,  7*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == TOTAL_SUPPLY / 10 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == 0, 1);

        clock::increment_for_testing(&mut clock, 4*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = tokenomic::ERR_NO_MORE_COIN)]
    fun test_milestone_cliff_first_cliff_zero_claim_nomore2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @marketingFund);

        test_scenario::next_tx(scenario, @marketingFund);
        clock::increment_for_testing(&mut clock, 2*TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @marketingFund) == 40 * TOTAL_SUPPLY / 1000 , 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @marketingFund) == TOTAL_SUPPLY / 10 - 40 * TOTAL_SUPPLY / 1000, 1);

        clock::increment_for_testing(&mut clock, MONTH_IN_MS/2);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = tokenomic::ERR_NO_MORE_COIN)]
    fun test_unlock_first_cliff_zero_claim_nomore2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        clock::increment_for_testing(&mut clock, 9 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == (500 + 9500 / 2) * TOTAL_SUPPLY / 100000, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @seedFund
            ) == TOTAL_SUPPLY / 10 - (500 + 9500 / 2) * TOTAL_SUPPLY / 100000,
            1
        );

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, 9 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @seedFund) == TOTAL_SUPPLY / 10, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @seedFund) == 0, 1);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, 9 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_unlock_first_cliff_onemonth_claim_at_tge() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        assert!(tokenomic::getFundUnlockPercent(&pie, @privateFund) == 1000, 1);
        assert!(tokenomic::getFundTotal(&pie, @privateFund) == (TOTAL_SUPPLY * 12 / 100), 1);
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == 0, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == (TOTAL_SUPPLY * 12 / 100), 1);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100), 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_unlock_first_cliff_onemonth_claim_in_cliff_nomore_coin() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        assert!(tokenomic::getFundUnlockPercent(&pie, @privateFund) == 1000, 1);
        assert!(tokenomic::getFundTotal(&pie, @privateFund) == (TOTAL_SUPPLY * 12 / 100), 1);
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == 0, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == (TOTAL_SUPPLY * 12 / 100), 1);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS / 2);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_unlock_first_cliff_onemonth_claim_at_tail_cliff() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        assert!(tokenomic::getFundUnlockPercent(&pie, @privateFund) == 1000, 1);
        assert!(tokenomic::getFundTotal(&pie, @privateFund) == (TOTAL_SUPPLY * 12 / 100), 1);
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == 0, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == (TOTAL_SUPPLY * 12 / 100), 1);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_unlock_first_cliff_onemonth_claim_linear() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS + 6 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 * 110 / 20000, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 * 110 / 20000,
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, 6 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_unlock_first_cliff_onemonth_claim_linear2() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS + 6 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 * 110 / 20000, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 * 110 / 20000,
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, 6 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == 0, 1);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, 6 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_unlock_first_cliff_onemonth_claim_linear3() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS + 12 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_unlock_first_cliff_onemonth_claim_linear4() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS + 20 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_unlock_first_cliff_onemonth_claim_linear5() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        init_env(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = take_shared<Clock>(scenario);
        let version = take_shared<Version>(scenario);
        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TGE_ONE_MONTH_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100 * 10 / 100, 1);
        assert!(
            tokenomic::getFundVestingAvailable(
                &pie,
                @privateFund
            ) == TOTAL_SUPPLY * 12 / 100 - TOTAL_SUPPLY * 12 / (10 * 100),
            1
        );

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, MONTH_IN_MS + 20 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));
        assert!(tokenomic::getFundReleased(&pie, @privateFund) == TOTAL_SUPPLY * 12 / 100, 1);
        assert!(tokenomic::getFundVestingAvailable(&pie, @privateFund) == 0, 1);

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, 6 * MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, &mut version, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);
        test_scenario::return_shared(version);
        test_scenario::end(scenario_val);
    }
}
