module seapad::stake {

    use std::vector;
    use sui::event;
    use sui::coin;
    use sui::clock;
    use sui::clock::Clock;
    use sui::transfer;
    use sui::transfer::{transfer, share_object};
    use sui::object;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::Coin;
    use sui::table;
    use sui::object::{UID, id_address};

    const ERR_BAD_FUND_PARAMS: u64 = 8001;
    const ERR_TIMEDIFF_CANNOT_BE_ZERO: u64 = 8002;
    const ERR_STAKED_CANNOT_BE_ZERO: u64 = 8003;
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 8004;
    const ERR_NO_FUND: u64 = 8005;
    const ERR_NO_STAKE: u64 = 8006;
    const ERR_NOT_ENOUGH_S_BALANCE: u64 = 8007;
    const ERR_TOO_EARLY_UNSTAKE: u64 = 8008;
    const ERR_NOTHING_TO_HARVEST: u64 = 8009;
    const ERR_PAUSED: u64 = 8010;

    const ONE_YEARS_MS: u64 = 31536000000;


    struct STAKE has drop {}

    struct Admincap has store, key {
        id: UID,
    }

    struct StakePool<phantom S, phantom R> has key, store {
        id: UID,
        apy: u128,
        paused: bool,
        unlock_times: u64,
        stake_coins: Coin<S>,
        reward_coins: Coin<R>,
        stakes: table::Table<address, UserStake>
    }

    struct UserStake has store {
        spt_staked: u128,
        withdraw_stake: u128,
        reward_remaining: u128,
        lastest_updated_time: u64,
        unlock_times: u64
    }

    struct CreatePoolEvent has drop, copy {
        pool_id: address,
        unlock_times: u64,
        apy: u128
    }

