module seapad::stake {
    // !!! FOR AUDITOR!!!
    // Look at math part of this module.

    use seapad::stake_config;
    use sui::coin::{Coin};
    use sui::tx_context::{TxContext, sender};
    use seapad::stake_config::GlobalConfig;
    use sui::coin;
    use seapad::math128;
    use sui::table;
    use sui::transfer::share_object;
    use sui::object::UID;
    use sui::object;
    use sui::event;
    use sui::math;

    //
    // Errors
    //

    /// Pool does not exist.
    const ERR_NO_POOL: u64 = 100;

    /// Pool already exists.
    const ERR_POOL_ALREADY_EXISTS: u64 = 101;

    /// Pool reward can't be zero.
    const ERR_REWARD_CANNOT_BE_ZERO: u64 = 102;

    /// User has no stake.
    const ERR_NO_STAKE: u64 = 103;

    /// Not enough S balance to unstake
    const ERR_NOT_ENOUGH_S_BALANCE: u64 = 104;

    /// Amount can't be zero.
    const ERR_AMOUNT_CANNOT_BE_ZERO: u64 = 105;

    /// Nothing to harvest yet.
    const ERR_NOTHING_TO_HARVEST: u64 = 106;

    /// CoinType is not a coin.
    const ERR_IS_NOT_COIN: u64 = 107;

    /// Cannot unstake before lockup period end.
    const ERR_TOO_EARLY_UNSTAKE: u64 = 108;

    /// The pool is in the "emergency state", all operations except for the `emergency_unstake()` are disabled.
    const ERR_EMERGENCY: u64 = 109;

    /// The pool is not in "emergency state".
    const ERR_NO_EMERGENCY: u64 = 110;

    /// Only one hardcoded account can enable "emergency state" for the pool, it's not the one.
    const ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY: u64 = 111;

    /// Duration can't be zero.
    const ERR_DURATION_CANNOT_BE_ZERO: u64 = 112;

    /// When harvest finished for a pool.
    const ERR_HARVEST_FINISHED: u64 = 113;

    /// When withdrawing at wrong period.
    const ERR_NOT_WITHDRAW_PERIOD: u64 = 114;

    /// When not treasury withdrawing.
    const ERR_NOT_TREASURY: u64 = 115;

    /// When reward coin has more than 10 decimals.
    const ERR_INVALID_REWARD_DECIMALS: u64 = 123;

    //
    // Constants
    //

    /// Week in seconds, lockup period.
    const WEEK_IN_SECONDS: u64 = 604800;

    /// When treasury can withdraw rewards (~3 months).
    const WITHDRAW_REWARD_PERIOD_IN_SECONDS: u64 = 7257600;

    /// Scale of pool accumulated reward field.
    const ACCUM_REWARD_SCALE: u128 = 1000000000000;

