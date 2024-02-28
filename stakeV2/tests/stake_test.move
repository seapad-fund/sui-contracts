#[test_only]
module seapad::stake_test {
    use seapad::stake;
    use seapad::stake::{StakePool, Admincap};
    use sui::clock;
    use sui::coin;
    use sui::clock::Clock;
    use seapad::version::{Version, initForTest};
    use sui::test_scenario::{Scenario, next_tx, return_shared, ctx, take_shared};
    use sui::test_scenario;

    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND: address = @0xC0FFFF;

    const REWARD_VALUE: u64 = 10000000000;
    const STAKE_VALUE: u64 = 100000000000;
    const APY: u128 = 2000;
    const UNLOCTIME: u64 = 10000;



    #[test]
    #[expected_failure(abort_code = stake::ERR_AMOUNT_CANNOT_BE_ZERO)]
    fun test_value_stake() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);
        init_env(scenario);
        next_tx(scenario, ADMIN);

        let pool = create_pool(scenario);

        next_tx(scenario, SEED_FUND);
        stake(SEED_FUND,&mut pool,0, &clock, scenario);

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    fun create_pool(scenario: &mut Scenario): StakePool<STAKE_COIN, REWARD_COIN> {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin = test_scenario::take_from_sender<Admincap>(scenario);
            let version = test_scenario::take_shared<Version>(scenario);
            let ctx = test_scenario::ctx(scenario);
            stake::createPool<STAKE_COIN, REWARD_COIN>(
                &admin,
                UNLOCTIME,
                APY,
                &mut version,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin);
            test_scenario::return_shared(version);
        };
        test_scenario::next_tx(scenario, ADMIN);
        test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario)
    }

    fun stake(staker: address,pool: &mut StakePool<STAKE_COIN,REWARD_COIN>,stake_value: u64, clock: &Clock, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, staker);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let stake_coin = coin::mint_for_testing<STAKE_COIN>(stake_value, ctx);
        stake::stake(pool, stake_coin, clock, &mut version, ctx);
        return_shared(version);
    }

    fun unstake(unstaker:address,pool: &mut StakePool<STAKE_COIN,REWARD_COIN>,stake_amount: u128, clock: &Clock, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, unstaker);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        stake::unstake( pool, stake_amount, clock, &mut version, ctx);
        return_shared(version);
    }

    fun init_env(scenario: &mut Scenario) {
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
        initForTest(ctx);
        stake::initForTesting(ctx);
    }

    struct REWARD_COIN has drop {}

    struct STAKE_COIN has drop {}

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }
}