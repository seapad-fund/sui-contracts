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
    use sui::event;
    use sui::table::Table;
    use sui::table;

    struct TIER has drop {}

    const ErrInvalidParams: u64 = 1001;
    const ErrMinLock: u64 = 1002;
    const ErrNotEmergency: u64 = 1003;
    const ErrEmergency: u64 = 1004;

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
        minLock: u64,
        lockPeriodMs: u64,
        funds: Table<address, StakePosititon>
    }

    struct LockEvent has drop, copy {
        sender: address,
        value: u64,
        timestamp: u64,
        expire: u64,
    }

    struct UnlockEvent has drop, copy {
        sender: address,
        value: u64,
        timestamp: u64,
        emergency: bool
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
            minLock,
            lockPeriodMs,
            funds: table::new(ctx)
        });
    }

    public entry fun setEmergency<TOKEN>(_admin: &TAdminCap, pool: &mut Pool<TOKEN<>>, emergency: bool, _ctx: &mut TxContext){
        assert!(pool.emergency != emergency, ErrInvalidParams);
        pool.emergency = emergency;
    }

    public entry fun lock<TOKEN>(deal: Coin<TOKEN>, pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        assert!(!pool.emergency, ErrEmergency);
        let value = coin::value(&deal);
        let timestamp = clock::timestamp_ms(sclock);
        let expire = timestamp + pool.lockPeriodMs;
        let sender = sender(ctx);

        if(!table::contains(&pool.funds, sender)) {
                table::add(&mut pool.funds, sender,  StakePosititon {
                    value,
                    timestamp,
                    expire
                })
        } else{
            let fund = table::borrow_mut(&mut pool.funds, sender);
            value = value + fund.value;
            fund.value = value;
            fund.timestamp = timestamp;
            fund.expire = expire
        };

        assert!(value >= pool.minLock, ErrMinLock);

        coin::join(&mut pool.fund, deal);

        event::emit(LockEvent {
            sender,
            value,
            timestamp,
            expire
        })
    }

    public entry fun unlock<TOKEN>(pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        assert!(!pool.emergency, ErrEmergency);
        let timestamp = clock::timestamp_ms(sclock);
        let sender = sender(ctx);
        assert!(table::contains(&mut pool.funds, sender)
                && table::borrow(&pool.funds, sender).expire <= timestamp, ErrInvalidParams);

        let StakePosititon {
            value,
            timestamp: _timestamp,
            expire: _expire,
        } = table::remove(&mut pool.funds, sender);

        public_transfer(coin::split(&mut pool.fund, value, ctx), sender);

        event::emit(UnlockEvent {
            sender,
            value,
            timestamp,
            emergency: false
        })
    }

    public entry fun unlockEmergency<TOKEN>(pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
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
            sender,
            value,
            timestamp: clock::timestamp_ms(sclock),
            emergency: true
        })
    }
}
