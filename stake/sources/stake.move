// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: GPL-3.0

module seapad::stake {
    use seapad::stake_config;
    use sui::coin::{Coin};
    use sui::tx_context::{TxContext, sender};
    use seapad::stake_config::GlobalConfig;
    use sui::coin;
    use w3libs::math128;
    use sui::table;
    use sui::transfer::share_object;
    use sui::object::UID;
    use sui::object;
    use sui::event;
    use sui::math;
    use sui::clock::Clock;
    use sui::clock;

    const ERR_NO_POOL: u64 = 100;
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;
    const ERR_REWARD_CANNOT_BE_ZERO: u64 = 102;
    const ERR_NO_STAKE: u64 = 103;
    const ERR_NOT_ENOUGH_S_BALANCE: u64 = 104;
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 105;
    const ERR_NOTHING_TO_HARVEST: u64 = 106;
    const ERR_IS_NOT_COIN: u64 = 107;
    const ERR_TOO_EARLY_UNSTAKE: u64 = 108;
    const ERR_EMERGENCY: u64 = 109;
    const ERR_NO_EMERGENCY: u64 = 110;
    const ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY: u64 = 111;
    const ERR_DURATION_CANNOT_BE_ZERO: u64 = 112;
    const ERR_HARVEST_FINISHED: u64 = 113;
    const ERR_NOT_WITHDRAW_PERIOD: u64 = 114;
    const ERR_NOT_TREASURY: u64 = 115;
    const ERR_INVALID_REWARD_DECIMALS: u64 = 123;
    const ERR_EXCEED_MAX_STAKE: u64 = 124;

    /// When treasury can withdraw rewards (~2 days).
    const WITHDRAW_REWARD_PERIOD_IN_SECONDS: u64 = 172800;

    /// Scale of pool accumulated reward field.
    const ACCUM_REWARD_SCALE: u128 = 1000000000000;

    /// Stake pool, stores stake, reward coins and related info.
    struct StakePool<phantom S, phantom R> has key, store {
        id: UID,
        reward_per_sec: u64,
        // pool reward ((reward_per_sec * time) / total_staked) + accum_reward (previous period)
        accum_reward: u128,
        // last accum_reward update time
        last_updated: u64,
        // start timestamp.
        start_timestamp: u64,
        // when harvest will be finished.
        end_timestamp: u64,

        stakes: table::Table<address, UserStake>,
        stake_coins: Coin<S>,
        reward_coins: Coin<R>,
        // multiplier to handle decimals
        scale: u128,
        /// This field set to `true` only in case of emergency:
        /// * only `emergency_unstake()` operation is available in the state of emergency
        emergency_locked: bool,
        duration_unstake_time_sec: u64,
        max_stake: u64
    }

    /// Stores user stake info.
    struct UserStake has store {
        amount: u64,
        // contains the value of rewards that cannot be harvested by the user
        unobtainable_reward: u128,
        earned_reward: u64,
        unlock_time: u64,
    }

    /// Registering pool for specific coin. Multiple pool can be created with the same pair!!!
    /// Allow treasury admin only
    public fun register_pool<S, R>(
        reward_coins: Coin<R>,
        duration_sec: u64,
        config: &GlobalConfig,
        decimalS: u8,
        decimalR: u8,
        sClock: &Clock,
        unstake_duration_ms: u64,
        user_max_stake: u64,
        ctx: &mut TxContext
    ) {
        validate_treasury_admin(config, ctx);
        assert!(!stake_config::is_global_emergency(config), ERR_EMERGENCY);
        assert!(duration_sec > 0, ERR_DURATION_CANNOT_BE_ZERO);

        let timestamp_ms = clock::timestamp_ms(sClock);

        let reward_per_sec = coin::value(&reward_coins) / duration_sec;
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);

        let current_time = timestamp_ms / 1000;
        let end_timestamp = current_time + duration_sec;

        let origin_decimals = (decimalR as u128);
        assert!(origin_decimals <= 10, ERR_INVALID_REWARD_DECIMALS);

        let reward_scale = ACCUM_REWARD_SCALE / math128::pow(10, origin_decimals);
        let stake_scale = math128::pow(10, (decimalS as u128));
        let scale = stake_scale * reward_scale;
        let reward_amount = coin::value(&reward_coins);

