// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: GPL-3.0

module seapad::stake_config {
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::object::UID;
    use sui::object;

    const ERR_NO_PERMISSIONS: u64 = 200;
    const ERR_NOT_INITIALIZED: u64 = 201;
    const ERR_GLOBAL_EMERGENCY: u64 = 202;

    struct STAKE_CONFIG has drop {}
    struct GlobalConfig has key, store {
        id: UID,
        emergency_admin_address: address,
        treasury_admin_address: address,
        global_emergency_locked: bool,
    }

    fun init(_witness: STAKE_CONFIG, ctx: &mut TxContext){
        assert!(sender(ctx) == @stake_emergency_admin, ERR_NO_PERMISSIONS);
        transfer::share_object(GlobalConfig {
            id: object::new(ctx),
            emergency_admin_address: @stake_emergency_admin,
            treasury_admin_address: @treasury_admin,
            global_emergency_locked: false,
        })
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(STAKE_CONFIG {}, ctx)
    }

    /// Sets `emergency_admin` account.
    public fun set_emergency_admin_address(global_config: &mut GlobalConfig, new_address: address, ctx: &mut TxContext) {
        assert!(sender(ctx) == global_config.emergency_admin_address, ERR_NO_PERMISSIONS);
        global_config.emergency_admin_address = new_address;
    }

    /// Gets current address of `emergency_admin` account.
    public fun get_emergency_admin_address(global_config: &GlobalConfig): address {
        global_config.emergency_admin_address
    }

    /// Sets `treasury_admin` account.
    public fun set_treasury_admin_address(global_config: &mut GlobalConfig, new_address: address, ctx: &mut TxContext) {
        assert!(sender(ctx) == global_config.treasury_admin_address, ERR_NO_PERMISSIONS);
        global_config.treasury_admin_address = new_address;
    }

    /// Gets current address of `treasury admin` account.
    public fun get_treasury_admin_address(global_config: &GlobalConfig): address {
        global_config.treasury_admin_address
    }

    /// Enables "global emergency state". All the pools' operations are disabled except for `emergency_unstake()`.
    /// This state cannot be disabled, use with caution.
    public fun enable_global_emergency(global_config: &mut GlobalConfig, ctx: &mut TxContext) {
        assert!(sender(ctx) == global_config.emergency_admin_address, ERR_NO_PERMISSIONS);
        assert!(!global_config.global_emergency_locked, ERR_GLOBAL_EMERGENCY);
        global_config.global_emergency_locked = true;
    }

    /// Checks whether global "emergency state" is enabled.
    /// Returns true if emergency enabled.
    public fun is_global_emergency(global_config: &GlobalConfig): bool {
        global_config.global_emergency_locked
    }
}
