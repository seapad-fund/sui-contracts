module common::kyc {

    use sui::object::UID;
    use sui::vec_set;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::object;
    use sui::vec_set::VecSet;
    use std::vector;
    use sui::transfer::public_transfer;
    use sui::event::emit;


    ///Witness
    struct KYC has drop {}

    struct AdminCap has key, store {
        id: UID
    }

    struct Kyc has key, store {
        id: UID,
        whitelist: VecSet<address>
    }

    fun init(_witness: KYC, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, sender(ctx));

        transfer::share_object(Kyc {
            id: object::new(ctx),
            whitelist: vec_set::empty<address>(),
        });
    }

    public entry fun change_admin(admin_cap: AdminCap, to: address) {
        public_transfer(admin_cap, to);
    }

    public entry fun add(_admin_cap: &AdminCap, users: vector<address>, kyc: &mut Kyc){
        let (i, n) = (0, vector::length(& users));
        let users_copy = vector::empty<address>();
        vector::append(&mut users_copy, users);

        while (i < n){
            let user = vector::pop_back(&mut users);
            assert!(!vec_set::contains(&kyc.whitelist, &user), 0);
            vec_set::insert(&mut kyc.whitelist, user);

            i = i + 1;
        };

        emit(AddKycEvent {
            users: users_copy
        })
    }

    public entry fun remove(_admin_cap: &AdminCap, users: vector<address>, kyc: &mut Kyc){
        let (i, n) = (0, vector::length(& users));
        let users_copy = vector::empty<address>();
        vector::append(&mut users_copy, users);

        while (i < n){
            let user = vector::pop_back(&mut users);
            assert!(vec_set::contains(&kyc.whitelist, &user), 0);
            vec_set::remove(&mut kyc.whitelist, &user);

            i = i + 1;
        };

        emit(RemoveKycEvent {
            users: users_copy
        })
    }

    public fun hasKYC(user: address, kyc: &Kyc): bool{
        vec_set::contains(&kyc.whitelist, &user)
    }

    struct AddKycEvent has copy, drop {
        users: vector<address>
    }

    struct RemoveKycEvent has copy, drop {
        users: vector<address>
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext){
        init(KYC{}, ctx);
    }
}