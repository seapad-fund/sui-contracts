#[test_only]
module seapad::project_test {
    use std::vector;

    use seapad::project::{Self, AdminCap, Project};
    use seapad::spt::{Self, SPT};
    use sui::coin::{Self, CoinMetadata, Coin};
    use sui::sui::SUI;
    use sui::test_scenario::{Self, Scenario};
    use sui::tx_context;

    const ADMIN: address = @0xC0FFEE;
    const TOKEN_MINT_TEST: u64 = 1000000000000000;
    const SWAP_RATIO_SUI: u64 = 1;
    const SWAP_RATIO_TOKEN: u64 = 5;
    //1000sui
    const SOFT_CAP: u64 = 1000000000000;
    //2000sui
    const HARD_CAP: u64 = 2000000000000;
    const MAX_ALLOCATE: u64 = 500000000000;
    const OWNER_PROJECT: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;
    const USER4: address = @0x4;
    const USER5: address = @0x5;
    const USER6: address = @0x6;
    const USER7: address = @0x7;
    const USER8: address = @0x8;
    const USER9: address = @0x9;

    const USE_WHITELIST: bool = false;


    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }


    #[test]
    fun test_create_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);
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
        create_project_(false, scenario);

        add_milestone_(1000, 75, scenario);//alway pass
        add_milestone_(2000, 25, scenario);//must pass

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_add_milestone_must_failure() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);

        add_milestone_(1000, 75, scenario);//alway pass
        add_milestone_(2000, 25, scenario);//must pass
        add_milestone_(900, 25, scenario);//must failed
        add_milestone_(2000, 30, scenario);//must failed

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fundraising_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_buy_token() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);

        buy_token_(OWNER_PROJECT, 500000000000, scenario);//pass
        buy_token_(USER2, 500000000000, scenario);//pass


        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_buy_token_out_of_hardcap() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);

        buy_token_(OWNER_PROJECT, 500000000000, scenario);//pass
        buy_token_(USER3, 500000000000, scenario);//failed out of hard_card
        buy_token_(USER4, 500000000000, scenario);//failed out of hard_card
        buy_token_(USER5, 500000000000, scenario);//failed out of hard_card
        buy_token_(USER6, 500000000000, scenario);//failed out of hard_card
        buy_token_(USER7, 500000000000, scenario);//failed out of hard_card
        buy_token_(USER8, 500000000000, scenario);//failed out of hard_card
        buy_token_(USER9, 500000000000, scenario);//failed out of hard_card

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_buy_token_max_allocate() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);

        buy_token_(OWNER_PROJECT, 500000000000, scenario);//pass
        buy_token_(OWNER_PROJECT, 500000000000, scenario);//failed cause max allocate

        test_scenario::end(scenario_val);
    }

    #[test]
    // #[expected_failure]
    fun test_buy_token_use_whitelist() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(true, scenario);
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);
        add_whitelist_(OWNER_PROJECT, scenario);
        buy_token_(OWNER_PROJECT, 500000000000, scenario);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);

        // add_whitelist_(USER1, scenario);
        let sui_buy = 500000000000;
        buy_token_(USER4, sui_buy, scenario);
        buy_token_(USER2, sui_buy, scenario);
        buy_token_(USER3, sui_buy, scenario);
        end_fund_raising_(scenario);

        let percent = 50;
        add_milestone_(0, percent, scenario);
        receive_token_(USER2, scenario);

        test_scenario::next_tx(scenario, USER2);
        {
            let spt = test_scenario::take_from_sender<Coin<SPT>>(scenario);
            let spt_value = coin::value(&spt);

            let spt_value_expected = (sui_buy / SWAP_RATIO_SUI) * SWAP_RATIO_TOKEN;
            let spt_value_actual = spt_value_expected / 100 * (percent as u64);

            assert!(spt_value_actual == spt_value, 0);

            test_scenario::return_to_sender(scenario, spt);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let project = test_scenario::take_shared<Project<SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            project::distribute_raised_fund(&admin_cap, &mut project, OWNER_PROJECT, ctx);
            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, OWNER_PROJECT);
            let sui_raised = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let sui_value = coin::value(&sui_raised);

            assert!(sui_value == 500000000000 * 3, 0);
            test_scenario::return_to_sender(scenario, sui_raised);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_refund_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_(false, scenario);

        let deposit_value = 5000000000000;
        deposit_to_project_(OWNER_PROJECT, scenario);
        start_fund_raising_(scenario);

        // add_whitelist_(USER1, scenario);
        let sui_buy = 500000000000;
        buy_token_(USER2, sui_buy, scenario);
        end_fund_raising_(scenario);

        //refund sui to user
        test_scenario::next_tx(scenario, USER2);
        {
            let project = test_scenario::take_shared<Project<SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            project::claim_refund(&mut project, ctx);

            test_scenario::next_tx(scenario, USER2);
            let sui_bought = test_scenario::take_from_address<Coin<SUI>>(scenario, USER2);
            assert!(coin::value(&sui_bought) == sui_buy, 0);

            test_scenario::return_shared(project);
            test_scenario::return_to_address(USER2, sui_bought);
        };

        end_refund_(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            //refund token to owner
            let project = test_scenario::take_shared<Project<SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            project::refund_token_to_owner(&admin_cap, &mut project, OWNER_PROJECT, ctx);
            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, OWNER_PROJECT);
            let stp_from_refund = test_scenario::take_from_sender<Coin<SPT>>(scenario);
            let value = coin::value(&stp_from_refund);
            assert!(deposit_value == value, 0);
            test_scenario::return_to_sender(scenario, stp_from_refund);
        };

        test_scenario::end(scenario_val);
    }

    fun create_project_(usewhitelist: bool, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            project::init_for_testing(ctx);
            spt::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let coin_metadata = test_scenario::take_immutable<CoinMetadata<spt::SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            let now = tx_context::epoch(ctx);
            let time1 = now + 1000;


            project::create_project<SPT>(
                &admin_cap,
                OWNER_PROJECT,
                1,
                usewhitelist,
                SOFT_CAP,
                HARD_CAP,
                SWAP_RATIO_SUI,
                SWAP_RATIO_TOKEN,
                MAX_ALLOCATE,
                1,
                time1,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_immutable(coin_metadata);
        };
    }

    fun update_project_(scenario: &mut Scenario) {
        create_project_(false, scenario);

        test_scenario::next_tx(scenario, ADMIN);
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

    fun add_milestone_(time: u64, percent: u8, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);
        project::add_milestone(&admin_cap, &mut ido, time, percent, ctx);
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun start_fund_raising_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::start_fund_raising(&admin_cap, &mut ido, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun end_fund_raising_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::end_fund_raising(&admin_cap, &mut ido, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun end_refund_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::end_refund(&admin_cap, &mut ido, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun deposit_to_project_(owner: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, owner);
        {
            //deposit
            let ido = test_scenario::take_shared<Project<SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let spt = coin::mint_for_testing<SPT>(TOKEN_MINT_TEST, ctx);
            let spts = vector::empty<Coin<SPT>>();
            vector::push_back(&mut spts, spt);
            //expect 5k
            project::deposit_project(spts, &mut ido, ctx);

            test_scenario::return_shared(ido);
        };
    }

    fun buy_token_(user: address, value: u64, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, user);
        {
            let project = test_scenario::take_shared<Project<SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let sui = coin::mint_for_testing<SUI>(TOKEN_MINT_TEST, ctx);
            let suis = vector::empty<Coin<SUI>>();
            vector::push_back(&mut suis, sui);

            project::buy(suis, value, &mut project, ctx);

            test_scenario::return_shared(project);
        };
    }

    fun add_whitelist_(user: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let project = test_scenario::take_shared<Project<SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            let ctx = test_scenario::ctx(scenario);
            project::add_whitelist(&admin_cap, &mut project, user, ctx);

            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);
        }
    }

    fun receive_token_(user: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, user);
        let ido = test_scenario::take_shared<Project<SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::receive_token(&mut ido, ctx);

        test_scenario::return_shared(ido);
    }
}

