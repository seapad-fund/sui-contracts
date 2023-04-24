module seapad::nftbox_scripts {

    use seapad::nftbox::{NftAdminCap, NftPool};
    use seapad::nftbox;
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::coin::Coin;

    public entry fun change_admin(adminCap: NftAdminCap, to: address) {
        nftbox::change_admin(adminCap, to);
    }


    public entry fun create_pool<COIN>(adminCap: &NftAdminCap,
                                 owner: address,
                                 soft_cap: u64,
                                 hard_cap: u64,
                                 round: u8,
                                 use_whitelist: bool,
                                 vesting_time: u64,
                                 allocate: u64,
                                 start_time: u64,
                                 end_time: u64,
                                 system_clock: &Clock,
                                 ctx: &mut TxContext){
        nftbox::create_pool<COIN>(adminCap, owner, soft_cap, hard_cap, round, use_whitelist, vesting_time,
            allocate, start_time, end_time, system_clock, ctx);
    }

    public entry fun add_template<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>,
                                  name: vector<u8>, description: vector<u8>, url: vector<u8>,
                                  price: u64, type: u8){
        nftbox::add_template<COIN>(_adminCap, pool, name, description, url, price, type);
    }

    public entry fun start_pool<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        nftbox::start_pool<COIN>(_adminCap, pool, system_clock);
    }

    public entry fun buy_nft<COIN>(coinin: &mut Coin<COIN>, nft_amounts: vector<u64>, nft_types:  vector<u8>,
                             pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext){
        nftbox::buy_nft<COIN>(coinin, nft_amounts, nft_types, pool, system_clock, ctx);
    }

    public entry fun stop_pool<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        nftbox::start_pool<COIN>(_adminCap, pool, system_clock);
    }

    public entry fun claim_nft<COIN>(pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext) {
        nftbox::claim_nft<COIN>(pool, system_clock, ctx);
    }

    public entry fun claim_refund<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext){
        nftbox::claim_refund<COIN>(_adminCap, pool, system_clock, ctx);
    }

    public entry fun add_whitelist<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, white: address){
        nftbox::add_whitelist(_adminCap, pool, white);
    }

    public entry fun withdraw_fund<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, ctx: &mut TxContext){
        nftbox::withdraw_fund(_adminCap, pool, ctx);
    }
}
