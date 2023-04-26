#[test_only]
module seapad::emergency_tests {
    use sui::test_scenario::{Scenario, next_tx, ctx};
    use sui::test_scenario;
    use seapad::stake_config;
    use seapad::stake_config::GlobalConfig;
    use seapad::stake;
    use sui::coin;
    use seapad::stake_entries;
    use sui::clock::Clock;
    use sui::clock;

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
    fun test_stake() {
        let scenario_val = test_scenario::begin(@treasury_admin);
        let scenario = &mut scenario_val;
        let ctx = ctx(scenario);
        let clock = clock::create_for_testing(ctx);

        next_tx(scenario, @treasury_admin);
        {
            register_pool(&clock,scenario);
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
            stake_entries::register_pool<STAKE_COIN, REWARD_COIN>(reward,
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
