#[test_only]
module seapad::stake_test {
    use sui::coin::Coin;
    use seapad::stake;
    use seapad::stake::{StakePool, Admincap};
    use sui::clock;
    use sui::coin;
    use sui::clock::Clock;
    use seapad::version::{Version, initForTest};
    use sui::test_scenario::{Scenario, next_tx, return_shared, ctx, return_to_sender, take_from_sender};
    use sui::test_scenario;

    const ADMIN: address = @0xC0FFEE;
    const SEED_FUND: address = @0xC0FFFF;
    const USER_ERR: address = @alice;

    const REWARD_VALUE: u128 = 10000000000;
    const STAKE_VALUE: u128 = 100000000000;
    const APY: u128 = 2000;
    const UNLOCTIME: u64 = 86400000;
    const TWELVE_IN_MS: u64 = 43200000;
    const TIME_WITHDRAW: u64 = 129600001;
    const VALUE_TEST: u64 = 50000000000;


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
        stake(SEED_FUND, &mut pool, 0, &clock, scenario);

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_STAKE)]
    fun test_user_unstake() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        init_env(scenario);
        next_tx(scenario, ADMIN);

        let pool = create_pool(scenario);
        next_tx(scenario, SEED_FUND);
        stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);

        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);
        unstake(USER_ERR, &mut pool, STAKE_VALUE / 2, &clock, scenario);

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_unstake() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        init_env(scenario);
        next_tx(scenario, ADMIN);

        let pool = create_pool(scenario);
        depositRewardCoins(&mut pool, REWARD_VALUE, scenario);

        next_tx(scenario, SEED_FUND);
        stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);

        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);

        let unstake_amount = STAKE_VALUE / 2;
        unstake(SEED_FUND, &mut pool, unstake_amount, &clock, scenario);

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_unstake = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_unstake) < (unstake_amount as u64), 0);
            return_to_sender(scenario, coin_unstake);
        };

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_withdrawSpt(){
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);


        init_env(scenario);
        next_tx(scenario, ADMIN);

        //Create pool and Deposit Reward
        let pool = create_pool(scenario);
        depositRewardCoins(&mut pool, REWARD_VALUE, scenario);

        //User stake amount
        next_tx(scenario, SEED_FUND);
        stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);

        // next time 12 hours
        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);

        // user unstake
        let unstake_amount = STAKE_VALUE / 2;
        unstake(SEED_FUND, &mut pool, unstake_amount, &clock, scenario);

        // user withdraw SPT
        clock::increment_for_testing(&mut clock, TIME_WITHDRAW);
        withdrawSpt(SEED_FUND,&mut pool,&clock,scenario);

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_unstake = take_from_sender<Coin<STAKE_COIN>>(scenario);
            assert!(coin::value(&coin_unstake) == VALUE_TEST, 0);
            return_to_sender(scenario, coin_unstake);
        };

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

    fun stake(
        staker: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        stake_value: u128,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, staker);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let stake_coin = coin::mint_for_testing<STAKE_COIN>((stake_value as u64), ctx);
        stake::stake(pool, stake_coin, clock, &mut version, ctx);
        return_shared(version);
    }

    fun unstake(
        unstaker: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        stake_amount: u128,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, unstaker);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        stake::unstake(pool, stake_amount, clock, &mut version, ctx);
        return_shared(version);
    }

    fun withdrawSpt(
        user: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, user);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        stake::withdrawSpt(pool, clock, &mut version, ctx);

        return_shared(version);
    }

    fun depositRewardCoins(pool: &mut StakePool<STAKE_COIN, REWARD_COIN>, reward_value: u128, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);
        let reward_coin = coin::mint_for_testing<REWARD_COIN>((reward_value as u64), ctx);
        stake::depositRewardCoins(&admin, pool, &mut version, reward_coin);

        return_to_sender(scenario, admin);
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