    //
    // Core data structures
    //

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
    }

    /// Stores user stake info.
    struct UserStake has store {
        amount: u64,
        // contains the value of rewards that cannot be harvested by the user
        unobtainable_reward: u128,
        earned_reward: u64,
        unlock_time: u64,
    }

    //
    // Public functions
    //

    /// Registering pool for specific coin. Multiple pool can be created with the same pair!!!
    ///     * `reward_coins` - R coins which are used in distribution as reward.
    ///     * `duration` - pool life duration, can be increased by depositing more rewards.
    ///     * `global_config` - shared global config.
    ///     * `coin_metadata_s` - coin metadata S.
    ///     * `coin_metadata_r` - coin metadata R.
    ///     * `timestamp_ms` - shared singleton system clock.
    public fun register_pool<S, R>(
        reward_coins: Coin<R>,
        duration: u64,
        global_config: &GlobalConfig,
        decimalS: u8,
        decimalR: u8,
        timestamp_ms: u64,
        ctx: &mut TxContext
    ) {
        assert!(!stake_config::is_global_emergency(global_config), ERR_EMERGENCY);
        assert!(duration > 0, ERR_DURATION_CANNOT_BE_ZERO);

        let reward_per_sec = coin::value(&reward_coins) / duration;
        assert!(reward_per_sec > 0, ERR_REWARD_CANNOT_BE_ZERO);

        let current_time = timestamp_ms / 1000; //@todo review math div
        let end_timestamp = current_time + duration;

        let origin_decimals = (decimalR as u128);
        assert!(origin_decimals <= 10, ERR_INVALID_REWARD_DECIMALS);

        let reward_scale = ACCUM_REWARD_SCALE / math128::pow(10, origin_decimals);
        let stake_scale = math128::pow(10, (decimalS as u128));
        let scale = stake_scale * reward_scale;

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
        };

        share_object(pool);
    }

    /// Depositing reward coins to specific pool, updates pool duration.
    ///     * `depositor` - rewards depositor account.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `coins` - R coins which are used in distribution as reward.
    public fun deposit_reward_coins<S, R>(pool: &mut StakePool<S, R>,
                                          coins: Coin<R>,
                                          global_config: &GlobalConfig,
                                          timestamp_ms: u64,
                                          ctx: &mut TxContext) {
        assert!(!is_emergency_inner(pool, global_config), ERR_EMERGENCY);

        // it's forbidden to deposit more rewards (extend pool duration) after previous pool duration passed
        // preventing unfair reward distribution
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
    ///     * `user` - account that making a stake.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `coins` - S coins that will be staked in pool.
    public fun stake<S, R>(
        pool: &mut StakePool<S, R>,
        coins: Coin<S>,
        global_config: &GlobalConfig,
        timestamp_ms: u64,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&coins);
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);

        assert!(!is_emergency_inner(pool, global_config), ERR_EMERGENCY);
        assert!(!is_finished_inner(pool, timestamp_ms), ERR_HARVEST_FINISHED);

        // update pool accum_reward and timestamp
        update_accum_reward(pool, timestamp_ms);

        let current_time = timestamp_ms / 1000;
        let user_address = sender(ctx);
        let accum_reward = pool.accum_reward;

        if (!table::contains(&pool.stakes, user_address)) {
            let new_stake = UserStake {
                amount,
                unobtainable_reward: 0,
                earned_reward: 0,
                unlock_time: current_time + WEEK_IN_SECONDS,
            };

            // calculate unobtainable reward for new stake
            new_stake.unobtainable_reward = (accum_reward * (amount as u128)) / pool.scale;
            table::add(&mut pool.stakes, user_address, new_stake);
        } else {
            let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

            // update earnings
            update_user_earnings(accum_reward, pool.scale, user_stake);

            user_stake.amount = user_stake.amount + amount;

            // recalculate unobtainable reward after stake amount changed
            user_stake.unobtainable_reward =
                (accum_reward * user_stake_amount(user_stake)) / pool.scale;

            user_stake.unlock_time = current_time + WEEK_IN_SECONDS;
        };

        coin::join(&mut pool.stake_coins, coins);

        event::emit(
            StakeEvent { pool_id: object::id_address(pool), user_address, amount },
        );
    }

    /// Unstakes user coins from pool.
    ///     * `user` - account that owns stake.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `amount` - a number of S coins to unstake.
    /// Returns S coins: `Coin<S>`.
    public fun unstake<S, R>(
        pool: &mut StakePool<S, R>,
        amount: u64,
        global_config: &GlobalConfig,
        timestamp_ms: u64,
        ctx: &mut TxContext
    ): Coin<S> {
        assert!(amount > 0, ERR_AMOUNT_CANNOT_BE_ZERO);

        assert!(!is_emergency_inner(pool, global_config), ERR_EMERGENCY);

        let user_address = sender(ctx);
        assert!(table::contains(&pool.stakes, user_address), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool, timestamp_ms);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);
        assert!(amount <= user_stake.amount, ERR_NOT_ENOUGH_S_BALANCE);

        // check unlock timestamp
        let current_time = timestamp_ms / 1000; //@todo review math div
        if (pool.end_timestamp >= current_time) {
            assert!(current_time >= user_stake.unlock_time, ERR_TOO_EARLY_UNSTAKE);
        };

        // update earnings
        update_user_earnings(pool.accum_reward, pool.scale, user_stake);

        user_stake.amount = user_stake.amount - amount;

        // recalculate unobtainable reward after stake amount changed
        user_stake.unobtainable_reward =
            (pool.accum_reward * user_stake_amount(user_stake)) / pool.scale;

        event::emit(UnstakeEvent { pool_id: object::id_address(pool), user_address, amount });

        coin::split(&mut pool.stake_coins, amount, ctx)
    }

    /// Harvests user reward.
    ///     * `user` - stake owner account.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns R coins: `Coin<R>`.
    public fun harvest<S, R>(pool: &mut StakePool<S, R>,
                             global_config: &GlobalConfig,
                             timestamp_ms: u64,
                             ctx: &mut TxContext): Coin<R> {
        assert!(!is_emergency_inner(pool, global_config), ERR_EMERGENCY);

        let user_address = sender(ctx);
        assert!(table::contains(&pool.stakes, user_address), ERR_NO_STAKE);

        // update pool accum_reward and timestamp
        update_accum_reward(pool, timestamp_ms);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_address);

        // update earnings
        update_user_earnings(pool.accum_reward, pool.scale, user_stake);

        let earned = user_stake.earned_reward;
        assert!(earned > 0, ERR_NOTHING_TO_HARVEST);

        user_stake.earned_reward = 0;

        event::emit(HarvestEvent { pool_id: object::id_address(pool), user_address, amount: earned });

        // !!!FOR AUDITOR!!!
        // Double check that always enough rewards.
        coin::split(&mut pool.reward_coins, earned, ctx)
    }


    /// Enables local "emergency state" for the specific `<S, R>` pool at `pool_addr`. Cannot be disabled.
    ///     * `admin` - current emergency admin account.
    ///     * `pool_addr` - address under which pool are stored.
    public fun enable_emergency<S, R>(pool: &mut StakePool<S, R>,
                                      global_config: &GlobalConfig,
                                      ctx: &mut TxContext) {
        assert!(
            sender(ctx) == stake_config::get_emergency_admin_address(global_config),
            ERR_NOT_ENOUGH_PERMISSIONS_FOR_EMERGENCY
        );

        assert!(!is_emergency_inner(pool, global_config), ERR_EMERGENCY);

        pool.emergency_locked = true;
    }

    /// Withdraws all the user stake and nft from the pool. Only accessible in the "emergency state".
    ///     * `user` - user who has stake.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns staked coins `S` and optionaly nft: `Coin<S>`, `Option<Token>`.
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

    /// If 3 months passed we can withdraw any remaining rewards using treasury account.
    /// In case of emergency we can withdraw to treasury immediately.
    ///     * `treasury` - treasury admin account.
    ///     * `pool_addr` - address of the pool.
    ///     * `amount` - rewards amount to withdraw.
    public fun withdraw_to_treasury<S, R>(pool: &mut StakePool<S, R>,
                                          amount: u64,
                                          global_config: &GlobalConfig,
                                          timestamp_ms: u64,
                                          ctx: &mut TxContext): Coin<R> {
        assert!(sender(ctx) == stake_config::get_treasury_admin_address(global_config), ERR_NOT_TREASURY);

        if (!is_emergency_inner(pool, global_config)) {
            let now = timestamp_ms / 1000; //@todo review math
            assert!(now >= (pool.end_timestamp + WITHDRAW_REWARD_PERIOD_IN_SECONDS), ERR_NOT_WITHDRAW_PERIOD);
        };

        coin::split(&mut pool.reward_coins, amount, ctx)
    }

    //
    // Getter functions
    //

    /// Get timestamp of pool creation.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns timestamp contains date when pool created.
    public fun get_start_timestamp<S, R>(pool: &StakePool<S, R>): u64 {
        pool.start_timestamp
    }

    /// Checks if harvest on the pool finished.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns true if harvest finished for the pool.
    public fun is_finished<S, R>(pool: &StakePool<S, R>, timestamp_ms: u64): bool {
        is_finished_inner(pool, timestamp_ms)
    }

    /// Gets timestamp when harvest will be finished for the pool.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns timestamp.
    public fun get_end_timestamp<S, R>(pool: &StakePool<S, R>): u64 {
        pool.end_timestamp
    }

    /// Checks if stake exists.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `user_addr` - stake owner address.
    /// Returns true if stake exists.
    public fun stake_exists<S, R>(pool: &StakePool<S, R>, user_addr: address): bool {
        table::contains(&pool.stakes, user_addr)
    }

    /// Checks current total staked amount in pool.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns total staked amount.
    public fun get_pool_total_stake<S, R>(pool: &StakePool<S, R>): u64 {
        coin::value(&pool.stake_coins)
    }

    /// Checks current amount staked by user in specific pool.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `user_addr` - stake owner address.
    /// Returns staked amount.
    public fun get_user_stake<S, R>(pool: &StakePool<S, R>, user_addr: address): u64 {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);
        table::borrow(&pool.stakes, user_addr).amount
    }

    /// Checks current pending user reward in specific pool.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `user_addr` - stake owner address.
    /// Returns reward amount that can be harvested by stake owner.
    public fun get_pending_user_rewards<S, R>(pool: &StakePool<S, R>, user_addr: address, timestamp_ms: u64): u64 {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        let user_stake = table::borrow(&pool.stakes, user_addr);
        let current_time = get_time_for_last_update(pool, timestamp_ms);
        let new_accum_rewards = accum_rewards_since_last_updated(pool, current_time);

        let earned_since_last_update = user_earned_since_last_update(
            pool.accum_reward + new_accum_rewards,
            pool.scale,
            user_stake,
        );
        user_stake.earned_reward + (earned_since_last_update as u64)
    }

    /// Checks stake unlock time in specific pool.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `user_addr` - stake owner address.
    /// Returns stake unlock time.
    public fun get_unlock_time<S, R>(pool: &StakePool<S, R>, user_addr: address): u64 {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        math::min(pool.end_timestamp, table::borrow(&pool.stakes, user_addr).unlock_time)
    }

    /// Checks if stake is unlocked.
    ///     * `pool_addr` - address under which pool are stored.
    ///     * `user_addr` - stake owner address.
    /// Returns true if user can unstake.
    public fun is_unlocked<S, R>(pool: &StakePool<S, R>, user_addr: address, timestamp_ms: u64): bool {
        assert!(table::contains(&pool.stakes, user_addr), ERR_NO_STAKE);

        let current_time = timestamp_ms / 1000;
        let unlock_time = math::min(pool.end_timestamp, table::borrow(&pool.stakes, user_addr).unlock_time);

        current_time >= unlock_time
    }

    /// Checks whether "emergency state" is enabled. In that state, only `emergency_unstake()` function is enabled.
    ///     * `pool_addr` - address under which pool are stored.
    /// Returns true if emergency happened (local or global).
    public fun is_emergency<S, R>(pool: &StakePool<S, R>, global_config: &GlobalConfig): bool {
        is_emergency_inner(pool, global_config)
    }

    /// Checks whether a specific `<S, R>` pool at the `pool_addr` has an "emergency state" enabled.
    ///     * `pool_addr` - address of the pool to check emergency.
    /// Returns true if local emergency enabled for pool.
    public fun is_local_emergency<S, R>(pool: &StakePool<S, R>): bool {
        pool.emergency_locked
    }

    //
    // Private functions.
    //

    /// Checks if local pool or global emergency enabled.
    ///     * `pool` - pool to check emergency.
    /// Returns true of any kind or both of emergency enabled.
    fun is_emergency_inner<S, R>(pool: &StakePool<S, R>, global_config: &GlobalConfig): bool {
        pool.emergency_locked || stake_config::is_global_emergency(global_config)
    }

    /// Internal function to check if harvest finished on the pool.
    ///     * `pool` - the pool itself.
    /// Returns true if harvest finished for the pool.
    fun is_finished_inner<S, R>(pool: &StakePool<S, R>, timestamp_ms: u64): bool {
        let now = timestamp_ms / 1000;
        now >= pool.end_timestamp
    }

    /// Calculates pool accumulated reward, updating pool.
    ///     * `pool` - pool to update rewards.
    fun update_accum_reward<S, R>(pool: &mut StakePool<S, R>, timestamp_now: u64) {
        let current_time = get_time_for_last_update(pool, timestamp_now);
        let new_accum_rewards = accum_rewards_since_last_updated(pool, current_time);

        pool.last_updated = current_time;

        if (new_accum_rewards != 0) {
            pool.accum_reward = pool.accum_reward + new_accum_rewards;
        };
    }

    /// Calculates accumulated reward without pool update.
    ///     * `pool` - pool to calculate rewards.
    ///     * `current_time` - execution timestamp.
    /// Returns new accumulated reward.
    fun accum_rewards_since_last_updated<S, R>(pool: &StakePool<S, R>, current_time: u64): u128 {
        let seconds_passed = current_time - pool.last_updated;
        if (seconds_passed == 0) return 0;

        let total_stake = pool_total_staked(pool);
        if (total_stake == 0) return 0;

        let total_rewards =
            (pool.reward_per_sec as u128) * (seconds_passed as u128) * pool.scale;
        total_rewards / total_stake
    }

    /// Calculates user earnings, updating user stake.
    ///     * `accum_reward` - reward accumulated by pool.
    ///     * `scale` - multiplier to handle decimals.
    ///     * `user_stake` - stake to update earnings.
    fun update_user_earnings(accum_reward: u128, scale: u128, user_stake: &mut UserStake) {
        let earned =
            user_earned_since_last_update(accum_reward, scale, user_stake);
        user_stake.earned_reward = user_stake.earned_reward + (earned as u64);
        user_stake.unobtainable_reward = user_stake.unobtainable_reward + earned;
    }

    /// Calculates user earnings without stake update.
    ///     * `accum_reward` - reward accumulated by pool.
    ///     * `scale` - multiplier to handle decimals.
    ///     * `user_stake` - stake to update earnings.
    /// Returns new stake earnings.
    fun user_earned_since_last_update(
        accum_reward: u128,
        scale: u128,
        user_stake: &UserStake
    ): u128 {
        ((accum_reward * user_stake_amount(user_stake)) / scale)
            - user_stake.unobtainable_reward
    }

    /// Get time for last pool update: current time if the pool is not finished or end timmestamp.
    ///     * `pool` - pool to get time.
    /// Returns timestamp.
    fun get_time_for_last_update<S, R>(pool: &StakePool<S, R>, timestamp_now: u64): u64 {
        math::min(pool.end_timestamp, timestamp_now / 1000) //@todo review math div
    }

    /// Get total staked amount in the pool.
    ///     * `pool` - the pool itself.
    /// Returns amount.
    fun pool_total_staked<S, R>(pool: &StakePool<S, R>): u128 {
        (coin::value(&pool.stake_coins) as u128)
    }

    /// Get total staked amount by the user.
    ///     * `user_stake` - the user stake.
    /// Returns amount.
    fun user_stake_amount(user_stake: &UserStake): u128 {
        (user_stake.amount as u128)
    }

    //
    // Events
    //

    struct StakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u64,
    }

    struct UnstakeEvent has drop, store, copy {
        pool_id: address,
        user_address: address,
        amount: u64,
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
    }

    #[test_only]
    /// Access unobtainable_reward field in user stake.
    public fun get_unobtainable_reward<S, R>(
        pool: &StakePool<S, R>,
        user_addr: address
    ): u128 {
        table::borrow(&pool.stakes, user_addr).unobtainable_reward
    }

    #[test_only]
    /// Access staking pool fields with no getters.
    public fun get_pool_info<S, R>(pool: &StakePool<S, R>): (u64, u128, u64, u64, u128) {
        (pool.reward_per_sec,
            pool.accum_reward,
            pool.last_updated,
            coin::value<R>(&pool.reward_coins),
            pool.scale)
    }

    #[test_only]
    /// Force pool & user stake recalculations.
    public fun recalculate_user_stake<S, R>(pool: &mut StakePool<S, R>, user_addr: address, timestamp_ms: u64) {
        update_accum_reward(pool, timestamp_ms);

        let user_stake = table::borrow_mut(&mut pool.stakes, user_addr);
        update_user_earnings(pool.accum_reward, pool.scale, user_stake);
    }
}
