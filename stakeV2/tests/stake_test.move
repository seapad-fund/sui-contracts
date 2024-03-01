#[test_only]
module seapad::stake_test {
    use sui::coin::Coin;
    use seapad::stake;
    use seapad::stake::{StakePool, Admincap, MigrateInfor};
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
    const VALUE_REWARD_UNSTAKE: u64 = 27397261;
    const VALUE_WITHDRAW_REWARD_COIN: u64 = 9972602739;


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
            assert!(coin::value(&coin_unstake) < VALUE_REWARD_UNSTAKE, 0);
            return_to_sender(scenario, coin_unstake);
        };

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_withdrawSpt() {
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
        withdrawSpt(SEED_FUND, &mut pool, &clock, scenario);

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

    #[test]
    fun test_updateUnlockTime() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;

        init_env(scenario);
        next_tx(scenario, ADMIN);
        //Create pool
        let pool = create_pool(scenario);

        //Update unlock time
        update_UnlockTime(&mut pool, 10000000, scenario);

        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_change_admin() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);
        next_tx(scenario, ADMIN);
        change_admin(@admin, scenario);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_pause() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        init_env(scenario);
        next_tx(scenario, ADMIN);

        //Create pool and Deposit Reward
        let pool = create_pool(scenario);

        //pause pool
        pause(&mut pool, true, scenario);

        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claimRewards() {
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

        // user claim reward
        claimRewards(SEED_FUND, &mut pool, &clock, scenario);

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_reward) < VALUE_REWARD_UNSTAKE, 0);
            return_to_sender(scenario, coin_reward);
        };

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_stakeRewards() {
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

        // user stake rewards
        stakeRewards(SEED_FUND, &mut pool, &clock, scenario);

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_withdrawRewardCoins() {
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

        // user claim reward
        claimRewards(SEED_FUND, &mut pool, &clock, scenario);

        //withdraw reward coin
        next_tx(scenario, ADMIN);
        withdrawRewardCoins(&mut pool, scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_reward) > VALUE_WITHDRAW_REWARD_COIN, 0);
            return_to_sender(scenario, coin_reward);
        };
        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_updateApy() {
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

        next_tx(scenario, @alice);
        stake(@alice, &mut pool, STAKE_VALUE, &clock, scenario);


        //admin updateApy
        next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);

        updateApy(&mut pool, vector[SEED_FUND, @alice], 2001, &clock, scenario);

        //next 12 hours user claim rewards
        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS + TWELVE_IN_MS);
        claimRewards(SEED_FUND, &mut pool, &clock, scenario);

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_reward) > 54794521, 0);
            return_to_sender(scenario, coin_reward);
        };

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_updateApyV2() {
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

        next_tx(scenario, @alice);
        stake(@alice, &mut pool, STAKE_VALUE, &clock, scenario);

        //admin updateApy
        next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);

        updateApyV2(&mut pool, vector[SEED_FUND, @alice], 2002, 2000, &clock, scenario);

        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS + TWELVE_IN_MS);
        claimRewards(SEED_FUND, &mut pool, &clock, scenario);

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_reward) > 54794520, 0);
            return_to_sender(scenario, coin_reward);
        };

        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_stopEmergency() {
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

        next_tx(scenario, @alice);
        stake(@alice, &mut pool, STAKE_VALUE, &clock, scenario);

        // next time 12 hours
        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);

        // user claim reward
        claimRewards(SEED_FUND, &mut pool, &clock, scenario);


        // next 12 hours admin stop emergency
        next_tx(scenario, ADMIN);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS + 1);
        stopEmergency(&mut pool, vector[SEED_FUND, @alice], true, &clock, scenario);

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_reward = take_from_sender<Coin<STAKE_COIN>>(scenario);
            assert!(coin::value(&coin_reward) == (STAKE_VALUE as u64), 0);
            return_to_sender(scenario, coin_reward);
        };


        clock::destroy_for_testing(clock);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_start_migrate() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;

        init_env(scenario);
        next_tx(scenario, ADMIN);

        //admin start migrate
        let migrate = start_migrate(scenario);

        return_shared(migrate);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_set_treasury_admin_address() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;

        init_env(scenario);
        next_tx(scenario, ADMIN);

        // admin start migrate
        let migrate = start_migrate(scenario);

        //admin set treasury
        set_treasury_admin_address(&mut migrate, @alice, scenario);

        return_shared(migrate);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_migrateNewVersion() {
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

        // admin start migrate
        next_tx(scenario, ADMIN);
        let migrate = start_migrate(scenario);

        //user migrate
        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);
        migrateNewVersion(SEED_FUND, &mut pool, b"package_target", b"BSC", &mut migrate, &clock, scenario);

        test_scenario::next_tx(scenario, @treasury_admin);
        {
            let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
            assert!(coin::value(&coin_stake) == (STAKE_VALUE as u64), 0);
            return_to_sender(scenario, coin_stake);
        };

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_reward) < VALUE_REWARD_UNSTAKE, 0);
            return_to_sender(scenario, coin_reward);
        };


        clock::destroy_for_testing(clock);
        return_shared(migrate);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_FUND)]
    fun test_value_spt_migrate() {
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
        let unstake_amount = STAKE_VALUE ;
        unstake(SEED_FUND, &mut pool, unstake_amount, &clock, scenario);

        // user withdraw SPT
        clock::increment_for_testing(&mut clock, TIME_WITHDRAW);
        withdrawSpt(SEED_FUND, &mut pool, &clock, scenario);

        // admin start migrate
        next_tx(scenario, ADMIN);
        let migrate = start_migrate(scenario);

        //user migrate --> err because spt ==0
        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);
        migrateNewVersion(SEED_FUND, &mut pool, b"package_target", b"BSC", &mut migrate, &clock, scenario);

        clock::destroy_for_testing(clock);
        return_shared(migrate);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_NO_FUND)]
    fun test_user_not_migrate() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        init_env(scenario);
        next_tx(scenario, ADMIN);

        //Create pool and Deposit Reward
        let pool = create_pool(scenario);
        depositRewardCoins(&mut pool, REWARD_VALUE, scenario);

        // admin start migrate
        next_tx(scenario, ADMIN);
        let migrate = start_migrate(scenario);

        //User stake amount
        next_tx(scenario, SEED_FUND);
        stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);


        //user migrate --> err because user is not in the stakes table
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);
        migrateNewVersion(USER_ERR, &mut pool, b"package_target", b"BSC", &mut migrate, &clock, scenario);

        clock::destroy_for_testing(clock);
        return_shared(migrate);
        return_shared(pool);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_user_unstake_with_migrate() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        init_env(scenario);
        next_tx(scenario, ADMIN);

        //Create pool and Deposit Reward
        let pool = create_pool(scenario);
        depositRewardCoins(&mut pool, REWARD_VALUE, scenario);

        // admin start migrate
        next_tx(scenario, ADMIN);
        let migrate = start_migrate(scenario);


        //User stake amount
        next_tx(scenario, SEED_FUND);
        stake(SEED_FUND, &mut pool, STAKE_VALUE, &clock, scenario);

        // next time 12 hours
        next_tx(scenario, SEED_FUND);
        clock::increment_for_testing(&mut clock, TWELVE_IN_MS);

        // user unstake
        let unstake_amount = STAKE_VALUE / 2 ;
        unstake(SEED_FUND, &mut pool, unstake_amount, &clock, scenario);

        // next user done time unstake.
        clock::increment_for_testing(&mut clock, TIME_WITHDRAW);
        migrateNewVersion(SEED_FUND, &mut pool, b"package_target", b"BSC", &mut migrate, &clock, scenario);


        test_scenario::next_tx(scenario, @treasury_admin);
        {
            let coin_stake = take_from_sender<Coin<STAKE_COIN>>(scenario);
            assert!(coin::value(&coin_stake) == VALUE_TEST, 0);
            return_to_sender(scenario, coin_stake);
        };

        test_scenario::next_tx(scenario, SEED_FUND);
        {
            let coin_reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(coin::value(&coin_reward) < VALUE_REWARD_UNSTAKE + VALUE_REWARD_UNSTAKE, 0);
            return_to_sender(scenario, coin_reward);
        };

        clock::destroy_for_testing(clock);
        return_shared(migrate);
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

    fun update_UnlockTime(pool: &mut StakePool<STAKE_COIN, REWARD_COIN>, unlock_times: u64, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        stake::updateUnlockTime(&admin, pool, unlock_times, &mut version);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun change_admin(to: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        stake::change_admin(admin, to, &mut version);

        return_shared(version);
    }

    fun pause(pool: &mut StakePool<STAKE_COIN, REWARD_COIN>, pause: bool, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        stake::pause(&admin, pool, pause);

        return_to_sender(scenario, admin);
    }

    fun claimRewards(
        claimer: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, claimer);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::claimRewards(pool, clock, &mut version, ctx);

        return_shared(version);
    }

    fun stakeRewards(
        staker: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, staker);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::stakeRewards(pool, clock, &mut version, ctx);

        return_shared(version);
    }

    fun withdrawRewardCoins(pool: &mut StakePool<STAKE_COIN, REWARD_COIN>, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::withdrawRewardCoins(&admin, pool, &mut version, ctx);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun updateApy(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        owners: vector<address>,
        apy: u128,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);

        stake::updateApy(&admin, pool, owners, apy, &mut version, clock);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun updateApyV2(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        owners: vector<address>,
        apy: u128,
        old_apy: u128,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);

        stake::updateApyV2(&admin, pool, owners, apy, old_apy, &mut version, clock);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun stopEmergency(
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        owners: vector<address>,
        paused: bool,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::stopEmergency(&admin, pool, owners, paused, clock, &mut version, ctx);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun start_migrate(scenario: &mut Scenario): MigrateInfor {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin = take_from_sender<Admincap>(scenario);
            let version = test_scenario::take_shared<Version>(scenario);
            let ctx = test_scenario::ctx(scenario);

            stake::start_migrate<STAKE_COIN, REWARD_COIN>(
                &admin,
                &mut version,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin);
            test_scenario::return_shared(version);
        };
        test_scenario::next_tx(scenario, ADMIN);
        test_scenario::take_shared<MigrateInfor>(scenario)
    }

    fun set_treasury_admin_address(migrate: &mut MigrateInfor, new_address: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin = take_from_sender<Admincap>(scenario);
        let version = test_scenario::take_shared<Version>(scenario);

        stake::set_treasury_admin_address<STAKE_COIN, REWARD_COIN>(&admin, migrate, new_address, &mut version);

        return_to_sender(scenario, admin);
        return_shared(version);
    }

    fun migrateNewVersion(
        user: address,
        pool: &mut StakePool<STAKE_COIN, REWARD_COIN>,
        package_target: vector<u8>,
        network: vector<u8>,
        admin: &mut MigrateInfor,
        clock: &Clock,
        scenario: &mut Scenario
    ) {
        test_scenario::next_tx(scenario, user);
        let version = test_scenario::take_shared<Version>(scenario);
        let ctx = test_scenario::ctx(scenario);

        stake::migrateNewVersion(pool, package_target, network, admin, &mut version, clock, ctx);

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