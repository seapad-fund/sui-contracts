module seapad::vesting {
    use sui::tx_context::{TxContext, sender};
    use sui::object::{UID, id_address};
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
    use sui::event::emit;
    use sui::event;

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
    const ERR_FULL_SUPPLY: u64 = 8012;


    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;

    struct VESTING has drop {}

    struct VAdminCap has key, store {
        id: UID
    }

    struct FundAddedEvent has drop, copy {
        owner: address,
        vesting_type: u8,
        tge_ms: u64,
        cliff_ms: u64,
        unlock_percent: u64,
        linear_vesting_duration_ms: u64,
        milestone_times: vector<u64>,
        milestone_percents: vector<u64>,
        vesting_fund_total: u64,
        project_percent: u64
    }

    struct FundClaimEvent has drop, copy {
        owner: address,
        vesting_type: u8,
        tge_ms: u64,
        cliff_ms: u64,
        unlock_percent: u64,
        linear_vesting_duration_ms: u64,
        milestone_times: vector<u64>,
        milestone_percents: vector<u64>,
        last_claim_ms: u64,
        vesting_fund_total: u64,
        vesting_fund_total_released: u64,
        vesting_fund_claimed: u64,
        pie_percent: u64
    }

    struct ProjectCreatedEvent has drop, copy {
        //@todo layout
    }

    struct Fund<phantom COIN> has store {
        owner: address, //owner of fund
        last_claim_ms: u64, //last claim time
        fund_total: u64, //total of vesting fund, set when fund deposited, nerver change!
        fund_locked: Coin<COIN>, //all currently locked fund
        fund_released: u64, //total released
        project_percent: u64 //percent on project
    }

    struct Project<phantom COIN> has key, store{
        id: UID,
        name: vector<u8>, //project name
        project_url: vector<u8>, //should redirect to ido link
        tge_ms: u64, //TGE timestamp
        total_supply: u64, //total supply of vesting, pre-set and nerver change!
        total_deposit: u64, //total shared coin amount by funds
        total_deposit_percent: u64, //total shared coin amount by funds
        funds: Table<address, Fund<COIN>>, //funds details
        vesting_type: u8,
        cliff_ms: u64, //lock duration before start vesting
        unlock_percent: u64, //in %
        linear_vesting_duration_ms: u64, //linear time vesting duration
        milestone_times: vector<u64>, //list of milestone timestamp
        milestone_percents: vector<u64>, //list of milestone percents
    }

    struct ProjectRegistry has key, store{
        id: UID,
        projects: Table<address, u64>,
        user_projects: Table<address, vector<address>>,
    }

    fun init(_witness: VESTING, ctx: &mut TxContext) {
        transfer::transfer(VAdminCap { id: object::new(ctx) }, sender(ctx));

        share_object(ProjectRegistry {
            id: object::new(ctx),
            projects: table::new(ctx),
            user_projects:  table::new(ctx),
        })
    }

    public entry fun change_admin(admin: VAdminCap,
                                  to: address,
                                  version: &mut Version) {
        checkVersion(version, VERSION);
        transfer(admin, to);
    }

    public entry fun create_project<COIN>(_admin: &VAdminCap,
                                          name: vector<u8>,
                                          project_url: vector<u8>,
                                          total_supply: u64,
                                          tge_ms: u64,
                                          vesting_type: u8,
                                          cliff_ms: u64,
                                          unlock_percent: u64,
                                          linear_vesting_duration_ms: u64,
                                          milestone_times: vector<u64>,
                                          milestone_percents: vector<u64>,
                                          sclock: &Clock,
                                          version: &mut Version,
                                          project_registry: &mut ProjectRegistry,
                                          ctx: &mut TxContext){
        //validate
        checkVersion(version, VERSION);

        assert!(vesting_type >= VESTING_TYPE_MILESTONE_UNLOCK_FIRST
            && vesting_type <= VESTING_TYPE_LINEAR_CLIFF_FIRST, ERR_BAD_VESTING_TYPE);

        let now = clock::timestamp_ms(sclock);
        assert!(tge_ms >= now
            && (vector::length<u8>(&name) > 0)
            && (vector::length<u8>(&project_url) > 0)
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

        let now_ms = clock::timestamp_ms(sclock);
        assert!(tge_ms >= now_ms, ERR_BAD_TGE);
        assert!(total_supply > 0 , ERR_BAD_SUPPLY);

        let project = Project {
            id: object::new(ctx),
            name,
            project_url,
            tge_ms,
            total_supply,
            total_deposit: 0,
            total_deposit_percent: 0,
            funds: table::new<address, Fund<COIN>>(ctx),
            vesting_type,
            cliff_ms,
            unlock_percent,
            linear_vesting_duration_ms,
            milestone_times,
            milestone_percents
        };

        table::add(&mut project_registry.projects, id_address(&project), 0);

        event::emit(ProjectCreatedEvent{
            //@todo add new project event
        });

        share_object(project);
    }


    public entry fun addFund<COIN>(_admin: &VAdminCap,
                                   owner: address,
                                   fund: Coin<COIN>,
                                   project: &mut Project<COIN>,
                                   project_registry: &mut ProjectRegistry,
                                   version: &mut Version,
                                   _ctx: &mut TxContext)
    {
        checkVersion(version, VERSION);

        let fundAmt = coin::value(&fund);
        assert!(fundAmt > 0 , ERR_BAD_FUND_PARAMS);

        project.total_deposit = u256::add_u64(project.total_deposit, fundAmt);
        assert!(project.total_deposit <= project.total_supply, ERR_FULL_SUPPLY);

        project.total_deposit_percent = project.total_deposit * ONE_HUNDRED_PERCENT_SCALED/ project.total_supply;
        let projectPercent = fundAmt * ONE_HUNDRED_PERCENT_SCALED/project.total_supply;
        let tokenFund =  Fund<COIN> {
            owner,
            last_claim_ms: 0u64,
            fund_total: fundAmt,
            fund_released: 0,
            fund_locked: fund,
            project_percent: projectPercent
        };

        table::add(&mut project.funds, owner, tokenFund);

        //@todo review
        if(table::contains(&project_registry.user_projects, owner)){
            let userProjects = table::borrow_mut(&mut project_registry.user_projects, owner);
            vector::push_back(userProjects, id_address(project));
        }
        else{
            let userProjects = vector::empty<address>();
            vector::push_back(&mut userProjects, id_address(project));
            table::add(&mut project_registry.user_projects, owner, userProjects);
        };

        emit(FundAddedEvent {
            owner,
            vesting_type: project.vesting_type,
            tge_ms: project.tge_ms,
            cliff_ms: project.cliff_ms,
            unlock_percent: project.unlock_percent,
            linear_vesting_duration_ms: project.linear_vesting_duration_ms,
            milestone_times: project.milestone_times,
            milestone_percents: project.milestone_percents,
            vesting_fund_total: fundAmt,
            project_percent: projectPercent
        })
    }

    public entry fun claim<COIN>(project: &mut Project<COIN>,
                                 sclock: &Clock,
                                 version: &Version,
                                 ctx: &mut TxContext){
        //validate
        checkVersion(version, VERSION);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(now_ms >= project.tge_ms, ERR_TGE_NOT_STARTED);

        let senderAddr = sender(ctx);
        assert!(table::contains(&project.funds, senderAddr), ERR_NO_FUND);

        assert!(now_ms >= project.tge_ms, ERR_TGE_NOT_STARTED);

        let fund0 = table::borrow(&mut project.funds, senderAddr);
        assert!(senderAddr == fund0.owner, ERR_NO_PERMISSION);

        //compute claim percent
        let claimPercent = cal_claim_percent<COIN>(project, now_ms);
        assert!(claimPercent > 0, ERR_NO_COIN);

        let fund = table::borrow_mut(&mut project.funds, senderAddr);

        let totalTokenAmt = (fund.fund_total * claimPercent)/ONE_HUNDRED_PERCENT_SCALED;
        let remainTokenAmt = totalTokenAmt - fund.fund_released;
        assert!(remainTokenAmt > 0, ERR_NO_MORE_COIN);

        //send fund & update
        transfer::public_transfer(coin::split<COIN>(&mut fund.fund_locked, remainTokenAmt, ctx), senderAddr);
        fund.fund_released = fund.fund_released + remainTokenAmt;
        fund.last_claim_ms = now_ms;

        //fire event
        emit(FundClaimEvent {
            owner: fund.owner,
            vesting_type: project.vesting_type,
            tge_ms: project.tge_ms,
            cliff_ms: project.cliff_ms,
            unlock_percent: project.unlock_percent,
            linear_vesting_duration_ms: project.linear_vesting_duration_ms,
            milestone_times: project.milestone_times,
            milestone_percents: project.milestone_percents,
            last_claim_ms: fund.last_claim_ms,
            vesting_fund_total: fund.fund_total,
            vesting_fund_total_released: fund.fund_released,
            vesting_fund_claimed: remainTokenAmt,
            pie_percent: fund.project_percent
        })
    }

    fun cal_claim_percent<COIN>(project: &Project<COIN>, now: u64): u64 {
        let milestone_times = &project.milestone_times;
        let milestone_percents = &project.milestone_percents;

        let tge_ms = project.tge_ms;
        let total_percent = 0;

        if(project.vesting_type == VESTING_TYPE_MILESTONE_CLIFF_FIRST) {
            if(now >= tge_ms + project.cliff_ms){
                total_percent = total_percent + project.unlock_percent;

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
        else if (project.vesting_type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST) {
            if(now >= tge_ms){
                total_percent = total_percent + project.unlock_percent;

                if(now >= tge_ms + project.cliff_ms){
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
        else if (project.vesting_type == VESTING_TYPE_LINEAR_UNLOCK_FIRST) {
            if (now >= tge_ms) {
                total_percent = total_percent + project.unlock_percent;
                if(now >= tge_ms + project.cliff_ms){
                    let delta = now - tge_ms - project.cliff_ms;
                    total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED - project.unlock_percent) / project.linear_vesting_duration_ms;
                }
            };
        }
        else if (project.vesting_type == VESTING_TYPE_LINEAR_CLIFF_FIRST) {
            if (now >= tge_ms + project.cliff_ms) {
                total_percent = total_percent + project.unlock_percent;
                let delta = now - tge_ms - project.cliff_ms;
                total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED - project.unlock_percent) / project.linear_vesting_duration_ms;
            };
        };

        math::min(total_percent, ONE_HUNDRED_PERCENT_SCALED)
    }

    public fun getProjectTotalSupply<COIN>(project: &Project<COIN>): u64{
        project.total_supply
    }

    public fun getProjectTotalDeposit<COIN>(project: &Project<COIN>): u64{
        project.total_deposit
    }

    public fun getProjectTotalSharePercent<COIN>(project: &Project<COIN>): u64{
        project.total_deposit_percent
    }

    public fun getProjectTgeTimeMs<COIN>(project: &Project<COIN>): u64{
        project.tge_ms
    }

    public fun getFundLocked<COIN>(project: &Project<COIN>, addr: address): u64{
        let share = table::borrow(&project.funds, addr);
        coin::value(&share.fund_locked)
    }

    public fun getFundReleased<COIN>(project: &Project<COIN>, addr: address): u64{
        let share = table::borrow(&project.funds, addr);
        share.fund_released
    }

    public fun getFundTotal<COIN>(project: &Project<COIN>, addr: address): u64{
        let share = table::borrow(&project.funds, addr);
        share.fund_total
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(VESTING {}, ctx);
    }
}
