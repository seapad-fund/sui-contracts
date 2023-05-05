module seapad::project_entries {
    use seapad::project::{AdminCap, Project};
    use sui::tx_context::TxContext;
    use sui::coin::{Coin};
    use seapad::project;
    use std::vector;
    use sui::clock::Clock;
    use common::kyc::Kyc;
    use seapad::version::Version;

    public entry fun change_admin(adminCap: AdminCap,
                                  to: address,
                                  version: &mut Version) {
        project::change_admin(adminCap, to, version);
    }

    public entry fun create_project<COIN, TOKEN>(adminCap: &AdminCap,
                                                 owner: address,
                                                 vesting_type: u8,
                                                 cliff_time: u64,
                                                 tge_ms: u64,
                                                 unlock_percent: u64,
                                                 linear_time_ms: u64,
                                                 coin_decimals: u8,
                                                 token_decimals: u8,
                                                 require_kyc: bool,
                                                 version: &mut Version,
                                                 clock: &Clock,
                                                 ctx: &mut TxContext) {
        project::create_project<COIN, TOKEN>(
            adminCap,
            owner,
            vesting_type,
            cliff_time,
            tge_ms,
            unlock_percent,
            linear_time_ms,
            coin_decimals,
            token_decimals,
            require_kyc,
            version,
            clock,
            ctx
        );
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
                                                   user: address,
                                                   max_allocate: u64,
                                                   project: &mut Project<COIN, TOKEN>,
                                                   version: &mut Version,
                                                   ctx: &mut TxContext) {
        project::set_max_allocate<COIN, TOKEN>(admin_cap, user, max_allocate, project, version, ctx);
    }

    public entry fun remove_max_allocate<COIN, TOKEN>(_admin_cap: &AdminCap,
                                                      user: address,
                                                      project: &mut Project<COIN, TOKEN>,
                                                      version: &mut Version,
                                                      ctx: &mut TxContext) {
        project::clear_max_allocate<COIN, TOKEN>(_admin_cap, user, project, version, ctx);
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

    public entry fun buy<COIN, TOKEN>(
        coin: Coin<COIN>,
        amount: u64,
        project: &mut Project<COIN, TOKEN>,
        clock: &Clock,
        kyc: &Kyc,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        let coins = vector::empty<Coin<COIN>>();
        vector::push_back(&mut coins, coin);
        project::buy<COIN, TOKEN>(coins, amount, project, clock, kyc, version, ctx);
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

    public entry fun end_refund<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::end_refund<COIN, TOKEN>(_adminCap, project, version, ctx);
    }

    public entry fun distribute_raised_fund<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::distribute_raised_fund<COIN, TOKEN>(_adminCap, project, version, ctx);
    }

    public entry fun distribute_raised_fund2<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        to: address,
        amount: u64,
        version: &mut Version,
        ctx: &mut TxContext
    ){
        project::distribute_raised_fund2<COIN, TOKEN>(_adminCap, project, to, amount, version, ctx);
    }

    public entry fun refund_token_to_owner<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        project::refund_token_to_owner<COIN, TOKEN>(_adminCap, project, version, ctx);
    }

    public entry fun deposit_by_owner<COIN, TOKEN>(
        token: Coin<TOKEN>,
        value: u64,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        let tokens = vector::empty<Coin<TOKEN>>();
        vector::push_back(&mut tokens, token);
        project::deposit_by_owner<COIN, TOKEN>(tokens, value, project, version, ctx);
    }

    public entry fun claim_token<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                              clock: &Clock,
                                              version: &mut Version,
                                              ctx: &mut TxContext) {
        project::claim_token<COIN, TOKEN>(project, clock, version, ctx);
    }

    public entry fun claim_refund<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                               version: &mut Version,
                                               ctx: &mut TxContext) {
        project::claim_refund<COIN, TOKEN>(project, version, ctx);
    }

    public entry fun vote<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                       version: &mut Version,
                                       ctx: &mut TxContext) {
        project::vote<COIN, TOKEN>(project, version, ctx);
    }
}
