// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: GPL-3.0

module common::kyc {
    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::object;
    use std::vector;
    use sui::transfer::transfer;
    use sui::event::emit;
    use sui::table::Table;
    use sui::table;

    struct KYC has drop {}

    struct AdminCap has key, store {
        id: UID
    }

    const KYC_LEVEL_ONE: u8 = 1;
    const KYC_LEVEL_TWO: u8 = 2;
    const KYC_LEVEL_THREE: u8 = 3;
    const KYC_LEVEL_FOUR: u8 = 4;

    const ERR_ALREADY_KYC: u64 = 1001;
    const ERR_NOT_KYC: u64 = 1002;
    const ERR_BAD_PARAMS: u64 = 1003;

    struct Kyc has key, store {
        id: UID,
        whitelist: Table<address, u8>
    }

    fun init(_witness: KYC, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, sender(ctx));

        transfer::share_object(Kyc {
            id: object::new(ctx),
            whitelist: table::new<address, u8>(ctx),
        });
    }

    public entry fun change_admin(admin_cap: AdminCap, to: address) {
        transfer(admin_cap, to);
    }

    public entry fun add(_admin_cap: &AdminCap, users: vector<address>, kyc: &mut Kyc){
        assert!(vector::length(&users) > 0, ERR_BAD_PARAMS);
        emit(AddKycEvent {
            users
        });

        while (!vector::is_empty(&users)) {
            let userAddr = vector::pop_back(&mut users);
            assert!(!table::contains(&kyc.whitelist, userAddr), ERR_ALREADY_KYC);
            table::add(&mut kyc.whitelist, userAddr, KYC_LEVEL_ONE);
        };
    }

    public entry fun remove(_admin_cap: &AdminCap, users: vector<address>, kyc: &mut Kyc){
        assert!(vector::length(&users) > 0, ERR_BAD_PARAMS);
        emit(RemoveKycEvent {
            users
        });
        while (!vector::is_empty(&users)) {
            let userAddr = vector::pop_back(&mut users);
            assert!(table::contains(&kyc.whitelist, userAddr), ERR_NOT_KYC);
            table::remove(&mut kyc.whitelist, userAddr);
        };
    }

    public fun hasKYC(user: address, kyc: &Kyc): bool{
        table::contains(&kyc.whitelist, user)
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