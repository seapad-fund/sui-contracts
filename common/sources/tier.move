module common::tier {
    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use sui::coin::Coin;
    use sui::transfer::{share_object, public_transfer};
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use sui::event;
    use sui::table::Table;
    use sui::table;

    struct TIER has drop {}

    const ErrInvalidParams: u64 = 1001;
    const ErrMinLock: u64 = 1002;
    const ErrNotEmergency: u64 = 1003;
    const ErrEmergency: u64 = 1004;
    const ErrValuePosititon: u64 = 1005;


    struct TAdminCap has key, store {
        id: UID
    }

    struct StakePosititon has store{
        value: u64,
        timestamp: u64,
        expire: u64,
    }

    struct Pool<phantom TOKEN> has key, store {
        id: UID,
        emergency: bool,
        fund: Coin<TOKEN>,
        min_lock: u64,
        lock_period_ms: u64,
        funds: Table<address, StakePosititon>
    }

    struct LockEvent has drop, copy {
        pool_tier: address,
        sender: address,
        value: u64,
        timestamp: u64,
        expire: u64,
        lock_amount: u64
    }

    struct UnlockEvent has drop, copy {
        pool_tier: address,
        sender: address,
        value: u64,
        timestamp: u64,
        emergency: bool,
        lock_amount: u64
    }

    fun init(_witness: TIER, ctx: &mut TxContext) {
        let adminCap = TAdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, sender(ctx));
    }

    public entry fun change_admin(admin_cap: TAdminCap, to: address) {
        transfer::public_transfer(admin_cap, to);
    }

    public entry fun createPool<TOKEN>(_admin: &TAdminCap, minLock: u64, lockPeriodMs: u64, ctx: &mut TxContext){
        assert!(lockPeriodMs > 0, ErrInvalidParams);
        share_object(Pool<TOKEN<>>{
            id: object::new(ctx),
            emergency: false,
            fund: coin::zero(ctx),
            min_lock: minLock,
            lock_period_ms: lockPeriodMs,
            funds: table::new(ctx)
        });
    }

    public entry fun set_emergency<TOKEN>(_admin: &TAdminCap, pool: &mut Pool<TOKEN<>>, emergency: bool, _ctx: &mut TxContext){
        assert!(pool.emergency != emergency, ErrInvalidParams);
        pool.emergency = emergency;
    }

    public entry fun lock<TOKEN>(deal: Coin<TOKEN>, pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        assert!(!pool.emergency, ErrEmergency);
        let value = coin::value(&deal);
        let timestamp = clock::timestamp_ms(sclock);
        let expire = timestamp + pool.lock_period_ms;
        let sender = sender(ctx);
        assert!(value >= pool.min_lock, ErrMinLock);

        let lock_amount = value;
        if(!table::contains(&pool.funds, sender)) {
                table::add(&mut pool.funds, sender,  StakePosititon {
                    value,
                    timestamp,
                    expire
                })
        } else{
            let fund = table::borrow_mut(&mut pool.funds, sender);
            fund.value = fund.value + value;
            fund.timestamp = timestamp;
            fund.expire = expire;

            lock_amount = fund.value;
        };


        coin::join(&mut pool.fund, deal);

        event::emit(LockEvent {
            pool_tier: id_address(pool),
            sender,
            value,
            timestamp,
            expire,
            lock_amount
        })
    }

    public entry fun unlock<TOKEN>(value: u64, pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        assert!(!pool.emergency, ErrEmergency);
        let timestamp = clock::timestamp_ms(sclock);
        let sender = sender(ctx);
        assert!(table::contains(&mut pool.funds, sender) && table::borrow(&pool.funds, sender).expire <= timestamp, ErrInvalidParams);

        let stakePosititon = table::borrow_mut(&mut pool.funds, sender);
        assert!(value <= stakePosititon.value, ErrValuePosititon);

        let lock_amount = 0;
        if(value < coin::value(&pool.fund)){
            stakePosititon.value = stakePosititon.value - value;
            lock_amount = stakePosititon.value;
        } else {
            let StakePosititon {
                value: _value,
                timestamp: _timestamp,
                expire: _expire,
            } = table::remove(&mut pool.funds, sender);
        };
        public_transfer(coin::split(&mut pool.fund, value, ctx), sender);

        event::emit(UnlockEvent {
            pool_tier: id_address(pool),
            sender,
            value,
            timestamp,
            emergency: false,
            lock_amount
        })
    }

    public entry fun unlock_emergency<TOKEN>(pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        assert!(pool.emergency, ErrNotEmergency);
        let sender = sender(ctx);
        assert!(table::contains(&mut pool.funds, sender), ErrInvalidParams);

        let StakePosititon {
            value,
            timestamp: _timestamp,
            expire: _expire,
        } = table::remove(&mut pool.funds, sender);

        public_transfer(coin::split(&mut pool.fund, value, ctx), sender);

        event::emit(UnlockEvent {
            pool_tier: id_address(pool),
            sender,
            value,
            timestamp: clock::timestamp_ms(sclock),
            emergency: true,
            lock_amount: 0
        })
    }
}
