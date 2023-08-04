// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: GPL-3.0

module seapad::stake_entries {
    use seapad::stake;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Coin};
    use seapad::stake_config::GlobalConfig;
    use sui::clock::Clock;
    use seapad::stake::StakePool;
    use sui::transfer;
    use seapad::stake_config;

    /// Register new staking pool with staking coin `S` and reward coin `R`.
    public entry fun register_pool<S, R>(rewards: Coin<R>,
                                         duration_sec: u64,
                                         global_config: &GlobalConfig,
                                         decimalS: u8,
                                         decimalR: u8,
                                         clock: &Clock,
                                         duration_unstake_time_ms: u64,
                                         max_stake_value: u64,
                                         ctx: &mut TxContext) {
        stake::register_pool<S, R>(
            rewards,
            duration_sec,
            global_config,
            decimalS,
            decimalR,
            clock,
            duration_unstake_time_ms,
            max_stake_value,
            ctx
        );
    }

    /// Stake an `amount` of `Coin<S>` to the pool of stake coin `S` and reward coin `R` on the address `pool_addr`.
    public entry fun stake<S, R>(pool: &mut StakePool<S, R>,
                                 coins: Coin<S>,
                                 global_config: &GlobalConfig,
                                 clock: &Clock,
                                 ctx: &mut TxContext) {
        stake::stake<S, R>(pool, coins, global_config, clock, ctx);
    }

    /// Unstake an `amount` of `Coin<S>` from a pool of stake coin `S` and reward coin `R` `pool`.
    public entry fun unstake<S, R>(pool: &mut StakePool<S, R>,
                                   stake_amount: u64,
                                   global_config: &GlobalConfig,
                                   clock: &Clock,
                                   ctx: &mut TxContext) {
        let coins = stake::unstake<S, R>(pool, stake_amount, global_config, clock, ctx);
        transfer::public_transfer(coins, sender(ctx));
    }

    /// Collect `user` rewards on the pool
    public entry fun harvest<S, R>(pool: &mut StakePool<S, R>,
                                   global_config: &GlobalConfig,
                                   clock: &Clock,
                                   ctx: &mut TxContext) {
        let rewards = stake::harvest<S, R>(pool, global_config, clock, ctx);
        transfer::public_transfer(rewards, sender(ctx));
    }

    /// Deposit more `Coin<R>` rewards to the pool.
    public entry fun deposit_reward_coins<S, R>(pool: &mut StakePool<S, R>,
                                                reward_coins: Coin<R>,
                                                global_config: &GlobalConfig,
                                                clock: &Clock,
                                                ctx: &mut TxContext) {
        stake::deposit_reward_coins<S, R>(pool, reward_coins, global_config,  clock, ctx);
    }

    /// Enable "emergency state" for a pool on a `pool_addr` address. This state cannot be disabled
    /// and removes all operations except for `emergency_unstake()`, which unstakes all the coins for a user.
    public entry fun enable_emergency<S, R>(pool: &mut StakePool<S, R>,
                                            global_config: &GlobalConfig,
                                            ctx: &mut TxContext) {
        stake::enable_emergency<S, R>(pool, global_config, ctx);
    }

    /// Unstake coins and boost of the user and deposit to user account.
    /// Only callable in "emergency state".
    public entry fun emergency_unstake<S, R>(pool: &mut StakePool<S, R>,
                                             global_config: &GlobalConfig,
                                             ctx: &mut TxContext) {
        let stake_coins = stake::emergency_unstake<S, R>(pool, global_config, ctx);
        transfer::public_transfer(stake_coins, sender(ctx));
    }

    /// Withdraw and deposit rewards to treasury.
    public entry fun withdraw_reward_to_treasury<S, R>(pool: &mut StakePool<S, R>,
                                                       amount: u64,
                                                       global_config: &GlobalConfig,
                                                       clock: &Clock,
                                                       ctx: &mut TxContext) {
        let treasury_addr = sender(ctx);
        let rewards = stake::withdraw_to_treasury<S, R>(
            pool,
            amount,
            global_config,
            clock,
            ctx
        );
        transfer::public_transfer(rewards, treasury_addr);
    }

    public entry fun enable_global_emergency(global_config: &mut GlobalConfig, ctx: &mut TxContext) {
        stake_config::enable_global_emergency(global_config, ctx);
    }

    public entry fun set_treasury_admin_address(
        global_config: &mut GlobalConfig,
        new_address: address,
        ctx: &mut TxContext
    ) {
        stake_config::set_treasury_admin_address(global_config, new_address, ctx);
    }

    public entry fun set_emergency_admin_address(
        global_config: &mut GlobalConfig,
        new_address: address,
        ctx: &mut TxContext
    ) {
        stake_config::set_emergency_admin_address(global_config, new_address, ctx);
    }
}
