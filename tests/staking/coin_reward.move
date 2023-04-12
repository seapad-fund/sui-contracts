#[test_only]
module staking::coin_reward {
    use std::option;
    use sui::coin::{Self, CoinMetadata, TreasuryCap};
    use sui::url;
    use sui::test_scenario;
    use sui::test_scenario::{Scenario};
    use sui::transfer::{public_share_object};

    friend staking::emergency_tests;

    struct COIN_REWARD has drop {}

    const TEST_ADDR: address = @0xA11CE;

    #[test]
    fun test_create_coin() {
        let scenario = test_scenario::begin(TEST_ADDR);

        test_scenario::next_tx(&mut scenario, TEST_ADDR);
            {
                create_coin(&mut scenario);
            };

        test_scenario::next_tx(&mut scenario, TEST_ADDR);
            {
                let metadata = test_scenario::take_shared<CoinMetadata<COIN_REWARD>>(&mut scenario);
                let treasury = test_scenario::take_shared<TreasuryCap<COIN_REWARD>>(&mut scenario);
                test_scenario::return_shared(metadata);
                test_scenario::return_shared(treasury);
            };

        test_scenario::end(scenario);
    }

    #[test_only]
    public fun create_coin(test: &mut Scenario){
        let ctx = test_scenario::ctx(test);
        let witness = COIN_REWARD {};
        let (treasury, metadata) = coin::create_currency(
                witness,
                6
                , b"COIN_REWARD",
                b"COIN_REWARD",
                b"COIN_REWARD",
                option::some(url::new_unsafe_from_bytes(b"reward_url")),
                ctx);
        public_share_object(metadata);
        public_share_object(treasury);
    }
}