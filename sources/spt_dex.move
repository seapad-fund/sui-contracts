// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module seapad::spt_dex {
    use sui::tx_context::{TxContext, sender};
    use seapad::dex;
    use sui::coin;
    use std::option;
    use sui::transfer;
    use sui::object::UID;
    use sui::object;
    use sui::coin::{Coin, TreasuryCap};
    use sui::sui::SUI;
    use seapad::dex::Pool;

    ///witness
    struct INFI_POOL has drop {}

    ///token
    struct SPT_DEX has drop {}

    ///admin cap
    struct AdminCap has key {id: UID}

    const PRE_MINTED_SPT: u64 = 100000000000;

    /// Init token
    /// Set admin role
    fun init(witness: SPT_DEX, ctx: &mut TxContext) {
        transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
        let (treasury_cap, metadata) =
            coin::create_currency<SPT_DEX>(
                witness,
                5,
                b"INFINITY_DEX",
                b"infinity_dex",
                b"infinity dex token",
                option::none(),
                ctx);
        transfer::freeze_object(metadata);
        transfer::transfer(treasury_cap, sender(ctx));
    }

    /// Create new pool
    entry fun createPool(_adminCap : &mut AdminCap, treasuryCap : &mut TreasuryCap<SPT_DEX>, liquidSui: Coin<SUI>, ctx: &mut TxContext){
        //create pool & save lsp
        let liquidToken = coin::mint(treasuryCap, 1000000000, ctx);
        let lsp = dex::create_pool(INFI_POOL {}, liquidToken, liquidSui, 1, ctx);
        transfer::transfer(lsp, sender(ctx));
    }

    entry fun mintToken(_adminCap : &mut AdminCap, treasuryCap : &mut TreasuryCap<SPT_DEX>, to: address, amt: u64, ctx: &mut TxContext){
        let token = coin::mint(treasuryCap, amt, ctx);
        transfer::transfer(token, to);
    }

    entry fun addLiquid(xpool: &mut Pool<INFI_POOL, SPT_DEX>, token: Coin<SPT_DEX>, sui: Coin<SUI>, ctx: &mut TxContext){
        transfer::transfer(dex::add_liquidity(xpool, sui, token, ctx), sender(ctx));
    }

    entry fun swapSui(xpool: &mut Pool<INFI_POOL, SPT_DEX>, sui: Coin<SUI>, ctx: &mut TxContext){
        transfer::transfer(dex::swap_sui(xpool, sui, ctx), sender(ctx));
    }

    entry fun swapToken(xpool: &mut Pool<INFI_POOL, SPT_DEX>, sui: Coin<SPT_DEX>, ctx: &mut TxContext){
        transfer::transfer(dex::swap_token(xpool, sui, ctx), sender(ctx));
    }
}
