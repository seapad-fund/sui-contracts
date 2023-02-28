// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

///This module provide fund raising functions:
/// - support whitelist, soft cap, hardcap, refund
/// - support vesting token, claim token
/// - many round
module seapad::project {
    use std::ascii;
    use std::option::{Self, Option};
    use std::string;
    use std::vector;

    use sui::coin::{Self, CoinMetadata, Coin};
    use sui::dynamic_field;
    use sui::event;
    use sui::object::{Self, UID, id_address};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext, sender};
    use sui::url;
    use sui::vec_map::{Self, VecMap};
    use sui::vec_set::{Self, VecSet};

    ///Define model first

    struct SPT_PAD has drop {

    }

    struct PROJECT has drop {

    }

    const ERR_INVALID_VESTING_TYPE: u64 = 1000;
    const ERR_INVALID_ROUND: u64 = 1001;
    const ERR_INVALID_ROUND_STATE: u64 = 1002;
    const ERR_MAX_ALLOCATE: u64 = 1003;
    const ERR_OUTOF_HARDCAP: u64 = 1004;
    const ERR_ALREADY_VOTE: u64 = 1005;
    const ERR_CLAIM_DONE: u64 = 1006;
    const ERR_PROJECT_NOTWHITELIST: u64 = 1007;
    const ERR_ALREADY_WHITELIST: u64 = 1008;
    const ERR_NOT_WHITELIST: u64 = 1009;

    const ROUND_SEED: u8 = 1;
    const ROUND_PRIVATE: u8 = 2;
    const ROUND_PUBLIC: u8 = 3;
    const ROUND_STATE_INIT: u8 = 1;
    const ROUND_STATE_PREPARE: u8 = 2;
    const ROUND_STATE_RASING: u8 = 3;
    const ROUND_STATE_REFUNDING: u8 = 4; //complete & start refunding
    const ROUND_STATE_END_REFUND: u8 = 5; //refund completed & stop
    const ROUND_STATE_ENDED_CLAIM: u8 = 6; //complete & ready to claim token


    ///lives in launchpad domain
    ///use dynamic field to add likes, votes, and watch
    const LIKES: vector<u8> =  b"likes"; //likes: VecSet<address>
    const WATCHS: vector<u8> =  b"watchs"; //watchs: VecSet<address>,
    const VOTES: vector<u8> =  b"votes"; //votes: VecSet<address>

    const VESTING_TYPE_MILESTONE: u8 = 1;
    const VESTING_TYPE_LINEAR: u8 = 2;
    const VESTING: vector<u8> = b"vesting";
    const WHITELIST: vector<u8> = b"whitelist";

    struct ProjectProfile has key, store{
        id: UID,
        name: vector<u8>,
        twitter: vector<u8>,
        discord: vector<u8>,
        telegram: vector<u8>,
        website: vector<u8>,
    }

    struct BuyOrder  has store{
        buyer: address,
        sui_amount: u64,
        token_amt: u64, //total token
        token_released: u64, //released
    }

    struct LaunchState<phantom COIN> has key, store{
        id: UID,
        soft_cap: u64,
        hard_cap: u64,
        round: u8, //which round ?
        state: u8,
        total_sold: u64, //for each round
        swap_ratio_sui: u64,
        swap_ratio_token: u64,
        participants: u64,
        max_allocate: u64, //in sui
        start_time: u64,
        end_time: u64, //when project stop fund-raising and decide to refund or payout token(ready to claim)
        token_fund: Option<Coin<COIN>>, //owner of project deposit token fund enough to raising fund
        raised_sui: Option<Coin<SUI>>,
        buy_orders: VecMap<address, BuyOrder>,
    }

    ///should refer to object
    struct Contract has key, store{
        id: UID,
        coin_metadata: address,
        symbol: vector<u8>,
        name: vector<u8>,
        description: vector<u8>,
        url: Option<vector<u8>>,
        decimals: u8,
    }

    struct Community has key, store{
        id: UID,
        like: u128,
        vote: u128,
        watch: u128,
    }

    struct ProjectVestingMileStone has copy, drop, store{
        time: u64,
        percent: u8
    }

    struct Vesting<phantom COIN> has key, store{
        id: UID,
        type: u8,
        init_release_time: u64,
        //must be shorted list
        milestones: Option<vector<ProjectVestingMileStone>>
    }

    struct Project<phantom COIN> has key, store {
        id: UID,
        profile: ProjectProfile,
        launchstate: LaunchState<COIN>,
        contract: Contract,
        community: Community,
        usewhitelist: bool,
//        whitelist: VecSet<address> //use dynamic field
//        vesting: Vesting<COIN> //use dynamic field
    }

    ///@todo review: when change admin account, should flush all fund to all project
    /// or should have "resource" account!
    struct PadConfig has key, store {
        id: UID,
        adminAddr: address
    }

    struct Projects<phantom PAD> has key{
      id: UID,
      projects: vector<address>
    }

    struct AdminCap has key, store {
        id: UID
    }

    ///initialize SPT_PAD project
    /// with witness
    /// with admin
    /// share list of projects
    /// share pad config
    fun init(_witness: PROJECT, ctx: &mut TxContext){
        let adminCap = AdminCap { id: object::new(ctx)};
        transfer::transfer(adminCap, sender(ctx));
    }

    ///change admin
    public entry fun change_admin(adminCap: AdminCap, to: address, _ctx: &mut TxContext){
        transfer::transfer(adminCap, to);
    }

    /// add one project
    /// @todo validate params
    public entry fun add_project<COIN>(_adminCap: &AdminCap,
                                      round: u8,
                                      name: vector<u8>,
                                      twitter: vector<u8>,
                                      discord: vector<u8>,
                                      telegram: vector<u8>,
                                      website: vector<u8>,
                                      usewhitelist: bool,
                                      soft_cap: u64,
                                      hard_cap: u64,
                                      swap_ratio_sui: u64,
                                      swap_ratio_token: u64,
                                      max_allocate: u64,
                                      vesting_type: u8,
                                      first_mlst_time: u64,
                                      first_mlst_percent: u8,
                                      second_mlst_time: u64,
                                      second_mlst_percent: u8,
                                      third_first_mlst_time: u64,
                                      third_first_mlst_percent: u8,
                                      fourth_first_mlst_time: u64,
                                      fourth_first_mlst_percent: u8,
                                      coin_metadata: &CoinMetadata<COIN>,
                                      ctx: &mut TxContext
    ){
        let profile = ProjectProfile {
            id: object::new(ctx),
            name,
            twitter,
            discord,
            telegram,
            website
        };

        let launchstate = LaunchState<COIN> {
            id: object::new(ctx),
            soft_cap,
            hard_cap,
            round,
            state: ROUND_STATE_INIT,
            total_sold: 0,
            swap_ratio_sui,
            swap_ratio_token,
            participants: 0,
            max_allocate,
            start_time: 0,
            end_time: 0,
            token_fund: option::none<Coin<COIN>>(),
            buy_orders: vec_map::empty<address, BuyOrder>(),
            raised_sui: option::none<Coin<SUI>>(),
        };

        let iconUrl = option::none<vector<u8>>();
        let iconUrl0 = coin::get_icon_url(coin_metadata);
        if(option::is_some(&iconUrl0))
        {
            let url = *ascii::as_bytes(&url::inner_url(&option::extract(&mut iconUrl0)));
            option::fill(&mut iconUrl, url);
        };

        let contract = Contract {
            id: object::new(ctx),
            coin_metadata: object::id_address(coin_metadata),
            name: *string::bytes(&mut coin::get_name(coin_metadata)),
            symbol: *ascii::as_bytes(&mut coin::get_symbol(coin_metadata)),
            description: *string::bytes(&mut coin::get_description(coin_metadata)),
            decimals: coin::get_decimals(coin_metadata),
            url:  iconUrl
        };

        let community = Community{
            id: object::new(ctx),
            like: 0,
            vote: 0,
            watch: 0
        };
        dynamic_field::add(&mut community.id, LIKES, vec_set::empty<address>());
        dynamic_field::add(&mut community.id, WATCHS, vec_set::empty<address>());
        dynamic_field::add(&mut community.id, VOTES, vec_set::empty<address>());

        let vestingMlsts = vector::empty<ProjectVestingMileStone>();

        if(vesting_type == VESTING_TYPE_MILESTONE) {
            let mlst1 = ProjectVestingMileStone {
                time: first_mlst_time,
                percent: first_mlst_percent
            };

            let mlst2 = ProjectVestingMileStone {
                time: second_mlst_time,
                percent: second_mlst_percent
            };

            let mlst3 = ProjectVestingMileStone {
                time: third_first_mlst_time,
                percent: third_first_mlst_percent
            };

            let mlst4 = ProjectVestingMileStone {
                time: fourth_first_mlst_time,
                percent: fourth_first_mlst_percent
            };

            vector::push_back(&mut vestingMlsts, mlst1);
            vector::push_back(&mut vestingMlsts, mlst2);
            vector::push_back(&mut vestingMlsts, mlst3);
            vector::push_back(&mut vestingMlsts, mlst4);
            check_mile_stones(&mut vestingMlsts);
        };

        let vesting = Vesting<COIN> {
            id: object::new(ctx),
            type: vesting_type,
            init_release_time: first_mlst_time,
            milestones: option::some(vestingMlsts)
        };

        let project = Project {
            id: object::new(ctx),
            profile,
            launchstate,
            contract,
            community,
            usewhitelist
        };

        dynamic_field::add(&mut project.id, VESTING, vesting);
        if(usewhitelist) {
            dynamic_field::add(&mut project.id, WHITELIST, vec_set::empty<address>());
        };
        //fire event
        let event = build_event_add_project(&project);
        //share project
        transfer::share_object(project);
        event::emit(event);
    }

    /// if you want more milestones
    public entry fun add_mile_stone<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, time: u64, percent: u8){
        let vesting = dynamic_field::borrow_mut<vector<u8>, Vesting<COIN>>(&mut project.id, VESTING);
        assert!(vesting.type == VESTING_TYPE_MILESTONE, ERR_INVALID_VESTING_TYPE);
        let milestone = option::borrow_mut(&mut vesting.milestones);
        vector::push_back(milestone, ProjectVestingMileStone{ time, percent });
        check_mile_stones(milestone);
    }

    public entry fun update_project<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         usewhitelist: bool,
                                         swap_ratio_sui: u64,
                                         swap_ratio_token: u64,
                                         max_allocate: u64,
                                         start_time: u64,
                                         soft_cap: u64,
                                         hard_cap: u64,
                                         end_time: u64,
                                         _ctx: &mut TxContext){
        project.usewhitelist = usewhitelist;
        let lState = &mut project.launchstate;
        lState.swap_ratio_sui = swap_ratio_sui;
        lState.swap_ratio_token = swap_ratio_token;
        lState.max_allocate = max_allocate;
        lState.start_time = start_time;
        lState.end_time = end_time;
        lState.soft_cap = soft_cap;
        lState.hard_cap = hard_cap;

        event::emit(build_event_add_project(project));
    }


    public entry fun add_whitelist<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         user: address,
                                         _ctx: &mut TxContext){
        assert!(project.usewhitelist, ERR_PROJECT_NOTWHITELIST);
        let whitelist = dynamic_field::borrow_mut<vector<u8>, VecSet<address>>(&mut project.id, WHITELIST);
        assert!(vec_set::contains(whitelist, &user), ERR_ALREADY_WHITELIST);
        vec_set::insert(whitelist, user);
        event::emit(AddWhiteListEvent {whitelist: user})
    }

    struct ProjectDepositFundEvent has copy, drop {
        depositor: address,
        token_amount: u64
    }

    ///@todo
    /// - make sure coin merged
    /// - should limit to the one that register project ?
    /// - make sure token deposit match the market cap & swap ratio
    public entry fun user_deposit_project_fund_token<COIN>(_adminCap: &AdminCap, token: Coin<COIN>, project: &mut Project<COIN>, ctx: &mut TxContext){
        let tokenAmt = coin::value(&token);

        if(option::is_some(&project.launchstate.token_fund)){
            let before = option::borrow_mut(&mut project.launchstate.token_fund);
            coin::join(before, token);
        }
        else {
            option::fill(&mut project.launchstate.token_fund, token);
        };

        event::emit(ProjectDepositFundEvent{
            depositor: sender(ctx),
            token_amount:tokenAmt
        })
    }


    ///@todo
    /// - clear prev state
    /// - set new state
    public entry fun start_fund_raising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext){
        validate_start_fund_raising(project);
        project.launchstate.start_time = tx_context::epoch(ctx);
        project.launchstate.total_sold = 0;
        project.launchstate.participants = 0;
        project.launchstate.state = ROUND_STATE_RASING;

        event::emit(StartFundRaisingEvent {
            project: id_address(project),
            start_time: project.launchstate.start_time
        })
    }

    /// - check whitelist,  cap, max_allocate
    /// - support multiple buy orders
    public entry fun buy<COIN>(suiCoin: Coin<SUI>, project: &mut Project<COIN>, ctx: &mut TxContext){
        validate_state_for_buy(project, sender(ctx));
        let lState = &mut project.launchstate;
        let boughtAmt = 0u64;
        let bought = false;
        if(vec_map::contains(&lState.buy_orders, &sender(ctx))){
            boughtAmt = vec_map::get_mut(&mut lState.buy_orders, &sender(ctx)).sui_amount;
            bought = true;
        };

        assert!(coin::value(&suiCoin) + boughtAmt <= lState.max_allocate, ERR_MAX_ALLOCATE);
        assert!(lState.hard_cap >= lState.total_sold + coin::value(&suiCoin), ERR_OUTOF_HARDCAP);

        lState.total_sold = lState.total_sold + coin::value(&suiCoin);

        //@todo check math overflow
        let moreSuiAmt = coin::value(&suiCoin);
        let tokenAmt = moreSuiAmt * lState.swap_ratio_sui / lState.swap_ratio_sui;

        if(!bought){
            vec_map::insert(&mut lState.buy_orders, sender(ctx), BuyOrder {
                buyer: sender(ctx),
                sui_amount: moreSuiAmt,
                token_amt: tokenAmt, //not distributed
                token_released: 0, //not released
            });
            lState.participants  = lState.participants + 1;
        }
        else {
            let order = vec_map::get_mut(&mut lState.buy_orders, &sender(ctx));
            order.sui_amount = order.sui_amount + moreSuiAmt;
            order.token_amt = order.token_amt + tokenAmt;
        };

        if(option::is_none(&lState.raised_sui)){
            option::fill(&mut lState.raised_sui, suiCoin);
        }
        else {
            coin::join(option::borrow_mut(&mut lState.raised_sui), suiCoin);
        };

        event::emit(BuyEvent{
            project: id_address(project),
            buyer: sender(ctx),
            total_sui_amt: boughtAmt,
            epoch: tx_context::epoch(ctx)
        })
    }



    /// @todo
    /// - call to stop fund raising, maybe refund or success
    /// - if refund: go to REFUND state with timeout
    public entry fun end_fund_raising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext){
        let lState = &mut project.launchstate;
        lState.end_time = tx_context::epoch(ctx);
        if(lState.total_sold < lState.soft_cap){
            //start refund
            lState.state = ROUND_STATE_REFUNDING;
            event::emit(RefundingEvent{
                project: id_address(project),
                total_sold: project.launchstate.total_sold,
                epoch: tx_context::epoch(ctx)
            })
        }
        else {
            lState.state = ROUND_STATE_ENDED_CLAIM;
            event::emit(TokenClaimEvent{
                project: id_address(project),
                total_sold: project.launchstate.total_sold,
                epoch: tx_context::epoch(ctx)
            })
        }
    }

    struct RefundClosedEvent has copy, drop {
        project: address,
        sui_refunded: u64,
        epoch: u64
    }

    ///@todo
    /// - stop refund process
    /// - set state to end with refund
    /// - clear state ?
    public entry fun end_refund<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext){
        project.launchstate.state = ROUND_STATE_END_REFUND;
        event::emit(RefundClosedEvent{
            project: id_address(project),
            sui_refunded: project.launchstate.total_sold, //@todo update total refunded
            epoch: tx_context::epoch(ctx)
        })
    }

    struct DistributeRaisedFundEvent has copy, drop {
        project: address,
        epoch: u64
    }

    ///@todo
    /// - allocate raised budget, maybe:
    ///     *transfer all to project owner
    ///     *charge fee
    ///     *add liquidity
    public entry fun distribute_raised_fund<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, projectOwner: address, ctx: &mut TxContext){
        validate_allocate_budget(project);
        let budget = option::extract(&mut project.launchstate.raised_sui);
        transfer::transfer(budget, projectOwner);
        event::emit(DistributeRaisedFundEvent{
            project: id_address(project),
            epoch: tx_context::epoch(ctx)
        })
    }

    ///@todo
   /// - refund token to owner when failed to make fund-raising
    public entry fun reufund_token<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, projectOwner: address, _ctx: &mut TxContext){
        validate_allocate_budget(project);
        let budget = option::extract(&mut project.launchstate.token_fund);
        transfer::transfer(budget, projectOwner);
    }

    ///@todo user claim token
    public entry fun vest_token<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        validate_vesting(project);
        let sender = sender(ctx);
        let lState = &mut project.launchstate;
        let order = vec_map::get_mut(&mut lState.buy_orders, &sender);
        //@todo make vesting according to milestone or linear, the most simple: distribute right now
        let moreToken = order.token_amt - order.token_released;
        assert!(moreToken > 0, ERR_CLAIM_DONE);
        let token = coin::split<COIN>(option::borrow_mut(&mut lState.token_fund), moreToken, ctx);
        transfer::transfer(token, sender);
    }

    ///@todo when project refund, use claim sui
    public entry fun claim_refund<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        validate_refund(project);
        let sender = sender(ctx);
        let order = vec_map::get_mut(&mut project.launchstate.buy_orders, &sender(ctx));
        let userSui = coin::split(option::borrow_mut(&mut project.launchstate.raised_sui), order.sui_amount, ctx);
        transfer::transfer(userSui, sender);
    }

    public entry fun vote<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        let com = &mut project.community;
        let senderAddr = sender(ctx);
        let votes = dynamic_field::borrow_mut<vector<u8>, VecSet<address>>(&mut com.id, VOTES);

        assert!(vec_set::contains(votes, &senderAddr), ERR_ALREADY_VOTE);

        com.vote = com.vote + 1;
        vec_set::insert(votes, senderAddr);
    }

    public entry fun like<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        let com = &mut project.community;
        let senderAddr = sender(ctx);
        let likes = dynamic_field::borrow_mut<vector<u8>, VecSet<address>>(&mut com.id, LIKES);

        assert!(vec_set::contains(likes, &senderAddr), ERR_ALREADY_VOTE);

        com.like = com.like +1;
        vec_set::insert(likes, senderAddr);
    }

    public entry fun watch<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        let com = &mut project.community;
        let senderAddr = sender(ctx);
        let watch = dynamic_field::borrow_mut<vector<u8>, VecSet<address>>(&mut com.id, WATCHS);

        assert!(vec_set::contains(watch, &senderAddr), ERR_ALREADY_VOTE);

        com.like = com.like +1;
        vec_set::insert(watch, senderAddr);
    }

    ///@todo validate mile stone:
    /// -make sure that sum of all milestone is <= 100%
    /// -time is ordered min --> max, is valid, should be offset
    fun check_mile_stones(_milestone: &vector<ProjectVestingMileStone>){
       
    }

    //==========================================Start Validate Area==========================================
    ///@todo
    /// round must not be started, running ...
    fun validate_start_fund_raising<COIN>(project: &mut Project<COIN>){
        assert!(project.launchstate.state >= ROUND_STATE_ENDED_CLAIM, ERR_INVALID_ROUND_STATE);
    }

    fun validate_state_for_buy<COIN>(project: &mut Project<COIN>, senderAddr: address){
        assert!(project.launchstate.state == ROUND_STATE_RASING, ERR_INVALID_ROUND_STATE);
        assert!(!project.usewhitelist || vec_set::contains(dynamic_field::borrow<vector<u8>, VecSet<address>>(&project.id, WHITELIST), &senderAddr), ERR_NOT_WHITELIST);
    }

    fun validate_vesting<COIN>(project: &mut Project<COIN>){
        assert!(project.launchstate.state == ROUND_STATE_ENDED_CLAIM, ERR_INVALID_ROUND_STATE);
    }

    fun validate_refund<COIN>(project: &mut Project<COIN>){
        assert!(project.launchstate.state == ROUND_STATE_REFUNDING, ERR_INVALID_ROUND_STATE);
    }

    fun validate_allocate_budget<COIN>(project: &mut Project<COIN>){
        assert!(project.launchstate.state == ROUND_STATE_END_REFUND || project.launchstate.state == ROUND_STATE_ENDED_CLAIM, ERR_INVALID_ROUND_STATE);
    }
    //==========================================End Validate Area==========================================


    //==========================================Start Event Area==========================================
    fun build_event_add_project<COIN>(project: &Project<COIN>): ProjectCreatedEvent{
        let event = ProjectCreatedEvent{
            name: project.profile.name,
            twitter: project.profile.twitter,
            discord: project.profile.discord,
            telegram: project.profile.telegram,
            website: project.profile.website,
            soft_cap: project.launchstate.soft_cap,
            hard_cap: project.launchstate.hard_cap,
            round: project.launchstate.round, //which round ?
            state: project.launchstate.state,
            total_sold: project.launchstate.total_sold, //for each round
            swap_ratio_sui: project.launchstate.swap_ratio_sui,
            swap_ratio_token: project.launchstate.swap_ratio_token,
            participants: project.launchstate.participants,
            max_allocate: project.launchstate.max_allocate, //in sui
            start_time: project.launchstate.start_time,
            end_time: project.launchstate.end_time,
            coin_metadata: project.contract.coin_metadata,
            token_symbol: project.contract.symbol,
            token_name:  project.contract.name,
            token_description:  project.contract.description,
            token_url:  project.contract.url,
            token_decimals:  project.contract.decimals,
            usewhitelist:  project.usewhitelist,
            vesting_type: dynamic_field::borrow<vector<u8>, Vesting<COIN>>(&project.id, VESTING).type,
            vesting_init_release_time: dynamic_field::borrow<vector<u8>, Vesting<COIN>>(&project.id, VESTING).init_release_time,
            vesting_milestones:dynamic_field::borrow<vector<u8>, Vesting<COIN>>(&project.id, VESTING).milestones
        };

        event
    }
    struct StartFundRaisingEvent has copy, drop {
        project: address,
        start_time: u64
    }
    struct BuyEvent has copy, drop {
        project: address,
        buyer: address,
        total_sui_amt: u64,
        epoch: u64
    }
    struct RefundingEvent has copy, drop {
        project: address,
        total_sold: u64,
        epoch: u64
    }
    struct TokenClaimEvent has copy, drop {
        project: address,
        total_sold: u64,
        epoch: u64
    }
    struct AddWhiteListEvent has copy, drop {
        whitelist: address
    }
    struct ProjectCreatedEvent has copy, drop {
        name: vector<u8>,
        twitter: vector<u8>,
        discord: vector<u8>,
        telegram: vector<u8>,
        website: vector<u8>,
        soft_cap: u64,
        hard_cap: u64,
        round: u8, //which round ?
        state: u8,
        total_sold: u64, //for each round
        swap_ratio_sui: u64,
        swap_ratio_token: u64,
        participants: u64,
        max_allocate: u64, //in sui
        start_time: u64,
        end_time: u64,
        coin_metadata: address,
        token_symbol: vector<u8>,
        token_name: vector<u8>,
        token_description: vector<u8>,
        token_url: Option<vector<u8>>,
        token_decimals: u8,
        usewhitelist: bool,
        vesting_type: u8,
        vesting_init_release_time: u64,
        vesting_milestones: Option<vector<ProjectVestingMileStone>>
    }
    //==========================================Start Event Area==========================================
}

#[test_only]
module seapad::project_tests {
    #[test]
    fun test_create_project(){

    }

    #[test]
    fun test_update_project(){

    }

    #[test]
    fun test_fundraising_project(){

    }

    #[test]
    fun test_refund_project(){

    }

    #[test]
    fun test_claim_project(){

    }
}