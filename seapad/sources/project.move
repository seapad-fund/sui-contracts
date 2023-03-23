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

    use w3libs::payment;

    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::dynamic_field;
    use sui::event;
    use sui::math;
    use sui::object::{Self, UID, id_address};
    use sui::sui::SUI;
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext, sender};
    use sui::url;
    use sui::vec_set::{Self, VecSet};
    use sui::bag::Bag;
    use sui::bag;

    ///Define model first

    struct SPT_PAD has drop {}

    struct PROJECT has drop {}

    const SUI_DECIMALS: u8 = 9;

    const EInvalidVestingType: u64 = 1000;
    const EInvalidRound: u64 = 1001;
    const EInvalidRoundState: u64 = 1002;
    const EMaxAllocate: u64 = 1003;
    const EOutOfHardCap: u64 = 1004;
    const EVoted: u64 = 1005;
    const EClaimDone: u64 = 1006;
    const EProjectNotWhitelist: u64 = 1007;
    const EExistsInWhitelist: u64 = 1008;
    const ENotWhitelist: u64 = 1009;
    const EInvalidPercent: u64 = 1010;
    const EExceedPercent: u64 = 1011;
    const ETimeGENext: u64 = 1012;
    const EInvalidTimeVest: u64 = 1013;
    const EInvalidSwapRatioToken: u64 = 1014;
    const EInvalidSwapRatioSui: u64 = 1015;
    const ENotEnoughTokenFund: u64 = 1016;
    const ENoOrder: u64 = 1017;
    const ENotOwner: u64 = 1018;
    const EExistsCoinMetadata: u64 = 1019;
    const ENotExistsInWhitelist: u64 = 1020;


    const ROUND_SEED: u8 = 1;
    const ROUND_PRIVATE: u8 = 2;
    const ROUND_PUBLIC: u8 = 3;
    const ROUND_STATE_INIT: u8 = 1;
    const ROUND_STATE_PREPARE: u8 = 2;
    const ROUND_STATE_RASING: u8 = 3;
    const ROUND_STATE_REFUNDING: u8 = 4;
    //complete & start refunding
    const ROUND_STATE_END_REFUND: u8 = 5;
    //refund completed & stop
    const ROUND_STATE_CLAIMING: u8 = 6; //complete & ready to claim token


    ///lives in launchpad domain
    ///use dynamic field to add likes, votes, and watch
    const LIKES: vector<u8> = b"likes";
    //likes: VecSet<address>
    const WATCHS: vector<u8> = b"watchs";
    //watchs: VecSet<address>,
    const VOTES: vector<u8> = b"votes"; //votes: VecSet<address>

    const VESTING_TYPE_MILESTONE: u8 = 1;
    const VESTING_TYPE_LINEAR: u8 = 2;
    const TOKEN_INFO: vector<u8> = b"token_info";
    const WHITELIST: vector<u8> = b"whitelist";
    const PROFILE: vector<u8> = b"profile";
    const MAX_ALLOCATE: vector<u8> = b"max_allocate";

    struct ProjectProfile has store {
        name: vector<u8>,
        twitter: vector<u8>,
        discord: vector<u8>,
        telegram: vector<u8>,
        website: vector<u8>,
    }

    struct Order has store {
        buyer: address,
        sui_amount: u64,
        token_amount: u64,
        token_released: u64,
    }

    struct LaunchState<phantom COIN> has key, store {
        id: UID,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        //which round ?
        state: u8,
        total_token_sold: u64,
        //for each round
        swap_ratio_sui: u64,
        swap_ratio_token: u64,
        participants: u64,
        //in sui
        start_time: u64,
        //when project stop fund-raising and decide to refund or payout token(ready to claim)
        end_time: u64,
        //owner of project deposit token fund enough to raising fund
        token_fund: Option<Coin<COIN>>,
        sui_raised: Option<Coin<SUI>>,
        order_book: Table<address, Order>,
        max_allocation: Bag,
    }

    ///should refer to object
    struct TokenMetadata has store {
        coin_metadata: address,
        symbol: vector<u8>,
        name: vector<u8>,
        description: vector<u8>,
        icon_url: vector<u8>,
        decimals: u8,
    }

    struct Community has key, store {
        id: UID,
        total_vote: u64,
        voters: VecSet<address>
    }

    struct VestingMileStone has copy, drop, store {
        time: u64,
        percent: u16
    }

    struct Vesting has key, store {
        id: UID,
        type: u8,
        init_release_time: u64,
        //must be shorted list
        milestones: vector<VestingMileStone>
    }

    struct Project<phantom COIN> has key, store {
        id: UID,
        launch_state: LaunchState<COIN>,
        community: Community,
        use_whitelist: bool,
        owner: address,
        token_metadata: TokenMetadata,
        vesting: Vesting
        //        profile: //use dynamic field
        //        whitelist: VecSet<address> //use dynamic field
    }

    struct AdminCap has key, store {
        id: UID
    }

    ///initialize SPT_PAD project
    /// with witness
    /// with admin
    /// share list of projects
    /// share pad config
    fun init(_witness: PROJECT, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::transfer(adminCap, sender(ctx));
    }

    ///change admin
    public entry fun abdicate_admin(adminCap: AdminCap, to: address) {
        transfer::transfer(adminCap, to);
    }

    /// add one project
    public entry fun create_project<COIN>(_adminCap: &AdminCap,
                                          owner: address,
                                          vesting_type: u8,
                                          coin_metadata: &CoinMetadata<COIN>,
                                          ctx: &mut TxContext) {
        let launchstate = LaunchState<COIN> {
            id: object::new(ctx),
            soft_cap: 0,
            hard_cap: 0,
            round: 0,
            state: ROUND_STATE_INIT,
            total_token_sold: 0,
            swap_ratio_sui: 0,
            swap_ratio_token: 0,
            participants: 0,
            start_time: 0,
            end_time: 0,
            token_fund: option::none<Coin<COIN>>(),
            sui_raised: option::none<Coin<SUI>>(),
            order_book: table::new(ctx),
            max_allocation: bag::new(ctx)
        };

        let community = Community {
            id: object::new(ctx),
            total_vote: 0,
            voters: vec_set::empty()
        };
        dynamic_field::add(&mut community.id, LIKES, vec_set::empty<address>());
        dynamic_field::add(&mut community.id, WATCHS, vec_set::empty<address>());
        dynamic_field::add(&mut community.id, VOTES, vec_set::empty<address>());

        let vesting_obj = Vesting {
            id: object::new(ctx),
            type: vesting_type,
            init_release_time: 0,
            milestones: vector::empty<VestingMileStone>()
        };

        let project = Project {
            id: object::new(ctx),
            owner,
            launch_state: launchstate,
            community,
            use_whitelist: false,
            token_metadata: flat_token_metadata(coin_metadata),
            vesting: vesting_obj
        };

        event::emit(build_event_create_project(&project));
        transfer::share_object(project);
    }

    public entry fun change_owner<COIN>(_admin_cap: &AdminCap, new_owner: address, project: &mut Project<COIN>){
        project.owner = new_owner;
        event::emit(ChangeProjectOwnerEvent{project: id_address(project), new_owner});
    }

    /// if you want more milestones
    public entry fun add_milestone<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         time: u64,
                                         percent: u16,
                                         ctx: &mut TxContext) {
        let vesting = &mut project.vesting;

        assert!(vesting.type == VESTING_TYPE_MILESTONE, EInvalidVestingType);
        let milestones = &mut vesting.milestones;
        if (vector::is_empty(milestones)) {
            vesting.init_release_time = time;
        };
        vector::push_back(milestones, VestingMileStone { time, percent });
        validate_mile_stones(milestones, tx_context::epoch(ctx));
    }

    public entry fun reset_milestone<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, _ctx: &mut TxContext) {
        let vesting = &mut project.vesting;
        vesting.milestones = vector::empty<VestingMileStone>();
    }

    public entry fun setup_project<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         round: u8,
                                         usewhitelist: bool,
                                         swap_ratio_sui: u64,
                                         swap_ratio_token: u64,
                                         max_allocate: u64,
                                         start_time: u64,
                                         end_time: u64,
                                         soft_cap: u64,
                                         hard_cap: u64,
                                         _ctx: &mut TxContext) {
        project.use_whitelist = usewhitelist;
        if (usewhitelist) {
            dynamic_field::add(&mut project.id, WHITELIST, vec_set::empty<address>());
        };
        let launchstate = &mut project.launch_state;

        bag::add(&mut launchstate.max_allocation, MAX_ALLOCATE, max_allocate);
        launchstate.round = round;
        launchstate.swap_ratio_sui = swap_ratio_sui;
        launchstate.swap_ratio_token = swap_ratio_token;
        launchstate.start_time = start_time;
        launchstate.end_time = end_time;
        launchstate.soft_cap = soft_cap;
        launchstate.hard_cap = hard_cap;

        event::emit(SetupProjectEvent {
            project: id_address(project),
            usewhitelist,
            round,
            swap_ratio_sui,
            swap_ratio_token,
            max_allocate,
            start_time,
            end_time,
            soft_cap,
            hard_cap
        });
    }

    public entry fun add_max_allocate<COIN>(_admin_cap: &AdminCap,
                                            user: address,
                                            max_allocate: u64,
                                            project: &mut Project<COIN>,
                                            _ctx: &mut TxContext) {
        let max_allocation = &mut project.launch_state.max_allocation;
        if (bag::contains(max_allocation, user)) {
            bag::remove<address, u64>(max_allocation, user);
        };
        bag::add(max_allocation, user, max_allocate);

        event::emit(AddMaxAllocateEvent { user, max_allocate })
    }

    public entry fun remove_max_allocate<COIN>(_admin_cap: &AdminCap,
                                               user: address,
                                               project: &mut Project<COIN>,
                                               _ctx: &mut TxContext) {
        let max_allocation = &mut project.launch_state.max_allocation;
        if (bag::contains(max_allocation, user)) {
            bag::remove<address, u64>(max_allocation, user);
        };
        event::emit(RemoveMaxAllocateEvent { user })
    }

    public entry fun save_profile<COIN>(_adminCap: &AdminCap,
                                        project: &mut Project<COIN>,
                                        name: vector<u8>,
                                        twitter: vector<u8>,
                                        discord: vector<u8>,
                                        telegram: vector<u8>,
                                        website: vector<u8>,
                                        _ctx: &mut TxContext) {
        let exists = dynamic_field::exists_with_type<vector<u8>, ProjectProfile>(&project.id, PROFILE);
        if (exists) {
            let profile = dynamic_field::borrow_mut<vector<u8>, ProjectProfile>(&mut project.id, PROFILE);
            profile.name = name;
            profile.twitter = twitter;
            profile.discord = discord;
            profile.telegram = telegram;
            profile.website = website;
        }else {
            dynamic_field::add(&mut project.id, PROFILE, ProjectProfile {
                name,
                twitter,
                discord,
                telegram,
                website
            })
        }
    }

    public entry fun add_whitelist<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         user_list: vector<address>,
                                         _ctx: &mut TxContext) {
        assert!(project.use_whitelist, EProjectNotWhitelist);
        let whitelist = dynamic_field::borrow_mut<vector<u8>, VecSet<address>>(&mut project.id, WHITELIST);
        let temp_list = vector::empty<address>();

        let i = 0;
        while (i < vector::length(&user_list)) {
            let user_address = vector::pop_back(&mut user_list);
            assert!(!vec_set::contains(whitelist, &user_address), EExistsInWhitelist);
            vec_set::insert(whitelist, user_address);
            vector::push_back(&mut temp_list, user_address);

            i = i + 1;
        };

        event::emit(AddWhiteListEvent { project: id_address(project), users: temp_list });
    }

    public entry fun remove_whitelist<COIN>(_adminCap: &AdminCap,
                                            project: &mut Project<COIN>,
                                            user_list: vector<address>,
                                            _ctx: &mut TxContext) {
        assert!(project.use_whitelist, EProjectNotWhitelist);
        let whitelist = dynamic_field::borrow_mut<vector<u8>, VecSet<address>>(&mut project.id, WHITELIST);
        let temp_list = vector::empty<address>();

        let i = 0;
        while (i < vector::length(&user_list)) {
            let user_address = vector::pop_back(&mut user_list);
            assert!(vec_set::contains(whitelist, &user_address), ENotExistsInWhitelist);
            vec_set::remove(whitelist, &user_address);
            vector::push_back(&mut temp_list, user_address);

            i = i + 1;
        };
        event::emit(RemoveWhiteListEvent { project: id_address(project), users: temp_list });
    }

    public entry fun start_fund_raising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        validate_start_fund_raising(project);
        project.launch_state.total_token_sold = 0;
        project.launch_state.participants = 0;
        project.launch_state.state = ROUND_STATE_RASING;
        event::emit(StartFundRaisingEvent {
            project: id_address(project),
            epoch: tx_context::epoch(ctx)
        })
    }

    public entry fun buy<COIN>(suis: vector<Coin<SUI>>, amount: u64, project: &mut Project<COIN>, ctx: &mut TxContext) {
        let sui_amt = payment::take_from(suis, amount, ctx);
        let buyer_address = sender(ctx);
        validate_state_for_buy(project, buyer_address);
        let more_sui = coin::value(&sui_amt);
        let more_token = to_token_value(more_sui, project);

        let launchstate = &mut project.launch_state;
        launchstate.total_token_sold = launchstate.total_token_sold + more_token;

        assert!(launchstate.hard_cap >= launchstate.total_token_sold, EOutOfHardCap);
        let order_book = &mut launchstate.order_book;

        if (!table::contains(order_book, buyer_address)) {
            let newBuyOrder = Order {
                buyer: buyer_address,
                sui_amount: 0,
                token_amount: 0, //not distributed
                token_released: 0, //not released
            };
            table::add(order_book, buyer_address, newBuyOrder);
            launchstate.participants = launchstate.participants + 1;
        };
        let order = table::borrow_mut(order_book, buyer_address);
        order.sui_amount = order.sui_amount + more_sui;
        order.token_amount = order.token_amount + more_token;

        let bought_amt = order.sui_amount;
        assert!(bought_amt <= get_max_allocate<COIN>(buyer_address, launchstate), EMaxAllocate);

        if (option::is_none(&launchstate.sui_raised)) {
            option::fill(&mut launchstate.sui_raised, sui_amt);
        }else {
            coin::join(option::borrow_mut(&mut launchstate.sui_raised), sui_amt);
        };

        event::emit(BuyEvent {
            project: id_address(project),
            buyer: buyer_address,
            total_sui_amt: bought_amt,
            epoch: tx_context::epoch(ctx)
        })
    }

    public entry fun end_fund_raising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        let total_sui_raised = coin::value(option::borrow(&project.launch_state.sui_raised));

        if (total_sui_raised < project.launch_state.soft_cap) {
            project.launch_state.state = ROUND_STATE_REFUNDING; //start refund
        }else {
            project.launch_state.state = ROUND_STATE_CLAIMING;
        };

        event::emit(LaunchStateEvent {
            project: id_address(project),
            total_sold: project.launch_state.total_token_sold,
            epoch: tx_context::epoch(ctx),
            state: project.launch_state.state
        })
    }

    ///@todo
    /// - stop refund process
    /// - set state to end with refund
    /// - clear state ?
    public entry fun end_refund<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext) {
        project.launch_state.state = ROUND_STATE_END_REFUND;
        event::emit(RefundClosedEvent {
            project: id_address(project),
            sui_refunded: project.launch_state.total_token_sold,
            epoch: tx_context::epoch(ctx)
        })
    }

    ///@todo
    /// - allocate raised budget, maybe:
    ///     *transfer all to project owner
    ///     *charge fee
    ///     *add liquidity
    public entry fun distribute_raised_fund<COIN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN>,
        ctx: &mut TxContext
    ) {
        validate_allocate_budget(project);
        let budget = option::extract(&mut project.launch_state.sui_raised);
        transfer::transfer(budget, project.owner);

        event::emit(DistributeRaisedFundEvent {
            project: id_address(project),
            epoch: tx_context::epoch(ctx)
        })
    }


    ///@todo
    /// - refund token to owner when failed to make fund-raising
    public entry fun refund_token_to_owner<COIN>(_cap: &AdminCap, project: &mut Project<COIN>, _ctx: &mut TxContext) {
        validate_allocate_budget(project);
        let budget = option::extract(&mut project.launch_state.token_fund);
        transfer::transfer(budget, project.owner);
    }


    /// - make sure token deposit match the market cap & swap ratio
    public entry fun deposit_by_owner<COIN>(coins: vector<Coin<COIN>>,
                                            value: u64,
                                            project: &mut Project<COIN>,
                                            ctx: &mut TxContext) {
        validate_deposit(project, ctx);

        let launchstate = &mut project.launch_state;
        let token_fund = payment::take_from(coins, value, ctx);

        if (option::is_some(&launchstate.token_fund)) {
            let before = option::borrow_mut(&mut launchstate.token_fund);
            coin::join(before, token_fund);
        }else {
            option::fill(&mut launchstate.token_fund, token_fund);
        };

        event::emit(ProjectDepositFundEvent {
            project: id_address(project),
            depositor: sender(ctx),
            token_amount: value
        })
    }

    public entry fun claim_token<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext) {
        validate_vest_token(project);
        let sender = sender(ctx);
        let launchstate = &mut project.launch_state;
        let order_book = &mut launchstate.order_book;

        assert!(table::contains(order_book, sender), ENoOrder);
        let order = table::borrow_mut(order_book, sender);

        let vesting = &mut project.vesting;
        let milestones = &vesting.milestones;

        let total_percent = if (vector::is_empty(milestones)) {
            1000
        }else {
            let i = 0;
            let n = vector::length(milestones);
            let sum = 0;

            while (i < n) {
                let milestone = vector::borrow(milestones, i);
                if (tx_context::epoch(ctx) >= milestone.time) {
                    sum = sum + milestone.percent;
                }else {
                    break
                };
                i = i + 1;
            };
            sum
        };

        let more_token = order.token_amount / 1000 * (total_percent as u64);
        let more_token_actual = more_token - order.token_released;

        assert!(more_token_actual > 0, EClaimDone);
        order.token_released = order.token_released + more_token_actual;
        let token = coin::split<COIN>(option::borrow_mut(&mut launchstate.token_fund), more_token_actual, ctx);
        transfer::transfer(token, sender);
    }

    public entry fun claim_refund<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext) {
        validate_refund(project);
        let sender = sender(ctx);
        let order_book = &mut project.launch_state.order_book;
        let order = table::borrow_mut(order_book, sender);
        let amount_fund = order.sui_amount;
        let coin_fund = coin::split(option::borrow_mut(&mut project.launch_state.sui_raised), amount_fund, ctx);
        transfer::transfer(coin_fund, sender);
    }

    fun get_max_allocate<COIN>(user: address, launchstate: &LaunchState<COIN>): u64 {
        let max_allocation = &launchstate.max_allocation;
        let max_allocate = if (bag::contains(max_allocation, user)) {
            bag::borrow<address, u64>(max_allocation, user)
        }else {
            bag::borrow<vector<u8>, u64>(max_allocation, MAX_ALLOCATE)
        };

        *max_allocate
    }

    fun to_token_value<COIN>(sui_value: u64, project: &Project<COIN>): u64 {
        let swap_ratio_coin = project.launch_state.swap_ratio_sui;
        let swap_ratio_token = project.launch_state.swap_ratio_token;

        let ratio_coin = math::pow(10, SUI_DECIMALS) / swap_ratio_coin;
        let ratio_token = math::pow(10, project.token_metadata.decimals) / swap_ratio_token;

        let token_value = if (ratio_coin >= ratio_token) {
            sui_value * (ratio_coin / ratio_token)
        }else {
            let delta = ratio_token - ratio_coin;
            while(delta % 10 == 0 && ratio_token % 10 == 0){
                delta = delta / 10;
                ratio_token = ratio_token / 10;
            };
            sui_value - (sui_value * delta) / ratio_token
        };

        token_value
    }

    fun flat_token_metadata<COIN>(coin_metadata: &CoinMetadata<COIN>): TokenMetadata {
        let icon_opt = coin::get_icon_url(coin_metadata);
        let icon = vector::empty<u8>();
        if (option::is_some(&icon_opt)) {
            let url = *ascii::as_bytes(&url::inner_url(&option::extract(&mut icon_opt)));
            vector::append(&mut icon, url);
        };

        TokenMetadata {
            coin_metadata: object::id_address(coin_metadata),
            name: *string::bytes(&mut coin::get_name(coin_metadata)),
            symbol: *ascii::as_bytes(&mut coin::get_symbol(coin_metadata)),
            description: *string::bytes(&mut coin::get_description(coin_metadata)),
            decimals: coin::get_decimals(coin_metadata),
            icon_url: icon
        }
    }

    //==========================================Start Community Area=======================================
    public entry fun vote<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext) {
        let com = &mut project.community;
        let voter_address = sender(ctx);
        assert!(vec_set::contains(&mut com.voters, &voter_address), EVoted);
        com.total_vote = com.total_vote + 1;
        vec_set::insert(&mut com.voters, voter_address);
    }
    //==========================================End Community Area=========================================


    //==========================================Start Validate Area========================================
    fun validate_start_fund_raising<COIN>(project: &mut Project<COIN>) {
        let launchstate = &project.launch_state;
        let state = launchstate.state;

        assert!(
            (state >= ROUND_STATE_INIT && state < ROUND_STATE_RASING)
                || state >= ROUND_STATE_CLAIMING
                || state == ROUND_STATE_END_REFUND,
            EInvalidRoundState
        );

        let total_token = if (option::is_none(&project.launch_state.token_fund)) {
            0
        }else {
            coin::value(option::borrow(&project.launch_state.token_fund))
        };
        let token_amt_expect = to_token_value(launchstate.soft_cap, project);
        assert!(total_token >= token_amt_expect, ENotEnoughTokenFund);
    }

    /// -make sure that sum of all milestone is <= 100%
    /// -time is ordered min --> max, is valid, should be offset
    fun validate_mile_stones(milestones: &vector<VestingMileStone>, now: u64) {
        let i = 0;
        let n = vector::length(milestones);
        let total_percent = 0;

        while (i < n) {
            let milestone = vector::borrow(milestones, i);
            assert!(milestone.percent <= 1000, EInvalidPercent);
            assert!(milestone.time >= now, EInvalidTimeVest);
            if (i < n - 1) {
                let next = vector::borrow(milestones, i + 1);
                assert!(milestone.time < next.time, ETimeGENext);
            };
            total_percent = total_percent + milestone.percent;
            i = i + 1;
        };
        assert!(total_percent <= 1000, EExceedPercent);
    }

    fun validate_state_for_buy<COIN>(project: &mut Project<COIN>, senderAddr: address) {
        assert!(project.launch_state.state == ROUND_STATE_RASING, EInvalidRoundState);
        if (project.use_whitelist) {
            let whitelist = dynamic_field::borrow<vector<u8>, VecSet<address>>(&project.id, WHITELIST);
            assert!(vec_set::contains(whitelist, &senderAddr), ENotWhitelist);
        }
    }

    fun validate_vest_token<COIN>(project: &mut Project<COIN>) {
        assert!(project.launch_state.state == ROUND_STATE_CLAIMING, EInvalidRoundState);
    }

    fun validate_refund<COIN>(project: &mut Project<COIN>) {
        assert!(project.launch_state.state == ROUND_STATE_REFUNDING, EInvalidRoundState);
    }

    fun validate_allocate_budget<COIN>(project: &mut Project<COIN>) {
        let state = project.launch_state.state;
        assert!(state == ROUND_STATE_END_REFUND || state == ROUND_STATE_CLAIMING, EInvalidRoundState);
    }

    fun validate_deposit<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext) {
        let state = project.launch_state.state;
        assert!(state == ROUND_STATE_INIT, EInvalidRoundState);
        assert!(sender(ctx) == project.owner, ENotOwner);
    }
    //==========================================End Validate Area==========================================


    //==========================================Start Event Area===========================================
    fun build_event_create_project<COIN>(project: &Project<COIN>): ProjectCreatedEvent {
        let event = ProjectCreatedEvent {
            project: id_address(project),
            state: project.launch_state.state,
            usewhitelist: project.use_whitelist,
            vesting_type: project.vesting.type,
            vesting_milestones: project.vesting.milestones,
            token_info: project.token_metadata.coin_metadata
        };

        event
    }

    struct SetupProjectEvent has copy, drop {
        project: address,
        usewhitelist: bool,
        round: u8,
        swap_ratio_sui: u64,
        swap_ratio_token: u64,
        max_allocate: u64,
        start_time: u64,
        end_time: u64,
        soft_cap: u64,
        hard_cap: u64,
    }

    struct StartFundRaisingEvent has copy, drop {
        project: address,
        epoch: u64
    }

    struct BuyEvent has copy, drop {
        project: address,
        buyer: address,
        total_sui_amt: u64,
        epoch: u64
    }

    struct LaunchStateEvent has copy, drop {
        project: address,
        total_sold: u64,
        epoch: u64,
        state: u8
    }

    struct AddWhiteListEvent has copy, drop {
        project: address,
        users: vector<address>
    }

    struct RemoveWhiteListEvent has copy, drop {
        project: address,
        users: vector<address>
    }

    struct DistributeRaisedFundEvent has copy, drop {
        project: address,
        epoch: u64
    }

    struct RefundClosedEvent has copy, drop {
        project: address,
        sui_refunded: u64,
        epoch: u64
    }

    struct ProjectDepositFundEvent has copy, drop {
        project: address,
        depositor: address,
        token_amount: u64
    }

    struct ProjectCreatedEvent has copy, drop {
        project: address,
        state: u8,
        usewhitelist: bool,
        vesting_type: u8,
        vesting_milestones: vector<VestingMileStone>,
        token_info: address
    }

    struct AddMaxAllocateEvent has copy, drop {
        user: address,
        max_allocate: u64
    }

    struct RemoveMaxAllocateEvent has copy, drop {
        user: address
    }

    struct ChangeProjectOwnerEvent has copy, drop{
        project: address,
        new_owner: address
    }
    //==========================================Start Event Area==========================================

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(PROJECT {}, ctx);
    }
}

