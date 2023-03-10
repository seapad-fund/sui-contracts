#[test_only]
module seapad::launchpad_tests {
    use seapad::project::{Self, AdminCap, Project};
    use seapad::spt::{Self, SPT};
    use sui::test_scenario::{Self, Scenario};
    use sui::tx_context;
    use sui::sui::SUI;

    const OWNER: address = @0xC0FFEE;

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }


    #[test]
    fun test_create_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        test_create_project_(scenario);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        test_update_project_(scenario);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fundraising_project() {}

    #[test]
    fun test_refund_project() {}

    #[test]
    fun test_claim_project() {}

    fun test_create_project_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, OWNER);
        {
            let ctx = test_scenario::ctx(scenario);
            project::init_for_testing(ctx);
            spt::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let now = tx_context::epoch(ctx);
            let time1 = now + 1000;

            project::add_project<SUI>(
                &admin_cap,
                1,
                false,
                1000000,
                5000000,
                1,
                1,
                1000,
                1,
                time1,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin_cap);
        };
    }

    fun test_update_project_(scenario: &mut Scenario) {
        test_create_project_(scenario);

        test_scenario::next_tx(scenario, OWNER);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let project = test_scenario::take_shared<Project<SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let round = 1;
            let usewhitelist = true;
            let swap_ratio_sui = 2;
            let swap_ratio_token = 2;
            let max_allocate = 1111;
            let start_time = tx_context::epoch(ctx) + 1000;
            let end_time = start_time + 1000;

            let soft_cap = 999999;
            let hard_cap = 999999;

            project::update_project(
                &admin_cap,
                &mut project,
                round,
                usewhitelist,
                swap_ratio_sui,
                swap_ratio_token,
                max_allocate,
                start_time,
                soft_cap,
                hard_cap,
                end_time,
                ctx);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(project);
        };
    }
}

