module common::tier {
    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use sui::coin::Coin;
    use sui::transfer::{share_object, public_transfer};
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use sui::math;
    use sui::event;
    use sui::table::Table;
    use sui::table_vec::TableVec;
    use sui::table;
    use sui::table_vec;

    struct TIER has drop {}

    const ErrInvalidToken: u64 = 1001;
    const ErrInvalidParams: u64 = 1002;

    struct TAdminCap has key, store {
        id: UID
    }

    struct StakePosititon has store{
        value: u64, //token value
        timestamp: u64, //deposit time
        expire: u64, //expire time
    }

    struct Pool<phantom TOKEN> has key, store {
        id: UID,
        fund: Coin<TOKEN>,
        minLock: u64,
        lockPeriodMs: u64,
        funds: Table<address, TableVec<StakePosititon>>
    }

    struct LockEvent has drop, copy {
        sender: address,
        value: u64,
        timestamp: u64, //deposit time
        expire: u64, //expire time
    }

    struct UnlockEvent has drop, copy {
        sender: address,
        value: u64,
        timestamp: u64
    }

    fun init(_witness: TIER, ctx: &mut TxContext) {
        let adminCap = TAdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, sender(ctx));
    }

    public entry fun createPool<TOKEN>(_admin: &TAdminCap, minLock: u64, lockPeriodMs: u64, ctx: &mut TxContext){
        assert!(minLock > 0 && lockPeriodMs > 0, ErrInvalidParams);
        share_object(Pool<TOKEN<>>{
            id: object::new(ctx),
            fund: coin::zero(ctx),
            minLock,
            lockPeriodMs,
            funds: table::new(ctx)
        });
    }

    public entry fun lock<TOKEN>(
        deal: Coin<TOKEN>, pool: &mut Pool<TOKEN>, lockPeriodMs: u64, sclock: &Clock, ctx: &mut TxContext){
        let value = coin::value(&deal);

        assert!(value > 0 && pool.lockPeriodMs <= lockPeriodMs, ErrInvalidParams);

        coin::join(&mut pool.fund, deal);

        let timestamp = clock::timestamp_ms(sclock);
        let expire = timestamp + math::max(lockPeriodMs, pool.lockPeriodMs);
        let sender = sender(ctx);

        if(!table::contains(&pool.funds, sender)) {
                table::add(&mut pool.funds, sender,  table_vec::empty(ctx))
        };

        let ufunds = table::borrow_mut(&mut pool.funds, sender);
        table_vec::push_back(ufunds, StakePosititon {
            value,
            timestamp,
            expire: timestamp + math::max(lockPeriodMs, pool.lockPeriodMs),
        });

        event::emit(LockEvent {
            sender,
            value,
            timestamp,
            expire
        })
    }

    ///Future:
    /// - with yield info, every time user unlock, real yield will be estimated & fund to owner
    public entry fun unlock<TOKEN>(pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        let timestamp = clock::timestamp_ms(sclock);
        let sender = sender(ctx);
        assert!(table::contains(&mut pool.funds, sender), ErrInvalidParams);

        let ufunds = table::remove(&mut pool.funds, sender);
        let newUFunds = table_vec::empty(ctx);
        let value = 0;

        //collect
        while (!table_vec::is_empty(&ufunds)){
            let deal = table_vec::pop_back(&mut ufunds);
            if(timestamp <= deal.timestamp){
                value = value + deal.value;
                destroy(deal);
            }
            else {
                table_vec::push_back(&mut newUFunds, deal);
            }
        };

        //update
        table_vec::destroy_empty(ufunds);
        if(table_vec::length(&newUFunds) > 0 ){
            table::add (&mut pool.funds, sender, newUFunds);
        }
        else {
            table_vec::destroy_empty(newUFunds);
        };

        //fund back
        public_transfer(coin::split(&mut pool.fund, value, ctx), sender);

        //event
        event::emit(UnlockEvent {
            sender,
            value,
            timestamp
        })
    }


    fun destroy(sp: StakePosititon){
        let StakePosititon {
            value: _value,
            timestamp: _timestamp,
            expire: _expire,
        } = sp;
    }
}
