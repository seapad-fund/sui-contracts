module seapad::version {
    use sui::object::{UID, id, ID};
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::object;
    use sui::transfer::share_object;

    #[test_only]
    use sui::object::id_from_address;

    const VERSION_INIT: u64 = 1;

    const ERR_WRONG_VERSION: u64 = 1001;
    const ERR_NOT_ADMIN: u64 = 1002;

    struct VERSION has drop {}


    struct VAdminCap has key, store {
        id: UID
    }

    struct Version has key, store {
        id: UID,
        version: u64,
        admin: ID
    }

    fun init(_witness: VERSION, ctx: &mut TxContext) {
        let adminCap = VAdminCap { id: object::new(ctx) };
        let adminCapId = id(&adminCap);
        transfer::transfer( adminCap, sender(ctx));
        share_object(Version {
            id: object::new(ctx),
            version: VERSION_INIT,
            admin: adminCapId
        })
    }

    public fun checkVersion(version: &Version, modVersion: u64) {
        assert!(modVersion == version.version, ERR_WRONG_VERSION)
    }

    public entry fun migrate(admin: &VAdminCap, ver: &mut Version, newVer: u64 ){
        assert!(object::id(admin) == ver.admin, ERR_NOT_ADMIN);
        assert!(newVer > ver.version, ERR_WRONG_VERSION);
        ver.version = newVer
    }

    #[test_only]
    public fun versionForTest(ctx: &mut TxContext): Version {
        Version {
            id:  object::new(ctx),
            version: VERSION_INIT,
            admin: id_from_address(@0xCAFFE)
        }
    }

    #[test_only]
    public fun initForTest(ctx: &mut TxContext) {
        init(VERSION {}, ctx);
    }

    #[test_only]
    public fun destroyForTest(version: Version) {
        let Version {
            id,
            version: _version,
            admin: _admin
        } = version;

        object::delete(id);
    }
}