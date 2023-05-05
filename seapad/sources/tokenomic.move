module seapad::tokenomic {
    use sui::tx_context::{TxContext, sender};
    use sui::object::UID;
    use sui::object;
    use sui::transfer;
    use sui::coin::{Coin};
    use sui::clock::Clock;
    use sui::coin;
    use sui::transfer::{share_object, transfer};
    use sui::clock;
    use sui::table::Table;
    use sui::table;
    use std::vector;
    use sui::math;
    use w3libs::u256;
    use seapad::version::{Version, checkVersion};

    const VERSION: u64 = 1;

    const MONTH_IN_MS: u64 =  2592000000;
    const TEN_YEARS_IN_MS: u64 = 311040000000;
    const ONE_HUNDRED_PERCENT_SCALED: u64 = 10000;

    const ERR_BAD_TGE: u64 = 8001;
    const ERR_BAD_SUPPLY: u64 = 8002;
    const ERR_BAD_FUND_PARAMS: u64 = 8003;
    const ERR_TGE_NOT_STARTED: u64 = 8004;
    const ERR_BAD_VESTING_TIME: u64 = 8005;
    const ERR_NO_PERMISSION: u64 = 8006;
    const ERR_NO_MORE_COIN: u64 = 8007;
    const ERR_BAD_VESTING_TYPE: u64 = 8008;
    const ERR_BAD_VESTING_PARAMS: u64 = 8009;
    const ERR_NO_COIN: u64 = 8010;
    const ERR_NO_FUND: u64 = 8011;


    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;

    struct TOKENOMIC has drop {}

    struct TAdminCap has key, store {
        id: UID
    }

    struct TokenomicFund<phantom COIN> has store {
        owner: address, //owner of fund
        name: vector<u8>, //name
        vesting_type: u8,
        tge_ms: u64, //tge timestamp
        cliff_ms: u64, //duration
        unlock_percent: u64, //released at tge, in %
        linear_vesting_duration_ms: u64, //linear time vesting duration
        milestone_times: vector<u64>, //list of milestone timestamp
        milestone_percents: vector<u64>, //list of milestone percents
        last_claim_ms: u64, //last claim time
        vesting_fund_total: u64, //total of vesting fund, inited just one time, nerver change!
        vesting_fund_released: u64, //total released
        vesting_fund: Coin<COIN>, //all locked fund
        pie_percent: u64 //percent on pie
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

    public entry fun change_admin(admin: TAdminCap,
                                  to: address,
                                  version: &mut Version) {
        checkVersion(version, VERSION);
        transfer(admin, to);
    }

    public entry fun init_tokenomic<COIN>(_admin: &TAdminCap,
                                     total_supply: u64,
                                     tge_ms: u64,
                                     sclock: &Clock,
                                     version: &mut Version,
                                     ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(tge_ms > now_ms, ERR_BAD_TGE);
        assert!(total_supply > 0 , ERR_BAD_SUPPLY);

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
                                   vesting_type: u8,
                                   tge_ms: u64, //timestamp
                                   cliff_ms: u64, //duration
                                   fund: Coin<COIN>,
                                   unlock_percent: u64,
                                   linear_vesting_duration_ms: u64, //duration
                                   sclock: &Clock,
                                   version: &mut Version,
                                   milestone_times: vector<u64>, //if milestone mode, timestamps
                                   milestone_percents: vector<u64>, //if milestone mode
                                   _ctx: &mut TxContext
    )
    {
        checkVersion(version, VERSION);

        assert!(vesting_type >= VESTING_TYPE_MILESTONE_UNLOCK_FIRST
            && vesting_type <= VESTING_TYPE_LINEAR_CLIFF_FIRST, ERR_BAD_VESTING_TYPE);

        let now = clock::timestamp_ms(sclock);
        assert!(tge_ms >= now
            && (vector::length<u8>(&name) > 0)
            && (unlock_percent >= 0 && unlock_percent <= ONE_HUNDRED_PERCENT_SCALED)
            && (cliff_ms >= 0),
            ERR_BAD_FUND_PARAMS);

        //validate milestones
        if(vesting_type == VESTING_TYPE_MILESTONE_CLIFF_FIRST || vesting_type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST){
            assert!(vector::length(&milestone_times) == vector::length(&milestone_percents)
                && vector::length(&milestone_times) >= 0
                && linear_vesting_duration_ms == 0, ERR_BAD_VESTING_PARAMS);
            let total = unlock_percent;
            let (index, len) = (0, vector::length(&milestone_times));

            //make sure timestamp ordered!
            let curTime = 0u64;
            while (index < len){
                total = total + *vector::borrow(&milestone_percents, index);
                let tmpTime = *vector::borrow(&milestone_times, index);
                assert!(tmpTime >= tge_ms + cliff_ms
                    && tmpTime > curTime, ERR_BAD_VESTING_PARAMS);
                curTime = tmpTime;
                index = index + 1;
            };
            //make sure total percent is 100%, or fund will be leak!
            assert!(total == ONE_HUNDRED_PERCENT_SCALED, ERR_BAD_VESTING_PARAMS);
        }
        else{
            assert!(vector::length(&milestone_times) == 0
                && vector::length(&milestone_percents) == 0
                && (linear_vesting_duration_ms > 0 && linear_vesting_duration_ms < TEN_YEARS_IN_MS)
                , ERR_BAD_VESTING_PARAMS);
        };

        let fundAmt = coin::value(&fund);
        pie.total_shares = u256::add_u64(pie.total_shares, fundAmt);
        pie.total_shares_percent = pie.total_shares*ONE_HUNDRED_PERCENT_SCALED/pie.total_supply;

        let tokenFund =  TokenomicFund<COIN> {
                owner,
                name,
                vesting_type,
                tge_ms,
                cliff_ms,
                unlock_percent,
                linear_vesting_duration_ms,
                milestone_times,
                milestone_percents,
                last_claim_ms: 0u64,
                vesting_fund_total: fundAmt,
                vesting_fund_released: 0,
                vesting_fund: fund,
                pie_percent:  fundAmt * ONE_HUNDRED_PERCENT_SCALED/pie.total_supply
            };

        table::add(&mut pie.shares, owner, tokenFund);
    }


    public entry fun claim<COIN>(pie: &mut TokenomicPie<COIN>,
                                 sclock: &Clock,
                                 version: &mut Version,
                                 ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(now_ms >= pie.tge_ms, ERR_TGE_NOT_STARTED);

        let senderAddr = sender(ctx);
        assert!(table::contains(&pie.shares, senderAddr), ERR_NO_FUND);
        let fund = table::borrow_mut(&mut pie.shares, senderAddr);
        assert!(senderAddr == fund.owner, ERR_NO_PERMISSION);
        assert!(now_ms >= fund.tge_ms, ERR_TGE_NOT_STARTED);

        let claimPercent = cal_claim_percent<COIN>(fund, now_ms);

        claimPercent = math::min(claimPercent, ONE_HUNDRED_PERCENT_SCALED);

        assert!(claimPercent > 0, ERR_NO_COIN);

        let total_token_amt = (fund.vesting_fund_total * claimPercent)/ONE_HUNDRED_PERCENT_SCALED;
        let remain_token_val = total_token_amt - fund.vesting_fund_released;
        assert!(remain_token_val > 0, ERR_NO_MORE_COIN);

        transfer::public_transfer(coin::split<COIN>(&mut fund.vesting_fund, remain_token_val, ctx), senderAddr);

        fund.vesting_fund_released = fund.vesting_fund_released + remain_token_val;
        fund.last_claim_ms = now_ms;
    }

    fun cal_claim_percent<COIN>(vesting: &TokenomicFund<COIN>, now: u64): u64 {
        let milestone_times = &vesting.milestone_times;
        let milestone_percents = &vesting.milestone_percents;

        let tge_ms = vesting.tge_ms;
        let total_percent = 0;

        if(vesting.vesting_type == VESTING_TYPE_MILESTONE_CLIFF_FIRST) {
            if(now >= tge_ms + vesting.cliff_ms){
                total_percent = total_percent + vesting.unlock_percent;

                let (i, n) = (0, vector::length(milestone_times));

                while (i < n) {
                    let milestone_time = *vector::borrow(milestone_times, i);
                    let milestone_percent = *vector::borrow(milestone_percents, i);

                    if (now >= milestone_time) {
                        total_percent = total_percent + milestone_percent;
                    } else {
                        break
                    };
                    i = i + 1;
                };
            };
        }
        else if (vesting.vesting_type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST) {
            if(now >= tge_ms){
                total_percent = total_percent + vesting.unlock_percent;

                if(now >= tge_ms + vesting.cliff_ms){
                    let (i, n) = (0, vector::length(milestone_times));

                    while (i < n) {
                        let milestone_time = *vector::borrow(milestone_times, i);
                        let milestone_percent = *vector::borrow(milestone_percents, i);
                        if (now >= milestone_time) {
                            total_percent = total_percent + milestone_percent;
                        } else {
                            break
                        };
                        i = i + 1;
                    };
                }
            };
        }
        else if (vesting.vesting_type == VESTING_TYPE_LINEAR_UNLOCK_FIRST) {
            if (now >= tge_ms) {
                total_percent = total_percent + vesting.unlock_percent;
                if(now >= tge_ms + vesting.cliff_ms){
                    let delta = now - tge_ms - vesting.cliff_ms;
                    total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED - vesting.unlock_percent) / vesting.linear_vesting_duration_ms;
                }
            };
        }
        else if (vesting.vesting_type == VESTING_TYPE_LINEAR_CLIFF_FIRST) {
            if (now >= tge_ms + vesting.cliff_ms) {
                total_percent = total_percent + vesting.unlock_percent;
                let delta = now - tge_ms - vesting.cliff_ms;
                total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED - vesting.unlock_percent) / vesting.linear_vesting_duration_ms;
            };
        };

        total_percent
    }

    public entry fun change_fund_owner<COIN>(pie: &mut TokenomicPie<COIN>,
                                             to: address,
                                             version: &mut Version,
                                             ctx: &mut TxContext){
        checkVersion(version, VERSION);

        let senderAddr = sender(ctx);
        assert!(table::contains(&pie.shares, senderAddr)
            && !table::contains(&pie.shares, to), ERR_NO_PERMISSION);

        let fund = table::borrow_mut<address, TokenomicFund<COIN>>(&mut pie.shares, senderAddr);
        fund.owner = to;

        let fund2 = table::remove<address, TokenomicFund<COIN>>(&mut pie.shares, senderAddr);
        table::add<address, TokenomicFund<COIN>>(&mut pie.shares, to, fund2);
    }

    public fun getPieTotalSupply<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_supply
    }

    public fun getPieTotalShare<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_shares
    }

    public fun getPieTotalSharePercent<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.total_shares_percent
    }

    public fun getPieTgeTimeMs<COIN>(pie: &TokenomicPie<COIN>): u64{
        pie.tge_ms
    }

    public fun getFundUnlockPercent<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        share.unlock_percent
    }

    public fun getFundVestingAvailable<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        coin::value(&share.vesting_fund)
    }

    public fun getFundReleased<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        share.vesting_fund_released
    }

    public fun getFundTotal<COIN>(pie: &TokenomicPie<COIN>, addr: address): u64{
        let share = table::borrow(&pie.shares, addr);
        share.vesting_fund_total
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(TOKENOMIC {}, ctx);
    }
}
