module seapad::reward {
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
    use seapad::version::{Version, checkVersion};
    use sui::event::emit;
    use sui::event;
    use std::option::Option;
    use std::option;

    const VERSION: u64 = 1;

    const ONE_HUNDRED_PERCENT_SCALED_U128: u128 = 10000;
    const ONE_HUNDRED_PERCENT_SCALED_U64: u64 = 10000;

    const ERR_BAD_FUND_PARAMS: u64 = 8001;
    const ERR_TGE_NOT_STARTED: u64 = 8002;
    const ERR_NO_PERMISSION: u64 = 8003;
    const ERR_NO_FUND: u64 = 8004;
    const ERR_PAUSED: u64 = 8010;
    const ERR_FUND_NOT_ENOUGH: u64 = 8011;

    struct REWARD has drop {}

    struct RewardAdminCap has key, store {
        id: UID,
    }

    struct RewardAdminCapVault has key, store {
        id: UID,
        owner: Option<address>,
        to: Option<address>,
        cap: Option<RewardAdminCap>
    }

    struct RewardAddedEvent has drop, copy {
        owner: address,
        project: address,
        fund: u128
    }

    struct RewardRemoveEvent has drop, copy {
        owner: address,
        project: address,
        fund: u128
    }

    struct RewardClaimEvent has drop, copy {
        owner: address,
        project: address,
        total: u128,
        released: u128,
        claim: u128,
    }

    struct ProjectCreatedEvent has drop, copy {
        project: address,
        name: vector<u8>
    }

    struct Reward<phantom COIN> has store {
        owner: address, //owner of fund
        total: u128, //total of vesting fund, set when fund deposited, nerver change!
        fund: Coin<COIN>, //all currently locked fund
        released: u128, //total released
        last_claim_ms: u64,
        tge_ms: u64,
        vesting_duration_ms: u64,
    }

    struct Project<phantom COIN> has key, store {
        id: UID,
        name: vector<u8>,
        deposited: u128,
        funds: Table<address, Reward<COIN>>,
        paused: bool
    }

    struct ProjectRegistry has key, store {
        id: UID,
        projects: Table<address, u64>,
        user_projects: Table<address, vector<address>>,
    }

    fun init(_witness: REWARD, ctx: &mut TxContext) {
        transfer::transfer(RewardAdminCap { id: object::new(ctx) }, sender(ctx));

        share_object(ProjectRegistry {
            id: object::new(ctx),
            projects: table::new(ctx),
            user_projects: table::new(ctx),
        });

        share_object(RewardAdminCapVault {
            id: object::new(ctx),
            owner: option::none(),
            to:  option::none(),
            cap: option::none(),
        })
    }

    public entry fun transferAdmin(adminCap: RewardAdminCap, to: address, vault: &mut RewardAdminCapVault, version: &Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        option::fill(&mut vault.owner, sender(ctx));
        option::fill(&mut vault.to, to);
        option::fill(&mut vault.cap, adminCap);
    }

    public entry fun revokeAdmin(vault: &mut RewardAdminCapVault, version: &Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let owner = *option::borrow(&vault.owner);
        execTransferAdmin(vault, owner, version, ctx);
    }

    public entry fun acceptAdmin(vault: &mut RewardAdminCapVault, version: &mut Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let to = *option::borrow(&vault.to);
        execTransferAdmin(vault, to, version, ctx);
    }

    fun execTransferAdmin(vault: &mut RewardAdminCapVault, ownerOrReceiver: address, version: &Version, ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        assert!(option::is_some(&vault.cap) && ownerOrReceiver == sender(ctx), ERR_NO_PERMISSION);
        transfer(option::extract(&mut vault.cap), sender(ctx));
        let _owner = option::extract(&mut vault.owner);
        let _to = option::extract(&mut vault.to);
    }

    public entry fun createProject<COIN>(_admin: &RewardAdminCap,
                                         name: vector<u8>,
                                         sclock: &Clock,
                                         version: &mut Version,
                                         project_registry: &mut ProjectRegistry,
                                         ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        let now = clock::timestamp_ms(sclock);
        assert!((vector::length<u8>(&name) > 0),
            ERR_BAD_FUND_PARAMS);

        let project = Project {
            id: object::new(ctx),
            name,
            deposited: 0,
            funds: table::new<address, Reward<COIN>>(ctx),
            paused: false
        };

        let projectId = id_address(&project);
        table::add(&mut project_registry.projects, projectId, 0);

        event::emit(ProjectCreatedEvent {
            project: projectId,
            name
        });

        share_object(project);
    }

    public entry fun pauseProject<COIN>(_admin: &RewardAdminCap, project: &mut Project<COIN>, paused: bool) {
        project.paused = paused;
    }

