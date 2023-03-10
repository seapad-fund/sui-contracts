#[test_only]
module seapad::project_test {
    use std::vector;

    use seapad::project::{Self, AdminCap, DataIDO};
    use seapad::spt::{Self, SPT};
    use sui::coin::{Self, CoinMetadata, Coin};
    use sui::test_scenario::{Self, Scenario};
    use sui::tx_context;

    const OWNER: address = @0xC0FFEE;
    const TOKEN_MINT_TEST: u64 = 1000000000000000;
    const SWAP_RATIO_SUI: u64 = 1;
    const SWAP_RATIO_TOKEN: u64 = 5;
    //1000sui
    const SOFT_CAP: u64 = 1000000000000;
    //100ksui
    const HARD_CAP: u64 = 100000000000000;
    const MAX_ALLOCATE: u64 = 0;
    const USER1: address = @0x1;
    const USER2: address = @0x2;


    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }


    #[test]
    fun test_create_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(scenario);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        update_project_(scenario);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_milestone() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(scenario);

        add_milestone_(1000, 75, scenario);//alway pass
        // add_milestone_(900, 25, scenario);//must failed
        // add_milestone_(2000, 25, scenario);//must pass
        // add_milestone_(2000, 30, scenario);//must failed

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fundraising_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(scenario);
        deposit_to_project(5000000000000, scenario);
        start_fund_raising_(scenario);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_refund_project() {}

    #[test]
    fun test_claim_project() {}

    fun create_project_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, OWNER);
        {
            let ctx = test_scenario::ctx(scenario);
            project::init_for_testing(ctx);
            spt::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, OWNER);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let coin_metadata = test_scenario::take_immutable<CoinMetadata<spt::SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let now = tx_context::epoch(ctx);
            let time1 = now + 1000;


            project::create_project(
                &admin_cap,
                1,
                false,
                SOFT_CAP,
                HARD_CAP,
                SWAP_RATIO_SUI,
                SWAP_RATIO_TOKEN,
                MAX_ALLOCATE,
                1,
                time1,
                &coin_metadata,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_immutable(coin_metadata);
        };
    }

    fun update_project_(scenario: &mut Scenario) {
        create_project_(scenario);

        test_scenario::next_tx(scenario, OWNER);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let project = test_scenario::take_shared<DataIDO<SPT>>(scenario);
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

    fun add_milestone_(time: u64, percent: u8, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, OWNER);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<DataIDO<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);
        project::add_milestone(&admin_cap, &mut ido, time, percent, ctx);
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun start_fund_raising_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, OWNER);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<DataIDO<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::start_fund_raising(&admin_cap, &mut ido, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun deposit_to_project(value: u64, scenario: &mut Scenario) {
        let owner_project = @0x1;
        test_scenario::next_tx(scenario, owner_project);
        {
            //deposit
            let ido = test_scenario::take_shared<DataIDO<SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let spt = coin::mint_for_testing<SPT>(TOKEN_MINT_TEST, ctx);
            let spts = vector::empty<Coin<SPT>>();
            vector::push_back(&mut spts, spt);
            //expect 5k
            project::deposit_project(spts, value, &mut ido, ctx);

            test_scenario::return_shared(ido);
        };
    }
}

