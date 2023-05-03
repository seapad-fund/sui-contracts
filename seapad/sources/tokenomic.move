module seapad::tokenomic {
    use sui::tx_context::{TxContext, sender};
    use sui::object::UID;
    use sui::object;
    use sui::transfer;
    use sui::coin::{Coin};
    use sui::clock::Clock;
    use sui::coin;
    use sui::transfer::{share_object, public_transfer, transfer};
    use sui::clock;
    use sui::table::Table;
    use sui::table;
    use std::vector;
    use sui::math;
    use w3libs::u256;

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

    struct TAdminCap has key, store {
        id: UID
    }

    struct TokenomicFund<phantom COIN> has store {
        owner: address, //owner of fund
        name: vector<u8>, //name
        tge_ms: u64, //TGE timestamp
        tge_release_percent: u64, //released at tge, in %
        claim_start_ms: u64, //time to be able to claim.
        claim_end_ms: u64, //end tge
        last_claim_ms: u64,
        tge_fund: Coin<COIN>,
        vesting_fund_total: u64, //total of vesting fund, inited just one time, nerver change!
        vesting_fund: Coin<COIN>,
        fund_percent: u64
    }

    struct TokenomicPie<phantom COIN> has key, store{
        id: UID,
        tge_ms: u64, //TGE timestamp
        total_supply: u64, //total supply of coin value, preset and nerver change!
        total_shares: u64,
        total_shares_percent: u64,
        shares: Table<address, TokenomicFund<COIN>> //all shares
    }

    fun init(_witness: TOKENOMIC, ctx: &mut TxContext) {
        transfer::transfer(TAdminCap { id: object::new(ctx) }, sender(ctx));
    }

    public entry fun change_admin(admin: TAdminCap, to: address) {
        transfer(admin, to);
    }

    public entry fun init_tokenomic<COIN>(_admin: &TAdminCap,
                                     total_supply: u64,
                                     tge_ms: u64,
                                     sclock: &Clock,
                                     ctx: &mut TxContext){
        let now_ms = clock::timestamp_ms(sclock);
        assert!(tge_ms > now_ms, ERR_INVALID_TGE);
        assert!(total_supply > 0 , ERR_INVALID_SUPPLY);

        let pie = TokenomicPie {
            id: object::new(ctx),
            tge_ms,
            total_supply,
            total_shares: 0,
            total_shares_percent: 0,
            shares: table::new<address, TokenomicFund<COIN>>(ctx)
        };
        share_object(pie);
    }


    public entry fun addFund<COIN>(_admin: &TAdminCap,
                                   pie: &mut TokenomicPie<COIN>,
                                   owner: address,
                                   name: vector<u8>,
                                   tge_ms: u64,
                                   fund: Coin<COIN>,
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
            && (tge_release_percent >= 0 && tge_release_percent <= 10000)
            && (claim_start_ms >= now && claim_start_ms >= tge_ms)
            && (claim_end_ms > claim_start_ms && claim_end_ms - claim_start_ms <= TEN_YEARS_IN_MS),
            ERR_INVALID_FUND_PARAMS);

        pie.total_shares = u256::add_u64(pie.total_shares, coin::value(&fund));
        pie.total_shares_percent = pie.total_shares*10000/pie.total_supply;

        let fundAmt = coin::value(&fund);

        let tgeFundCoin = if(tge_release_percent == 0){
                coin::zero<COIN>(ctx)
            }
            else {
                coin::split(&mut fund, (fundAmt * tge_release_percent)/ ONE_HUNDRED_PERCENT_SCALED, ctx)
            };

        let fund =  TokenomicFund<COIN> {
                owner,
                name,
                tge_ms,
                tge_release_percent,
                claim_start_ms,
                claim_end_ms,
                last_claim_ms: 0u64,
                tge_fund: tgeFundCoin,
                vesting_fund_total: coin::value(& fund),
                vesting_fund: fund,
                fund_percent:  fundAmt*100/pie.total_supply
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
        assert!(now_ms >= fund.tge_ms, ERR_TGE_NOT_STARTED);

        let tgeFundAmt = coin::value(&fund.tge_fund);
        let claimedCoin = if(tgeFundAmt <= 0) {
            coin::zero<COIN>(ctx) }
        else {
            coin::split(&mut fund.tge_fund, tgeFundAmt, ctx)
        };

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
            let effectiveLastClaimTime = if(fund.last_claim_ms <= fund.claim_start_ms) {
                fund.claim_start_ms
            }
            else{
                fund.last_claim_ms
            };

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

    public fun getTotalShares<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_shares
    }

    public fun getTotalSharesPercent<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_shares_percent
    }

    public fun getTGETimeMs<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.tge_ms
    }

    public fun getShareFundReleasedAtTGE<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        coin::value(&share.tge_fund)
    }

    public fun getShareFundVestingAvailable<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        coin::value(&share.vesting_fund)
    }



    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TOKENOMIC {}, ctx);
    }
}
