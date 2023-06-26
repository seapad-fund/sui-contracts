module seapad::project_custom_entries {
    use sui::tx_context::TxContext;
    use sui::coin::{Coin};
    use seapad::project_custom as project;
    use std::vector;
    use sui::clock::Clock;
    use common::kyc::Kyc;
    use seapad::version::Version;
    use seapad::project_custom::{AdminCap, Project};

    public entry fun change_admin(adminCap: AdminCap,
                                  to: address,
                                  version: &mut Version) {
        project::change_admin(adminCap, to, version);
    }

    public entry fun create_project<COIN, TOKEN>(adminCap: &AdminCap,
                                                 owner: address,
                                                 coin_decimals: u8,
                                                 token_decimals: u8,
                                                 require_kyc: bool,
                                                 version: &mut Version,
                                                 ctx: &mut TxContext) {
        project::create_project<COIN, TOKEN>(
            adminCap,
            owner,
            coin_decimals,
            token_decimals,
            require_kyc,
            version,
            ctx
        );
    }

    public entry fun set_vesting<COIN, TOKEN>(adminCap: &AdminCap,
                                              vesting_type: u8,
                                              linear_time: u64,
                                              cliff_time: u64,
                                              tge: u64,
                                              unlock_percent: u64,
                                              project: &mut Project<COIN, TOKEN>,
                                              clock: &Clock,
                                              ctx: &mut TxContext) {
        project::set_vesting(adminCap,
            vesting_type,
            linear_time,
            cliff_time,
            tge,
            unlock_percent,
            project,
            clock,
            ctx);
    }

    public entry fun change_owner<COIN, TOKEN>(
        new_owner: address,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::change_owner<COIN, TOKEN>(new_owner, project, version, ctx);
    }

    public entry fun add_milestone<COIN, TOKEN>(_adminCap: &AdminCap,
                                                project: &mut Project<COIN, TOKEN>,
                                                time: u64,
                                                percent: u64,
                                                clock: &Clock,
                                                version: &mut Version) {
        project::add_milestone<COIN, TOKEN>(_adminCap, project, time, percent, clock, version);
    }

    public entry fun reset_milestone<COIN, TOKEN>(_adminCap: &AdminCap,
                                                  project: &mut Project<COIN, TOKEN>,
                                                  version: &mut Version) {
        project::reset_milestone<COIN, TOKEN>(_adminCap, project, version);
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
                                                clock: &Clock,
                                                version: &mut Version) {
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
            clock,
            version
        );
    }

    public entry fun add_max_allocate<COIN, TOKEN>(admin_cap: &AdminCap,
                                                   users: vector<address>,
                                                   max_allocates: vector<u64>,
                                                   project: &mut Project<COIN, TOKEN>,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext) {
        project::add_max_allocations<COIN, TOKEN>(admin_cap, users, max_allocates, project, version, ctx);
    }

    public entry fun remove_max_allocate<COIN, TOKEN>(_admin_cap: &AdminCap,
                                                      users: vector<address>,
                                                      project: &mut Project<COIN, TOKEN>,
                                                      version: &mut Version,
                                                      ctx: &mut TxContext) {
        project::clear_max_allocate<COIN, TOKEN>(_admin_cap, users, project, version, ctx);
    }

    public entry fun add_whitelist<COIN, TOKEN>(_adminCap: &AdminCap,
                                                project: &mut Project<COIN, TOKEN>,
                                                user_list: vector<address>,
                                                version: &mut Version,
                                                ctx: &mut TxContext) {
        project::add_whitelist<COIN, TOKEN>(_adminCap, project, user_list, version, ctx);
    }

    public entry fun remove_whitelist<COIN, TOKEN>(_adminCap: &AdminCap,
                                                   project: &mut Project<COIN, TOKEN>,
                                                   user_list: vector<address>,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext) {
        project::remove_whitelist<COIN, TOKEN>(_adminCap, project, user_list, version, ctx);
    }

    public entry fun start_fund_raising<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        clock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::start_fund_raising<COIN, TOKEN>(_adminCap, project, clock, version, ctx);
    }

    public fun push_orders<COIN, TOKEN>(adminCap: &AdminCap,
                                        buyers: vector<address>,
                                        amounts: vector<u64>,
                                        project: &mut Project<COIN, TOKEN>,
                                        sclock: &Clock,
                                        kyc: &Kyc,
                                        version: &mut Version) {
        project::push_orders(adminCap, buyers, amounts, project, sclock, kyc, version);
    }

    public entry fun end_fund_raising<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        clock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::end_fund_raising<COIN, TOKEN>(_adminCap, project, clock, version, ctx);
    }

    public entry fun distribute_raised_fund<COIN, TOKEN>(
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::distribute_raised_fund<COIN, TOKEN>(project, version, ctx);
    }

    public entry fun refund_token_to_owner<COIN, TOKEN>(
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::refund_token_to_owner<COIN, TOKEN>(project, version, ctx);
    }

    public entry fun deposit_token<COIN, TOKEN>(
        token: Coin<TOKEN>,
        value: u64,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        let tokens = vector::empty<Coin<TOKEN>>();
        vector::push_back(&mut tokens, token);
        project::deposit_token<COIN, TOKEN>(tokens, value, project, version, ctx);
    }

    public entry fun claim_token<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                              clock: &Clock,
                                              version: &mut Version,
                                              ctx: &mut TxContext) {
        project::claim_token<COIN, TOKEN>(project, clock, version, ctx);
    }

    // public entry fun claim_refund<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
    //                                            version: &mut Version,
    //                                            ctx: &mut TxContext) {
    //     project::claim_refund<COIN, TOKEN>(project, version, ctx);
    // }

    public entry fun set_state_refund<COIN, TOKEN>(
        admin_cap: &AdminCap,
        version: &mut Version,
        project: &mut Project<COIN, TOKEN>
    ) {
        project::set_state_refund<COIN, TOKEN>(admin_cap, version, project);
    }
}
