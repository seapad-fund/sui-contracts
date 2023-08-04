module seapad::vesting {
    use sui::tx_context::{TxContext, sender};
    use sui::object::{UID, id_address};
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
    use seapad::version::{Version, checkVersion};
    use sui::event::emit;
    use sui::event;
    use sui::sui::SUI;
    use std::option::Option;
    use std::option;

    const VERSION: u64 = 1;

    const MONTH_IN_MS: u64 = 2592000000;
    const TEN_YEARS_IN_MS: u64 = 311040000000;
    const ONE_HUNDRED_PERCENT_SCALED_U128: u128 = 10000;
    const ONE_HUNDRED_PERCENT_SCALED_U64: u64 = 10000;

    const ERR_BAD_FUND_PARAMS: u64 = 8001;
    const ERR_TGE_NOT_STARTED: u64 = 8002;
    const ERR_NO_PERMISSION: u64 = 8003;
    const ERR_NO_FUND: u64 = 8004;
    const ERR_BAD_VESTING_TYPE: u64 = 8005;
    const ERR_BAD_VESTING_PARAMS: u64 = 8006;
    const ERR_FULL_SUPPLY: u64 = 8007;
    const ERR_FEE_NOT_ENOUGH: u64 = 8008;
    const ERR_BDEPRECATED: u64 = 8009;
    const ERR_PAUSED: u64 = 8010;
    const ERR_FUND_NOT_ENOUGH: u64 = 8011;

    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;

    struct VESTING has drop {}

    struct AdminCap has key, store {
        id: UID,
    }

    struct AdminCapVault has key, store {
        id: UID,
        owner: Option<address>,
        to: Option<address>,
        cap: Option<AdminCap>
    }

    struct FundAddedEvent has drop, copy {
        owner: address,
        project: address,
        fund: u128
    }

    struct FundRemoveEvent has drop, copy {
        owner: address,
        project: address,
        fund: u128
    }

    struct FundClaimEvent has drop, copy {
        owner: address,
        project: address,
        total: u128,
        released: u128,
        claim: u128,
    }

    struct ProjectCreatedEvent has drop, copy {
        project: address,
        name: vector<u8>,
        url: vector<u8>,
    }

    struct Fund<phantom COIN> has store {
        owner: address, //owner of fund
        total: u128, //total of vesting fund, set when fund deposited, nerver change!
        locked: Coin<COIN>, //all currently locked fund
        released: u128, //total released
        last_claim_ms: u64,
    }

    struct Project<phantom COIN> has key, store {
        id: UID,
        name: vector<u8>,
        url: vector<u8>,
        deprecated: bool,
        tge_ms: u64,
        //total supply of vesting, fixed when create new project
        supply: u128,
        //total deposited amount
        deposited: u128,
        deposited_percent: u128,
        //total deposited percent
        funds: Table<address, Fund<COIN>>,
        //locked funds
        vesting_type: u8,
        cliff_ms: u64,
        unlock_percent: u64,
        //in %
        linear_vesting_duration_ms: u64,
        milestone_times: vector<u64>,
        milestone_percents: vector<u64>,
        fee: u64,
        //how many sui will be charged when user claim fund!
        feeTreasury: Coin<SUI>,
        paused: bool
    }

    struct ProjectRegistry has key, store {
        id: UID,
        projects: Table<address, u64>,
        user_projects: Table<address, vector<address>>,
    }

    fun init(_witness: VESTING, ctx: &mut TxContext) {
        transfer::transfer(AdminCap { id: object::new(ctx) }, sender(ctx));

        share_object(ProjectRegistry {
            id: object::new(ctx),
            projects: table::new(ctx),
            user_projects: table::new(ctx),
        });

        share_object(AdminCapVault{
            id: object::new(ctx),
            owner: option::none(),
            to:  option::none(),
            cap: option::none(),
        })
    }

    public entry fun transferAdmin(adminCap: AdminCap, to: address, vault: &mut AdminCapVault, version: &mut Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        option::fill(&mut vault.owner, sender(ctx));
        option::fill(&mut vault.to, to);
        option::fill(&mut vault.cap, adminCap);
    }

    public entry fun revokeAdmin(vault: &mut AdminCapVault, version: &mut Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let owner = *option::borrow(&vault.owner);
        execTransferAdmin(vault, owner, version, ctx);
    }

    public entry fun acceptAdmin(vault: &mut AdminCapVault, version: &mut Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let to = *option::borrow(&vault.to);
        execTransferAdmin(vault, to, version, ctx);
    }

    fun execTransferAdmin(vault: &mut AdminCapVault, ownerOrReceiver: address, version: &mut Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        assert!(option::is_some(&vault.cap) && ownerOrReceiver == sender(ctx), ERR_NO_PERMISSION);
        transfer(option::extract(&mut vault.cap), sender(ctx));
        let _owner = option::extract(&mut vault.owner);
        let _to = option::extract(&mut vault.to);
    }

    public entry fun createProject<COIN>(_admin: &AdminCap,
                                         name: vector<u8>,
                                         url: vector<u8>,
                                         supply: u128,
                                         tge_ms: u64,
                                         vesting_type: u8,
                                         cliff_ms: u64,
                                         unlock_percent: u64,
                                         linear_vesting_duration_ms: u64,
                                         milestone_times: vector<u64>,
                                         milestone_percents: vector<u64>,
                                         sclock: &Clock,
                                         version: &mut Version,
                                         fee: u64,
                                         project_registry: &mut ProjectRegistry,
                                         ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        assert!(
            vesting_type >= VESTING_TYPE_MILESTONE_UNLOCK_FIRST && vesting_type <= VESTING_TYPE_LINEAR_CLIFF_FIRST,
            ERR_BAD_VESTING_TYPE
        );
        let now = clock::timestamp_ms(sclock);
        assert!(tge_ms >= now
            && supply > 0
            && (vector::length<u8>(&name) > 0)
            && (vector::length<u8>(&url) > 0)
            && (unlock_percent >= 0 && unlock_percent <= ONE_HUNDRED_PERCENT_SCALED_U64)
            && (cliff_ms >= 0),
            ERR_BAD_FUND_PARAMS);

        if (vesting_type == VESTING_TYPE_MILESTONE_CLIFF_FIRST || vesting_type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST) {
            assert!(vector::length(&milestone_times) == vector::length(&milestone_percents)
                && vector::length(&milestone_times) >= 0
                && linear_vesting_duration_ms == 0, ERR_BAD_VESTING_PARAMS);
            let total = unlock_percent;
            let (index, len) = (0, vector::length(&milestone_times));

            //timestamp must be ordered!
            let curTime = 0u64;
            while (index < len) {
                total = total + *vector::borrow(&milestone_percents, index);
                let tmpTime = *vector::borrow(&milestone_times, index);
                assert!(tmpTime >= tge_ms + cliff_ms && tmpTime > curTime, ERR_BAD_VESTING_PARAMS);
                curTime = tmpTime;
                index = index + 1;
            };
            assert!(total == ONE_HUNDRED_PERCENT_SCALED_U64, ERR_BAD_VESTING_PARAMS);
        }
        else {
            assert!(vector::length(&milestone_times) == 0
                && vector::length(&milestone_percents) == 0
                && (linear_vesting_duration_ms > 0 && linear_vesting_duration_ms < TEN_YEARS_IN_MS),
                ERR_BAD_VESTING_PARAMS);
        };

        let project = Project {
            id: object::new(ctx),
            fee,
            feeTreasury: coin::zero(ctx),
            name,
            url,
            deprecated: false,
            tge_ms,
            supply,
            deposited: 0,
            deposited_percent: 0,
            funds: table::new<address, Fund<COIN>>(ctx),
            vesting_type,
            cliff_ms,
            unlock_percent,
            linear_vesting_duration_ms,
            milestone_times,
            milestone_percents,
            paused: false
        };

        let projectId = id_address(&project);
        table::add(&mut project_registry.projects, projectId, 0);

        event::emit(ProjectCreatedEvent {
            project: projectId,
            name,
            url
        });

        share_object(project);
    }

    public entry fun pauseProject<COIN>(_admin: &AdminCap, project: &mut Project<COIN>, paused: bool) {
        project.paused = paused;
    }

    public entry fun setDeprecated<COIN>(_admin: &AdminCap, project: &mut Project<COIN>, deprecated: bool) {
        project.deprecated = deprecated;
    }

    public entry fun setProjectFee<COIN>(_admin: &AdminCap, project: &mut Project<COIN>, fee: u64) {
        project.fee = fee;
    }

    public entry fun withdrawFee<COIN>(_admin: &AdminCap, receiver: address, project: &mut Project<COIN>, ctx: &mut TxContext) {
        let all = coin::value(&project.feeTreasury);
        public_transfer(coin::split(&mut project.feeTreasury, all, ctx), receiver);
    }

    public entry fun addFunds<COIN>(admin: &AdminCap,
                                    owners: vector<address>,
                                    values: vector<u64>,
                                    totalFund: Coin<COIN>,
                                    project: &mut Project<COIN>,
                                    registry: &mut ProjectRegistry,
                                    version: &Version,
                                    ctx: &mut TxContext) {
        let (i, n) = (0, vector::length(&owners));
        assert!(vector::length(&values) == n, ERR_BAD_FUND_PARAMS);
        while (i < n) {
            let owner = *vector::borrow(&owners, i);
            let value_fund = *vector::borrow(&values, i);
            let fund = coin::split(&mut totalFund, value_fund, ctx);
            addFund(admin, owner, fund, project, registry, version);
            i = i + 1;
        };
        transfer::public_transfer(totalFund, sender(ctx));
    }


    public entry fun addFund<COIN>(_admin: &AdminCap,
                                   owner: address,
                                   fund: Coin<COIN>,
                                   project: &mut Project<COIN>,
                                   registry: &mut ProjectRegistry,
                                   version: &Version)
    {
        checkVersion(version, VERSION);

        assert!(!project.deprecated, ERR_BDEPRECATED);

        let fundAmt = (coin::value(&fund) as u128);

        assert!(fundAmt > 0u128, ERR_BAD_FUND_PARAMS);

        project.deposited = project.deposited + fundAmt;
        assert!(project.deposited <= project.supply, ERR_FULL_SUPPLY);

        project.deposited_percent = project.deposited * ONE_HUNDRED_PERCENT_SCALED_U128 / project.supply;

        if (table::contains(&mut project.funds, owner)) {
            let currentFund = table::borrow_mut(&mut project.funds, owner);
            currentFund.total = currentFund.total + fundAmt;
            coin::join(&mut currentFund.locked, fund);
        } else {
            let newFund = Fund<COIN> {
                owner,
                last_claim_ms: 0u64,
                total: fundAmt,
                released: 0u128,
                locked: fund
            };
            table::add(&mut project.funds, owner, newFund);
        };

        let projectId = id_address(project);
        addProjectToRegistry(registry, owner, projectId);

        emit(FundAddedEvent {
            owner,
            project: projectId,
            fund: fundAmt,
        })
    }

    public entry fun removeFund<COIN>(_admin: &AdminCap,
                                      owner: address,
                                      project: &mut Project<COIN>,
                                      registry: &mut ProjectRegistry,
                                      version: &Version,
                                      ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(table::contains(&mut project.funds, owner), ERR_NO_FUND);

        let Fund<COIN> {
            owner,
            total:_,
            locked,
            released: _,
            last_claim_ms: _
        } = table::remove(&mut project.funds, owner);

        let lockedValue = (coin::value(&locked) as u128);
        assert!(project.deposited >= lockedValue, ERR_FUND_NOT_ENOUGH);
        project.deposited = project.deposited - lockedValue;
        project.deposited_percent = project.deposited * ONE_HUNDRED_PERCENT_SCALED_U128 / project.supply;
        transfer::public_transfer(locked, sender(ctx));

        let projectId = object::id_address(project);
        removeProjectFromRegistry(registry, owner, projectId);

        emit(FundRemoveEvent {
            project: id_address(project),
            owner,
            fund: lockedValue,
        })
    }

    public entry fun removeFunds<COIN>(_admin: &AdminCap,
                                       owners: vector<address>,
                                       project: &mut Project<COIN>,
                                       registry: &mut ProjectRegistry,
                                       version: &Version,
                                       ctx: &mut TxContext) {
        let (i, n) = (0, vector::length(&owners));
        while (i < n){
            let owner = *vector::borrow(&owners,i);
            removeFund(_admin, owner, project, registry, version, ctx);
            i = i +1;
        }
    }

    public entry fun claim<COIN>(fee: Coin<SUI>,
                                 project: &mut Project<COIN>,
                                 sclock: &Clock,
                                 version: &Version,
                                 registry: &mut ProjectRegistry,
                                 ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        assert!(!project.paused, ERR_PAUSED);
        assert!(coin::value(&fee) >= project.fee, ERR_FEE_NOT_ENOUGH);
        let now_ms = clock::timestamp_ms(sclock);
        assert!(now_ms >= project.tge_ms, ERR_TGE_NOT_STARTED);

        let owner = sender(ctx);
        assert!(table::contains(&project.funds, owner), ERR_NO_FUND);

        let claimPercent = (computeClaimPercent<COIN>(project, now_ms) as u128);
        assert!(claimPercent > 0, ERR_NO_FUND);

        let projectId = object::id_address(project);

        let fund = table::borrow_mut(&mut project.funds, owner);
        assert!(owner == fund.owner, ERR_NO_PERMISSION);

        let claimTotal = (fund.total * claimPercent) / ONE_HUNDRED_PERCENT_SCALED_U128;
        assert!(claimTotal >  fund.released, ERR_NO_FUND);
        let claimRemain = claimTotal - fund.released;

        project.deposited = project.deposited - claimRemain;
        project.deposited_percent = project.deposited * ONE_HUNDRED_PERCENT_SCALED_U128 / project.supply;

        transfer::public_transfer(coin::split<COIN>(&mut fund.locked, (claimRemain as u64), ctx), owner);
        fund.released = fund.released + claimRemain;
        fund.last_claim_ms = now_ms;

        if ((fund.released == fund.total)){
            removeProjectFromRegistry(registry, owner, projectId);
        };

        if(project.fee > 0){
            let takeFee = coin::split(&mut fee, project.fee, ctx);
            coin::join(&mut project.feeTreasury, takeFee);
        };

        transfer::public_transfer(fee, sender(ctx));

        emit(FundClaimEvent {
            owner: fund.owner,
            total: fund.total,
            released: fund.released,
            claim: claimRemain,
            project: id_address(project),
        })
    }

    fun computeClaimPercent<COIN>(project: &Project<COIN>, now: u64): u64 {
        let milestone_times = &project.milestone_times;
        let milestone_percents = &project.milestone_percents;
        let tge_ms = project.tge_ms;
        let total_percent = 0u64;

        if (project.vesting_type == VESTING_TYPE_MILESTONE_CLIFF_FIRST) {
            if (now >= tge_ms + project.cliff_ms) {
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
            if (now >= tge_ms) {
                total_percent = total_percent + project.unlock_percent;

                if (now >= tge_ms + project.cliff_ms) {
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
                if (now >= tge_ms + project.cliff_ms) {
                    let delta = now - tge_ms - project.cliff_ms;
                    total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED_U64 - project.unlock_percent) / project.linear_vesting_duration_ms;
                }
            };
        }
        else if (project.vesting_type == VESTING_TYPE_LINEAR_CLIFF_FIRST) {
            if (now >= tge_ms + project.cliff_ms) {
                total_percent = total_percent + project.unlock_percent;
                let delta = now - tge_ms - project.cliff_ms;
                total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED_U64 - project.unlock_percent) /project.linear_vesting_duration_ms;
            };
        };

        math::min(total_percent, ONE_HUNDRED_PERCENT_SCALED_U64)
    }

    #[test_only]
    public fun initForTesting(ctx: &mut TxContext) {
        init(VESTING {}, ctx);
    }

    #[test_only]
    public fun getProjectDeposited<COIN>(project: &Project<COIN>): (u128, u128) {
        (project.deposited, project.deposited_percent)
    }

    #[test_only]
    public fun getUserProjects<COIN>(registry: &ProjectRegistry, owner: address): vector<address> {
        *table::borrow(&registry.user_projects, owner)
    }

    fun removeProjectFromRegistry(registry: &mut ProjectRegistry, owner: address, projectId: address){
        if(table::contains(&registry.user_projects, owner)){
            let projects = table::borrow_mut(&mut registry.user_projects, owner);
            let (exist, index) = vector::index_of(projects, &projectId);
            if(exist) {
                vector::remove(projects, index);
            };
            if(vector::length(projects) == 0){
                table::remove(&mut registry.user_projects, owner);
            }
        }
    }

    fun addProjectToRegistry(registry: &mut ProjectRegistry, owner: address, projectId: address){
        if (table::contains(&registry.user_projects, owner)) {
            let projectIds = table::borrow_mut(&mut registry.user_projects, owner);
            let (exist, _index) = vector::index_of(projectIds, &projectId);
            if(!exist){
                vector::push_back(projectIds, projectId);
            }
        } else {
            let projects = vector::empty<address>();
            vector::push_back(&mut projects, projectId);
            table::add(&mut registry.user_projects, owner, projects);
        };
    }


}