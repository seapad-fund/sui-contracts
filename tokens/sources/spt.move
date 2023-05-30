// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: GPL-3.0

module seapad::spt {
    use std::ascii::{string, into_bytes};
    use std::option;

    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::url;
    use sui::transfer::{public_freeze_object};
    use sui::object::id_address;
    use std::type_name;
    use sui::event::emit;

    const SYMBOL: vector<u8> = b"SPT";
    const NAME: vector<u8> = b"SPT";
    const DESCRIPTION: vector<u8> = b"Seapad launchpad foundation token";
    const DECIMAL: u8 = 9;
    const ICON_URL: vector<u8> = b"https://seapad.s3.ap-southeast-1.amazonaws.com/uploads/TEST/public/media/images/logo_1679906850804.png";

    struct SPT has drop {}

    struct TreasuryBurnedEvent has drop, copy, store {
        owner: address,
        treasury_id: address,
        name: vector<u8>
    }

    fun init(witness: SPT, ctx: &mut TxContext) {
        let (treasury_cap, spt_metadata) = coin::create_currency<SPT>(
            witness,
            DECIMAL,
            SYMBOL,
            NAME,
            DESCRIPTION,
            option::some(url::new_unsafe(string(ICON_URL))),
            ctx);

        transfer::public_freeze_object(spt_metadata);
        transfer::public_transfer(treasury_cap, @treasury);
    }

    public entry fun burn_cap(treasuryCap: TreasuryCap<SPT>, ctx: &mut TxContext){
        let burnEvent = TreasuryBurnedEvent {
            owner: sender(ctx),
            treasury_id: id_address(&treasuryCap),
            name:  into_bytes(type_name::into_string(type_name::get<SPT>()))
        };
        public_freeze_object(treasuryCap);
        emit(burnEvent);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SPT {}, ctx);
    }
}
