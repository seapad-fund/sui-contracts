#[test_only]
module seapad::tokenomic_test {
    use sui::test_scenario::{Scenario, take_shared};
    use sui::test_scenario;
    use sui::clock;
    use sui::clock::Clock;
    use seapad::tokenomic;
    use seapad::tokenomic::{TAdmin, TokenomicPie};
    use sui::coin;
    use std::debug;
    use sui::coin::Coin;


    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND2: address = @0xC0FFFF;
    const TOTAL_SUPPLY: u64 = 100000000;
    const TWO_HOURS_IN_MS: u64 = 2*3600000;
    const ONE_HOURS_IN_MS: u64 = 3600000;

    const MONTH_IN_MS: u64 =    2592000000;
    const TEN_YEARS_IN_MS: u64 =    311040000000;

    struct XCOIN has drop {}

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }

    fun create_clock_time(addr: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, addr);
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
    }

    #[test]
    fun test_init_tokenomic() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        assert!(tokenomic::getFundRemain(&pie) == 0, 1);
        assert!(tokenomic::getTotalSupply(&pie) == TOTAL_SUPPLY, 1);
        assert!(tokenomic::getTotalShare(&pie) == 10000, 1);
        assert!(tokenomic::getFundRemain(&pie) == 0, 1);

        assert!(tokenomic::getShareFundTGE(&pie, @seedFund) == 500000, 1);
        assert!(tokenomic::getShareFundVesting(&pie, @seedFund) == (10000000 - 500000), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @privateFund) == 12000000/10, 1);
        assert!(tokenomic::getShareFundVesting(&pie, @privateFund) == (12000000 - 12000000/10), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @publicFund) == (3000000 * 25/100), 1);
        assert!(tokenomic::getShareFundVesting(&pie, @publicFund) == (3000000 - 3000000 * 25/100), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @foundationFund) == 0, 1);
        assert!(tokenomic::getShareFundVesting(&pie, @foundationFund) == (15000000), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @advisorpartnerFund) == 0, 1);
        assert!(tokenomic::getShareFundVesting(&pie, @advisorpartnerFund) == (5000000), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @marketingFund) == (12000000 * 5/100), 1);
        assert!(tokenomic::getShareFundVesting(&pie, @marketingFund) == (12000000 - 12000000 * 5/100), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @ecosystemFund) == (0), 1);
        assert!(tokenomic::getShareFundVesting(&pie, @ecosystemFund) == (28000000), 1);

        assert!(tokenomic::getShareFundTGE(&pie, @daoFund) == (0), 1);
        assert!(tokenomic::getShareFundVesting(&pie, @daoFund) == (15000000), 1);

        test_scenario::return_shared(clock);
        test_scenario::return_to_sender(scenario, ecoAdmin);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }


    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_PERMISSION)]
    fun test_claim_no_perm() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_to_sender(scenario, ecoAdmin);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_claim_bad_vesting_time() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @privateFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @publicFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @foundationFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @advisorpartnerFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @marketingFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @ecosystemFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, @daoFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_to_sender(scenario, ecoAdmin);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }


    #[test]
    fun test_claim_oneshot() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, ecoAdmin);

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, 18*MONTH_IN_MS + TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));
        debug::print(&tokenomic::getShareFundTGE(&pie, @seedFund));
        assert!(tokenomic::getShareFundTGE(&pie, @seedFund) == 0, 1);
        debug::print(&tokenomic::getShareFundVesting(&pie, @seedFund));
        assert!(tokenomic::getShareFundVesting(&pie, @seedFund) == 0, 1);


        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_just_tge() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, ecoAdmin);

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));
        debug::print(&tokenomic::getShareFundTGE(&pie, @seedFund));
        assert!(tokenomic::getShareFundTGE(&pie, @seedFund) == 0, 1);
        debug::print(&tokenomic::getShareFundVesting(&pie, @seedFund));
        assert!(tokenomic::getShareFundVesting(&pie, @seedFund) == 9500000, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_tge_and_partial() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, ecoAdmin);

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS + 9*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        debug::print(&tokenomic::getShareFundTGE(&pie, @seedFund));
        assert!(tokenomic::getShareFundTGE(&pie, @seedFund) == 0, 1);
        debug::print(&tokenomic::getShareFundVesting(&pie, @seedFund));
        assert!(tokenomic::getShareFundVesting(&pie, @seedFund) == 9500000 - 9500000 * 9/18, 1);

        test_scenario::next_tx(scenario, @seedFund);
        let claimedCoin = test_scenario::take_from_sender<Coin<XCOIN>>(scenario);
        assert!(coin::value(&claimedCoin) == (500000 + 9500000 * 9/18), 1);
        test_scenario::return_to_sender<Coin<XCOIN>>(scenario, claimedCoin);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_claim_tge_and_partial_no_more() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, ecoAdmin);

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, TWO_HOURS_IN_MS + 9*MONTH_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        debug::print(&tokenomic::getShareFundTGE(&pie, @seedFund));
        assert!(tokenomic::getShareFundTGE(&pie, @seedFund) == 0, 1);
        debug::print(&tokenomic::getShareFundVesting(&pie, @seedFund));
        assert!(tokenomic::getShareFundVesting(&pie, @seedFund) == 9500000 - 9500000 * 9/18, 1);

        test_scenario::next_tx(scenario, @seedFund);
        let claimedCoin = test_scenario::take_from_sender<Coin<XCOIN>>(scenario);
        assert!(coin::value(&claimedCoin) == (500000 + 9500000 * 9/18), 1);
        test_scenario::return_to_sender<Coin<XCOIN>>(scenario, claimedCoin);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = seapad::tokenomic::ERR_NO_MORE_COIN)]
    fun test_claim_twoshot() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, ecoAdmin);

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, 18*MONTH_IN_MS + TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));
        debug::print(&tokenomic::getShareFundTGE(&pie, @seedFund));
        assert!(tokenomic::getShareFundTGE(&pie, @seedFund) == 0, 1);
        debug::print(&tokenomic::getShareFundVesting(&pie, @seedFund));
        assert!(tokenomic::getShareFundVesting(&pie, @seedFund) == 0, 1);

        test_scenario::next_tx(scenario, @seedFund);
        clock::increment_for_testing(&mut clock, 18*MONTH_IN_MS + TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_change_user_then_claim() {
        let scenario_val = test_scenario::begin(ADMIN);
        let scenario = &mut scenario_val;
        clock::share_for_testing(clock::create_for_testing(test_scenario::ctx(scenario)));
        tokenomic::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        let ecoAdmin = test_scenario::take_from_sender<TAdmin>(scenario);

        tokenomic::init_tokenomic0(&ecoAdmin,
            coin::mint_for_testing<XCOIN>(TOTAL_SUPPLY, test_scenario::ctx(scenario)),
            TOTAL_SUPPLY,
            clock::timestamp_ms(&clock) + TWO_HOURS_IN_MS,
            &clock,
            test_scenario::ctx(scenario));

        test_scenario::return_to_sender(scenario, ecoAdmin);

        test_scenario::next_tx(scenario, ADMIN);

        let pie = take_shared<TokenomicPie<XCOIN>>(scenario);

        test_scenario::next_tx(scenario, @seedFund);
        tokenomic::change_fund_owner(&mut pie, SEED_FUND2, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, SEED_FUND2);
        clock::increment_for_testing(&mut clock, 18*MONTH_IN_MS + TWO_HOURS_IN_MS);
        tokenomic::claim(&mut pie, &clock, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, SEED_FUND2);
        assert!(tokenomic::getShareFundTGE(&pie, SEED_FUND2) == 0, 1);
        assert!(tokenomic::getShareFundVesting(&pie, SEED_FUND2) == 0, 1);

        test_scenario::return_shared(clock);
        test_scenario::return_shared(pie);

        test_scenario::end(scenario_val);
    }
}
