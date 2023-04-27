module seapad::tokenomic {
    use sui::tx_context::{TxContext, sender};
    use sui::object::UID;
    use sui::object;
    use sui::transfer;
    use sui::coin::{Coin, TreasuryCap};
    use sui::clock::Clock;
    use sui::coin;
    use sui::transfer::{share_object, public_transfer, public_freeze_object};
    use sui::clock;
    use sui::table::Table;
    use sui::table;
    use std::vector;
    use sui::math;

    const MONTH_IN_MS: u64 =    2592000000;
    const TEN_YEARS_IN_MS: u64 =    311040000000;
    const ONE_HUNDRED_PERCENT_SCALED: u64 = 10000;

    const ERR_INVALID_TGE: u64 = 8001;
    const ERR_INVALID_SUPPLY: u64 = 8002;
    const ERR_INVALID_FUND_PARAMS: u64 = 8003;
    const ERR_TGE_NOT_STARTED: u64 = 8004;
    const ERR_BAD_VESTING_TIME: u64 = 8005;
    const ERR_NO_PERMISSION: u64 = 8006;
    const ERR_NO_MORE_COIN: u64 = 8007;

    struct TOKENOMIC has drop {}

    struct TAdmin has key, store {
        id: UID
    }

    struct TokenomicFund<phantom COIN> has store {
        owner: address, //owner of fund
        name: vector<u8>, //name
        share_percent: u64, //share of pie in percent * 100
        tge_ms: u64, //TGE timestamp
        tge_release_percent: u64, //released at tge, in %
        claim_start_ms: u64, //time to be able to claim.
        claim_end_ms: u64, //end tge

        last_claim_ms: u64,

        tge_fund: Coin<COIN>,
        vesting_fund_total: u64, //total of vesting fund, inited just one time, nerver change!
        vesting_fund: Coin<COIN>
    }

    struct TokenomicPie<phantom COIN> has key, store{
        id: UID,
        tge_ms: u64, //TGE timestamp
        total_supply: u64, //total supply of coin value, preset and nerver change!
        total_shared_percent: u64, //total pecent that shared by funds
        fund_remain: Coin<COIN>, //total supply preminted, reduced when distribute to sub fund!
        shares: Table<address, TokenomicFund<COIN>> //all shares
    }

    fun init(_witness: TOKENOMIC, ctx: &mut TxContext) {
        transfer::transfer(TAdmin { id: object::new(ctx) }, sender(ctx));
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TOKENOMIC {}, ctx);
    }

    public entry fun init_tokenomic<COIN>(_admin: &TAdmin,
                                          treasuryCap: TreasuryCap<COIN>,
                                          total_supply: u64,
                                          tge: u64,
                                          sclock: &Clock,
                                          ctx: &mut TxContext) {
        let preMint = coin::mint(&mut treasuryCap, total_supply, ctx);
        public_freeze_object(treasuryCap);
        init_tokenomic0(_admin, preMint, total_supply, tge, sclock, ctx);
    }

    #[test_only]
    public fun init_fund_for_test<COIN>(_admin: &TAdmin,
                                        pie: &mut TokenomicPie<COIN>,
                                        tge: u64,
                                        sclock: &Clock,
                                        ctx: &mut TxContext){
                addFund(_admin,
                    pie,
                    @seedFund,
                    b"Seed Fund",
                    tge,
                    1000,
                    500,
                    tge,
                    tge + 18*MONTH_IN_MS,
                    sclock,
                    ctx
                );

                addFund(_admin,
                    pie,
                    @privateFund,
                    b"Private Fund",
                    tge,
                    1200,
                    1000,
                    tge,
                    tge + 12*MONTH_IN_MS,
                    sclock,
                    ctx
                );

                addFund(_admin,
                    pie,
                    @publicFund,
                    b"Public(IDO) Fund",
                    tge,
                    300,
                    2500,
                    tge,
                    tge + 6*MONTH_IN_MS,
                    sclock,
                    ctx
                );

                addFund(_admin,
                    pie,
                    @foundationFund,
                    b"Foundation Fund",
                    tge,
                    1500,
                    0,
                    tge + 12* MONTH_IN_MS,
                    tge + 48*MONTH_IN_MS,
                    sclock,
                    ctx
                );


                addFund(_admin,
                    pie,
                    @advisorpartnerFund,
                    b"Advisor/Partner Fund",
                    tge,
                    500,
                    0,
                    tge + 12* MONTH_IN_MS,
                    tge + 36*MONTH_IN_MS,
                    sclock,
                    ctx
                );


                addFund(_admin,
                    pie,
                    @marketingFund,
                    b"Market Fund",
                    tge,
                    1200,
                    500,
                    tge,
                    tge + 36*MONTH_IN_MS,
                    sclock,
                    ctx
                );

                addFund(_admin,
                    pie,
                    @ecosystemFund,
                    b"Ecosystem Fund",
                    tge,
                    2800,
                    0,
                    tge,
                    tge + 60*MONTH_IN_MS,
                    sclock,
                    ctx
                );

                addFund(_admin,
                    pie,
                    @daoFund,
                    b"DAO Fund",
                    tge,
                    1500,
                    0,
                    tge + 24* MONTH_IN_MS,
                    tge + 36*MONTH_IN_MS,
                    sclock,
                    ctx
                );
    }
    public fun init_tokenomic0<COIN>(_admin: &TAdmin,
                                     genesis_mint: Coin<COIN>,
                                     total_supply: u64,
                                     tge: u64,
                                     sclock: &Clock,
                                     ctx: &mut TxContext){
        let now = clock::timestamp_ms(sclock);
        assert!(tge > now, ERR_INVALID_TGE);
        assert!(total_supply > 0 && total_supply == coin::value(&genesis_mint), ERR_INVALID_SUPPLY);

        let fund_remain = genesis_mint;

        let pie = TokenomicPie {
            id: object::new(ctx),
            tge_ms: tge,
            total_supply,
            fund_remain,
            total_shared_percent: 0u64,
            shares: table::new<address, TokenomicFund<COIN>>(ctx)
        };

//        addFund(_admin,
//            &mut pie,
//            @seedFund,
//            b"Seed Fund",
//            tge,
//            1000,
//            500,
//            tge,
//            tge + 18*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//        addFund(_admin,
//            &mut pie,
//            @privateFund,
//            b"Private Fund",
//            tge,
//            1200,
//            1000,
//            tge,
//            tge + 12*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//        addFund(_admin,
//            &mut pie,
//            @publicFund,
//            b"Public(IDO) Fund",
//            tge,
//            300,
//            2500,
//            tge,
//            tge + 6*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//        addFund(_admin,
//            &mut pie,
//            @foundationFund,
//            b"Foundation Fund",
//            tge,
//            1500,
//            0,
//            tge + 12* MONTH_IN_MS,
//            tge + 48*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//
//        addFund(_admin,
//            &mut pie,
//            @advisorpartnerFund,
//            b"Advisor/Partner Fund",
//            tge,
//            500,
//            0,
//            tge + 12* MONTH_IN_MS,
//            tge + 36*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//
//        addFund(_admin,
//            &mut pie,
//            @marketingFund,
//            b"Market Fund",
//            tge,
//            1200,
//            500,
//            tge,
//            tge + 36*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//        addFund(_admin,
//            &mut pie,
//            @ecosystemFund,
//            b"Ecosystem Fund",
//            tge,
//            2800,
//            0,
//            tge,
//            tge + 60*MONTH_IN_MS,
//            sclock,
//            ctx
//        );
//
//        addFund(_admin,
//            &mut pie,
//            @daoFund,
//            b"DAO Fund",
//            tge,
//            1500,
//            0,
//            tge + 24* MONTH_IN_MS,
//            tge + 36*MONTH_IN_MS,
//            sclock,
//            ctx
//        );

        share_object(pie);
    }


    public entry fun addFund<COIN>(_admin: &TAdmin,
                                   pie: &mut TokenomicPie<COIN>,
        owner: address,
        name: vector<u8>,
        tge_ms: u64,
        share_percent: u64,
        tge_release_percent: u64,
        claim_start_ms: u64,
        claim_end_ms: u64,
        sclock: &Clock,
        ctx: &mut TxContext
    )
    {
        let now = clock::timestamp_ms(sclock);
        assert!(tge_ms >= now
            && (vector::length<u8>(&name) > 0)
            && (share_percent > 0 && share_percent <= 10000)
            && (tge_release_percent >= 0 && tge_release_percent <= 10000)
            && (claim_start_ms >= now && claim_start_ms >= tge_ms)
            && (claim_end_ms > claim_start_ms && claim_end_ms - claim_start_ms <= TEN_YEARS_IN_MS)
            && (ONE_HUNDRED_PERCENT_SCALED - pie.total_shared_percent >= share_percent),
            ERR_INVALID_FUND_PARAMS);

        pie.total_shared_percent = pie.total_shared_percent + share_percent;

        let fundAmt = (pie.total_supply * share_percent)/ ONE_HUNDRED_PERCENT_SCALED;
        let fundCoin = coin::split(&mut pie.fund_remain, fundAmt, ctx);

        let tgeFundCoin = if(tge_release_percent == 0){
                coin::zero<COIN>(ctx)
            }
            else {
                coin::split(&mut fundCoin, (fundAmt * tge_release_percent)/ ONE_HUNDRED_PERCENT_SCALED, ctx)
            };

        let fund =  TokenomicFund<COIN> {
                owner,
                name,
                share_percent,
                tge_ms,
                tge_release_percent,
                claim_start_ms,
                claim_end_ms,

                last_claim_ms: 0u64,

                tge_fund: tgeFundCoin,
                vesting_fund_total: coin::value(& fundCoin),
                vesting_fund: fundCoin
            };

        table::add(&mut pie.shares, owner, fund);
    }

    //Claim fund!
    //Support multiple claim
    public entry fun claim<COIN>(pie: &mut TokenomicPie<COIN>, sclock: &Clock, ctx: &mut TxContext){
        let now_ms = clock::timestamp_ms(sclock);
        assert!(now_ms >= pie.tge_ms, ERR_INVALID_TGE);

        let senderAddr = sender(ctx);
        assert!(table::contains(&pie.shares, senderAddr), ERR_NO_PERMISSION);

        let fund = table::borrow_mut(&mut pie.shares, senderAddr);

        assert!(senderAddr == fund.owner, ERR_NO_PERMISSION);
        assert!(fund.share_percent > 0, ERR_INVALID_FUND_PARAMS);
        assert!(now_ms >= fund.tge_ms, ERR_TGE_NOT_STARTED);

        let tgeFundAmt = coin::value(&fund.tge_fund);
        let claimedCoin = if(tgeFundAmt <= 0){ coin::zero<COIN>(ctx) } else { coin::split(&mut fund.tge_fund, tgeFundAmt, ctx) };

        claimedCoin = if(now_ms < fund.claim_start_ms){
            claimedCoin
        }
        else if(now_ms >= fund.claim_end_ms){
            let vestingAvail = coin::value(&fund.vesting_fund);
            if(vestingAvail > 0){
                coin::join(&mut claimedCoin, coin::split(&mut fund.vesting_fund, vestingAvail , ctx));
            };
            claimedCoin
        }
        else {
            let effectiveLastClaimTime = if(fund.last_claim_ms <= fund.claim_start_ms) { fund.claim_start_ms } else{ fund.last_claim_ms };
            assert!(now_ms >= effectiveLastClaimTime, ERR_BAD_VESTING_TIME);

            let claimValue =  (now_ms - effectiveLastClaimTime) * fund.vesting_fund_total/(fund.claim_end_ms - fund.claim_start_ms);
            let vestingAvail = coin::value(&fund.vesting_fund);
            coin::join(&mut claimedCoin, coin::split(&mut fund.vesting_fund, math::min(claimValue, vestingAvail), ctx));
            claimedCoin
        };

        fund.last_claim_ms = now_ms;

        assert!(coin::value(&claimedCoin) > 0, ERR_NO_MORE_COIN);

        public_transfer(claimedCoin, senderAddr);
    }


    ///change one fund owner to other owner
    ///CRITICAL!!!
    public entry fun change_fund_owner<COIN>(pie: &mut TokenomicPie<COIN>, to: address, ctx: &mut TxContext){
        let senderAddr = sender(ctx);
        assert!(table::contains(&pie.shares, senderAddr)
            && !table::contains(&pie.shares, to), ERR_NO_PERMISSION);

        let fund = table::borrow_mut<address, TokenomicFund<COIN>>(&mut pie.shares, senderAddr);
        fund.owner = to;

        let fund2 = table::remove<address, TokenomicFund<COIN>>(&mut pie.shares, senderAddr);
        table::add<address, TokenomicFund<COIN>>(&mut pie.shares, to, fund2);
    }

    public fun getTotalSupply<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_supply
    }

    public fun getTotalSharePercent<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_shared_percent
    }

    public fun getTGETimeMs<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.tge_ms
    }

    public fun getFundRemain<COIN>(pie: &TokenomicPie<COIN>): u64{
        coin::value(&pie.fund_remain)
    }

    public fun getShareFundReleasedAtTGE<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        coin::value(&share.tge_fund)
    }

    public fun getShareFundVestingAvailable<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        coin::value(&share.vesting_fund)
    }
}
