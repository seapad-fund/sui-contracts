#[test_only]
module seapad::emergency_tests {
    use sui::test_scenario::{Scenario, next_tx, ctx};
    use sui::test_scenario;
    use seapad::stake_config;
    use seapad::stake_config::GlobalConfig;
    use seapad::stake;
    use sui::coin;

    /// this is number of decimals in both StakeCoin and RewardCoin by default, named like that for readability
    const ONE_COIN: u64 = 1000000;

    const START_TIME: u64 = 682981200;
    const MAX_STAKE: u64 = 1000000000000000000;

    // utilities
    fun scenario(): Scenario { test_scenario::begin(@stake_emergency_admin) }
    fun admins(): (address, address) { (@stake_emergency_admin, @treasury) }

    #[test]
    fun test_initialize() {
        let scenario = scenario();
        test_initialize_(&mut scenario);
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

    fun test_initialize_(scenario: &mut Scenario) {
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
                stake_config::set_treasury_admin_address(&mut gConfig, @treasury,  ctx(scenario));
                test_scenario::return_shared(gConfig)
            };
    }

    struct  REWARD_COIN has drop {}
    struct  STAKE_COIN has drop {}
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

                stake::register_pool<STAKE_COIN, REWARD_COIN>(reward_coins, duration, &gConfig, decimalS, decimalR, TIMESTAMP_MS_NOW, duration, MAX_STAKE, ctx(scenario));
                test_scenario::return_shared(gConfig);
            };
    }