        let pool = StakePool<S, R> {
            id: object::new(ctx),
            reward_per_sec,
            accum_reward: 0,
            last_updated: current_time,
            start_timestamp: current_time,
            end_timestamp,
            stakes: table::new(ctx),
            stake_coins: coin::zero(ctx),
            reward_coins,
            scale,
            emergency_locked: false,
            duration_unstake_time_sec: unstake_duration_ms / 1000,
            max_stake: user_max_stake
        };

        event::emit(RegisterPoolEvent {
            pool_id: object::id_address(&pool),
            reward_per_sec,
            end_timestamp,
            start_timestamp: current_time,
            last_updated: current_time,
            reward_amount
        });

        share_object(pool);
    }

    /// Depositing reward coins to specific pool, updates pool duration.
    /// Allow treasury admin only
    public fun deposit_reward_coins<S, R>(pool: &mut StakePool<S, R>,
                                          coins: Coin<R>,
                                          config: &GlobalConfig,
                                          sClock: &Clock,
                                          ctx: &mut TxContext) {
        assert!(!is_emergency_inner(pool, config), ERR_EMERGENCY);
        validate_treasury_admin(config, ctx);
        // it's forbidden to deposit more rewards (extend pool duration) after previous pool duration passed
        // preventing unfair reward distribution
        let timestamp_ms = clock::timestamp_ms(sClock);
        assert!(!is_finished_inner(pool, timestamp_ms), ERR_HARVEST_FINISHED);

        let amount = coin::value(&coins);
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);

        let additional_duration = amount / pool.reward_per_sec;
        assert!(additional_duration > 0, ERR_DURATION_CANNOT_BE_ZERO);

        pool.end_timestamp = pool.end_timestamp + additional_duration;

        coin::join(&mut pool.reward_coins, coins);

        let depositor_addr = sender(ctx);

        event::emit(
            DepositRewardEvent {
                pool_id: object::id_address(pool),
                user_address: depositor_addr,
                amount,
                new_end_timestamp: pool.end_timestamp,
            },
        );
    }

    /// Stakes user coins in pool.
    public fun stake<S, R>(
        pool: &mut StakePool<S, R>,
        coins: Coin<S>,
        config: &GlobalConfig,
        sClock: &Clock,
        ctx: &mut TxContext
    ) {
        let timestamp_ms = clock::timestamp_ms(sClock);
        let amount = coin::value(&coins);
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);
        assert!(!is_emergency_inner(pool, config), ERR_EMERGENCY);
        assert!(!is_finished_inner(pool, timestamp_ms), ERR_HARVEST_FINISHED);

        // update pool accum_reward and timestamp
        update_accum_reward(pool, timestamp_ms);

        let current_time = timestamp_ms / 1000;
        let user_address = sender(ctx);
        let accum_reward = pool.accum_reward;

        if (!table::contains(&pool.stakes, user_address)) {
            let new_user_stake = UserStake {
                amount,
                unobtainable_reward: 0,
                earned_reward: 0,
                unlock_time: current_time + pool.duration_unstake_time_sec,
            };

            // calculate unobtainable reward for new stake
            new_user_stake.unobtainable_reward = (accum_reward * (amount as u128)) / pool.scale;
            table::add(&mut pool.stakes, user_address, new_user_stake);
        } else {
            let user_stake = table::borrow_mut(&mut pool.stakes, user_address);
            // update earnings
            update_user_earnings(accum_reward, pool.scale, user_stake);
            user_stake.amount = user_stake.amount + amount;
            // recalculate unobtainable reward after stake amount changed
            user_stake.unobtainable_reward = (accum_reward * user_stake_amount(user_stake)) / pool.scale;
            user_stake.unlock_time = current_time + pool.duration_unstake_time_sec;
        };
        let user_stake = table::borrow(&mut pool.stakes, user_address);
        assert!(user_stake.amount <= pool.max_stake, ERR_EXCEED_MAX_STAKE);

        coin::join(&mut pool.stake_coins, coins);

        event::emit(StakeEvent {
            pool_id: object::id_address(pool),
            user_address,
            amount,
            user_staked_amount: user_stake.amount,
            accum_reward: pool.accum_reward,
            total_staked: coin::value(&pool.stake_coins),
            unlock_time_sec: current_time + pool.duration_unstake_time_sec,
            pool_last_updated_sec: pool.last_updated,
            unobtainable_reward: user_stake.unobtainable_reward,
            earned_reward: user_stake.earned_reward,
            unlock_time: user_stake.unlock_time
        });
    }

    /// Unstakes user coins from pool.
    /// Returns S coins: `Coin<S>`.
    public fun unstake<S, R>(
        pool: &mut StakePool<S, R>,
        amount: u64,
        global_config: &GlobalConfig,
        sClock: &Clock,
        ctx: &mut TxContext
    ): Coin<S> {
        let timestamp_ms = clock::timestamp_ms(sClock);
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);

        assert!(!is_emergency_inner(pool, global_config), ERR_EMERGENCY);

        let user_address = sender(ctx);
        assert!(table::contains(&pool.stakes, user_address), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool, timestamp_ms);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);
        assert!(amount <= user_stake.amount, ERR_NOT_ENOUGH_S_BALANCE);

        // check unlock timestamp
        let timestamp_sec = timestamp_ms / 1000;
        if (pool.end_timestamp >= timestamp_sec) {
            assert!(timestamp_sec >= user_stake.unlock_time, ERR_TOO_EARLY_UNSTAKE);
        };

        // update earnings
        update_user_earnings(pool.accum_reward, pool.scale, user_stake);
        user_stake.amount = user_stake.amount - amount;

        // recalculate unobtainable reward after stake amount changed
        user_stake.unobtainable_reward = (pool.accum_reward * user_stake_amount(user_stake)) / pool.scale;

        let coin = coin::split(&mut pool.stake_coins, amount, ctx);
        event::emit(UnstakeEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount,
            user_staked_amount: user_stake.amount,
            accum_reward: pool.accum_reward,
            total_staked: coin::value(&pool.stake_coins),
            pool_last_updated_sec: pool.last_updated,
            unobtainable_reward: user_stake.unobtainable_reward,
            earned_reward: user_stake.earned_reward,
            unlock_time: user_stake.unlock_time
        });

        coin
    }

    /// Harvests user reward.
    /// Returns R coins: `Coin<R>`.
    public fun harvest<S, R>(pool: &mut StakePool<S, R>,
                             config: &GlobalConfig,
                             sclock: &Clock,
                             ctx: &mut TxContext): Coin<R> {
        let timestamp_ms = clock::timestamp_ms(sclock);
        assert!(!is_emergency_inner(pool, config), ERR_EMERGENCY);

        let user_address = sender(ctx);
        assert!(table::contains(&pool.stakes, user_address), ERR_NO_STAKE);

        update_accum_reward(pool, timestamp_ms);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        // update earnings
        update_user_earnings(pool.accum_reward, pool.scale, user_stake);

        let earned = user_stake.earned_reward;
        assert!(earned > 0, ERR_NOTHING_TO_HARVEST);

        user_stake.earned_reward = 0;

        // Double check that always enough rewards.
        let coin = coin::split(&mut pool.reward_coins, earned, ctx);

        event::emit(HarvestEvent {
            pool_id: object::uid_to_address(&pool.id),
            user_address,
            amount: earned,
            staked_amount: user_stake.amount,
            accum_reward: pool.accum_reward,
            total_staked: coin::value(&pool.stake_coins),
            pool_last_updated_sec: pool.last_updated,
            unobtainable_reward: user_stake.unobtainable_reward,
            earned_reward: user_stake.earned_reward,
            unlock_time: user_stake.unlock_time
        });

        coin
    }


    /// Enables local "emergency state" for the specific  pool. Cannot be disabled.
    public fun enable_emergency<S, R>(pool: &mut StakePool<S, R>,
                                      config: &GlobalConfig,
                                      ctx: &mut TxContext) {
        validate_emergency_admin(config, ctx);
        assert!(!is_emergency_inner(pool, config), ERR_EMERGENCY);
        pool.emergency_locked = true;
    }

    /// Withdraws all the user stake and nft from the pool. Only accessible in the "emergency state".
    /// Returns staked coins.
    public fun emergency_unstake<S, R>(pool: &mut StakePool<S, R>,
                                       global_config: &GlobalConfig,
                                       ctx: &mut TxContext): Coin<S> {
        assert!(is_emergency_inner(pool, global_config), ERR_NO_EMERGENCY);

        let user_addr = sender(ctx);
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        let user_stake = table::remove(&mut pool.stakes, user_addr);
        let UserStake {
            amount,
            unobtainable_reward: _,
            earned_reward: _,
            unlock_time: _,
        } = user_stake;

        coin::split(&mut pool.stake_coins, amount, ctx)
    }

    /// If WITHDRAW_REWARD_PERIOD_IN_SECONDS passed we can withdraw any remaining rewards using treasury account.
    /// In case of emergency we can withdraw to treasury immediately.
    public fun withdraw_to_treasury<S, R>(pool: &mut StakePool<S, R>,
                                          amount: u64,
                                          config: &GlobalConfig,
                                          sClock: &Clock,
                                          ctx: &mut TxContext): Coin<R> {
        validate_treasury_admin(config, ctx);

        let timestamp_ms = clock::timestamp_ms(sClock);
        if (!is_emergency_inner(pool, config)) {
            let now = timestamp_ms / 1000;
            assert!(now >= (pool.end_timestamp + WITHDRAW_REWARD_PERIOD_IN_SECONDS), ERR_NOT_WITHDRAW_PERIOD);
        };

        coin::split(&mut pool.reward_coins, amount, ctx)
    }

    fun get_start_timestamp<S, R>(pool: &StakePool<S, R>): u64 {
        pool.start_timestamp
    }

    fun is_finished<S, R>(pool: &StakePool<S, R>, timestamp_ms: u64): bool {
        is_finished_inner(pool, timestamp_ms)
    }

    fun get_end_timestamp<S, R>(pool: &StakePool<S, R>): u64 {
        pool.end_timestamp
    }

    fun stake_exists<S, R>(pool: &StakePool<S, R>, user_addr: address): bool {
        table::contains(&pool.stakes, user_addr)
    }

    fun get_pool_total_stake<S, R>(pool: &StakePool<S, R>): u64 {
        coin::value(&pool.stake_coins)
    }

    fun get_user_stake<S, R>(pool: &StakePool<S, R>, user_addr: address): u64 {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);
        table::borrow(&pool.stakes, user_addr).amount
    }

    public fun get_pending_user_rewards<S, R>(pool: &StakePool<S, R>, user_addr: address, sclock: &Clock): u64 {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        let user_stake = table::borrow(&pool.stakes, user_addr);
        let current_time = get_time_for_last_update(pool, clock::timestamp_ms(sclock));
        let new_accum_rewards = accum_rewards_since_last_updated(pool, current_time);

        let earned_since_last_update = user_earned_since_last_update(
            pool.accum_reward + new_accum_rewards,
            pool.scale,
            user_stake,
        );
        user_stake.earned_reward + (earned_since_last_update as u64)
    }

    fun get_unlock_time<S, R>(pool: &StakePool<S, R>, user_addr: address): u64 {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);
        math::min(pool.end_timestamp, table::borrow(&pool.stakes, user_addr).unlock_time)
    }

    fun is_unlocked<S, R>(pool: &StakePool<S, R>, user_addr: address, sclock: &Clock): bool {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);
        (clock::timestamp_ms(sclock) / 1000) >= math::min(pool.end_timestamp, table::borrow(&pool.stakes, user_addr).unlock_time)
    }

    fun is_emergency<S, R>(pool: &StakePool<S, R>, global_config: &GlobalConfig): bool {
        is_emergency_inner(pool, global_config)
    }

    fun is_local_emergency<S, R>(pool: &StakePool<S, R>): bool {
        pool.emergency_locked
    }

    fun is_emergency_inner<S, R>(pool: &StakePool<S, R>, global_config: &GlobalConfig): bool {
        pool.emergency_locked || stake_config::is_global_emergency(global_config)
    }

    fun is_finished_inner<S, R>(pool: &StakePool<S, R>, timestamp_ms: u64): bool {
        let now = timestamp_ms / 1000;
        now >= pool.end_timestamp
    }

    fun update_accum_reward<S, R>(pool: &mut StakePool<S, R>, timestamp_now: u64) {
        let current_time = get_time_for_last_update(pool, timestamp_now);
        let new_accum_rewards = accum_rewards_since_last_updated(pool, current_time);

        pool.last_updated = current_time;

        if (new_accum_rewards != 0) {
            pool.accum_reward = pool.accum_reward + new_accum_rewards;
        };
    }

    fun accum_rewards_since_last_updated<S, R>(pool: &StakePool<S, R>, current_time: u64): u128 {
        let seconds_passed = current_time - pool.last_updated;
        if (seconds_passed == 0) return 0;

        let total_stake = pool_total_staked(pool);
        if (total_stake == 0) return 0;

        let total_rewards = (pool.reward_per_sec as u128) * (seconds_passed as u128) * pool.scale;
        total_rewards / total_stake
    }

    fun update_user_earnings(accum_reward: u128, scale: u128, user_stake: &mut UserStake) {
        let earned = user_earned_since_last_update(accum_reward, scale, user_stake);
        user_stake.earned_reward = user_stake.earned_reward + (earned as u64);
        user_stake.unobtainable_reward = user_stake.unobtainable_reward + earned;
    }

    fun user_earned_since_last_update(
        accum_reward: u128,
        scale: u128,
        user_stake: &UserStake
    ): u128 {
        ((accum_reward * user_stake_amount(user_stake)) / scale) - user_stake.unobtainable_reward
    }

    fun get_time_for_last_update<S, R>(pool: &StakePool<S, R>, timestamp_now: u64): u64 {
        math::min(pool.end_timestamp, timestamp_now / 1000)
    }

    fun pool_total_staked<S, R>(pool: &StakePool<S, R>): u128 {
        (coin::value(&pool.stake_coins) as u128)
    }

    fun user_stake_amount(user_stake: &UserStake): u128 {
        (user_stake.amount as u128)
    }

    fun validate_treasury_admin(config: &GlobalConfig, ctx: &TxContext){
        assert!(sender(ctx) == stake_config::get_treasury_admin_address(config), ERR_NOT_TREASURY);
    }

    fun validate_emergency_admin(config: &GlobalConfig, ctx: &TxContext){
        assert!(sender(ctx) == stake_config::get_emergency_admin_address(config), ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY);
    }

    struct StakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u64,
        user_staked_amount: u64,
        accum_reward: u128,
        total_staked: u64,
        unlock_time_sec: u64,
        pool_last_updated_sec: u64,
        unobtainable_reward: u128,
        earned_reward: u64,
        unlock_time: u64
    }

    struct UnstakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u64,
        user_staked_amount: u64,
        accum_reward: u128,
        total_staked: u64,
        pool_last_updated_sec: u64,
        unobtainable_reward: u128,
        earned_reward: u64,
        unlock_time: u64
    }


    struct DepositRewardEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u64,
        new_end_timestamp: u64,
    }

    struct HarvestEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u64,
        staked_amount: u64,
        accum_reward: u128,
        total_staked: u64,
        pool_last_updated_sec: u64,
        unobtainable_reward: u128,
        earned_reward: u64,
        unlock_time: u64
    }

    struct RegisterPoolEvent has drop, copy, store {
        pool_id: address,
        reward_per_sec: u64,
        last_updated: u64,
        start_timestamp: u64,
        end_timestamp: u64,
        reward_amount: u64,
    }

    #[test_only]
    public fun get_unobtainable_reward<S, R>(
        pool: &StakePool<S, R>,
        user_addr: address
    ): u128 {
        table::borrow(&pool.stakes, user_addr).unobtainable_reward
    }

    #[test_only]
    public fun get_pool_info<S, R>(pool: &StakePool<S, R>): (u64, u128, u64, u64, u128) {
        (pool.reward_per_sec,
            pool.accum_reward,
            pool.last_updated,
            coin::value<R>(&pool.reward_coins),
            pool.scale)
    }

    #[test_only]
    public fun recalculate_user_stake<S, R>(pool: &mut StakePool<S, R>, user_addr: address, timestamp_ms: u64) {
        update_accum_reward(pool, timestamp_ms);
        let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);
        update_user_earnings(pool.accum_reward, pool.scale, user_stake);
    }
}
