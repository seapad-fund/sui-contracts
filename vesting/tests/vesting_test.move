#[test_only]
module seapad::vesting_test {
    use sui::test_scenario::{Scenario, take_shared, take_from_sender, return_to_sender, return_shared, next_tx};
    use sui::test_scenario;
    use sui::clock;
    use sui::clock::Clock;
    use seapad::vesting::{VAdminCap, Project, ProjectRegistry};

    use seapad::version::{Version, initForTest};
    use std::vector;
    use seapad::vesting;
    use sui::coin;
    use sui::coin::Coin;

    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND: address = @0xC0FFFF;
    const TOTAL_SUPPLY: u64 = 100000000;
    const TWO_HOURS_IN_MS: u64 = 2 * 3600000;
    const ONE_HOURS_IN_MS: u64 = 3600000;

    const MONTH_IN_MS: u64 = 2592000000;
    const TEN_YEARS_IN_MS: u64 = 311040000000;

    const TGE_ONE_MONTH_MS: u64 = 2592000000;

    const UNLOCK_PERCENT: u64 = 1000;
    const PERCENT_SCALE: u64 = 10000;

    struct XCOIN has drop {}

    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;


    // #[test]
    // #[expected_failure(abort_code = vesting::ERR_NO_FUND)]
    fun test_claim_no_fund() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);

        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_LINEAR_CLIFF_FIRST,
            0,
            UNLOCK_PERCENT,
            18 * MONTH_IN_MS,
            vector::empty(),
            vector::empty(),
            &sclock,
            scenario
        );
        let version = take_shared<Version>(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut sclock, 9 * MONTH_IN_MS);
        let fee = coin::mint_for_testing(0, test_scenario::ctx(scenario));
        vesting::claim(fee, &mut project, &sclock, &mut version, test_scenario::ctx(scenario));
        coin::burn_for_testing(fee);
        test_scenario::return_shared(sclock);
        test_scenario::return_shared(version);
        test_scenario::return_shared(project);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = vesting::ERR_NO_FUND)]
    fun test_milestone_unlock_first() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let halfAYear = 6 * MONTH_IN_MS;
        let oneYear = 12 * MONTH_IN_MS;

        let miletoneTimes = vector::empty<u64>();
        vector::push_back(&mut miletoneTimes, halfAYear);
        vector::push_back(&mut miletoneTimes, oneYear);

        let percent45 = 4500u64;
        let milestonePercents = vector::empty<u64>();
        vector::push_back(&mut milestonePercents, percent45);
        vector::push_back(&mut milestonePercents, percent45);

        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            0,
            UNLOCK_PERCENT,
            0,
            miletoneTimes,
            milestonePercents,
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario);

        //Test claim tge
        {
            clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * UNLOCK_PERCENT, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after 6month
        {
            clock::increment_for_testing(&mut sclock, 6 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * percent45, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after...failed
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = vesting::ERR_NO_FUND)]
    fun test_milestone_cliff_first() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let halfAYear = 6 * MONTH_IN_MS;
        let oneYear = 12 * MONTH_IN_MS;

        let miletoneTimes = vector::empty<u64>();
        vector::push_back(&mut miletoneTimes, halfAYear);
        vector::push_back(&mut miletoneTimes, oneYear);

        let percent45 = 4500u64;
        let milestonePercents = vector::empty<u64>();
        vector::push_back(&mut milestonePercents, percent45);
        vector::push_back(&mut milestonePercents, percent45);

        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            MONTH_IN_MS,
            UNLOCK_PERCENT,
            0,
            miletoneTimes,
            milestonePercents,
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario);

        //Test claim tge + cliff
        {
            clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS + MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * UNLOCK_PERCENT, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after 6month
        {
            clock::increment_for_testing(&mut sclock, 6 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * percent45, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after...failed
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = vesting::ERR_NO_FUND)]
    fun test_linenear_unlock_first() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let oneYear = 12 * MONTH_IN_MS;

        let unlockHalf = UNLOCK_PERCENT * 5;
        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            0,
            unlockHalf,
            oneYear,
            vector::empty(),
            vector::empty(),
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario);

        //Test claim tge
        {
            clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * unlockHalf, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after 3month
        {
            clock::increment_for_testing(&mut sclock, 3 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);

            let percentExpect = (PERCENT_SCALE - unlockHalf) * 3 / 12;
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * percentExpect, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after...failed
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }


    #[test]
    #[expected_failure(abort_code = vesting::ERR_NO_FUND)]
    fun test_linenear_cliff_first() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let oneYear = 12 * MONTH_IN_MS;

        let unlockHalf = UNLOCK_PERCENT * 5;
        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_LINEAR_CLIFF_FIRST,
            MONTH_IN_MS,
            unlockHalf,
            oneYear,
            vector::empty(),
            vector::empty(),
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario);

        //Test claim tge + cliff
        {
            clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS + MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * unlockHalf, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after 3month
        {
            clock::increment_for_testing(&mut sclock, 3 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);

            let percentExpect = (PERCENT_SCALE - unlockHalf) * 3 / 12;
            assert!(coin::value(&fundClaim) == (fundValue / PERCENT_SCALE) * percentExpect, 0);

            return_to_sender(scenario, fundClaim);
        };

        //claim after...failed
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_multiple_add_fund() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let oneYear = 12 * MONTH_IN_MS;

        let unlockHalf = UNLOCK_PERCENT * 5;
        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_LINEAR_CLIFF_FIRST,
            MONTH_IN_MS,
            unlockHalf,
            oneYear,
            vector::empty(),
            vector::empty(),
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario);
        addFund(fundValue, SEED_FUND, &mut project, scenario);

        //Test claim tge + cliff
        {
            clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS + MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) == (fundValue * 2 / PERCENT_SCALE) * unlockHalf, 0);

            return_to_sender(scenario, fundClaim);
        };

        //Test claim after 3month
        {
            clock::increment_for_testing(&mut sclock, 3 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);

            let percentExpect = (PERCENT_SCALE - unlockHalf) * 3 / 12;
            assert!(coin::value(&fundClaim) == (fundValue * 2 / PERCENT_SCALE) * percentExpect, 0);

            return_to_sender(scenario, fundClaim);
        };

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = vesting::ERR_NO_FUND)]
    fun test_remove_fund(){
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let oneYear = 12 * MONTH_IN_MS;

        let unlockHalf = UNLOCK_PERCENT * 5;
        let project = create_project_(
            TGE_ONE_MONTH_MS,
            VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            0,
            unlockHalf,
            oneYear,
            vector::empty(),
            vector::empty(),
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario);
        removeFund(SEED_FUND, &mut project, scenario);

        //Owner receive fund
        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let receiveFund = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&receiveFund) == fundValue, 0);
            return_to_sender(scenario, receiveFund);
        };
        //claim after...failed
        clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS);
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }


    fun claim(claimer: address, project: &mut Project<XCOIN>, sclock: &Clock, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, claimer);
        let version = take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let fee = coin::mint_for_testing(0, ctx);
        vesting::claim(fee, project, sclock, &version, ctx);
        coin::burn_for_testing(fee);
        return_shared(version);
    }


    fun addFund(amount: u64, owner: address, project: &mut Project<XCOIN>, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);

        let admin = take_from_sender<VAdminCap>(scenario);
        let version = take_shared<Version>(scenario);
        let resgistry = take_shared<ProjectRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let fund = coin::mint_for_testing<XCOIN>(amount, ctx);
        vesting::addFund(&admin, owner, fund, project, &mut resgistry, &version);

        return_to_sender(scenario, admin);
        return_shared(version);
        return_shared(resgistry);
    }

    fun removeFund(owner: address, project: &mut Project<XCOIN>, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);

        let admin = take_from_sender<VAdminCap>(scenario);
        let version = take_shared<Version>(scenario);
        let resgistry = take_shared<ProjectRegistry>(scenario);


        vesting::removeFund(&admin, owner, project, &mut resgistry,&version);

        return_to_sender(scenario, admin);
        return_shared(version);
        return_shared(resgistry);
    }

    fun create_project_(
        tge_ms: u64,
        vesting_type: u8,
        cliff_ms: u64,
        unlock_percent: u64,
        linear_vesting_duration_ms: u64,
        milestone_times: vector<u64>,
        milestone_percents: vector<u64>,
        sclock: &Clock,
        scenario: &mut Scenario
    ): Project<XCOIN> {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin = test_scenario::take_from_sender<VAdminCap>(scenario);
            let projectRegistry = test_scenario::take_shared<ProjectRegistry>(scenario);
            let version = test_scenario::take_shared<Version>(scenario);
            let ctx = test_scenario::ctx(scenario);

            vesting::createProject<XCOIN>(
                &admin,
                b"project1",
                b"http://url",
                TOTAL_SUPPLY,
                tge_ms,
                vesting_type,
                cliff_ms,
                unlock_percent,
                linear_vesting_duration_ms,
                milestone_times,
                milestone_percents,
                sclock,
                &mut version,
                0,
                &mut projectRegistry,
                ctx
            );

            test_scenario::return_shared(projectRegistry);
            test_scenario::return_to_sender(scenario, admin);
            test_scenario::return_shared(version);
        };

        test_scenario::next_tx(scenario, ADMIN);
        test_scenario::take_shared<Project<XCOIN>>(scenario)
    }

    fun init_env(scenario: &mut Scenario) {
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
        initForTest(ctx);
        vesting::initForTesting(ctx);
    }

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }
}
