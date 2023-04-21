module seapad::project_entries {
    use seapad::project::{AdminCap, Project};
    use sui::tx_context::TxContext;
    use sui::coin::{Coin};
    use seapad::project;
    use std::vector;
    use sui::clock::Clock;

    public entry fun change_admin(adminCap: AdminCap, to: address) {
        project::change_admin(adminCap, to);
    }

    public entry fun create_project<COIN, TOKEN>(adminCap: &AdminCap,
                                                 owner: address,
                                                 vesting_type: u8,
                                                 coin_decimals: u8,
                                                 token_decimals: u8,
                                                 linear_time_ms: u64,
                                                 ctx: &mut TxContext) {
        project::create_project<COIN, TOKEN>(
            adminCap,
            owner,
            vesting_type,
            linear_time_ms,
            coin_decimals,
            token_decimals,
            ctx
        );
    }

    public entry fun change_owner<COIN, TOKEN>(
        admin_cap: &AdminCap,
        new_owner: address,
        project: &mut Project<COIN, TOKEN>
    ) {
        project::change_owner<COIN, TOKEN>(admin_cap, new_owner, project);
    }

    public entry fun add_milestone<COIN, TOKEN>(_adminCap: &AdminCap,
                                                project: &mut Project<COIN, TOKEN>,
                                                time: u64,
                                                percent: u64,
                                                clock: &Clock) {
        project::add_milestone<COIN, TOKEN>(_adminCap, project, time, percent, clock);
    }

    public entry fun reset_milestone<COIN, TOKEN>(_adminCap: &AdminCap, project: &mut Project<COIN, TOKEN>) {
        project::reset_milestone<COIN, TOKEN>(_adminCap, project);
    }

    public entry fun setup_project<COIN, TOKEN>(_adminCap: &AdminCap,
                                                project: &mut Project<COIN, TOKEN>,
                                                round: u8,
                                                usewhitelist: bool,
                                                swap_ratio_sui: u64,
                                                swap_ratio_token: u64,
                                                max_allocate: u64,
                                                start_time: u64,
                                                end_time: u64,
                                                soft_cap: u64,
                                                hard_cap: u64,
                                                clock: &Clock) {
        project::setup_project<COIN, TOKEN>(
            _adminCap,
            project,
            round,
            usewhitelist,
            swap_ratio_sui,
            swap_ratio_token,
            max_allocate,
            start_time,
            end_time,
            soft_cap,
            hard_cap,
            clock
        );
    }

    public entry fun add_max_allocate<COIN, TOKEN>(admin_cap: &AdminCap,
                                                   user: address,
                                                   max_allocate: u64,
                                                   project: &mut Project<COIN, TOKEN>,
                                                   ctx: &mut TxContext) {
        project::set_max_allocate<COIN, TOKEN>(admin_cap, user, max_allocate, project, ctx);
    }

    public entry fun remove_max_allocate<COIN, TOKEN>(_admin_cap: &AdminCap,
                                                      user: address,
                                                      project: &mut Project<COIN, TOKEN>,
                                                      _ctx: &mut TxContext) {
        project::clear_max_allocate<COIN, TOKEN>(_admin_cap, user, project, _ctx);
    }

    // public entry fun save_profile<COIN, TOKEN>(_adminCap: &AdminCap,
    //                                            project: &mut Project<COIN, TOKEN>,
    //                                            name: vector<u8>,
    //                                            twitter: vector<u8>,
    //                                            discord: vector<u8>,
    //                                            telegram: vector<u8>,
    //                                            website: vector<u8>,
    //                                            _ctx: &mut TxContext) {
    //     project::save_profile<COIN, TOKEN>(_adminCap, project, name, twitter, discord, telegram, website, _ctx);
    // }

    public entry fun add_whitelist<COIN, TOKEN>(_adminCap: &AdminCap,
                                                project: &mut Project<COIN, TOKEN>,
                                                user_list: vector<address>,
                                                _ctx: &mut TxContext) {
        project::add_whitelist<COIN, TOKEN>(_adminCap, project, user_list, _ctx);
    }

    public entry fun remove_whitelist<COIN, TOKEN>(_adminCap: &AdminCap,
                                                   project: &mut Project<COIN, TOKEN>,
                                                   user_list: vector<address>,
                                                   _ctx: &mut TxContext) {
        project::remove_whitelist<COIN, TOKEN>(_adminCap, project, user_list, _ctx);
    }

    public entry fun start_fund_raising<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        project::start_fund_raising<COIN, TOKEN>(_adminCap, project, clock, ctx);
    }

    public entry fun buy<COIN, TOKEN>(
        coin: Coin<COIN>,
        amount: u64,
        project: &mut Project<COIN, TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let coins = vector::empty<Coin<COIN>>();
        vector::push_back(&mut coins, coin);
        project::buy<COIN, TOKEN>(coins, amount, project, clock, ctx);
    }

    public entry fun end_fund_raising<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        project::end_fund_raising<COIN, TOKEN>(_adminCap, project, clock, ctx);
    }

    public entry fun end_refund<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        ctx: &mut TxContext
    ) {
        project::end_refund<COIN, TOKEN>(_adminCap, project, ctx);
    }

    public entry fun distribute_raised_fund<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        ctx: &mut TxContext
    ) {
        project::distribute_raised_fund<COIN, TOKEN>(_adminCap, project, ctx);
    }

    public entry fun refund_token_to_owner<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        ctx: &mut TxContext
    ) {
        project::refund_token_to_owner<COIN, TOKEN>(_adminCap, project, ctx);
    }

    public entry fun deposit_by_owner<COIN, TOKEN>(
        token: Coin<TOKEN>,
        value: u64,
        project: &mut Project<COIN, TOKEN>,
        ctx: &mut TxContext
    ) {
        let tokens = vector::empty<Coin<TOKEN>>();
        vector::push_back(&mut tokens, token);
        project::deposit_by_owner<COIN, TOKEN>(tokens, value, project, ctx);
    }

    public entry fun claim_token<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>, clock: &Clock, ctx: &mut TxContext) {
        project::claim_token<COIN, TOKEN>(project, clock, ctx);
    }

    public entry fun claim_refund<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>, ctx: &mut TxContext) {
        project::claim_refund<COIN, TOKEN>(project, ctx);
    }

    public entry fun vote<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>, ctx: &mut TxContext) {
        project::vote<COIN, TOKEN>(project, ctx);
    }
}
