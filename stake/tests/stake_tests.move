#[test_only]
module seapad::emergency_tests {
    use sui::test_scenario::{Scenario, next_tx, ctx, return_shared, end, take_from_sender, return_to_sender};
    use sui::test_scenario;
    use seapad::stake_config;
    use seapad::stake_config::GlobalConfig;
    use seapad::stake;
    use sui::coin;
    use seapad::stake_entries;
    use sui::clock::Clock;
    use sui::clock;
    use seapad::stake::StakePool;
    use sui::coin::Coin;

    /// this is number of decimals in both StakeCoin and RewardCoin by default, named like that for readability
    const ONE_COIN: u64 = 1000000;

    const START_TIME: u64 = 682981200;
    const MAX_STAKE: u64 = 100000000000;
    const REWARD_VALUE: u64 = 10000000000;
    const STAKE_VALUE: u64 = 100000000000;
    const MAX_STAKE_VALUE: u64 = 200000000000;
    const DURATION_UNSTAKE_MS: u64 = 10000;
    const DURATION: u64 = 10000;
    const DECIMAL_S: u8 = 9;
    const DECIMAL_R: u8 = 9;

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@stake_emergency_admin) }

    fun admins(): (address, address) { (@stake_emergency_admin, @treasury) }

    #[test]
    fun test_initialize() {
        let scenario = scenario();
        config_initialize_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    fun test_set_treasury_admin_address() {
        let scenario = test_scenario::begin(@treasury_admin);
        test_set_treasury_admin_address_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = stake_config::ERR_NO_PERMISSIONS)]
    fun test_set_treasury_admin_address_from_no_permission_account_fails() {
        let scenario = test_scenario::begin(@treasury_admin);
        test_set_treasury_admin_address_from_no_permission_account_fails_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
    fun test_cannot_register_with_global_emergency() {
        let scenario = test_scenario::begin(@treasury_admin);
        test_cannot_register_with_global_emergency_(&mut scenario);
        test_scenario::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = stake::ERR_EXCEED_MAX_STAKE)]
    fun test_max_stake() {
        let scenario_val = test_scenario::begin(@treasury_admin);
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        //create pool
        next_tx(scenario, @treasury_admin);
        register_pool(&clock, scenario);

        //stake
        next_tx(scenario, @alice);
        stake(MAX_STAKE_VALUE + 1, &clock, scenario);

        clock::destroy_for_testing(clock);
        end(scenario_val);
    }

    #[test]
    fun test_unstake() {
        let scenario_val = test_scenario::begin(@treasury_admin);
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        //create pool
        next_tx(scenario, @treasury_admin);
        register_pool(&clock, scenario);

        //stake
        next_tx(scenario, @alice);
        stake(STAKE_VALUE, &clock, scenario);

        clock::increment_for_testing(&mut clock, DURATION_UNSTAKE_MS);

        //unstake
        let unstake_amount = STAKE_VALUE / 2;
        next_tx(scenario, @alice);
        unstake(unstake_amount, &clock, scenario);

        //check coin
        next_tx(scenario, @alice);
        {
            let coin_unstake = take_from_sender<Coin<STAKE_COIN>>(scenario);
            assert!(coin::value(&coin_unstake) == unstake_amount, 0);

            return_to_sender(scenario, coin_unstake);
        };

        clock::destroy_for_testing(clock);
        end(scenario_val);
    }

    #[test]
    //@TODO
    fun test_harvest() {
        let scenario_val = test_scenario::begin(@treasury_admin);
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        //create pool
        next_tx(scenario, @treasury_admin);
        register_pool(&clock, scenario);

        //stake
        next_tx(scenario, @alice);
        stake(STAKE_VALUE, &clock, scenario);

        clock::increment_for_testing(&mut clock, DURATION_UNSTAKE_MS);

        next_tx(scenario, @alice);
        let pending_reward = get_pending_reward(&clock, scenario);
        //harvest
        next_tx(scenario, @alice);
        harvest(&clock, scenario);

        //check harvest
        next_tx(scenario, @alice);
        {
            let reward = take_from_sender<Coin<REWARD_COIN>>(scenario);
            assert!(pending_reward == coin::value(&reward), 0);
            return_to_sender(scenario, reward);
        };

        clock::destroy_for_testing(clock);
        end(scenario_val);
    }

    fun get_pending_reward(clock: &Clock, scenario: &mut Scenario): u64 {
        let pool = test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario);
        let user = test_scenario::sender(scenario);

        let reward_value = stake::get_pending_user_rewards(&pool, user, clock::timestamp_ms(clock));
        return_shared(pool);

        reward_value
    }

    fun harvest(clock: &Clock, scenario: &mut Scenario) {
        {
            let pool = test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario);
            let config = test_scenario::take_shared<GlobalConfig>(scenario);
            let ctx = test_scenario::ctx(scenario);

            stake_entries::harvest(&mut pool, &config, clock, ctx);

            return_shared(pool);
            return_shared(config)
        }
    }

    fun unstake(stake_amount: u64, clock: &Clock, scenario: &mut Scenario) {
        {
            let pool = test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario);
            let config = test_scenario::take_shared<GlobalConfig>(scenario);
            let ctx = test_scenario::ctx(scenario);

            stake_entries::unstake(&mut pool, stake_amount, &config, clock, ctx);

            return_shared(pool);
            return_shared(config)
        }
    }

    fun stake(stake_value: u64, clock: &Clock, scenario: &mut Scenario) {
        {
            let pool = test_scenario::take_shared<StakePool<STAKE_COIN, REWARD_COIN>>(scenario);
            let config = test_scenario::take_shared<GlobalConfig>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let stake_coin = coin::mint_for_testing<STAKE_COIN>(stake_value, ctx);

            stake_entries::stake(&mut pool, stake_coin, &config, clock, ctx);

            return_shared(pool);
            return_shared(config)
        }
    }

    fun register_pool(clock: &Clock, scenario: &mut Scenario) {
        config_initialize_(scenario);

        let (stake_emergency_admin, _) = admins();
        next_tx(scenario, stake_emergency_admin);
        {
            let config = test_scenario::take_shared<GlobalConfig>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let reward = coin::mint_for_testing<REWARD_COIN>(REWARD_VALUE, ctx);
            stake_entries::register_pool<STAKE_COIN, REWARD_COIN>(
                reward,
                DURATION,
                &config,
                DECIMAL_S,
                DECIMAL_R,
                clock,
                DURATION_UNSTAKE_MS,
                MAX_STAKE_VALUE,
                ctx
            );
            test_scenario::return_shared(config);
        }
    }

    fun config_initialize_(scenario: &mut Scenario) {
        let (stake_emergency_admin, _) = admins();
        next_tx(scenario, stake_emergency_admin);
        {
            stake_config::init_for_testing(ctx(scenario));
        };

        next_tx(scenario, stake_emergency_admin);
        {
            let gConfig = test_scenario::take_shared<GlobalConfig>(scenario);
            assert!(stake_config::get_treasury_admin_address(&gConfig) == @treasury_admin, 1);
            assert!(stake_config::get_emergency_admin_address(&gConfig) == @stake_emergency_admin, 1);
            assert!(!stake_config::is_global_emergency(&gConfig), 1);
            test_scenario::return_shared(gConfig)
        };
    }

    fun test_set_treasury_admin_address_(scenario: &mut Scenario) {
        let (stake_emergency_admin, _) = admins();

        next_tx(scenario, stake_emergency_admin);
        {
            stake_config::init_for_testing(ctx(scenario));
        };

        next_tx(scenario, stake_emergency_admin);
        {
            let gConfig = test_scenario::take_shared<GlobalConfig>(scenario);
            stake_config::set_treasury_admin_address(&mut gConfig, @alice, ctx(scenario));
            assert!(stake_config::get_treasury_admin_address(&mut gConfig) == @alice, 1);
            test_scenario::return_shared(gConfig)
        };
    }

    fun test_set_treasury_admin_address_from_no_permission_account_fails_(scenario: &mut Scenario) {
        let (stake_emergency_admin, _) = admins();

        next_tx(scenario, stake_emergency_admin);
        {
            stake_config::init_for_testing(ctx(scenario));
        };

        next_tx(scenario, @treasury);
        {
            let gConfig = test_scenario::take_shared<GlobalConfig>(scenario);
            stake_config::set_treasury_admin_address(&mut gConfig, @treasury, ctx(scenario));
            test_scenario::return_shared(gConfig)
        };
    }

    struct REWARD_COIN has drop {}

    struct STAKE_COIN has drop {}

    const TIMESTAMP_MS_NOW: u64 = 1678444368000;

    fun test_cannot_register_with_global_emergency_(scenario: &mut Scenario) {
        let (stake_emergency_admin, _) = admins();

        next_tx(scenario, stake_emergency_admin);
        {
            stake_config::init_for_testing(ctx(scenario));
        };

        next_tx(scenario, stake_emergency_admin);
        {
            let gConfig = test_scenario::take_shared<GlobalConfig>(scenario);

            stake_config::enable_global_emergency(&mut gConfig, ctx(scenario));
            // register staking pool
            let decimalS = 6;
            let decimalR = 6;

            let reward_coins = coin::mint_for_testing<REWARD_COIN>(12345 * ONE_COIN, ctx(scenario));
            let duration = 12345;

            stake::register_pool<STAKE_COIN, REWARD_COIN>(
                reward_coins,
                duration,
                &gConfig,
                decimalS,
                decimalR,
                TIMESTAMP_MS_NOW,
                duration,
                MAX_STAKE,
                ctx(scenario)
            );
            test_scenario::return_shared(gConfig);
        };
    }
}
