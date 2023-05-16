module common::lfarm {
    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use sui::coin::Coin;
    use sui::transfer::share_object;
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use sui::math;
    use sui::event;

    struct LFARM has drop {}

    const ErrInvalidToken: u64 = 1001;
    const ErrInvalidParams: u64 = 1002;

    struct FAdminCap has key, store {
        id: UID
    }

    struct StakePosititon has key, store{
        id: UID,
        root_depositor: address, //the genesis user who lock first, never changed!
        value: u64, //token value
        timestamp: u64, //deposit time
        expire: u64 //expire time
    }

    struct Pool<phantom TOKEN> has key, store {
        id: UID,
        fund: Coin<TOKEN>,
        minLock: u64,
        lockPeriodMs: u64,
    }

    struct LockEvent has drop, copy {
        sender: address,
        value: u64,
        lockPeriodMs: u64
    }

    struct UnlockEvent has drop, copy {
        sender: address,
        value: u64,
        lockPeriodMs: u64
    }

    fun init(_witness: LFARM, ctx: &mut TxContext) {
        let adminCap = FAdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, sender(ctx));
    }

    public entry fun createPool<TOKEN>(_admin: &FAdminCap, minLock: u64, lockPeriodMs: u64, ctx: &mut TxContext){
        assert!(minLock > 0 && lockPeriodMs > 0, ErrInvalidParams);
        share_object(Pool<TOKEN<>>{
            id: object::new(ctx),
            fund: coin::zero(ctx),
            minLock,
            lockPeriodMs
        });
    }

    public entry fun lock<TOKEN>(
        deal: Coin<TOKEN>, pool: &mut Pool<TOKEN>, lockPeriodMs: u64, sclock: &Clock, ctx: &mut TxContext){
        let value = coin::value(&deal);

        assert!(value > 0 && pool.lockPeriodMs <= lockPeriodMs, ErrInvalidParams);

        coin::join(&mut pool.fund, deal);

        let nowMs = clock::timestamp_ms(sclock);
        let sender = sender(ctx);
        transfer::public_transfer(StakePosititon {
            id: object::new(ctx),
            value,
            timestamp: nowMs,
            expire: nowMs + math::max(lockPeriodMs, pool.lockPeriodMs),
            root_depositor: sender
        }, sender);

        event::emit(LockEvent {
            sender,
            value,
            lockPeriodMs
        })
    }

    public entry fun unlock<TOKEN>(deal: StakePosititon, pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        let nowMs = clock::timestamp_ms(sclock);
        let sender = sender(ctx);
        let value = deal.value;
        assert!(deal.expire <= nowMs && value > 0, ErrInvalidParams);
        transfer::public_transfer(coin::split(&mut pool.fund, value, ctx), sender);

        let lockPeriodMs = deal.expire - deal.timestamp;

        let StakePosititon {
            id,
            root_depositor: _root_depositor, //the genesis user who lock first, never changed!
            value: _value,
            timestamp: _timestamp,
            expire: _expire,
        } = deal;

        object::delete(id);

        event::emit(UnlockEvent {
            sender,
            value,
            lockPeriodMs
        })
    }

    public entry fun transfer<TOKEN>(deal: StakePosititon, to: address){
        transfer::transfer(deal, to);
    }
}
