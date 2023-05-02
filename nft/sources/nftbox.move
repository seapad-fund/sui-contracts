module seapad::nftbox {
    use sui::object::{UID, id_address, uid_to_address};
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
    use w3libs::u256;
    use sui::vec_map::VecMap;
    use sui::vec_map;
    use common::kyc::{Kyc, hasKYC};

    struct NFTBOX has drop {}

    struct NftAdminCap has key, store {
        id: UID
    }

    struct NftTreasuryCap has key, store {
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
        secured_types: VecMap<u8, u64>
    }

    struct NftPoolStartedEvent has copy, drop {
        id: address,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        state: u8,
        use_whitelist: bool,
        vesting_time_ms: u64,
        owner: address,
        start_time: u64,
        end_time: u64,
    }

    struct NftPoolCreatedEvent has copy, drop {
        id: address,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        state: u8,
        use_whitelist: bool,
        vesting_time_ms: u64,
        owner: address,
        start_time: u64,
        end_time: u64,
    }

    struct NftPoolBuyEvent has copy, drop {
        pool: address,
        buyer: address,
        amount: u64,
        cost: u64,
        timestamp: u64,
        nft_types: vector<u8>,
        nft_amounts: vector<u64>,
        total_nft_bought: u64,
        total_cost: u64,
        participants: u64,
        total_raised: u64,
        sold_out: bool
    }

    struct NftPoolStopEvent has copy, drop {
        id: address,
        total_sold_coin: u64,
        total_sold_nft: u64,
        soft_cap_percent: u64,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        state: u8,
        use_whitelist: bool,
        vesting_time_ms: u64,
        owner: address,
        start_time: u64,
        end_time: u64,
    }

    struct NftPoolClaimedEvent has copy, drop {
        pool: address,
        buyer: address,
        secured_nfts: u64,
        secured_coin: u64,
        secured_types: VecMap<u8, u64>,
        timestamp_ms: u64,
    }

    struct NftPoolRefundEvent has copy, drop {
        pool: address,
        buyer: address,
        secured_nfts: u64,
        refund_coin: u64,
        timestamp_ms: u64
    }

    struct NftTemplate has store {
        cap: u64,
        //hardcap in NFT token
        sold: u64,
        //amount of NFT sold
        allocate: u64,
        //max allocation per user per template
        price: u64,
        //price in coin
        type: u8,
        //collection type
        name: vector<u8>,
        link: vector<u8>,
        image_url: vector<u8>,
        description: vector<u8>,
        project_url: vector<u8>,
        edition: u64,
        thumbnail_url: vector<u8>,
        creator: vector<u8>,
        attributes: VecMap<vector<u8>, vector<u8>> //use vecmap for collection for easy
    }

    ///NFT pool, owned by project owner, listed by admin
    struct NftPool<phantom COIN> has key, store {
        id: UID,
        owner: address,
        //project owner address
        templates: Table<u8, NftTemplate>,
        //all template listed to sell
        soft_cap_percent: u64,
        //in percent scaled to x100
        soft_cap: u64,
        //in coin
        hard_cap: u64,
        //in coin
        round: u8,
        //which round
        state: u8,
        //state
        use_whitelist: bool,
        // is whitelist mode enabled ?
        vesting_time_ms: u64,
        //timestamp: when to vesting all nft
        fund: Coin<COIN>,
        //raised fund
        start_time: u64,
        //estimated start time, updated when realy started
        end_time: u64,
        //estimated end time, updated when realy ended
        participants: u64,
        //unique user joined
        total_sold_coin: u64,
        //total sold in coin unit
        total_sold_nft: u64,
        //total sold in nft count
        orders: Table<address, NftOrder>,
        //Buy order tables, use dynamic fields. if whitelist enabled: add whitelist address to this first that init order to zero
        require_kyc: bool
    }

    struct NftRemoveCollection has copy, drop {
        pool: address,
        nft_type: u8
    }

    struct NftAddCollectionEvent has copy, drop {
        pool: address,
        soft_cap: u64,
        hard_cap: u64
    }

    /// System scope
    fun init(_witness: NFTBOX, ctx: &mut TxContext) {
        let sender = sender(ctx);
        assert!(sender == @nftbox_admin, ERR_INVALID_ADMIN);
        public_transfer(NftAdminCap { id: object::new(ctx) }, @nftbox_admin);
        public_transfer(NftTreasuryCap { id: object::new(ctx) }, @nftbox_treasury_admin);
    }

    public fun change_admin(adminCap: NftAdminCap, to: address) {
        public_transfer(adminCap, to);
    }

    public fun change_treasury_admin(adminCap: NftTreasuryCap, to: address) {
        public_transfer(adminCap, to);
    }

    const ERR_INVALID_CAP: u64 = 6000;
    const ERR_INVALID_ROUND: u64 = 6001;
    const ERR_INVALID_VESTING_TIME: u64 = 6002;
    const ERR_INVALID_PRICE: u64 = 6003;
    const ERR_INVALID_ALLOCATE: u64 = 6004;
    const ERR_INVALID_DECIMALS: u64 = 6005;
    const ERR_INVALID_START_STOP_TIME: u64 = 6006;
    const ERR_INVALID_STATE: u64 = 6007;

    const ERR_INVALID_NFT_AMT: u64 = 6009;
    const ERR_NOT_ENOUGHT_FUND: u64 = 6010;
    const ERR_NOT_FUNDRAISING: u64 = 6011;
    const ERR_REACH_HARDCAP: u64 = 6012;
    const ERR_MISSING_ORDERS: u64 = 6013;
    const ERR_MISSING_NFT_TEMPLATE: u64 = 6014;
    const ERR_INVALID_TEMPLATE_TYPE: u64 = 6015;
    const ERR_NOT_IN_WHITELIST: u64 = 6016;
    const ERR_NOT_FOUND_NFT: u64 = 6017;
    const ERR_BAD_NFT_INFO: u64 = 6018;
    const ERR_WHITELIST_NOT_SUPPORTED: u64 = 6019;
    const ERR_WHITELIST: u64 = 6020;
    const ERR_OUTOF_ALLOCATE: u64 = 6021;
    const ERR_INVALID_ADMIN: u64 = 6022;
    const ERR_NFT_CAP: u64 = 6023;
    const ERR_BAD_ATTRIBUTE: u64 = 6024;
    const ERR_NOT_KYC: u64 = 6025;


    ///! NFT scope

    /// add pool
    public fun create_pool<COIN>(_adminCap: &NftAdminCap,
                                 owner: address,
                                 soft_cap_percent: u64,
                                 round: u8,
                                 use_whitelist: bool,
                                 vesting_time_ms: u64,
                                 start_time: u64,
                                 end_time: u64,
                                 system_clock: &Clock,
                                 require_kyc: bool,
                                 ctx: &mut TxContext) {
        //@todo review validate
        assert!(soft_cap_percent > 0 && soft_cap_percent < 10000, ERR_INVALID_CAP);
        assert!(round >= ROUND_SEED && round <= ROUND_PUBLIC, ERR_INVALID_ROUND);
        let ts_now_ms = clock::timestamp_ms(system_clock);
        assert!(vesting_time_ms > ts_now_ms, ERR_INVALID_VESTING_TIME);
        assert!(start_time > ts_now_ms && end_time > start_time, ERR_INVALID_START_STOP_TIME);

        let pool = NftPool<COIN> {
            id: object::new(ctx),
            templates: table::new<u8, NftTemplate>(ctx),
            soft_cap_percent,
            soft_cap: 0, //not initialzed yet
            hard_cap: 0, //not initialzed yet
            round,
            state: ROUND_STATE_INIT,
            use_whitelist,
            vesting_time_ms,
            owner,
            fund: coin::zero<COIN>(ctx),
            start_time,
            end_time,
            participants: 0,
            total_sold_coin: 0,
            total_sold_nft: 0,
            orders: table::new<address, NftOrder>(ctx),
            require_kyc
        };

        emit(NftPoolCreatedEvent {
            id: id_address(&pool),
            soft_cap: pool.soft_cap,
            hard_cap: pool.hard_cap,
            round: pool.round,
            state: pool.state,
            use_whitelist: pool.use_whitelist,
            vesting_time_ms: pool.vesting_time_ms,
            owner: pool.owner,
            start_time: pool.start_time,
            end_time: pool.end_time,
        });

        //share
        transfer::share_object(pool);
    }

    public fun add_attribute<COIN>(_adminCap: &NftAdminCap,
                                   pool: &mut NftPool<COIN>,
                                   type: u8,
                                   key: vector<u8>,
                                   value: vector<u8>) {
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);
        assert!(vector::length<u8>(&key) > 0
            && vector::length<u8>(&value) > 0
            && table::contains<u8, NftTemplate>(&pool.templates, type), ERR_BAD_NFT_INFO);
        let collection = table::borrow_mut<u8, NftTemplate>(&mut pool.templates, type);
        assert!(!vec_map::contains<vector<u8>, vector<u8>>(&collection.attributes, &key), ERR_BAD_NFT_INFO);
        vec_map::insert<vector<u8>, vector<u8>>(&mut collection.attributes, key, value);
    }

    public fun remove_collection<COIN>(_admin_cap: &NftAdminCap, type: u8, pool: &mut NftPool<COIN>) {
        table::remove(&mut pool.templates, type);

        emit(NftRemoveCollection {
            pool: id_address(pool),
            nft_type: type
        })
    }

    public fun add_collection<COIN>(_adminCap: &NftAdminCap,
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
                                    _ctx: &mut TxContext) {
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);

        assert!((cap >= allocate && allocate > 0)
            && (price > 0)
            && (type > 0)
            && vector::length<u8>(&name) > 0
            && vector::length<u8>(&link) > 0
            && vector::length<u8>(&image_url) > 0
            && vector::length<u8>(&description) > 0
            && vector::length<u8>(&project_url) > 0
            && (edition > 0)
            && vector::length<u8>(&thumbnail_url) > 0
            && vector::length<u8>(&creator) > 0,
            ERR_BAD_NFT_INFO);

        table::add(&mut pool.templates, type, NftTemplate {
            cap,
            sold: 0,
            allocate,
            price,
            type,
            name,
            link,
            image_url,
            description,
            project_url,
            edition,
            thumbnail_url,
            creator,
            attributes: vec_map::empty<vector<u8>, vector<u8>>()
        });

        //update cap
        pool.hard_cap = u256::mul_add_u64(cap, price, pool.hard_cap);
        pool.soft_cap = u256::mul_u64(pool.hard_cap, pool.soft_cap_percent) / 10000;

        emit(NftAddCollectionEvent {
            pool: uid_to_address(&pool.id),
            soft_cap: pool.soft_cap,
            hard_cap: pool.hard_cap
        })
    }

    public fun start_pool<COIN>(_adminCap: &NftAdminCap,
                                pool: &mut NftPool<COIN>,
                                system_clock: &Clock) {
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);
        assert!(table::length<u8, NftTemplate>(&pool.templates) > 0, ERR_MISSING_NFT_TEMPLATE);

        pool.state = ROUND_STATE_RASING;
        pool.start_time = clock::timestamp_ms(system_clock);

        //fire event
        emit(NftPoolStartedEvent {
            id: id_address<NftPool<COIN>>(pool),
            soft_cap: pool.soft_cap,
            hard_cap: pool.hard_cap,
            round: pool.round,
            state: pool.state,
            use_whitelist: pool.use_whitelist,
            vesting_time_ms: pool.vesting_time_ms,
            owner: pool.owner,
            start_time: pool.start_time,
            end_time: pool.end_time,
        });
    }

    ///@todo review code
    ///Buy multiple nft items with count, with coin in should afford total cost
    public fun buy_nft<COIN>(coin_in: &mut Coin<COIN>,
                             nft_types: vector<u8>,
                             nft_amounts: vector<u64>,
                             pool: &mut NftPool<COIN>,
                             system_clock: &Clock,
                             kyc: &Kyc,
                             ctx: &mut TxContext) {
        //check pool state
        assert!(pool.state == ROUND_STATE_RASING, ERR_NOT_FUNDRAISING);

        //check whitelist
        let buyer = sender(ctx);
        if (pool.require_kyc) {
            assert!(hasKYC(buyer, kyc), ERR_NOT_KYC);
        };
        let hasOrder = table::contains(&pool.orders, buyer);
        assert!(!pool.use_whitelist || hasOrder, ERR_NOT_IN_WHITELIST);

        //check nft info
        assert!(
            vector::length<u64>(&nft_amounts) > 0 && (vector::length<u64>(&nft_amounts) == vector::length<u8>(
                &nft_types
            )),
            ERR_BAD_NFT_INFO
        );

        //combine check:
        //- type exist, unique types list
        //- check max allocate per type
        //- check hard cap per type
        let orderIndex = vector::length<u8>(&nft_types);
        let cost256 = u256::zero();
        let totalNftAmt = 0u64;
        let uniqTypes = vec_map::empty<u8, u64>();

        while (orderIndex > 0) {
            orderIndex = orderIndex - 1;

            let nftType = *vector::borrow(&nft_types, orderIndex);
            assert!(vec_map::contains(&uniqTypes, &nftType), ERR_BAD_NFT_INFO);
            let nftAmount = *vector::borrow(&nft_amounts, orderIndex);
            assert!(nftAmount > 0 && nftType > 0 && table::contains(&pool.templates, nftType), ERR_BAD_NFT_INFO);

            let collection = table::borrow_mut(&mut pool.templates, nftType);

            //check max allocate, support multi buy!
            let nftSecured = if (!table::contains(&pool.orders, buyer)) {
                0u64
            } else {
                let order = table::borrow(&pool.orders, buyer);
                if (!vec_map::contains<u8, u64>(&order.secured_types, &nftType)) {
                    0u64
                }
                else
                    *vec_map::get(&order.secured_types, &nftType)
            };

            assert!(u256::add_u64(nftSecured, nftAmount) <= collection.allocate, ERR_OUTOF_ALLOCATE);

            //check hardcap & save total sold
            assert!(u256::add_u64(collection.sold, nftAmount) <= collection.cap, ERR_REACH_HARDCAP);
            collection.sold = u256::add_u64(nftAmount, collection.sold);

            cost256 = u256::mul_add(u256::from_u64(nftAmount), u256::from_u64(collection.price), cost256);
            totalNftAmt = totalNftAmt + nftAmount;
        };

        //check enough input coin
        let cost64 = u256::as_u64(cost256);
        assert!(cost64 <= coin::value(coin_in), ERR_NOT_ENOUGHT_FUND);

        //count unique participants
        if (!hasOrder || table::borrow(&pool.orders, buyer).secured_coin > 0) {
            pool.participants = u256::increment_u64(pool.participants);
        };

        //sold amount
        pool.total_sold_coin = u256::add_u64(pool.total_sold_coin, cost64);
        pool.total_sold_nft = u256::add_u64(pool.total_sold_nft, totalNftAmt);

        //take coin
        coin::join(&mut pool.fund, coin::split(coin_in, cost64, ctx));

        //mint nfts
        let nfts = vector::empty<PriNFT>();
        let size = vector::length(&nft_types);

        let securedTypes = if (hasOrder) {
            &mut table::borrow_mut(&mut pool.orders, buyer).secured_types
        }
        else {
            &mut vec_map::empty<u8, u64>()
        };

        while (size > 0) {
            size = size - 1;
            let nftType = *vector::borrow(&nft_types, size);
            let nftAmt = *vector::borrow(&nft_amounts, size);
            let collection = table::borrow(&pool.templates, nftType);
            vector::append(&mut nfts, mint_nft_batch_int(nftAmt, collection, ctx));

            //update secured types
            let newTotalAmt = if (vec_map::contains<u8, u64>(securedTypes, &nftType)) {
                let (_k, oldAmt) = vec_map::remove<u8, u64>(securedTypes, &nftType);
                oldAmt + nftAmt
            }else {
                nftAmt
            };
            vec_map::insert<u8, u64>(securedTypes, nftType, newTotalAmt);
        };

        if (hasOrder) {
            let order = table::borrow_mut(&mut pool.orders, buyer);
            order.secured_coin = u256::add_u64(order.secured_coin, cost64);
            vector::append(&mut order.secured_nfts, nfts);
        } else {
            table::add(&mut pool.orders, buyer, NftOrder {
                secured_coin: cost64,
                secured_nfts: nfts,
                secured_types: *securedTypes
            });
        };
        let order = table::borrow(&pool.orders, buyer);
        let total_cost = order.secured_coin;
        let nfts = &order.secured_nfts;

        let total_raised = coin::value(&pool.fund);

        let sold_out = if (total_raised == pool.hard_cap) {
            pool.state = ROUND_STATE_CLAIM;
            true
        } else {
            false
        };

        emit(NftPoolBuyEvent {
            pool: uid_to_address(&pool.id),
            buyer,
            amount: totalNftAmt,
            cost: cost64,
            timestamp: clock::timestamp_ms(system_clock),
            nft_types,
            nft_amounts,
            total_nft_bought: vector::length(nfts),
            total_cost,
            participants: pool.participants,
            total_raised,
            sold_out
        })
    }

    fun mint_nft_batch_int(nftAmt: u64, collection: &NftTemplate, ctx: &mut TxContext): vector<PriNFT> {
        mint_batch(nftAmt, collection.name, collection.link, collection.image_url,
            collection.description, collection.project_url, collection.edition,
            collection.thumbnail_url, collection.creator, &collection.attributes, ctx)
    }

    public fun stop_pool<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, system_clock: &Clock) {
        assert!(pool.state == ROUND_STATE_RASING, ERR_INVALID_STATE);

        pool.end_time = clock::timestamp_ms(system_clock);

        if (pool.total_sold_coin < pool.soft_cap) {
            //just set refund & wait for user to claim
            pool.state = ROUND_STATE_REFUND;
        }
        else {
            //set state & wait for use to claim/vesting
            pool.state = ROUND_STATE_CLAIM;
        };

        emit(NftPoolStopEvent {
            id: id_address(pool),
            total_sold_coin: pool.total_sold_coin,
            total_sold_nft: pool.total_sold_nft,
            soft_cap_percent: pool.soft_cap_percent,
            soft_cap: pool.soft_cap,
            hard_cap: pool.hard_cap,
            round: pool.round,
            state: pool.state,
            use_whitelist: pool.use_whitelist,
            vesting_time_ms: pool.vesting_time_ms,
            owner: pool.owner,
            start_time: pool.start_time,
            end_time: pool.end_time
        });
    }

    public fun claim_nft<COIN>(pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext) {
        assert!(pool.state == ROUND_STATE_CLAIM, ERR_INVALID_STATE);
        let timestamp_now = clock::timestamp_ms(system_clock);
        assert!(timestamp_now >= pool.vesting_time_ms, ERR_INVALID_VESTING_TIME);

        let buyer = sender(ctx);

        assert!(table::contains(&mut pool.orders, buyer)
            && vector::length<PriNFT>(&table::borrow(&pool.orders, buyer).secured_nfts) > 0,
            ERR_MISSING_ORDERS);

        let NftOrder {
            secured_coin,
            secured_nfts,
            secured_types
        } = table::remove(&mut pool.orders, buyer);

        let size = vector::length(&mut secured_nfts);
        let index = 0 ;
        while (index < size) {
            public_transfer(vector::pop_back(&mut secured_nfts), buyer);
        };

        vector::destroy_empty(secured_nfts);

        emit(NftPoolClaimedEvent {
            pool: id_address(pool),
            buyer,
            secured_nfts: size,
            secured_coin,
            secured_types,
            timestamp_ms: timestamp_now
        });
    }

    public fun claim_refund<COIN>(pool: &mut NftPool<COIN>, system_clock: &Clock, ctx: &mut TxContext) {
        assert!(pool.state == ROUND_STATE_REFUND, ERR_INVALID_STATE);

        let buyer = sender(ctx);

        assert!(table::contains(&mut pool.orders, buyer)
            && vector::length<PriNFT>(&table::borrow(&mut pool.orders, buyer).secured_nfts) > 0,
            ERR_MISSING_ORDERS);

        let nftOrder = table::remove(&mut pool.orders, buyer);
        let secured_coin = nftOrder.secured_coin;
        let size = vector::length<PriNFT>(&nftOrder.secured_nfts);

        destroyNftOrder(nftOrder);

        //refund coin
        public_transfer(coin::split(&mut pool.fund, secured_coin, ctx), buyer);

        //event
        emit(NftPoolRefundEvent {
            pool: id_address(pool),
            buyer,
            secured_nfts: size,
            refund_coin: secured_coin,
            timestamp_ms: clock::timestamp_ms(system_clock)
        });
    }

    public fun add_whitelist<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, tos: vector<address>) {
        assert!(pool.use_whitelist, ERR_WHITELIST);
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);
        let size = vector::length<address>(&tos);
        while (size > 0) {
            size = size - 1;
            let to = vector::pop_back(&mut tos);
            if (!table::contains(&pool.orders, to))
                table::add(&mut pool.orders, to, NftOrder {
                    secured_coin: 0,
                    secured_nfts: vector::empty<PriNFT>(),
                    secured_types: vec_map::empty<u8, u64>()
                });
        }
    }

    public fun remove_whitelist<COIN>(_adminCap: &NftAdminCap, pool: &mut NftPool<COIN>, froms: vector<address>) {
        assert!(pool.use_whitelist, ERR_WHITELIST);
        assert!(pool.state == ROUND_STATE_INIT, ERR_INVALID_STATE);
        let size = vector::length<address>(&froms);
        while (size > 0) {
            size = size - 1;
            let from = vector::pop_back(&mut froms);
            if (table::contains(&pool.orders, from)) {
                destroyNftOrder(table::remove(&mut pool.orders, from));
            }
        }
    }

    /// @todo implement charging fee
    public fun withdraw_fund<COIN>(
        _adminCap: &NftTreasuryCap,
        pool: &mut NftPool<COIN>,
        amt: u64,
        _ctx: &mut TxContext
    ) {
        assert!(pool.state == ROUND_STATE_CLAIM, ERR_INVALID_STATE);
        let val = coin::value(&pool.fund);
        assert!(amt <= val, ERR_NOT_ENOUGHT_FUND);
        let coin = coin::split(&mut pool.fund, amt, _ctx);
        public_transfer(coin, pool.owner);
    }

    fun destroyNftOrder(order: NftOrder) {
        let NftOrder {
            secured_coin: _secured_coin,
            secured_nfts,
            secured_types
        } = order;

        let size = vector::length<PriNFT>(&secured_nfts);
        while (size > 0) {
            size = size - 1;
            nft_private::burn(vector::pop_back(&mut secured_nfts))
        };
        vector::destroy_empty(secured_nfts);

        let keys = vec_map::keys(&secured_types);
        let ksize = vector::length<u8>(&keys);
        while (ksize > 0) {
            vec_map::remove<u8, u64>(&mut secured_types, &vector::pop_back(&mut keys));
            ksize = ksize - 1;
        };
        vec_map::destroy_empty(secured_types);
    }
}
