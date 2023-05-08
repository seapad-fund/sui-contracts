module seapad::tokenomic_entries {

    use seapad::tokenomic::{TAdminCap, TokenomicPie};
    use seapad::version::Version;
    use sui::clock::Clock;
    use sui::tx_context::TxContext;
    use sui::coin::Coin;
    use seapad::tokenomic;

    public entry fun change_admin(admin: TAdminCap,
                                  to: address,
                                  version: &mut Version) {
        tokenomic::change_admin(admin, to, version);
    }

    public entry fun init_tokenomic<COIN>(adminCap: &TAdminCap,
                                          total_supply: u64,
                                          tge_ms: u64,
                                          sclock: &Clock,
                                          version: &mut Version,
                                          ctx: &mut TxContext){
        tokenomic::init_tokenomic<COIN>(adminCap, total_supply, tge_ms, sclock, version, ctx);
    }

    public entry fun addFund<COIN>(adminCap: &TAdminCap,
                                   pie: &mut TokenomicPie<COIN>,
                                   owner: address,
                                   name: vector<u8>,
                                   vesting_type: u8,
                                   tge_ms: u64, //timestamp
                                   cliff_ms: u64, //duration
                                   fund: Coin<COIN>,
                                   unlock_percent: u64,
                                   linear_vesting_duration_ms: u64, //duration
                                   sclock: &Clock,
                                   version: &mut Version,
                                   milestone_times: vector<u64>, //if milestone mode, timestamps
                                   milestone_percents: vector<u64>, //if milestone mode
                                   ctx: &mut TxContext
    ){
        tokenomic::addFund<COIN>(adminCap, pie, owner, name, vesting_type, tge_ms,
                        cliff_ms, fund, unlock_percent, linear_vesting_duration_ms,
                        sclock, version, milestone_times, milestone_percents, ctx);
    }

    public entry fun claim<COIN>(pie: &mut TokenomicPie<COIN>,
                                 sclock: &Clock,
                                 version: &mut Version,
                                 ctx: &mut TxContext){
        tokenomic::claim<COIN>(pie, sclock, version, ctx);
    }

    public entry fun change_fund_owner<COIN>(pie: &mut TokenomicPie<COIN>,
                                             to: address,
                                             version: &mut Version,
                                             ctx: &mut TxContext){
        tokenomic::change_fund_owner(pie, to, version, ctx);
    }
}
