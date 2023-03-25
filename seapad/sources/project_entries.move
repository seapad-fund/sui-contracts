module seapad::project_entries {
    use seapad::project::{AdminCap, Project};
    use sui::tx_context::TxContext;
    use sui::coin::{CoinMetadata, Coin};
    use seapad::project;
    use sui::sui::SUI;

    public entry fun change_admin(adminCap: AdminCap, to: address) {
        project::change_admin(adminCap, to);
    }

    public entry fun create_project<COIN>(_adminCap: &AdminCap,
                                          owner: address,
                                          vesting_type: u8,
                                          coin_metadata: &CoinMetadata<COIN>,
                                          ctx: &mut TxContext) {
        project::create_project(_adminCap, owner, vesting_type, coin_metadata, ctx);
    }

    public entry fun change_owner<COIN>(admin_cap: &AdminCap, new_owner: address, project: &mut Project<COIN>){
        project::change_owner<COIN>(admin_cap, new_owner, project);
    }

    public entry fun add_milestone<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         time: u64,
                                         percent: u64,
                                         ctx: &mut TxContext){
        project::add_milestone<COIN>(_adminCap, project, time, percent, ctx);
    }

    public entry fun reset_milestone<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, _ctx: &mut TxContext) {
        project::reset_milestone<COIN>(_adminCap, project, _ctx);
    }


    public entry fun setup_project<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         round: u8,
                                         usewhitelist: bool,
                                         swap_ratio_sui: u64,
                                         swap_ratio_token: u64,
                                         max_allocate: u64,
                                         start_time: u64,
                                         end_time: u64,
                                         soft_cap: u64,
                                         hard_cap: u64,
                                         _ctx: &mut TxContext) {
        project::setup_project<COIN>(_adminCap, project, round, usewhitelist, swap_ratio_sui, swap_ratio_token, max_allocate, start_time, end_time, soft_cap, hard_cap, _ctx);

    }

    public entry fun add_max_allocate<COIN>(admin_cap: &AdminCap,
                                            user: address,
                                            max_allocate: u64,
                                            project: &mut Project<COIN>,
                                            ctx: &mut TxContext) {
        project::set_max_allocate<COIN>(admin_cap, user, max_allocate, project, ctx);
    }

    public entry fun remove_max_allocate<COIN>(_admin_cap: &AdminCap,
                                               user: address,
                                               project: &mut Project<COIN>,
                                               _ctx: &mut TxContext) {
        project::clear_max_allocate<COIN>(_admin_cap, user, project, _ctx);
    }

    public entry fun save_profile<COIN>(_adminCap: &AdminCap,
                                        project: &mut Project<COIN>,
                                        name: vector<u8>,
                                        twitter: vector<u8>,
                                        discord: vector<u8>,
                                        telegram: vector<u8>,
                                        website: vector<u8>,
                                        _ctx: &mut TxContext) {
        project::save_profile<COIN>(_adminCap, project, name, twitter, discord, telegram, website, _ctx);
    }

    public entry fun add_whitelist<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         user_list: vector<address>,
                                         _ctx: &mut TxContext) {
        project::add_whitelist<COIN>(_adminCap, project, user_list, _ctx);
    }

    public entry fun remove_whitelist<COIN>(_adminCap: &AdminCap,
                                            project: &mut Project<COIN>,
                                            user_list: vector<address>,
                                            _ctx: &mut TxContext) {
        project::remove_whitelist<COIN>(_adminCap, project, user_list, _ctx);
    }

    public entry fun start_fund_raising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::start_fund_raising<COIN>(_adminCap, project, ctx);

    }

    public entry fun buy<COIN>(suis: vector<Coin<SUI>>, amount: u64, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::buy<COIN>(suis, amount, project, ctx);
    }

    public entry fun end_fund_raising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::end_fund_raising<COIN>(_adminCap, project, ctx);
    }

    public entry fun end_refund<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::end_refund<COIN>(_adminCap, project, ctx);
    }

    public entry fun distribute_raised_fund<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::distribute_raised_fund<COIN>(_adminCap, project, ctx);
    }

    public entry fun refund_token_to_owner<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::refund_token_to_owner<COIN>(_adminCap, project, ctx);
    }

    public entry fun deposit_by_owner<COIN>(coins: vector<Coin<COIN>>, value: u64, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::deposit_by_owner<COIN>(coins, value, project, ctx);
    }

    public entry fun claim_token<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::claim_token<COIN>(project, ctx);
    }

    public entry fun claim_refund<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        project::claim_refund<COIN>(project, ctx);
    }

    public entry fun vote<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext) {
        project::vote<COIN>(project, ctx);
    }
}
