#[test_only]
module seapad::launchpad_tests {
    use seapad::project::{Self, AdminCap};
    use seapad::spt;
    use sui::coin::CoinMetadata;
    use sui::test_scenario;
    use sui::tx_context;

    #[test]
    fun test_create_project() {
        let owner = @0xC0FFEE;
        let scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, owner);
        {
            let ctx = test_scenario::ctx(scenario);
            project::init_for_testing(ctx);
            spt::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, owner);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let coin_metadata = test_scenario::take_immutable<CoinMetadata<spt::SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let now = tx_context::epoch(ctx);
            let time1 = now + 1000;
            let time2 = time1 + 1000;
            let time3 = time2 + 1000;
            let time4 = time3 + 1000;

            project::add_project(
                &admin_cap,
                1,
                b"PROJECT_TEST",
                b"https://twitter.com",
                b"https://discord.com/channels/916379725201563759/971488439931392130",
                b"https://web.telegram.org/z/#-1898400336",
                b"https://seapad.fund/",
                false,
                1000000,
                5000000,
                1,
                1,
                1000,
                1,
                time1,
                25,
                time2,
                20,
                time3,
                40,
                time4,
                15,
                &coin_metadata,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_immutable(coin_metadata);
        };
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_project() {}

    #[test]
    fun test_fundraising_project() {}

    #[test]
    fun test_refund_project() {}

    #[test]
    fun test_claim_project() {}
}

