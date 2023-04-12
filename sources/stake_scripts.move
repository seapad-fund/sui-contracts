/// Collection of entrypoints to handle staking pools.
module staking::stake_scripts {
    use staking::stake;
    use staking::stake_config;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Coin, CoinMetadata};
    use staking::stake_config::{GlobalConfig};
    use staking::stake::StakePool;
    use sui::transfer;
    use sui::clock::Clock;

    /// Register new staking pool with staking coin `S` and reward coin `R`.
    ///     * `rewards` - reward amount in R coins.
    ///     * `duration` - pool life duration in seconds, can be increased by depositing more rewards.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun register_pool<S, R>(
        name: vector<u8>,
        rewards: Coin<R>,
        duration_seconds: u64,
        global_config: &GlobalConfig,
        coin_metadata_s: &CoinMetadata<S>,
        coin_metadata_r: &CoinMetadata<R>,
        clock: &Clock,
        ctx: &mut TxContext) {
        stake::register_pool<S, R>(name, rewards, duration_seconds, global_config, coin_metadata_s, coin_metadata_r, clock, ctx);
    }

    /// Stake an `amount` of `Coin<S>` to the pool of stake coin `S` and reward coin `R` on the address `pool_addr`.
    ///     * `pool` - the pool to stake.
    ///     * `coins` - coins to stake.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun stake<S, R>(pool: &mut StakePool<S, R>,
                                 coins: Coin<S>,
                                 global_config: &GlobalConfig,
                                 clock: &Clock,
                                 ctx: &mut TxContext) {
        stake::stake<S, R>(pool, coins, global_config, clock, ctx);
    }

    /// Unstake an `amount` of `Coin<S>` from a pool of stake coin `S` and reward coin `R` `pool`.
    ///     * `pool` - address of the pool to unstake.
    ///     * `stake_amount` - amount of `S` coins to unstake.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun unstake<S, R>(pool: &mut StakePool<S, R>,
                                   stake_amount: u64,
                                   global_config: &GlobalConfig,
                                   clock: &Clock,
                                   ctx: &mut TxContext) {
        let coins = stake::unstake<S, R>(pool, stake_amount, global_config, clock, ctx);
        transfer::public_transfer(coins, sender(ctx));
    }

    /// Collect `user` rewards on the pool at the `pool_addr`.
    ///     * `pool` - the pool.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun harvest<S, R>(pool: &mut StakePool<S, R>,
                                   global_config: &GlobalConfig,
                                   clock: &Clock,
                                   ctx: &mut TxContext) {
        let rewards = stake::harvest<S, R>(pool, global_config, clock, ctx);
        transfer::public_transfer(rewards, sender(ctx));
    }

    /// Deposit more `Coin<R>` rewards to the pool.
    ///     * `pool` - address of the pool.
    ///     * `reward_coins` - reward coin `R` to deposit.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet

    public entry fun deposit_reward_coins<S, R>(pool: &mut StakePool<S, R>,
                                                reward_coins: Coin<R>,
                                                global_config: &GlobalConfig,
                                                clock: &Clock,
                                                ctx: &mut TxContext) {
        stake::deposit_reward_coins<S, R>(pool, reward_coins, global_config, clock, ctx);
    }

    /// Enable "emergency state" for a pool on a `pool_addr` address. This state cannot be disabled
    /// and removes all operations except for `emergency_unstake()`, which unstakes all the coins for a user.
    ///     * `global_config` - shared/guarded global config.
    ///     * `pool` - the pool.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun enable_emergency<S, R>(pool: &mut StakePool<S, R>,
                                            global_config: &GlobalConfig,
                                            ctx: &mut TxContext) {
        stake::enable_emergency<S, R>(pool, global_config, ctx);
    }

    /// Unstake coins and boost of the user and deposit to user account.
    /// Only callable in "emergency state".
    ///     * `global_config` - shared/guarded global config.
    ///     * `pool` - the pool.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun emergency_unstake<S, R>(pool: &mut StakePool<S, R>,
                                             global_config: &GlobalConfig,
                                             ctx: &mut TxContext) {
        let stake_coins = stake::emergency_unstake<S, R>(pool, global_config, ctx);
        transfer::public_transfer(stake_coins, sender(ctx));
    }

    /// Withdraw and deposit rewards to treasury.
    ///     * `pool` - the pool.
    ///     * `amount` - amount to withdraw.
    /// @fixme due to devnet not supported to inject &Clock opject, just mock timestamp now for devnet
    public entry fun withdraw_reward_to_treasury<S, R>(pool: &mut StakePool<S, R>,
                                                       amount: u64,
                                                       global_config: &GlobalConfig,
                                                       clock: &Clock,
                                                       ctx: &mut TxContext) {
        let treasury_addr = sender(ctx);
        let rewards = stake::withdraw_to_treasury<S, R>(pool, amount, global_config, clock, ctx);
        transfer::public_transfer(rewards, treasury_addr);
    }

    /// Sets `emergency_admin` account.
   /// Should be signed with current `emergency_admin` account.
   ///     * `stake_admin` - current emergency admin account.
   ///     * `new_address` - new emergency admin address.
    public entry fun set_stake_admin_address(global_config: &mut GlobalConfig, new_address: address, ctx: &mut TxContext) {
        stake_config::set_stake_admin_address(global_config, new_address, ctx);
    }


    /// Sets `treasury_admin` account.
    /// Should be signed with current `treasury_admin` account.
    ///     * `global_config` - current treasury admin account.
    ///     * `new_address` - new treasury admin address.
    ///     * ctx: current treasury_admin
    public entry fun set_treasury_admin_address(global_config: &mut GlobalConfig, new_address: address, ctx: &mut TxContext) {
        stake_config::set_treasury_admin_address(global_config, new_address, ctx);
    }

    /// Enables "global emergency state". All the pools' operations are disabled except for `emergency_unstake()`.
    /// This state cannot be disabled, use with caution.
    ///     * `emergency_admin` - current emergency admin account.
    public entry fun enable_global_emergency(global_config: &mut GlobalConfig, ctx: &mut TxContext) {
        stake_config::enable_global_emergency(global_config, ctx);
    }
}
