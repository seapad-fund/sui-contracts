#[test_only]
module seapad::stake_test {
    use seapad::stake;
    use seapad::stake::{StakePool, Admincap};
    use sui::clock;
    use sui::coin;
    use sui::clock::Clock;
    use seapad::version::{Version, initForTest};
    use sui::test_scenario::{Scenario, next_tx, return_shared, ctx};
    use sui::test_scenario;

    fun scenario(): Scenario { test_scenario::begin(@treasury_admin) }

    fun admins(): (address, address) { (@admin, @treasury) }

    const REWARD_VALUE: u64 = 10000000000;
    const STAKE_VALUE: u64 = 100000000000;
    const APY: u128 = 2000;
    const UNLOCTIME: u64 = 10000;



    #[test]
    #[expected_failure(abort_code = stake::ERR_AMOUNT_CANNOT_BE_ZERO)]
    fun test_value_stake() {
        let scenario_val = test_scenario::begin(@admin);
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);
        init_env(scenario);
        next_tx(scenario, @admin);
        create_pool(scenario);

        next_tx(scenario, @alice);
        stake(0, &clock, scenario);

        clock::destroy_for_testing(clock);
        test_scenario::end(scenario_val);
    }

    fun create_pool(scenario: &mut Scenario): StakePool<STAKE_COIN, REWARD_COIN> {
        let (stake_admin, _) = admins();
        next_tx(scenario, stake_admin);
        {
            let admin = test_scenario::take_from_sender<Admincap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let version = test_scenario::take_shared<Version>(scenario);
            // let reward = coin::mint_for_testing<REWARD_COIN>(REWARD_VALUE, ctx);
            // let stake_coin = coin::mint_for_testing<REWARD_COIN>(STAKE_VALUE, ctx);
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
        test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario)
    }

    fun stake(stake_value: u64, clock: &Clock, scenario: &mut Scenario) {
        let pool = test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let stake_coin = coin::mint_for_testing<STAKE_COIN>(stake_value, ctx);
        let version = test_scenario::take_shared<Version>(scenario);
        stake::stake(&mut pool, stake_coin, clock, &mut version, ctx);
        return_shared(pool);
    }

    fun unstake(stake_amount: u128, clock: &Clock, scenario: &mut Scenario) {
        let pool = test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        stake::unstake(&mut pool, stake_amount, clock, &mut version, ctx);
        return_shared(pool);
    }

    fun init_env(scenario: &mut Scenario) {
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
        initForTest(ctx);
        stake::initForTesting(ctx);
    }

    struct REWARD_COIN has drop {}

    struct STAKE_COIN has drop {}
}