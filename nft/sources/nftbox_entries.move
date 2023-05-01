module seapad::nftbox_entries {

    use seapad::nftbox::{NftAdminCap, NftPool, NftTreasuryCap};
    use seapad::nftbox;
    use sui::tx_context::TxContext;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use common::kyc::Kyc;

    public entry fun create_pool<COIN>(_adminCap: &NftAdminCap,
                                       owner: address,
                                       soft_cap_percent: u64,
                                       round: u8,
                                       use_whitelist: bool,
                                       vesting_time_seconds: u64,
                                       start_time: u64,
                                       end_time: u64,
                                       system_clock: &Clock,
                                       require_kyc: bool,
                                       ctx: &mut TxContext) {
        nftbox::create_pool<COIN>(_adminCap,
            owner,
            soft_cap_percent,
            round,
            use_whitelist,
            vesting_time_seconds,
            start_time,
            end_time,
            system_clock,
            require_kyc,
            ctx);
    }

    public entry fun add_collection<COIN>(_adminCap: &NftAdminCap,
                                          pool: &mut NftPool<COIN>,
                                          cap: u64, //max of NFT to sale
                                          allocate: u64, //max allocate per user
                                          price: u64, //price with coin
                                          type: u8, //collection type
                                          name: vector<u8>,
                                          link: vector<u8>,
                                          image_url: vector<u8>,
                                          description: vector<u8>,
                                          project_url: vector<u8>,
                                          edition: u64,
                                          thumbnail_url: vector<u8>,
                                          creator: vector<u8>,
                                          _ctx: &mut TxContext
    ) {
        nftbox::add_collection<COIN>(_adminCap, pool, cap, allocate, price, type,
            name, link, image_url, description
            , project_url, edition, thumbnail_url, creator, _ctx);
    }

    public entry fun start_pool<COIN>(adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        nftbox::start_pool<COIN>(adminCap, pool, system_clock);
    }

    public entry fun buy_nft<COIN>(coin_in: &mut Coin<COIN>,
                                   nft_types: vector<u8>,
                                   nft_amounts: vector<u64>,
                                   pool: &mut NftPool<COIN>,
                                   system_clock: &Clock,
                                   kyc: &Kyc,
                                   ctx: &mut TxContext) {
        nftbox::buy_nft<COIN>(coin_in, nft_types, nft_amounts, pool, system_clock, kyc, ctx);
    }

    public entry fun stop_pool<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        nftbox::start_pool<COIN>(_adminCap, pool, system_clock);
    }

    public entry fun claim_nft<COIN>(pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext) {
        nftbox::claim_nft<COIN>(pool, system_clock, ctx);
    }

    public entry fun claim_refund<COIN>(pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext) {
        nftbox::claim_refund<COIN>(pool, system_clock, ctx);
    }

    public entry fun add_whitelist<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, tos: vector<address>) {
        nftbox::add_whitelist(_adminCap, pool, tos);
    }

    public entry fun remove_whitelist<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, froms: vector<address>) {
        nftbox::remove_whitelist(_adminCap, pool, froms);
    }

    public entry fun withdraw_fund<COIN>(
        _adminCap: &NftTreasuryCap,
        pool: &mut NftPool<COIN>,
        amt: u64,
        ctx: &mut TxContext
    ) {
        nftbox::withdraw_fund(_adminCap, pool, amt, ctx);
    }

    public entry fun change_admin(adminCap: NftAdminCap, to: address) {
        nftbox::change_admin(adminCap, to);
    }

    public entry fun add_attribute<COIN>(_adminCap: &NftAdminCap,
                                         pool: &mut NftPool<COIN>,
                                         type: u8,
                                         key: vector<u8>,
                                         value: vector<u8>) {
        nftbox::add_attribute<COIN>(_adminCap, pool, type, key, value);
    }

    public entry fun remove_collection<COIN>(_admin_cap: &NftAdminCap, type: u8, pool: &mut NftPool<COIN>) {
        nftbox::remove_collection(_admin_cap, type, pool);
    }

    public entry fun change_treasury_admin(adminCap: NftTreasuryCap, to: address) {
        nftbox::change_treasury_admin(adminCap, to);
    }
}