//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_stake_with_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_unstake_with_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
//        coin::deposit(@alice, coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_add_rewards_with_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest, @harvest, reward_coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_harvest_with_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
//        let duration = 15768000;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        // wait for rewards
//        timestamp::update_global_time_for_test_secs(START_TIME + 100);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//        coin::deposit(@alice, reward_coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_boost_with_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        let collection_name = string::utf8(b"Test Collection");
//        let collection_owner = create_collecton(@collection_owner, collection_name);
//        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
//
//        // register staking pool with rewards and boost config
//        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
//        let duration = 15768000;
//        let boost_config = stake::create_boost_config(
//            @collection_owner,
//            collection_name,
//            5
//        );
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        // boost stake with nft
//        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_claim_with_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        let collection_name = string::utf8(b"Test Collection");
//        let collection_owner = create_collecton(@collection_owner, collection_name);
//        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
//
//        // register staking pool with rewards and boost config
//        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
//        let duration = 15768000;
//        let boost_config = stake::create_boost_config(
//            @collection_owner,
//            collection_name,
//            5
//        );
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        // boost stake with nft
//        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        // remove boost
//        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//        token::deposit_token(&alice_acc, nft);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_stake_with_global_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_unstake_with_global_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
//        coin::deposit(@alice, coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_add_rewards_with_global_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest, @harvest, reward_coins);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_harvest_with_global_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        // wait for rewards
//        timestamp::update_global_time_for_test_secs(START_TIME + 100);
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//        coin::deposit(@alice, reward_coins);
//    }
//
//        #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_boost_with_global_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        let collection_name = string::utf8(b"Test Collection");
//        let collection_owner = create_collecton(@collection_owner, collection_name);
//        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
//
//        // register staking pool with rewards and boost config
//        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
//        let duration = 15768000;
//        let boost_config = stake::create_boost_config(
//            @collection_owner,
//            collection_name,
//            5
//        );
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        // boost stake with nft
//        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_claim_with_global_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        let collection_name = string::utf8(b"Test Collection");
//        let collection_owner = create_collecton(@collection_owner, collection_name);
//        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
//
//        // register staking pool with rewards and boost config
//        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
//        let duration = 15768000;
//        let boost_config = stake::create_boost_config(
//            @collection_owner,
//            collection_name,
//            5
//        );
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//
//        // boost stake with nft
//        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        // remove boost
//        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//        token::deposit_token(&alice_acc, nft);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_enable_local_emergency_if_global_is_enabled() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake_config::enable_global_emergency(&emergency_admin);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY)]
//    fun test_cannot_enable_emergency_with_non_admin_account() {
//        let (harvest, _) = initialize_test();
//
//        let alice_acc = new_account(@alice);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//    }
//
//    #[test]
//    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
//    fun test_cannot_enable_emergency_twice() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//    }
//
//    #[test]
//    fun test_unstake_everything_in_case_of_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        // register staking pool
//        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
//        let duration = 12345;
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
//        assert!(option::is_none(&nft), 1);
//        option::destroy_none(nft);
//        coin::deposit(@alice, coins);
//
//        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice), 3);
//    }
//
//    #[test]
//    fun test_unstake_everything_and_nft_in_case_of_emergency() {
//        let (harvest, emergency_admin) = initialize_test();
//
//        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
//
//        let collection_name = string::utf8(b"Test Collection");
//        let collection_owner = create_collecton(@collection_owner, collection_name);
//        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
//
//        // register staking pool with rewards and boost config
//        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
//        let duration = 15768000;
//        let boost_config = stake::create_boost_config(
//            @collection_owner,
//            collection_name,
//            5
//        );
//        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
//
//        let coins =
//            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
//        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
//        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);
//        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
//
//        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
//
//        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
//        assert!(option::is_some(&nft), 1);
//        token::deposit_token(&alice_acc, option::extract(&mut nft));
//        option::destroy_none(nft);
//        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
//        coin::deposit(@alice, coins);
//
////    #test
////    fun test_set_treasury_admin_address_from_no_permission_account_fails_() {
////        let (stake_emergency_admin, _) = admins();
////
////        next_tx(scenario, stake_emergency_admin);
////            {
////                stake_config::init_for_testing(ctx(scenario));
////            };
////        next_tx(scenario, stake_emergency_admin);
////            {
////                let gConfig = test_scenario::take_shared<GlobalConfig>(scenario);
////                stake_config::set_treasury_admin_address(&gConfig, @treasury, ctx(scenario));
////                test_scenario::return_shared(gConfig)
////            }
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_register_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_stake_with_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_unstake_with_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
////        coin::deposit(@alice, coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_add_rewards_with_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest, @harvest, reward_coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_harvest_with_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        // wait for rewards
////        timestamp::update_global_time_for_test_secs(START_TIME + 100);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        coin::deposit(@alice, reward_coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_boost_with_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        let collection_name = string::utf8(b"Test Collection");
////        let collection_owner = create_collecton(@collection_owner, collection_name);
////        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
////
////        // register staking pool with rewards and boost config
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        let boost_config = stake::create_boost_config(
////            @collection_owner,
////            collection_name,
////            5
////        );
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        // boost stake with nft
////        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_claim_with_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        let collection_name = string::utf8(b"Test Collection");
////        let collection_owner = create_collecton(@collection_owner, collection_name);
////        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
////
////        // register staking pool with rewards and boost config
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        let boost_config = stake::create_boost_config(
////            @collection_owner,
////            collection_name,
////            5
////        );
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        // boost stake with nft
////        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        // remove boost
////        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        token::deposit_token(&alice_acc, nft);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_stake_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_unstake_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        let coins = stake::unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest, 100);
////        coin::deposit(@alice, coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_add_rewards_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        stake::deposit_reward_coins<StakeCoin, RewardCoin>(&harvest, @harvest, reward_coins);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_harvest_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        // wait for rewards
////        timestamp::update_global_time_for_test_secs(START_TIME + 100);
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        let reward_coins = stake::harvest<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        coin::deposit(@alice, reward_coins);
////    }
////
////        #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_boost_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        let collection_name = string::utf8(b"Test Collection");
////        let collection_owner = create_collecton(@collection_owner, collection_name);
////        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
////
////        // register staking pool with rewards and boost config
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        let boost_config = stake::create_boost_config(
////            @collection_owner,
////            collection_name,
////            5
////        );
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        // boost stake with nft
////        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_claim_with_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        let collection_name = string::utf8(b"Test Collection");
////        let collection_owner = create_collecton(@collection_owner, collection_name);
////        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
////
////        // register staking pool with rewards and boost config
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        let boost_config = stake::create_boost_config(
////            @collection_owner,
////            collection_name,
////            5
////        );
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        // boost stake with nft
////        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        // remove boost
////        let nft = stake::remove_boost<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        token::deposit_token(&alice_acc, nft);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_enable_local_emergency_if_global_is_enabled() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY)]
////    fun test_cannot_enable_emergency_with_non_admin_account() {
////        let (harvest, _) = initialize_test();
////
////        let alice_acc = new_account(@alice);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_EMERGENCY)]
////    fun test_cannot_enable_emergency_twice() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////    }
////
////    #[test]
////    fun test_unstake_everything_in_case_of_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
////        assert!(option::is_none(&nft), 1);
////        option::destroy_none(nft);
////        coin::deposit(@alice, coins);
////
////        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice), 3);
////    }
////
////    #[test]
////    fun test_unstake_everything_and_nft_in_case_of_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        let collection_name = string::utf8(b"Test Collection");
////        let collection_owner = create_collecton(@collection_owner, collection_name);
////        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
////
////        // register staking pool with rewards and boost config
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        let boost_config = stake::create_boost_config(
////            @collection_owner,
////            collection_name,
////            5
////        );
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);
////        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&emergency_admin, @harvest);
////
////        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        assert!(option::is_some(&nft), 1);
////        token::deposit_token(&alice_acc, option::extract(&mut nft));
////        option::destroy_none(nft);
////        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
////        coin::deposit(@alice, coins);
////
////        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice), 3);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake::ERR_NO_EMERGENCY)]
////    fun test_cannot_emergency_unstake_in_non_emergency() {
////        let (harvest, _) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////
////        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        option::destroy_none(nft);
////        coin::deposit(@alice, coins);
////    }
////
////    #[test]
////    fun test_emergency_is_local_to_a_pool() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins_1 = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let reward_coins_2 = mint_default_coin<StakeCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins_1, duration, option::none());
////        stake::register_pool<RewardCoin, StakeCoin>(&harvest, reward_coins_2, duration, option::none());
////
////        stake::enable_emergency<RewardCoin, StakeCoin>(&emergency_admin, @harvest);
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 3);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_GLOBAL_EMERGENCY)]
////    fun test_cannot_enable_global_emergency_twice() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        stake_config::enable_global_emergency(&emergency_admin);
////        stake_config::enable_global_emergency(&emergency_admin);
////    }
////
////    #[test]
////    fun test_unstake_everything_in_case_of_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        // register staking pool
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::none());
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
////        assert!(option::is_none(&nft), 1);
////        option::destroy_none(nft);
////        coin::deposit(@alice, coins);
////
////        let exists = stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice);
////        assert!(!exists, 3);
////    }
////
////    #[test]
////    fun test_unstake_everything_and_nft_in_case_of_global_emergency() {
////        let (harvest, emergency_admin) = initialize_test();
////
////        let alice_acc = new_account_with_stake_coins(@alice, 1 * ONE_COIN);
////
////        let collection_name = string::utf8(b"Test Collection");
////        let collection_owner = create_collecton(@collection_owner, collection_name);
////        let nft = create_token(&collection_owner, collection_name, string::utf8(b"Token"));
////
////        // register staking pool with rewards and boost config
////        let reward_coins = mint_default_coin<RewardCoin>(15768000000000);
////        let duration = 15768000;
////        let boost_config = stake::create_boost_config(
////            @collection_owner,
////            collection_name,
////            5
////        );
////        stake::register_pool<StakeCoin, RewardCoin>(&harvest, reward_coins, duration, option::some(boost_config));
////
////        let coins =
////            coin::withdraw<StakeCoin>(&alice_acc, 1 * ONE_COIN);
////        stake::stake<StakeCoin, RewardCoin>(&alice_acc, @harvest, coins);
////        assert!(stake::get_user_stake<StakeCoin, RewardCoin>(@harvest, @alice) == 1 * ONE_COIN, 1);
////        stake::boost<StakeCoin, RewardCoin>(&alice_acc, @harvest, nft);
////
////        stake_config::enable_global_emergency(&emergency_admin);
////
////        let (coins, nft) = stake::emergency_unstake<StakeCoin, RewardCoin>(&alice_acc, @harvest);
////        assert!(option::is_some(&nft), 1);
////        token::deposit_token(&alice_acc, option::extract(&mut nft));
////        option::destroy_none(nft);
////        assert!(coin::value(&coins) == 1 * ONE_COIN, 2);
////        coin::deposit(@alice, coins);
////
////        assert!(!stake::stake_exists<StakeCoin, RewardCoin>(@harvest, @alice), 3);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NO_PERMISSIONS)]
////    fun test_cannot_enable_global_emergency_with_non_admin_account() {
////        let (_, _) = initialize_test();
////        let alice = new_account(@alice);
////        stake_config::enable_global_emergency(&alice);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NO_PERMISSIONS)]
////    fun test_cannot_change_admin_with_non_admin_account() {
////        let (_, _) = initialize_test();
////        let alice = new_account(@alice);
////        stake_config::set_emergency_admin_address(&alice, @alice);
////    }
////
////    #[test]
////    fun test_enable_emergency_with_changed_admin_account() {
////        let (_, emergency_admin) = initialize_test();
////        stake_config::set_emergency_admin_address(&emergency_admin, @alice);
////
////        let alice = new_account(@alice);
////
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&alice, reward_coins, duration, option::none());
////
////        stake::enable_emergency<StakeCoin, RewardCoin>(&alice, @alice);
////
////        assert!(stake::is_local_emergency<StakeCoin, RewardCoin>(@alice), 1);
////        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@alice), 2);
////        assert!(!stake_config::is_global_emergency(), 3);
////    }
////
////    #[test]
////    fun test_enable_global_emergency_with_changed_admin_account_no_pool() {
////        let (_, emergency_admin) = initialize_test();
////        stake_config::set_emergency_admin_address(&emergency_admin, @alice);
////
////        let alice = new_account(@alice);
////        stake_config::enable_global_emergency(&alice);
////
////        assert!(stake_config::is_global_emergency(), 3);
////    }
////
////    #[test]
////    fun test_enable_global_emergency_with_changed_admin_account_with_pool() {
////        let (_, emergency_admin) = initialize_test();
////        stake_config::set_emergency_admin_address(&emergency_admin, @alice);
////
////        let alice = new_account(@alice);
////
////        let reward_coins = mint_default_coin<RewardCoin>(12345 * ONE_COIN);
////        let duration = 12345;
////        stake::register_pool<StakeCoin, RewardCoin>(&alice, reward_coins, duration, option::none());
////
////        stake_config::enable_global_emergency(&alice);
////
////        assert!(!stake::is_local_emergency<StakeCoin, RewardCoin>(@alice), 1);
////        assert!(stake::is_emergency<StakeCoin, RewardCoin>(@alice), 2);
////        assert!(stake_config::is_global_emergency(), 3);
////    }
////
////    // Cases for ERR_NOT_INITIALIZED.
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NOT_INITIALIZED)]
////    fun test_enable_global_emergency_not_initialized_fails() {
////        let emergency_admin = new_account(@stake_emergency_admin);
////        stake_config::enable_global_emergency(&emergency_admin);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NOT_INITIALIZED)]
////    fun test_is_global_emergency_not_initialized_fails() {
////        stake_config::is_global_emergency();
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NOT_INITIALIZED)]
////    fun test_get_emergency_admin_address_not_initialized_fails() {
////        stake_config::get_emergency_admin_address();
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NOT_INITIALIZED)]
////    fun test_get_treasury_admin_address_not_initialized_fails() {
////        stake_config::get_treasury_admin_address();
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NOT_INITIALIZED)]
////    fun test_set_emergency_admin_address_not_initialized_fails() {
////        let emergency_admin = new_account(@stake_emergency_admin);
////        stake_config::set_emergency_admin_address(&emergency_admin, @alice);
////    }
////
////    #[test]
////    #[expected_failure(abort_code = stake_config::ERR_NOT_INITIALIZED)]
////    fun test_set_treasury_admin_address_not_initialized_fails() {
////        let treasury_admin = new_account(@treasury);
////        stake_config::set_emergency_admin_address(&treasury_admin, @alice);
////    }
}
