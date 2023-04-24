module seapad::nftbox_config {
    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::object;

    const ERR_NO_PERMISSIONS: u64 = 200;
    const ERR_NOT_INITIALIZED: u64 = 201;
    const ERR_GLOBAL_EMERGENCY: u64 = 202;

    struct NFTBOX_CONFIG has drop {}

    struct NftBoxConfig has key, store {
        id: UID,
        admin: address,
        treasury_admin: address,
        escrow_admin: address,
        emergency: bool,
    }

    fun init(_witness: NFTBOX_CONFIG, ctx: &mut TxContext){
        assert!(sender(ctx) == @nftbox_admin, ERR_NO_PERMISSIONS);
        transfer::share_object(NftBoxConfig {
            id: object::new(ctx),
            admin: @nftbox_admin,
            treasury_admin: @nftbox_treasury_admin,
            escrow_admin: @nftbox_escrow_admin,
            emergency: false,
        })
    }


    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(NFTBOX_CONFIG {}, ctx)
    }

    public fun set_admin(config: &mut NftBoxConfig, new_address: address, ctx: &mut TxContext) {
        assert!(sender(ctx) == config.admin, ERR_NO_PERMISSIONS);
        config.admin = new_address;
    }

    public fun get_admin(config: &NftBoxConfig): address {
        config.admin
    }

    public fun set_treasury_admin_address(config: &mut NftBoxConfig, new_address: address, ctx: &mut TxContext) {
        assert!(sender(ctx) == config.treasury_admin, ERR_NO_PERMISSIONS);
        config.treasury_admin = new_address;
    }

    public fun get_treasury_admin_address(config: &NftBoxConfig): address {
        config.treasury_admin
    }

    public fun get_escrow_admin(config: &NftBoxConfig): address {
        config.escrow_admin
    }

    public fun set_escrow_admin(config: &mut NftBoxConfig, new_address: address, ctx: &mut TxContext) {
        assert!(sender(ctx) == config.escrow_admin, ERR_NO_PERMISSIONS);
        config.escrow_admin = new_address;
    }

    public fun enable_emergency(config: &mut NftBoxConfig, ctx: &mut TxContext) {
        assert!(sender(ctx) == config.admin, ERR_NO_PERMISSIONS);
        assert!(!config.emergency, ERR_GLOBAL_EMERGENCY);
        config.emergency = true;
    }

    public fun is_emergency(config: &NftBoxConfig): bool {
        config.emergency
    }
}
