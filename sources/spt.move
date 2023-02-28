// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module seapad::spt {
    use sui::tx_context::{TxContext, sender};
    use sui::coin;
    use std::option;
    use sui::url;
    use std::ascii::{String, string};
    use sui::transfer;
    use sui::coin::TreasuryCap;
    use std::string;

    const SYMBOL: vector<u8> = b"SPT";
    const NAME: vector<u8> = b"SPT";
    const DESCRIPTION: vector<u8> = b"Seapad launchpad foundation token";
    const DECIMAL: u8 = 8;
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
    public entry fun minto(treasury_cap: &TreasuryCap<SPT>, to: address, amount: u128){

    }

    //@todo
    public entry fun updateSupply(treasury_cap: &TreasuryCap<SPT>, supply: u128){

    }

    //@todo
    public entry fun burn(treasury_cap: &TreasuryCap<SPT>, amount: u128){

    }
}
