// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module seapad::tra {
    use std::ascii::string;
    use std::option;

    use w3libs::payment;

    use sui::balance;
    use sui::coin::{Self, TreasuryCap, Coin};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::url;

    const SYMBOL: vector<u8> = b"TRA";
    const NAME: vector<u8> = b"TRA";
    const DESCRIPTION: vector<u8> = b"Trantor Network";
    const DECIMAL: u8 = 9;
    const ICON_URL: vector<u8> = b"https://seapad.s3.ap-southeast-1.amazonaws.com/uploads/PROD/public/media/images/logo_1681993251675.jpeg";

    struct TRA has drop {}

    ///initialize SPT
    fun init(witness: TRA, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<TRA>(
            witness,
            DECIMAL,
            SYMBOL,
            NAME,
            DESCRIPTION,
            option::some(url::new_unsafe(string(ICON_URL))),
            ctx);

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, sender(ctx));
    }

    public entry fun minto(treasury_cap: &mut TreasuryCap<TRA>, to: address, amount: u64, ctx: &mut TxContext) {
        coin::mint_and_transfer(treasury_cap, amount, to, ctx);
    }

    public entry fun increase_supply(treasury_cap: &mut TreasuryCap<TRA>, value: u64, ctx: &mut TxContext) {
        minto(treasury_cap, sender(ctx), value, ctx);
    }

    public entry fun decrease_supply(
        treasury_cap: &mut TreasuryCap<TRA>,
        coins: vector<Coin<TRA>>,
        value: u64,
        ctx: &mut TxContext
    ) {
        let take = payment::take_from(coins, value, ctx);

        let total_supply = coin::supply_mut(treasury_cap);
        balance::decrease_supply(total_supply, coin::into_balance(take));
    }

    public entry fun burn(treasury_cap: &mut TreasuryCap<TRA>,
                          coins: vector<Coin<TRA>>,
                          value: u64,
                          ctx: &mut TxContext) {
        let take = payment::take_from(coins, value, ctx);
        coin::burn(treasury_cap, take);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TRA {}, ctx);
    }
}
