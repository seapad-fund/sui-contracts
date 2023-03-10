// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module seapad::spt {
    use std::ascii::string;
    use std::option;

    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::url;

    const SYMBOL: vector<u8> = b"SPT";
    const NAME: vector<u8> = b"SPT";
    const DESCRIPTION: vector<u8> = b"Seapad launchpad foundation token";
    const DECIMAL: u8 = 9;
    const ICON_URL: vector<u8> = b"https://docs.seapad.fund/icon.png";

    struct SPT has drop {}

    ///initialize SPT
    fun init(witness: SPT, ctx: &mut TxContext){
        let (treasury_cap, spt_metadata) = coin::create_currency<SPT>(
            witness, DECIMAL,  SYMBOL, NAME, DESCRIPTION, option::some(url::new_unsafe(string(ICON_URL))), ctx);

        transfer::transfer(treasury_cap, sender(ctx));
        transfer::freeze_object(spt_metadata);
    }

    //@todo
    public entry fun minto(_treasury_cap: &TreasuryCap<SPT>, _to: address, _amount: u128){

    }

    //@todo
    public entry fun updateSupply(_treasury_cap: &TreasuryCap<SPT>, _supply: u128){

    }

    //@todo
    public entry fun burn(_treasury_cap: &TreasuryCap<SPT>, _amount: u128){

    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SPT {}, ctx);
    }
}