    struct StakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u128,
        apy: u128,
        user_spt_staked: u128,
        user_reward_remaining: u128,
        user_lastest_updated_time: u64
    }

    struct UpdateApyEvent has drop, store, copy {
        poo_id: address,
        user_address: address,
        apy: u128,
        user_spt_staked: u128,
        user_withdraw_stake: u128,
        user_reward_remaining: u128,
        user_lastest_updated_time: u64,
        user_unlock_time: u64
    }

    struct DepositRewardEvent has drop, store, copy {
        pool_id: address,
        amount: u128,
        total_reward: u128
    }

    struct WithdarawRewardEvent has drop, store, copy {
        pool_id: address,
        total_reward: u128
    }

    struct UnStakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u128,
        user_spt_staked: u128,
        user_withdraw_stake: u128,
        user_reward_remaining: u128,
        user_lastest_updated_time: u64,
        user_unlock_time: u64
    }

    struct WithdrawSptEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        user_spt_staked: u128,
        user_withdraw_staked: u128,
        user_reward_remaining: u128,
        user_lastest_updated_time: u64,
        user_unlock_time: u64
    }

    struct ClaimRewardsEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u128,
        total_staked: u128,
        total_reward: u128,
        user_spt_staked: u128,
        user_withdraw_stake: u128,
        user_reward_remaining: u128,
        user_lastest_updated_time: u64,
        user_unlock_time: u64
    }

    struct StopEmergencyEvent has drop, store, copy {
        pool_id: address,
        total_staked: u128,
        paused: bool
    }

    struct StakeRewardsEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u128,
        total_staked: u128,
        user_spt_staked: u128,
        user_reward_remaining: u128,
        user_lastest_updated_time: u64,
    }

    fun init(_witness: STAKE, ctx: &mut TxContext) {
        let adminCap = Admincap { id: object::new(ctx) };
        transfer::transfer(adminCap, sender(ctx));
    }

    public entry fun change_admin(admin: Admincap, to: address) {
        transfer(admin, to);
    }

    public entry fun createPool<S, R>(
        _admin: &Admincap,
        unlock_times: u64,
        apy: u128,
        ctx: &mut TxContext
    ) {
        assert!(apy > 0u128, ERR_BAD_FUND_PARAMS);

        let pool = StakePool<S, R> {
            id: object::new(ctx),
            apy,
            paused: false,
            unlock_times,
            stake_coins: coin::zero(ctx),
            reward_coins: coin::zero(ctx),
            stakes: table::new(ctx)
        };

        let poolId = id_address(&pool);

        event::emit(CreatePoolEvent {
            pool_id: poolId,
            unlock_times,
            apy
        });

        share_object(pool);
    }

    public entry fun pause<S, R>(_admin: &Admincap, pool: &mut StakePool<S, R>, pause: bool) {
        pool.paused = pause;
    }

    public entry fun updateUnlockTime<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        unlock_times: u64,
    ) {
        assert!(unlock_times > 0, ERR_BAD_FUND_PARAMS);
        pool.unlock_times = unlock_times;
    }

    /// Stakes user coins in pool.
    public fun stake<S, R>(
        pool: &mut StakePool<S, R>,
        coins: Coin<S>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!pool.paused, ERR_PAUSED);
        let now = clock::timestamp_ms(sclock);
        let amount = (coin::value(&coins) as u128);
        assert!(amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);

        let user_address = sender(ctx);
        let apy = pool.apy;

        if (!table::contains(&pool.stakes, user_address)) {
            let new_user_stake = UserStake {
                spt_staked: amount,
                withdraw_stake: 0,
                reward_remaining: 0,
                lastest_updated_time: now,
                unlock_times: 0
            };
            table::add(&mut pool.stakes, user_address, new_user_stake);
        }else {
            let user_stake = table::borrow_mut(&mut pool.stakes, user_address);
            update_reward_remaining(apy, now, user_stake);
            user_stake.spt_staked = user_stake.spt_staked + amount;
        };
        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        coin::join(&mut pool.stake_coins, coins);

        event::emit(StakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount,
            apy,
            user_spt_staked: user_stake.spt_staked,
            user_reward_remaining: user_stake.reward_remaining,
            user_lastest_updated_time: user_stake.lastest_updated_time
        });
    }

    /// Unstakes user coins from pool.
    public fun unstake<S, R>(
        pool: &mut StakePool<S, R>,
        amount: u128,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!pool.paused, ERR_PAUSED);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);

        assert!(table::contains(&pool.stakes, user_address), ERR_NO_STAKE);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        update_reward_remaining(pool.apy, now, user_stake);

        let totalStake = user_stake.spt_staked;
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(totalStake > 0 && totalStake >= amount, ERR_NO_FUND);
        user_stake.spt_staked = user_stake.spt_staked - amount;

        user_stake.withdraw_stake = user_stake.withdraw_stake + amount;

        user_stake.unlock_times = now + pool.unlock_times;

        let value = (coin::value(&pool.reward_coins) as u128);
        let reward = user_stake.reward_remaining;
        assert!(reward > 0u128 && value >= reward, ERR_NO_FUND);

        user_stake.reward_remaining = 0;

        let reward = coin::split(&mut pool.reward_coins, (reward as u64), ctx);

        transfer::public_transfer(reward, user_address);


        event::emit(UnStakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount: totalStake,
            user_spt_staked: user_stake.spt_staked,
            user_withdraw_stake: user_stake.withdraw_stake,
            user_reward_remaining: user_stake.reward_remaining,
            user_lastest_updated_time: user_stake.lastest_updated_time,
            user_unlock_time: user_stake.unlock_times
        });
    }

    public entry fun withdrawSpt<S, R>(
        pool: &mut StakePool<S, R>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!pool.paused, ERR_PAUSED);
        let user_address = sender(ctx);
        let now = clock::timestamp_ms(sclock);
        let value = (coin::value(&pool.stake_coins) as u128);
        assert!(table::contains(&mut pool.stakes, user_address), ERR_NO_FUND);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        assert!(now >= user_stake.unlock_times, ERR_TOO_EARLY_UNSTAKE);
        assert!(user_stake.withdraw_stake > 0u128 && user_stake.withdraw_stake <= value, ERR_NOT_ENOUGH_S_BALANCE);

        let amount = user_stake.withdraw_stake;

        user_stake.withdraw_stake = 0;

        let coin = coin::split(&mut pool.stake_coins, (amount as u64), ctx);

        transfer::public_transfer(coin, user_address);

        event::emit(WithdrawSptEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            user_spt_staked: user_stake.spt_staked,
            user_withdraw_staked: user_stake.withdraw_stake,
            user_reward_remaining: user_stake.reward_remaining,
            user_lastest_updated_time: user_stake.lastest_updated_time,
            user_unlock_time: user_stake.unlock_times
        });
    }

    ///User claim Reward
    public entry fun claimRewards<S, R>(
        pool: &mut StakePool<S, R>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!pool.paused, ERR_PAUSED);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);
        assert!(table::contains(&pool.stakes, user_address), ERR_NO_STAKE);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        update_reward_remaining(pool.apy, now, user_stake);


        let value = (coin::value(&pool.reward_coins) as u128);
        let reward = user_stake.reward_remaining;
        assert!(reward > 0 && reward <= value, ERR_NOTHING_TO_HARVEST);

        user_stake.reward_remaining = 0;

        let coin = coin::split(&mut pool.reward_coins, (reward as u64), ctx);

        transfer::public_transfer(coin, user_address);

        event::emit(ClaimRewardsEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount: reward,
            total_staked: (coin::value(&pool.stake_coins) as u128),
            total_reward: (coin::value(&pool.reward_coins) as u128),
            user_spt_staked: user_stake.spt_staked,
            user_withdraw_stake: user_stake.withdraw_stake,
            user_reward_remaining: user_stake.reward_remaining,
            user_lastest_updated_time: user_stake.lastest_updated_time,
            user_unlock_time: user_stake.unlock_times
        });
    }

    public entry fun stakeRewards<S, R>(
        pool: &mut StakePool<S, R>,
        sclock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(!pool.paused, ERR_PAUSED);
        let now = clock::timestamp_ms(sclock);
        let user_address = sender(ctx);
        assert!(table::contains(&mut pool.stakes, user_address), ERR_NO_FUND);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        update_reward_remaining(pool.apy, now, user_stake);

        let value = user_stake.reward_remaining;
        assert!(value > 0, ERR_NO_FUND);
        user_stake.spt_staked = user_stake.spt_staked + value;

        user_stake.reward_remaining = 0;

        event::emit(StakeRewardsEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount: value,
            total_staked: (coin::value(&mut pool.stake_coins) as u128),
            user_spt_staked: user_stake.spt_staked,
            user_reward_remaining: user_stake.reward_remaining,
            user_lastest_updated_time: user_stake.lastest_updated_time
        });
    }

    /// Depositing reward coins to specific pool
    public entry fun deposit_reward_coins<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        coins: Coin<R>
    ) {
        let amount = (coin::value(&coins) as u128);
        assert!(amount > 0u128, ERR_AMOUNT_CANNOT_BE_ZERO);

        coin::join(&mut pool.reward_coins, coins);

        event::emit(
            DepositRewardEvent {
                pool_id: object::id_address(pool),
                amount,
                total_reward: (coin::value(&pool.reward_coins) as u128)
            }
        );
    }

    public entry fun withdraw_reward_coins<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        ctx: &mut TxContext
    ) {
        let value = (coin::value(&pool.reward_coins) as u128);
        assert!(value > 0u128, ERR_NO_FUND);
        let coin = coin::split(&mut pool.reward_coins, (value as u64), ctx);
        transfer::public_transfer(coin, sender(ctx));

        event::emit(WithdarawRewardEvent {
            pool_id: object::id_address(pool),
            total_reward: value
        });
    }

    fun update_reward_remaining(
        apy: u128,
        now: u64,
        user_stake: &mut UserStake) {
        assert!(apy > 0u128, ERR_BAD_FUND_PARAMS);

        let time_diff = ((now - user_stake.lastest_updated_time) as u128);

        let reward_increase = ((time_diff * user_stake.spt_staked * apy) / (ONE_YEARS_MS * 10000 as u128));

        user_stake.reward_remaining = user_stake.reward_remaining + reward_increase;

        user_stake.lastest_updated_time = now;
    }

    /// Update APY for Users.
    public entry fun updateApy<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        owners: vector<address>,
        apy: u128,
        sclock: &Clock,
    ) {
        assert!(apy > 0u128, ERR_BAD_FUND_PARAMS);
        let now = clock::timestamp_ms(sclock);
        pool.apy = apy;

        let (i, n) = (0, vector::length(&owners));
        while (i < n) {
            let owner = *vector::borrow(&owners, i);
            if (table::contains(&pool.stakes, owner)) {
                let user_stake = table::borrow_mut(&mut pool.stakes, owner);
                update_reward_remaining(apy, now, user_stake);

                event::emit(UpdateApyEvent {
                    poo_id: object::uid_to_address(&pool.id),
                    user_address: owner,
                    apy,
                    user_spt_staked: user_stake.spt_staked,
                    user_withdraw_stake: user_stake.withdraw_stake,
                    user_reward_remaining: user_stake.reward_remaining,
                    user_lastest_updated_time: user_stake.lastest_updated_time,
                    user_unlock_time: user_stake.unlock_times
                });
            } else {
                break
            };
            i = i + 1;
        };
    }


    public entry fun stopEmergency<S, R>(
        _admin: &Admincap,
        pool: &mut StakePool<S, R>,
        owners: vector<address>,
        paused: bool,
        ctx: &mut TxContext
    ) {
        let (i, n) = (0, vector::length(&owners));
        while (i < n) {
            let owner = *vector::borrow(&owners, i);
            if (table::contains(&mut pool.stakes, owner)) {
                let user_stake = table::borrow_mut(&mut pool.stakes, owner);

                let staked = user_stake.spt_staked;
                let value = (coin::value(&pool.stake_coins) as u128);
                assert!(staked > 0u128 && staked <= value, ERR_NO_FUND);

                user_stake.spt_staked = 0;

                let coin = coin::split(&mut pool.stake_coins, (staked as u64), ctx);

                transfer::public_transfer(coin, owner);
            } else {
                break
            };
            i = i + 1;
        };
        pool.paused = paused;

        event::emit(StopEmergencyEvent {
            pool_id: object::uid_to_address(&pool.id),
            total_staked: (coin::value(&pool.stake_coins) as u128),
            paused
        });
    }
}