    public entry fun addRewards<COIN>(admin: &RewardAdminCap,
                                      owners: vector<address>,
                                      tges: vector<u64>,
                                      vestingDurations: vector<u64>,
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
            let tge = *vector::borrow(&tges, i);
            let vestingDuration = *vector::borrow(&vestingDurations, i);
            let fund = coin::split(&mut totalFund, value_fund, ctx);
            addReward(admin, owner, fund,  tge, vestingDuration, project, registry, version);
            i = i + 1;
        };
        transfer::public_transfer(totalFund, sender(ctx));
    }


    public entry fun addReward<COIN>(_admin: &RewardAdminCap,
                                     owner: address,
                                     fund: Coin<COIN>,
                                     tge:u64,
                                     vestingDuration: u64,
                                     project: &mut Project<COIN>,
                                     registry: &mut ProjectRegistry,
                                     version: &Version)
    {
        checkVersion(version, VERSION);

        assert!(!project.paused, ERR_PAUSED);

        let fundAmt = (coin::value(&fund) as u128);

        assert!(fundAmt > 0u128, ERR_BAD_FUND_PARAMS);

        project.deposited = project.deposited + fundAmt;

        if (table::contains(&mut project.funds, owner)) {
            let currentFund = table::borrow_mut(&mut project.funds, owner);
            currentFund.total = currentFund.total + fundAmt;
            coin::join(&mut currentFund.fund, fund);
        } else {
            let newFund = Reward<COIN> {
                owner,
                last_claim_ms: 0u64,
                total: fundAmt,
                released: 0u128,
                fund,
                tge_ms: tge,
                vesting_duration_ms: vestingDuration,
            };
            table::add(&mut project.funds, owner, newFund);
        };

        let projectId = id_address(project);
        addProjectToRegistry(registry, owner, projectId);

        emit(RewardAddedEvent {
            owner,
            project: projectId,
            fund: fundAmt,
        })
    }

    public entry fun removeReward<COIN>(_admin: &RewardAdminCap,
                                        owner: address,
                                        project: &mut Project<COIN>,
                                        registry: &mut ProjectRegistry,
                                        version: &Version,
                                        ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(table::contains(&mut project.funds, owner), ERR_NO_FUND);

        let Reward<COIN> {
            owner,
            total:_,
            fund: locked,
            released: _,
            last_claim_ms: _,
            tge_ms: _,
            vesting_duration_ms:_
        } = table::remove(&mut project.funds, owner);

        let lockedValue = (coin::value(&locked) as u128);
        assert!(project.deposited >= lockedValue, ERR_FUND_NOT_ENOUGH);
        project.deposited = project.deposited - lockedValue;
        transfer::public_transfer(locked, sender(ctx));

        let projectId = object::id_address(project);
        removeProjectFromRegistry(registry, owner, projectId);

        emit(RewardRemoveEvent {
            project: id_address(project),
            owner,
            fund: lockedValue,
        })
    }

    public entry fun removeRewards<COIN>(_admin: &RewardAdminCap,
                                         owners: vector<address>,
                                         project: &mut Project<COIN>,
                                         registry: &mut ProjectRegistry,
                                         version: &Version,
                                         ctx: &mut TxContext) {
        let (i, n) = (0, vector::length(&owners));
        while (i < n){
            let owner = *vector::borrow(&owners,i);
            removeReward(_admin, owner, project, registry, version, ctx);
            i = i +1;
        }
    }

    public entry fun claim<COIN>(project: &mut Project<COIN>,
                                 sclock: &Clock,
                                 version: &Version,
                                 registry: &mut ProjectRegistry,
                                 ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        assert!(!project.paused, ERR_PAUSED);

        let projectId = object::id_address(project);

        let owner = sender(ctx);
        assert!(table::contains(&project.funds, owner), ERR_NO_FUND);

        let reward = table::borrow_mut(&mut project.funds, owner);
        assert!(owner == reward.owner, ERR_NO_PERMISSION);

        let now_ms = clock::timestamp_ms(sclock);
        assert!(now_ms >= reward.tge_ms, ERR_TGE_NOT_STARTED);

        let claimPercent = (computeClaimPercent(now_ms, reward.tge_ms, reward.vesting_duration_ms) as u128);
        assert!(claimPercent > 0, ERR_NO_FUND);


        let claimTotal = (reward.total * claimPercent) / ONE_HUNDRED_PERCENT_SCALED_U128;
        assert!(claimTotal >  reward.released, ERR_NO_FUND);
        let claimAvail = claimTotal - reward.released;

        project.deposited = project.deposited - claimAvail;

        transfer::public_transfer(coin::split<COIN>(&mut reward.fund, (claimAvail as u64), ctx), owner);

        reward.released = reward.released + claimAvail;
        reward.last_claim_ms = now_ms;

        if ((reward.released >= reward.total)){
            removeProjectFromRegistry(registry, owner, projectId);
        };

        emit(RewardClaimEvent {
            owner: reward.owner,
            total: reward.total,
            released: reward.released,
            claim: claimAvail,
            project: id_address(project),
        })
    }

    fun computeClaimPercent(now: u64, tge_ms: u64, vesting_duration_ms: u64): u64 {
        let total_percent = 0u64;
        if (now >= tge_ms) {
            let delta = now - tge_ms;
            total_percent = delta * (ONE_HUNDRED_PERCENT_SCALED_U64) / vesting_duration_ms;
        };
        math::min(total_percent, ONE_HUNDRED_PERCENT_SCALED_U64)
    }

    #[test_only]
    public fun initForTesting(ctx: &mut TxContext) {
        init(REWARD {}, ctx);
    }

    #[test_only]
    public fun getProjectDeposited<COIN>(project: &Project<COIN>): u128 {
        project.deposited
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