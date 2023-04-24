module seapad::nftbox {
    ///@todo review math actions
    use sui::object::{UID, id_address};
    use sui::coin::Coin;
    use seapad::nft_private::{PriNFT, mint_batch};
    use sui::table::Table;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use sui::table;
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use seapad::nft_private;
    use std::vector;
    use sui::event::emit;
    use sui::transfer::{public_transfer};

    struct NFTBOX has drop {}

    struct NftAdminCap has key, store {
        id: UID
    }


    const ROUND_SEED: u8 = 1;
    const ROUND_PRIVATE: u8 = 2;
    const ROUND_PUBLIC: u8 = 3;

    const ROUND_STATE_INIT: u8 = 1;
    const ROUND_STATE_RASING: u8 = 2;
    const ROUND_STATE_REFUND: u8 = 3;
    const ROUND_STATE_SECURE: u8 = 4;
    const ROUND_STATE_CLAIM: u8 = 5;
    const ROUND_STATE_DONE: u8 = 6;

    struct NftOrder has store {
        secured_coin: u64,
        secured_nfts: vector<PriNFT>,
    }

    struct NftPoolStartedEvent has copy, drop {
        id: address,
        start_time: u64
    }

    struct NftPoolBuyEvent has copy, drop {
        buyer: address,
        nft_amount: u64,
        cost: u64,
        timestamp: u64,
    }

    struct NftPoolCreatedEvent has copy, drop {
        id: address,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        state: u8,
        use_whitelist: bool,
        vesting_time_seconds: u64,
        allocate: u64,
        owner: address,
        start_time: u64,
        end_time: u64,
    }

    struct NftPoolStopEvent has copy, drop {
        id: address,
        total_sold: u64,
        total_sold_nft: u64,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        state: u8,
        use_whitelist: bool,
        vesting_time: u64,
        allocate: u64,
        owner: address,
        start_time: u64,
        end_time: u64,
    }

    struct NftPoolClaimedEvent has copy, drop {
        buyer: address,
        secured_nfts: u64,
        timestamp: u64
    }

    struct NftPoolRefundEvent has copy, drop {
        buyer: address,
        secured_nfts: u64,
        refund_coin: u64,
        timestamp: u64
    }

    struct NftTemplate has store, copy {
        type: u8,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        price: u64
    }

    ///NFT pool, owned by project owner, listed by admin
    struct NftPool<phantom COIN> has key, store {
        id: UID,
        owner: address,
        templates: Table<u8, NftTemplate>,
        soft_cap: u64, //in coin
        hard_cap: u64, //in coin
        round: u8,
        state: u8,
        use_whitelist: bool,
        vesting_time_seconds: u64, //when to vesting all nft
        allocate: u64, // in coin per user
        fund: Coin<COIN>,
        start_time: u64,
        end_time: u64,
        participants: u64,
        total_sold_coin: u64,
        total_sold_nft: u64,
        orders: Table<address, NftOrder> //if whitelist enabled: add whitelist address to this first!
    }


    /// System scope
    fun init(_witness: NFTBOX, ctx: &mut TxContext) {
        let adminCap = NftAdminCap { id: object::new(ctx) };
        public_transfer(adminCap, sender(ctx));
    }

    public fun change_admin(adminCap: NftAdminCap, to: address) {
        public_transfer(adminCap, to);
    }

    const ERR_INVALID_CAP: u64 = 6000;
    const ERR_INVALID_ROUND: u64 = 6001;
    const ERR_INVALID_VESTING_TIME: u64 = 6002;
    const ERR_INVALID_PRICE: u64 = 6003;
    const ERR_INVALID_ALLOCATE: u64 = 6005;
    const ERR_INVALID_DECIMALS: u64 = 6006;
    const ERR_INVALID_START_STOP_TIME: u64 = 6007;
    const ERR_INVALID_STATE: u64 = 6008;

    const ERR_INVALID_NFT_AMT: u64 = 6009;
    const ERR_NOT_ENOUGHT_FUND: u64 = 6010;
    const ERR_NOT_FUNDRAISING: u64 = 6011;
    const ERR_REACH_HARDCAP: u64 = 6012;
    const ERR_MISSING_ORDERS: u64 = 6013;
    const ERR_MISSING_NFT_TEMPLATE: u64 = 6014;
    const ERR_INVALID_TEMPLATE_TYPE: u64 = 6015;
    const ERR_NOT_IN_WHITELIST: u64 = 6015;
    const ERR_NOT_FOUND_NFT: u64 = 6015;
    const ERR_BAD_NFT_INFO: u64 = 6015;
    const ERR_WHITELIST_NOT_SUPPORTED: u64 = 6015;
    const ERR_WHITELIST: u64 = 6015;


    /// NFT scope

    /// add pool
    public fun create_pool<COIN>(_adminCap: &NftAdminCap,
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
                                 ctx: &mut TxContext) {

        //@todo review validate
        assert!(soft_cap >0 && hard_cap > 0 && hard_cap > soft_cap, ERR_INVALID_CAP);
        assert!(round >= ROUND_SEED && round <= ROUND_PUBLIC, ERR_INVALID_ROUND);
        assert!(vesting_time > clock::timestamp_ms(system_clock), ERR_INVALID_VESTING_TIME); //should we have a min period, ex: 3 days ?
        assert!(allocate > 0 && allocate < hard_cap, ERR_INVALID_ALLOCATE);

        assert!(start_time > clock::timestamp_ms(system_clock)
                && end_time > clock::timestamp_ms(system_clock)
                && end_time > start_time, ERR_INVALID_START_STOP_TIME); //should we have a min period, ex: 3 days ?

        let pool = NftPool<COIN>{
            id: object::new(ctx),
            templates: table::new<u8, NftTemplate>(ctx),
            soft_cap,
            hard_cap,
            round,
            state: ROUND_STATE_INIT,
            use_whitelist,
            vesting_time_seconds: vesting_time,
            allocate,
            owner,
            fund: coin::zero<COIN>(ctx),
            start_time,
            end_time,
            participants: 0,
            total_sold_coin: 0,
            total_sold_nft: 0,
            orders: table::new<address, NftOrder>(ctx)
        };

        //fire event
        emit(  NftPoolCreatedEvent {
            id:  id_address(&pool),
            soft_cap: pool.soft_cap,
            hard_cap: pool.hard_cap,
            round: pool.round,
            state: pool.state,
            use_whitelist: pool.use_whitelist,
            vesting_time_seconds: pool.vesting_time_seconds,
            allocate: pool.allocate,
            owner: pool.owner,
            start_time: pool.start_time,
            end_time: pool.end_time,
        });

        //share
        transfer::share_object(pool);
    }


    public fun add_template<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>,
                                  name: vector<u8>, description: vector<u8>, url: vector<u8>,
                                  price: u64, type: u8){
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);
        //@todo assert name, desc, url ?
        assert!(vector::length<u8>(&name) > 0 && vector::length<u8>(&description) > 0 && vector::length<u8>(&url) > 0, ERR_INVALID_STATE);
        assert!(price > 0, ERR_INVALID_PRICE);
        assert!(type > 0, ERR_INVALID_TEMPLATE_TYPE);

        let template = NftTemplate {
            type,
            name,
            description,
            url,
            price
        };

        table::add(&mut pool.templates, type, template);
    }


    public fun start_pool<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);
        assert!(table::length<u8, NftTemplate>(&pool.templates) > 0, ERR_MISSING_NFT_TEMPLATE);

        pool.state = ROUND_STATE_RASING;
        pool.start_time = clock::timestamp_ms(system_clock);

        emit(NftPoolStartedEvent {
                id:  id_address(pool),
                start_time: pool.start_time
            });
    }

    public fun buy_nft<COIN>(coinin: &mut Coin<COIN>, nft_amounts: vector<u64>, nft_types:  vector<u8>,
                             pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext){
        //check state
        assert!(pool.state == ROUND_STATE_RASING, ERR_NOT_FUNDRAISING);
        assert!(pool.hard_cap <= pool.total_sold_coin, ERR_REACH_HARDCAP);

        //check whitelist
        let buyer = sender(ctx);
        assert!(!pool.use_whitelist || table::contains(&pool.orders, buyer), ERR_NOT_IN_WHITELIST);

        //check nft info
        assert!(vector::length<u64>(&nft_amounts) == vector::length<u8>(&nft_types), ERR_BAD_NFT_INFO);

        let size = vector::length<u8>(&nft_types);
        let cost =( 0 as u64);
        let totalNft = (0 as u64);
        while (size > 0){
            size = size - 1;
            let nft_amount = *vector::borrow(&nft_amounts, size);
            assert!(nft_amount > 0, ERR_BAD_NFT_INFO);
            let type = *vector::borrow(&nft_types, size);
            assert!(type > 0 && table::contains(&pool.templates, type), ERR_BAD_NFT_INFO);
            cost = cost + nft_amount * table::borrow(&pool.templates, type).price; //@todo check overflow
            totalNft = totalNft + nft_amount;
        };

        assert!(cost < pool.allocate && cost <= coin::value(coinin), ERR_NOT_ENOUGHT_FUND);

        //start buy
        let buyer = sender(ctx);

        if(!table::contains(&pool.orders, buyer)){
            pool.participants =  pool.participants + 1; //@todo count unique address
        };
        pool.total_sold_coin = pool.total_sold_coin + cost;
        pool.total_sold_nft = pool.total_sold_nft + totalNft;

        //take coin
        coin::join(&mut pool.fund, coin::split(coinin, (cost as u64), ctx));

        let nfts = vector::empty<PriNFT>();
        let size = vector::length(&nft_types);
        while (size > 0){
            size = size -1;
            let type = vector::borrow(&nft_types, size);
            let amt = vector::borrow(&nft_amounts, size);
            let templ = table::borrow(&pool.templates, *type);
            vector::append(&mut nfts, mint_batch(*amt, templ.name, templ.description, templ.description, ctx));
        };


        let order = NftOrder {
            secured_coin: (cost as u64),
            secured_nfts: nfts
        };

        table::add(&mut pool.orders, buyer, order);

        emit(NftPoolBuyEvent {
            buyer,
            nft_amount: totalNft,
            cost: (cost as u64),
            timestamp: clock::timestamp_ms(system_clock),
        })
    }

    public fun stop_pool<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        assert!(pool.state == ROUND_STATE_RASING, ERR_INVALID_STATE);

        pool.end_time = clock::timestamp_ms(system_clock);

        if(pool.total_sold_coin < pool.soft_cap){
            //just set refund & wait for user to claim
            pool.state = ROUND_STATE_REFUND;
        }
        else {
            //set state & wait for use to claim/vesting
            pool.state = ROUND_STATE_CLAIM;
        };

        emit(NftPoolStopEvent {
            id:  id_address(pool),
            total_sold: pool.total_sold_coin,
            total_sold_nft: pool.total_sold_nft,

            soft_cap: pool.soft_cap,
            hard_cap: pool.hard_cap,

            round: pool.round,
            state: pool.state,
            use_whitelist: pool.use_whitelist,
            vesting_time: pool.vesting_time_seconds,
            allocate: pool.allocate,
            owner: pool.owner,
            start_time: pool.start_time,
            end_time: pool.end_time
        });
    }

    public fun claim_nft<COIN>(pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext) {
        assert!(pool.state == ROUND_STATE_CLAIM, ERR_INVALID_STATE);
        assert!(clock::timestamp_ms(system_clock) - pool.end_time >= pool.end_time, ERR_INVALID_VESTING_TIME);
        let buyer = sender(ctx);

        assert!(table::contains(&mut pool.orders, buyer)
                && vector::length<PriNFT>(&table::borrow(&mut pool.orders, buyer).secured_nfts) > 0,
                ERR_MISSING_ORDERS);

        let NftOrder {
            secured_coin: _secured_coin,
            secured_nfts,
        } = table::remove(&mut pool.orders, buyer);

        let size = vector::length(&mut secured_nfts);
        let index = 0 ;
        while (index < size){
            public_transfer(vector::pop_back(&mut secured_nfts), buyer);
        };

        vector::destroy_empty(secured_nfts);

        emit(NftPoolClaimedEvent {
            buyer,
            secured_nfts: size,
            timestamp: clock::timestamp_ms(system_clock)
        });
    }

    public fun claim_refund<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext){
        assert!(pool.state == ROUND_STATE_REFUND, ERR_INVALID_STATE);

        let buyer = sender(ctx);

        assert!(table::contains(&mut pool.orders, buyer)
                && vector::length<PriNFT>(&table::borrow(&mut pool.orders, buyer).secured_nfts) > 0,
            ERR_MISSING_ORDERS);

        let NftOrder {
            secured_coin,
            secured_nfts,
        } = table::remove(&mut pool.orders, buyer);

        //burn nft
        let index = 0 ;
        let size = vector::length(&mut secured_nfts);
        while (index < size){
            nft_private::burn(vector::pop_back(&mut secured_nfts));
        };
        vector::destroy_empty(secured_nfts);

        //refund coin
        public_transfer(coin::split(&mut pool.fund, secured_coin, ctx), buyer);

        emit(NftPoolRefundEvent {
            buyer,
            secured_nfts: size,
            refund_coin: secured_coin,
            timestamp: clock::timestamp_ms(system_clock)
        });
    }

    public fun add_whitelist<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, white: address){
        assert!(pool.use_whitelist && pool.state == ROUND_STATE_INIT, ERR_WHITELIST);
        if(!table::contains(&pool.orders, white))
            table::add(&mut pool.orders, white, NftOrder{
                secured_coin: 0,
                secured_nfts: vector::empty<PriNFT>(),
            });
    }

    /// @todo implement charging fee
    /// !CRITICAL
    public fun withdraw_fund<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, _ctx: &mut TxContext){
        assert!(pool.state == ROUND_STATE_CLAIM, ERR_INVALID_STATE);
        let val = coin::value(&pool.fund);
        let coin = coin::split(&mut pool.fund, val, _ctx);
        public_transfer(coin, pool.owner);
    }
}
