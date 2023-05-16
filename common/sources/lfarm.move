module common::lfarm {
    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use sui::coin::Coin;
    use sui::transfer::{share_object, transfer};
    use sui::coin;
    use sui::clock::Clock;
    use sui::clock;
    use sui::math;
    use sui::event;
    use std::vector;

    struct LFARM has drop {}

    const ErrInvalidToken: u64 = 1001;
    const ErrInvalidParams: u64 = 1002;

    struct FAdminCap has key, store {
        id: UID
    }

    struct StakePosititon has key, store{
        id: UID,
        value: u64, //token value
        timestamp: u64, //deposit time
        expire: u64, //expire time
        yield: u64 //future
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
        timestamp: u64, //deposit time
        expire: u64, //expire time
    }

    struct UnlockEvent has drop, copy {
        sender: address,
        value: u64,
        timestamp: u64
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

        let timestamp = clock::timestamp_ms(sclock);
        let expire = timestamp + math::max(lockPeriodMs, pool.lockPeriodMs)
        let sender = sender(ctx);
        transfer::public_transfer(StakePosititon {
            id: object::new(ctx),
            value,
            timestamp,
            expire: timestamp + math::max(lockPeriodMs, pool.lockPeriodMs),
            yield: 0
        }, sender);

        event::emit(LockEvent {
            sender,
            value,
            timestamp,
            expire
        })
    }

    public entry fun unlock<TOKEN>(deal: StakePosititon, pool: &mut Pool<TOKEN>, sclock: &Clock, ctx: &mut TxContext){
        let timestamp = clock::timestamp_ms(sclock);
        let sender = sender(ctx);
        let value = deal.value;
        assert!(deal.expire <= timestamp && value > 0, ErrInvalidParams);
        transfer::public_transfer(coin::split(&mut pool.fund, value, ctx), sender);

        let StakePosititon {
            id,
            value: _value,
            timestamp: _timestamp,
            expire: _expire,
            yield: _yield
        } = deal;

        object::delete(id);

        event::emit(UnlockEvent {
            sender,
            value,
            timestamp
        })
    }

    public entry fun merge<TOKEN>(deals: vector<StakePosititon>, ctx: &mut TxContext){
        let sumPos = StakePosititon {
            id: object::new(ctx),
            value: 0, //token value
            timestamp: 0, //deposit time
            expire: 0, //expire time
            yield: 0 //future
        };

        let value = 0u64;
        let diff = 0;
        let expire = 0;
        let yield = 0;
        while (!vector::is_empty(&deals)){
            let tmp = vector::pop_back(&mut deals);
            let tmpDiff = tmp.expire - tmp.timestamp;
            diff = if(diff == 0){
                tmpDiff
            } else{
                math::min(diff, tmpDiff)
            };
            expire = math::max(expire, tmp.expire);
            yield = math::min(yield, tmp.yield);
            value = value + tmp.value;
            destroy(tmp)
        };

        let timestamp = expire - diff;

        vector::destroy_empty(deals);

        transfer(StakePosititon {
            id: object::new(ctx),
            value,
            timestamp,
            expire,
            yield
        }, sender(ctx));
    }

    public entry fun split<TOKEN>(deal: &mut StakePosititon, amt: u64, ctx: &mut TxContext){
        assert!(deal.value >= amt, ErrInvalidParams);
        deal.value = deal.value - amt;
        transfer(StakePosititon {
            id: object::new(ctx),
            value: amt,
            timestamp: deal.timestamp,
            expire: deal.expire,
            yield: deal.yield
        });
    }

    fun destroy(sp: StakePosititon){
        let StakePosititon {
            id,
            value: _value,
            timestamp: _timestamp,
            expire: _expire,
            yield: _yield
        } = sp;

        object::delete(id);
    }
}
