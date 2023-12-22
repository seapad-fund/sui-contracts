#[test_only]
module seapad::reward_test {
    use sui::test_scenario::{Scenario, take_shared, take_from_sender, return_to_sender, return_shared, next_tx};
    use sui::test_scenario;
    use sui::clock;
    use sui::clock::Clock;
    use seapad::reward::{RewardAdminCap, Project, ProjectRegistry};

    use seapad::version::{Version, initForTest};
    use std::vector;
    use seapad::reward;
    use sui::coin;
    use sui::coin::Coin;
    use sui::object::id_address;

    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND: address = @0xC0FFFF;
    const ONE_MILLION_DECIMAL9: u128 = 1000000000000000;
    const TOTAL_SUPPLY: u128 = 100000000000000000;

    const TWO_HOURS_IN_MS: u64 = 2 * 3600000;
    const ONE_HOURS_IN_MS: u64 = 3600000;

    const MONTH_IN_MS: u64 = 2592000000;
    const HALF_MONTH_IN_MS: u64 = 1296000000;
    const ONE_QUARTER_MONTH_IN_MS: u64 = 648000000;

    const TEN_YEARS_IN_MS: u64 = 311040000000;

    const TGE_ONE_MONTH_MS: u64 = 2592000000;

    const UNLOCK_PERCENT: u64 = 1000;
    const PERCENT_SCALE: u64 = 10000;

    struct XCOIN has drop {}

    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;


    #[test]
    #[expected_failure(abort_code = reward::ERR_NO_FUND)]
    fun test_claim_no_fund() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);

        let project = create_project_(
            &sclock,
            scenario
        );
        let version = take_shared<Version>(scenario);
        let registry = test_scenario::take_shared<ProjectRegistry>(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut sclock, 9 * MONTH_IN_MS);
        reward::claim(&mut project, &sclock, &mut version, &mut registry, test_scenario::ctx(scenario));
        test_scenario::return_shared(sclock);
        test_scenario::return_shared(version);
        test_scenario::return_shared(project);
        test_scenario::return_shared(registry);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = reward::ERR_TGE_NOT_STARTED)]
    fun test_linenear_claim_tge() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);

        let oneYear = 12 * MONTH_IN_MS;

        let project = create_project_(
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario, 4* TGE_ONE_MONTH_MS, oneYear);

        //Test claim all
        {
            clock::increment_for_testing(&mut sclock, 3 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) >= 0, 0);

            return_to_sender(scenario, fundClaim);
        };

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = reward::ERR_NO_FUND)]
    fun test_linenear_claim() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);

        let oneYear = 12 * MONTH_IN_MS;

        let project = create_project_(
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario, TGE_ONE_MONTH_MS, oneYear);

        //Test claim all
        {
            clock::increment_for_testing(&mut sclock, 3 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) >= fundValue/7, 0);

            return_to_sender(scenario, fundClaim);
        };

        //then remove fund
        removeFund(SEED_FUND, &mut project, scenario);
        //make sure registry clear

        clock::increment_for_testing(&mut sclock, 13 * MONTH_IN_MS);

        //Claim expect failed because no more fund now
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_linenear_claim_all() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);

        let oneYear = 12 * MONTH_IN_MS;

        let project = create_project_(
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario, TGE_ONE_MONTH_MS, oneYear);

        //Test claim all
        {
            clock::increment_for_testing(&mut sclock, 13 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) >= fundValue, 0);

            return_to_sender(scenario, fundClaim);
        };

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_linenear_claim_all2() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);

        let oneYear = 12 * MONTH_IN_MS;

        let project = create_project_(
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario, TGE_ONE_MONTH_MS, oneYear);

        //Test claim all
        {
            clock::increment_for_testing(&mut sclock, 7 * MONTH_IN_MS);
            claim(SEED_FUND, &mut project, &sclock, scenario);

            test_scenario::next_tx(scenario, SEED_FUND);
            let fundClaim = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&fundClaim) >= fundValue/2, 0);

            return_to_sender(scenario, fundClaim);
        };

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }


    #[test]
    #[expected_failure(abort_code = reward::ERR_NO_FUND)]
    fun test_remove_fund(){
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);

        //setup
        next_tx(scenario, ADMIN);
        let sclock = take_shared<Clock>(scenario);
        let oneYear = 12 * MONTH_IN_MS;

        let project = create_project_(
            &sclock,
            scenario
        );

        let fundValue = 1000000u64;
        addFund(fundValue, SEED_FUND, &mut project, scenario, TGE_ONE_MONTH_MS, oneYear);
        removeFund(SEED_FUND, &mut project, scenario);

        //Admin receive fund back
        test_scenario::next_tx(scenario, ADMIN);
        {
            let receiveFund = take_from_sender<Coin<XCOIN>>(scenario);
            assert!(coin::value(&receiveFund) == fundValue, 0);
            return_to_sender(scenario, receiveFund);
        };

        //claim again & expect error no fund
        clock::increment_for_testing(&mut sclock, TGE_ONE_MONTH_MS);
        claim(SEED_FUND, &mut project, &sclock, scenario);

        return_shared(project);
        return_shared(sclock);
        test_scenario::end(scenario_val);
    }


    fun claim(claimer: address, project: &mut Project<XCOIN>, sclock: &Clock, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, claimer);
        let version = take_shared<Version>(scenario);
        let registry = take_shared<ProjectRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);
        reward::claim(project, sclock, &version, &mut registry, ctx);
        return_shared(version);
        return_shared(registry);
    }

    fun addFund(amount: u64, owner: address, project: &mut Project<XCOIN>, scenario: &mut Scenario, tge_ms: u64, vestingDur: u64) {
        test_scenario::next_tx(scenario, ADMIN);

        let admin = take_from_sender<RewardAdminCap>(scenario);
        let version = take_shared<Version>(scenario);
        let resgistry = take_shared<ProjectRegistry>(scenario);
        let ctx = test_scenario::ctx(scenario);

        let fund = coin::mint_for_testing<XCOIN>(amount, ctx);
        reward::addReward(&admin, owner, fund, tge_ms, vestingDur, project, &mut resgistry, &version);

        return_to_sender(scenario, admin);
        return_shared(version);
        return_shared(resgistry);
    }

    fun removeFund(owner: address, project: &mut Project<XCOIN>, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<RewardAdminCap>(scenario);
        let version = take_shared<Version>(scenario);
        let resgistry = take_shared<ProjectRegistry>(scenario);

        let ctx = test_scenario::ctx(scenario);
        reward::removeReward(&admin, owner, project, &mut resgistry, &version, ctx);

        return_to_sender(scenario, admin);
        return_shared(version);
        return_shared(resgistry);
    }

    fun create_project_(
        sclock: &Clock,
        scenario: &mut Scenario
    ): Project<XCOIN> {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin = test_scenario::take_from_sender<RewardAdminCap>(scenario);
            let projectRegistry = test_scenario::take_shared<ProjectRegistry>(scenario);
            let version = test_scenario::take_shared<Version>(scenario);
            let ctx = test_scenario::ctx(scenario);

            reward::createProject<XCOIN>(
                &admin,
                b"project1",
                sclock,
                &mut version,
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
        reward::initForTesting(ctx);
    }

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }
}
