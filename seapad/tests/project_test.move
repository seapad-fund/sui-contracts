#[test_only]
module seapad::project_test {
    use std::vector;

    use seapad::project::{Self, AdminCap, Project};
    use seapad::spt::{Self, SPT};
    use sui::coin::{Self, Coin};
    use sui::math;
    use sui::test_scenario::{Self, Scenario};
    use seapad::usdt;
    use seapad::usdt::USDT;
    use sui::clock;
    use sui::clock::Clock;

    const ADMIN: address = @0xC0FFEE;
    const TOKEN_MINT_TEST: u64 = 1000000000000000;
    const SWAP_RATIO_COIN: u64 = 1;
    const SWAP_RATIO_TOKEN: u64 = 2;
    //1000
    const SOFT_CAP: u64 = 1000000000000;
    //2000
    const HARD_CAP: u64 = 2000000000000;
    const DEPOSIT_VALUE: u64 = 40000000000000;

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

    const COIN_DECIMAL: u8 = 8;
    const TOKEN_DECIMAL: u8 = 9;
    const LINEAR_TIME: u64 = 10000;
    const START_TIME: u64 = 1000;
    const END_TIME: u64 = 3000;


    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }


    #[test]
    fun test_create_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_project_milestone_(scenario);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_update_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);
        let clock = test_scenario::take_shared<Clock>(scenario);
        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, true, &clock);
        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_add_milestone() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, true, &clock);

        add_milestone_(3500, 750, scenario, &clock);//alway pass
        add_milestone_(4000, 250, scenario, &clock);//must pass

        reset_milestone_(scenario);
        add_milestone_(3500, 1000, scenario, &clock);//alway pass

        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_add_milestone_must_failure() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, true, &clock);

        add_milestone_(1000, 750, scenario, &clock);//alway pass
        add_milestone_(2000, 250, scenario, &clock);//must pass
        add_milestone_(900, 250, scenario, &clock);//must failed
        add_milestone_(2000, 300, scenario, &clock);//must failed

        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_fundraising_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);
        clock::increment_for_testing(&mut clock, 1000);
        start_fund_raising_(scenario, &clock);

        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_buy_token() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);
        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);

        clock::increment_for_testing(&mut clock, 1500);
        start_fund_raising_(scenario, &clock);
        buy_token_(OWNER_PROJECT, 500000000000, scenario, &clock);//pass
        buy_token_(USER2, 500000000000, scenario, &clock);//pass

        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_buy_token_out_of_hardcap() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);
        start_fund_raising_(scenario, &clock);

        let coin_buy = if (TOKEN_DECIMAL >= COIN_DECIMAL) {
            500000000000 * math::pow(10, TOKEN_DECIMAL - COIN_DECIMAL)
        }else {
            500000000000 / math::pow(10, COIN_DECIMAL - TOKEN_DECIMAL)
        };

        buy_token_(USER2, coin_buy, scenario, &clock);//pass
        buy_token_(USER3, coin_buy, scenario, &clock);//failed out of hard_card
        buy_token_(USER4, coin_buy, scenario, &clock);//failed out of hard_card
        buy_token_(USER5, coin_buy, scenario, &clock);//failed out of hard_card
        buy_token_(USER6, coin_buy, scenario, &clock);//failed out of hard_card
        buy_token_(USER7, coin_buy, scenario, &clock);//failed out of hard_card
        buy_token_(USER8, coin_buy, scenario, &clock);//failed out of hard_card
        buy_token_(USER9, coin_buy, scenario, &clock);//failed out of hard_card

        test_scenario::return_shared(clock);

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure]
    fun test_buy_token_exceed_max_allocate() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);
        start_fund_raising_(scenario, &clock);

        add_max_allocate_(USER2, MAX_ALLOCATE * 2, scenario);
        remove_max_allocate_(USER2, scenario);
        buy_token_(OWNER_PROJECT, 500000000000, scenario, &clock);//pass
        buy_token_(OWNER_PROJECT, 500000000000, scenario, &clock);//failed cause max allocate

        test_scenario::return_shared(clock);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_buy_token_max_allocate() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);

        clock::increment_for_testing(&mut clock, 1500);
        start_fund_raising_(scenario, &clock);

        add_max_allocate_(USER2, MAX_ALLOCATE * 2, scenario);

        buy_token_(USER2, MAX_ALLOCATE, scenario, &clock);//pass
        buy_token_(USER2, MAX_ALLOCATE, scenario, &clock);//pass

        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    // #[expected_failure]
    fun test_buy_token_use_whitelist() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, true, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);

        clock::increment_for_testing(&mut clock, 1500);
        start_fund_raising_(scenario, &clock);
        add_whitelist_(USER2, scenario);
        buy_token_(USER2, 500000000000, scenario, &clock);

        test_scenario::return_shared(clock);

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_project_by_linear() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_linear_time_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);

        clock::increment_for_testing(&mut clock, 1500);
        start_fund_raising_(scenario, &clock);

        // add_whitelist_(USER1, scenario);
        let coin_buy = 500000000000;
        buy_token_(USER2, coin_buy, scenario, &clock);
        buy_token_(USER3, coin_buy, scenario, &clock);
        clock::increment_for_testing(&mut clock, 1500);
        end_fund_raising_(scenario, &clock);

        clock::increment_for_testing(&mut clock, 5000);
        let percent = ((clock::timestamp_ms(&clock) - END_TIME) * 1000) / LINEAR_TIME;
        receive_token_(USER2, scenario, &clock);
        test_scenario::next_tx(scenario, USER2);
        {
            let spt = test_scenario::take_from_sender<Coin<SPT>>(scenario);
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let spt_value = coin::value(&spt);

            let spt_value_expected = project::swap_token(coin_buy, &project);
            let spt_value_actual = spt_value_expected / 1000 * (percent);

            assert!(spt_value_actual == spt_value, 0);

            test_scenario::return_to_sender(scenario, spt);
            test_scenario::return_shared(project);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            project::distribute_raised_fund(&admin_cap, &mut project, ctx);
            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, OWNER_PROJECT);
            let coin_raised = test_scenario::take_from_sender<Coin<USDT>>(scenario);
            let coin_value = coin::value(&coin_raised);

            assert!(coin_value == 500000000000 * 2, 0);
            test_scenario::return_to_sender(scenario, coin_raised);
        };
        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_claim_project_by_milestone() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);

        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);
        deposit_to_project_(OWNER_PROJECT, DEPOSIT_VALUE, scenario);

        clock::increment_for_testing(&mut clock, 1500);
        start_fund_raising_(scenario, &clock);

        // add_whitelist_(USER1, scenario);
        let coin_buy = 500000000000;
        buy_token_(USER2, coin_buy, scenario, &clock);
        buy_token_(USER3, coin_buy, scenario, &clock);
        clock::increment_for_testing(&mut clock, 1500);
        end_fund_raising_(scenario, &clock);

        let percent = 500;
        add_milestone_(4000, percent, scenario, &clock);

        clock::increment_for_testing(&mut clock, 5000);
        receive_token_(USER2, scenario, &clock);

        test_scenario::next_tx(scenario, USER2);
        {
            let spt = test_scenario::take_from_sender<Coin<SPT>>(scenario);
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let spt_value = coin::value(&spt);

            let spt_value_expected = project::swap_token(coin_buy, &project);
            let spt_value_actual = spt_value_expected / 1000 * (percent);

            assert!(spt_value_actual == spt_value, 0);

            test_scenario::return_to_sender(scenario, spt);
            test_scenario::return_shared(project);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            project::distribute_raised_fund(&admin_cap, &mut project, ctx);
            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, OWNER_PROJECT);
            let coin_raised = test_scenario::take_from_sender<Coin<USDT>>(scenario);
            let coin_value = coin::value(&coin_raised);

            assert!(coin_value == 500000000000 * 2, 0);
            test_scenario::return_to_sender(scenario, coin_raised);
        };
        test_scenario::return_shared(clock);
        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_refund_project() {
        let scenario_val = scenario();
        let scenario = &mut scenario_val;
        create_clock_time_(scenario);
        test_scenario::next_tx(scenario, ADMIN);

        let clock = test_scenario::take_shared<Clock>(scenario);
        create_project_milestone_(scenario);
        setup_launch_state_(scenario, 1, false, &clock);

        let deposit_value = DEPOSIT_VALUE;
        deposit_to_project_(OWNER_PROJECT, deposit_value, scenario);
        clock::increment_for_testing(&mut clock, 1000);
        start_fund_raising_(scenario, &clock);

        // add_whitelist_(USER1, scenario);
        let coin_buy = 500000000000;
        clock::increment_for_testing(&mut clock, 1000);
        buy_token_(USER2, coin_buy, scenario, &clock);
        clock::increment_for_testing(&mut clock, 1000);
        end_fund_raising_(scenario, &clock);

        //refund coin to user
        test_scenario::next_tx(scenario, USER2);
        {
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);

            project::claim_refund(&mut project, ctx);

            test_scenario::next_tx(scenario, USER2);
            let coin_bought = test_scenario::take_from_address<Coin<USDT>>(scenario, USER2);
            assert!(coin::value(&coin_bought) == coin_buy, 0);

            test_scenario::return_shared(project);
            test_scenario::return_to_address(USER2, coin_bought);
        };

        end_refund_(scenario);

        test_scenario::next_tx(scenario, ADMIN);
        {
            //refund token to owner
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);
            project::refund_token_to_owner(&admin_cap, &mut project, ctx);
            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);

            test_scenario::next_tx(scenario, OWNER_PROJECT);
            let stp_from_refund = test_scenario::take_from_sender<Coin<SPT>>(scenario);
            let value = coin::value(&stp_from_refund);
            assert!(deposit_value == value, 0);
            test_scenario::return_to_sender(scenario, stp_from_refund);
        };

        test_scenario::return_shared(clock);

        test_scenario::end(scenario_val);
    }

    fun create_project_linear_time_(scenario: &mut Scenario) {
        create_project_(2, scenario);
    }

    fun create_project_(vesting_type: u8, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let ctx = test_scenario::ctx(scenario);
            project::init_for_testing(ctx);
            spt::init_for_testing(ctx);
            usdt::init_for_testing(ctx);
        };

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let ctx = test_scenario::ctx(scenario);

            project::create_project<USDT, SPT>(
                &admin_cap,
                OWNER_PROJECT,
                vesting_type,
                LINEAR_TIME,
                COIN_DECIMAL,
                TOKEN_DECIMAL,
                ctx
            );
            test_scenario::return_to_sender(scenario, admin_cap);
        };
    }

    fun create_project_milestone_(scenario: &mut Scenario) {
        create_project_(1, scenario);
    }

    fun setup_launch_state_(scenario: &mut Scenario, round: u8, usewhitelist: bool, clock: &Clock) {

        test_scenario::next_tx(scenario, ADMIN);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);

            project::setup_project<USDT, SPT>(
                &admin_cap,
                &mut project,
                round,
                usewhitelist,
                SWAP_RATIO_COIN,
                SWAP_RATIO_TOKEN,
                MAX_ALLOCATE,
                START_TIME,
                END_TIME,
                SOFT_CAP,
                HARD_CAP,
                clock);

            test_scenario::return_to_sender(scenario, admin_cap);
            test_scenario::return_shared(project);
        };
    }

    fun add_milestone_(time: u64, percent: u64, scenario: &mut Scenario, clock: &Clock) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        project::add_milestone(&admin_cap, &mut ido, time, percent, clock);
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun reset_milestone_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        project::reset_milestone(&admin_cap, &mut ido);
        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun start_fund_raising_(scenario: &mut Scenario, clock: &Clock) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::start_fund_raising(&admin_cap, &mut ido, clock, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun end_fund_raising_(scenario: &mut Scenario, clock: &Clock) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::end_fund_raising(&admin_cap, &mut ido, clock, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun end_refund_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);
        let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::end_refund(&admin_cap, &mut ido, ctx);

        test_scenario::return_to_sender(scenario, admin_cap);
        test_scenario::return_shared(ido);
    }

    fun deposit_to_project_(owner: address, value: u64, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, owner);
        {
            //deposit
            let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let spt1 = coin::mint_for_testing<SPT>(value, ctx);


            let spts = vector::empty<Coin<SPT>>();
            vector::push_back(&mut spts, spt1);

            //expect 5k
            project::deposit_by_owner(spts, value, &mut ido, ctx);

            test_scenario::return_shared(ido);
        };
    }

    fun buy_token_(user: address, value: u64, scenario: &mut Scenario, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        {
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let ctx = test_scenario::ctx(scenario);
            let coin = coin::mint_for_testing<USDT>(TOKEN_MINT_TEST, ctx);
            let coins = vector::empty<Coin<USDT>>();
            vector::push_back(&mut coins, coin);

            project::buy(coins, value, &mut project, clock, ctx);

            test_scenario::return_shared(project);
        };
    }

    fun add_whitelist_(user: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        {
            let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
            let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

            let ctx = test_scenario::ctx(scenario);

            let users = vector::empty<address>();
            vector::push_back(&mut users, user);
            project::add_whitelist(&admin_cap, &mut project, users, ctx);

            test_scenario::return_shared(project);
            test_scenario::return_to_sender(scenario, admin_cap);
        }
    }

    fun receive_token_(user: address, scenario: &mut Scenario, clock: &Clock) {
        test_scenario::next_tx(scenario, user);
        let ido = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        let ctx = test_scenario::ctx(scenario);

        project::claim_token(&mut ido, clock, ctx);

        test_scenario::return_shared(ido);
    }

    fun add_max_allocate_(user: address, max_allocate: u64, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

        let ctx = test_scenario::ctx(scenario);
        project::set_max_allocate(&admin_cap, user, max_allocate, &mut project, ctx);

        test_scenario::return_shared(project);
        test_scenario::return_to_sender(scenario, admin_cap);
    }

    fun remove_max_allocate_(user: address, scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let project = test_scenario::take_shared<Project<USDT, SPT>>(scenario);
        let admin_cap = test_scenario::take_from_sender<AdminCap>(scenario);

        let ctx = test_scenario::ctx(scenario);
        project::clear_max_allocate(&admin_cap, user, &mut project, ctx);

        test_scenario::return_shared(project);
        test_scenario::return_to_sender(scenario, admin_cap);
    }

    fun create_clock_time_(scenario: &mut Scenario) {
        test_scenario::next_tx(scenario, ADMIN);
        let ctx = test_scenario::ctx(scenario);
        clock::share_for_testing(clock::create_for_testing(ctx));
    }
}

