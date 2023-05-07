// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

///This module provide fund raising functions:
/// - support whitelist, soft cap, hardcap, refund
/// - support vesting token, claim token
/// - many round
module seapad::project {
    use std::vector;
    use w3libs::payment;
    use sui::coin::{Self, Coin};
    use sui::dynamic_field;
    use sui::event;
    use sui::math;
    use sui::object::{Self, UID, id_address};
    use sui::table::{Self, Table};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext, sender};
    use sui::vec_set::{Self, VecSet};
    use sui::clock::{Clock};
    use sui::clock;
    use common::kyc::{Kyc, hasKYC};
    use seapad::version::{Version, checkVersion};
    use sui::transfer::public_transfer;

    ///Define model first

    struct PROJECT has drop {}

    const VERSION: u64 = 1;

    const EInvalidVestingType: u64 = 1000;
    const EInvalidRound: u64 = 1001;
    const EInvalidRoundState: u64 = 1002;
    const EMaxAllocate: u64 = 1003;
    const EOutOfHardCap: u64 = 1004;
    const EVoted: u64 = 1005;
    const EClaimZero: u64 = 1006;
    const EProjectNotWhitelist: u64 = 1007;
    const EExistsInWhitelist: u64 = 1008;
    const ENotWhitelist: u64 = 1009;
    const EInvalidPercent: u64 = 1010;
    const EExceedPercent: u64 = 1011;
    const ETimeGENext: u64 = 1012;
    const EInvalidTime: u64 = 1013;
    const EPercentZero: u64 = 1014;
    const EInsufficientTokenFund: u64 = 1015;
    const ENotEnoughTokenFund: u64 = 1016;
    const ENoOrder: u64 = 1017;
    const ENotOwner: u64 = 1018;
    const EExistsCoinMetadata: u64 = 1019;
    const ENotExistsInWhitelist: u64 = 1020;
    const EInvalidPermission: u64 = 1021;
    const ENotKYC: u64 = 1022;
    const EInvalidVestingParam: u64 = 1023;
    const EInvalidCoinDecimal: u64 = 1024;
    const EInvalidCap: u64 = 1025;
    const EInvalidSwapRatio: u64 = 1026;
    const EInvalidTge: u64 = 1027;
    const EInvalidMaxAllocate: u64 = 1028;
    const EInvalidWhitelist: u64 = 1029;
    const EInvalidAmount: u64 = 1030;
    const ENotEnoughCoinFund: u64 = 1031;

    const ROUND_SEED: u8 = 1;
    const ROUND_PRIVATE: u8 = 2;
    const ROUND_PUBLIC: u8 = 3;

    const ROUND_STATE_INIT: u8 = 1;
    const ROUND_STATE_PREPARE: u8 = 2;
    const ROUND_STATE_RASING: u8 = 3;
    const ROUND_STATE_REFUNDING: u8 = 4;
    //complete & start refunding
    const ROUND_STATE_CLAIMING: u8 = 6;
    //complete & ready to claim token
    const ROUND_STATE_END: u8 = 7; //close project

    const ONE_HUNDRED_PERCENT_SCALED: u64 = 10000;


    ///lives in launchpad domain
    ///use dynamic field to add likes, votes, and watch
    const VOTES: vector<u8> = b"votes"; //votes: VecSet<address>

    const VESTING_TYPE_MILESTONE_UNLOCK_FIRST: u8 = 1;
    const VESTING_TYPE_MILESTONE_CLIFF_FIRST: u8 = 2;
    const VESTING_TYPE_LINEAR_UNLOCK_FIRST: u8 = 3;
    const VESTING_TYPE_LINEAR_CLIFF_FIRST: u8 = 4;

    struct ProjectProfile has store {
        name: vector<u8>,
        twitter: vector<u8>,
        discord: vector<u8>,
        telegram: vector<u8>,
        website: vector<u8>,
    }

    struct Order has store {
        buyer: address,
        coin_amount: u64,
        token_amount: u64,
        token_released: u64,
    }

    struct LaunchState<phantom COIN, phantom TOKEN> has key, store {
        id: UID,
        soft_cap: u64,
        hard_cap: u64,
        round: u8,
        state: u8,
        total_token_sold: u64,
        swap_ratio_coin: u64,
        swap_ratio_token: u64,
        participants: u64,
        start_time: u64,
        end_time: u64,
        //when project stop fund-raising, to claim or refund
        token_fund: Coin<TOKEN>,
        coin_raised: Coin<COIN>,
        order_book: Table<address, Order>,
        default_max_allocate: u64,
        max_allocations: Table<address, u64>,
    }

    struct Community has key, store {
        id: UID,
        total_vote: u64,
        voters: VecSet<address>
    }

    struct VestingMileStone has copy, drop, store {
        time: u64,
        percent: u64,
    }

    struct Vesting has key, store {
        id: UID,
        type: u8,
        tge: u64,
        cliff_time: u64,
        //cliff time duration in ms
        unlock_percent: u64,
        //unlock percent scaled to x10
        linear_time: u64,
        //linear vesting duration if linear mode
        milestones: vector<VestingMileStone> //if milestone vesting
    }

    struct Project<phantom COIN, phantom TOKEN> has key, store {
        id: UID,
        launch_state: LaunchState<COIN, TOKEN>,
        community: Community,
        use_whitelist: bool,
        owner: address,
        coin_decimals: u8,
        token_decimals: u8,
        vesting: Vesting,
        whitelist: Table<address, address>,
        require_kyc: bool
    }

    struct AdminCap has key, store {
        id: UID
    }

    ///init with admin cap
    fun init(_witness: PROJECT, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::public_transfer(adminCap, sender(ctx));
    }

    ///change admin
    public fun change_admin(adminCap: AdminCap,
                            to: address,
                            version: &mut Version) {
        checkVersion(version, VERSION);
        transfer::public_transfer(adminCap, to);
    }

    /// add one project
    public fun create_project<COIN, TOKEN>(_adminCap: &AdminCap,
                                           owner: address,
                                           vesting_type: u8,
                                           cliff_time: u64,
                                           tge: u64,
                                           unlock_percent: u64,
                                           linear_time: u64,
                                           coin_decimals: u8,
                                           token_decimals: u8,
                                           require_kyc: bool,
                                           version: &mut Version,
                                           clock: &Clock,
                                           ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(
            vesting_type >= VESTING_TYPE_MILESTONE_UNLOCK_FIRST && vesting_type <= VESTING_TYPE_LINEAR_CLIFF_FIRST,
            EInvalidVestingType
        );
        assert!(
            tge > clock::timestamp_ms(clock) && cliff_time >= 0 && (unlock_percent <= ONE_HUNDRED_PERCENT_SCALED),
            EInvalidVestingParam
        );
        assert!(coin_decimals > 0 && token_decimals > 0, EInvalidCoinDecimal);

        let state = LaunchState<COIN, TOKEN> {
            id: object::new(ctx),
            soft_cap: 0,
            hard_cap: 0,
            round: 0,
            state: ROUND_STATE_INIT,
            total_token_sold: 0,
            swap_ratio_coin: 0,
            swap_ratio_token: 0,
            participants: 0,
            start_time: 0,
            end_time: 0,
            token_fund: coin::zero<TOKEN>(ctx),
            coin_raised: coin::zero<COIN>(ctx),
            order_book: table::new(ctx),
            default_max_allocate: 0,
            max_allocations: table::new(ctx),
        };

        let community = Community {
            id: object::new(ctx),
            total_vote: 0,
            voters: vec_set::empty()
        };

        dynamic_field::add(&mut community.id, VOTES, vec_set::empty<address>());

        let vesting = Vesting {
            id: object::new(ctx),
            type: vesting_type,
            cliff_time,
            tge,
            unlock_percent,
            linear_time,
            milestones: vector::empty<VestingMileStone>()
        };

        let project = Project {
            id: object::new(ctx),
            owner,
            launch_state: state,
            community,
            use_whitelist: false,
            coin_decimals,
            token_decimals,
            vesting,
            whitelist: table::new(ctx),
            require_kyc
        };

        event::emit(build_event_create_project(&project));
        transfer::share_object(project);
    }

    public fun change_owner<COIN, TOKEN>(
        new_owner: address,
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        let sender = sender(ctx);
        assert!(sender == project.owner, EInvalidPermission);
        let current_owner = project.owner;
        project.owner = new_owner;
        event::emit(ChangeProjectOwnerEvent { project: id_address(project), old_owner: current_owner, new_owner });
    }

    public fun add_milestone<COIN, TOKEN>(_adminCap: &AdminCap,
                                          project: &mut Project<COIN, TOKEN>,
                                          time: u64,
                                          percent: u64,
                                          sclock: &Clock,
                                          version: &mut Version,
    ) {
        checkVersion(version, VERSION);

        let vesting = &mut project.vesting;
        assert!(vesting.type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST
            || vesting.type == VESTING_TYPE_MILESTONE_CLIFF_FIRST, EInvalidVestingType);
        assert!(percent <= ONE_HUNDRED_PERCENT_SCALED, EInvalidPercent);

        let now_ms = clock::timestamp_ms(sclock);
        let tge = vesting.tge;
        let cliff = vesting.cliff_time;
        assert!(tge > now_ms && cliff >= 0 && time >= tge + cliff, EInvalidTge);
        let end_time = project.launch_state.end_time;

        let milestones = &mut vesting.milestones;
        vector::push_back(milestones, VestingMileStone { time, percent });
        validate_mile_stones(vesting, end_time, now_ms);
    }

    public fun reset_milestone<COIN, TOKEN>(_adminCap: &AdminCap,
                                            project: &mut Project<COIN, TOKEN>,
                                            version: &mut Version) {
        checkVersion(version, VERSION);

        let vesting = &mut project.vesting;
        vesting.milestones = vector::empty<VestingMileStone>();
    }

    public fun setup_project<COIN, TOKEN>(_adminCap: &AdminCap,
                                          project: &mut Project<COIN, TOKEN>,
                                          round: u8,
                                          usewhitelist: bool,
                                          swap_ratio_coin: u64,
                                          swap_ratio_token: u64,
                                          max_allocate: u64,
                                          start_time: u64,
                                          end_time: u64,
                                          soft_cap: u64,
                                          hard_cap: u64,
                                          clock: &Clock,
                                          version: &mut Version
    ) {
        checkVersion(version, VERSION);

        assert!(start_time > clock::timestamp_ms(clock) && end_time > start_time, EInvalidTime);
        assert!(hard_cap > soft_cap && soft_cap > 0, EInvalidCap);
        assert!(swap_ratio_coin > 0 && swap_ratio_token > 0, EInvalidSwapRatio);
        assert!(round >= ROUND_SEED && round <= ROUND_PRIVATE, EInvalidRound);

        let state = &mut project.launch_state;
        assert!(state.state == ROUND_STATE_INIT, EInvalidRoundState);

        state.default_max_allocate = max_allocate;
        state.round = round;
        state.swap_ratio_coin = swap_ratio_coin;
        state.swap_ratio_token = swap_ratio_token;
        state.start_time = start_time;
        state.end_time = end_time;
        state.soft_cap = soft_cap;
        state.hard_cap = hard_cap;

        project.use_whitelist = usewhitelist;

        event::emit(SetupProjectEvent {
            project: id_address(project),
            usewhitelist,
            round,
            swap_ratio_coin,
            swap_ratio_token,
            max_allocate,
            start_time,
            end_time,
            soft_cap,
            hard_cap,
        });
    }

    public fun set_max_allocate<COIN, TOKEN>(_adminCap: &AdminCap,
                                             user: address,
                                             max_allocate: u64,
                                             project: &mut Project<COIN, TOKEN>,
                                             version: &mut Version,
                                             _ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(
            project.launch_state.hard_cap > 0 && max_allocate > 0 && max_allocate < project.launch_state.hard_cap,
            EInvalidMaxAllocate
        );

        let max_allocations = &mut project.launch_state.max_allocations;
        if (table::contains(max_allocations, user)) {
            table::remove<address, u64>(max_allocations, user);
        };
        table::add(max_allocations, user, max_allocate);

        event::emit(AddMaxAllocateEvent { project: id_address(project), user, max_allocate })
    }

    public fun clear_max_allocate<COIN, TOKEN>(_adminCap: &AdminCap,
                                               user: address,
                                               project: &mut Project<COIN, TOKEN>,
                                               version: &mut Version,
                                               _ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        let max_allocation = &mut project.launch_state.max_allocations;
        if (table::contains(max_allocation, user)) {
            table::remove<address, u64>(max_allocation, user);
        };
        event::emit(RemoveMaxAllocateEvent { project: id_address(project), user })
    }

    public fun add_whitelist<COIN, TOKEN>(_adminCap: &AdminCap,
                                          project: &mut Project<COIN, TOKEN>,
                                          user_list: vector<address>,
                                          version: &mut Version,
                                          _ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        assert!(project.use_whitelist, EProjectNotWhitelist);
        assert!(vector::length(&user_list) > 0, EInvalidWhitelist);

        let whitelist = &mut project.whitelist;
        let temp_list = vector::empty<address>();

        let i = 0;
        while (i < vector::length(&user_list)) {
            let user_address = vector::pop_back(&mut user_list);
            assert!(!table::contains(whitelist, user_address), EExistsInWhitelist);
            table::add(whitelist, user_address, user_address);
            vector::push_back(&mut temp_list, user_address);

            i = i + 1;
        };

        event::emit(AddWhiteListEvent { project: id_address(project), users: temp_list });
    }

    public fun remove_whitelist<COIN, TOKEN>(_adminCap: &AdminCap,
                                             project: &mut Project<COIN, TOKEN>,
                                             user_list: vector<address>,
                                             version: &mut Version,
                                             _ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        assert!(project.use_whitelist, EProjectNotWhitelist);
        assert!(vector::length(&user_list) > 0, EInvalidWhitelist);

        let whitelist = &mut project.whitelist;
        let temp_list = vector::empty<address>();

        let i = 0;
        while (i < vector::length(&user_list)) {
            let user_address = vector::pop_back(&mut user_list);
            assert!(table::contains(whitelist, user_address), ENotExistsInWhitelist);
            table::remove(whitelist, user_address);
            vector::push_back(&mut temp_list, user_address);

            i = i + 1;
        };
        event::emit(RemoveWhiteListEvent { project: id_address(project), users: temp_list });
    }

    public fun start_fund_raising<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        _clock: &Clock,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);

        validate_start_fund_raising(project);

        project.launch_state.total_token_sold = 0;
        project.launch_state.participants = 0;
        project.launch_state.state = ROUND_STATE_RASING;

        event::emit(StartFundRaisingEvent {
            project: id_address(project),
            epoch: tx_context::epoch(ctx)
        })
    }

    public fun buy<COIN, TOKEN>(
        coins: vector<Coin<COIN>>,
        amount: u64,
        project: &mut Project<COIN, TOKEN>,
        sclock: &Clock,
        kyc: &Kyc,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);

        assert!(amount > 0, EInvalidAmount);

        let buyer_address = tx_context::sender(ctx);
        let now_ms = clock::timestamp_ms(sclock);
        assert!(!project.require_kyc || hasKYC(buyer_address, kyc), ENotKYC);
        validate_buy(project, buyer_address, now_ms);

        let coin_out = payment::take_from(coins, amount, ctx);
        let coin_out_val = coin::value<COIN>(&coin_out);
        let token_out_val = swap_token(coin_out_val, project);

        let state = &mut project.launch_state;
        state.total_token_sold = state.total_token_sold + token_out_val;

        let order_book = &mut state.order_book;

        if (!table::contains(order_book, buyer_address)) {
            let newBuyOrder = Order {
                buyer: buyer_address,
                coin_amount: 0,
                token_amount: 0, //not distributed
                token_released: 0, //not released
            };
            table::add(order_book, buyer_address, newBuyOrder);
            state.participants = state.participants + 1;
        };

        let order = table::borrow_mut(order_book, buyer_address);
        order.coin_amount = order.coin_amount + coin_out_val;
        order.token_amount = order.token_amount + token_out_val;

        let bought_amt = order.coin_amount;
        let max_allocations = &state.max_allocations;
        assert!(
            bought_amt <= get_max_allocate<COIN, TOKEN>(
                buyer_address,
                max_allocations,
                state.default_max_allocate
            ),
            EMaxAllocate
        );

        coin::join<COIN>(&mut state.coin_raised, coin_out);

        let project_id = object::uid_to_address(&project.id);
        let total_raised = coin::value<COIN>(&state.coin_raised);
        assert!(state.hard_cap >= total_raised, EOutOfHardCap);

        if (total_raised == state.hard_cap) {
            state.state = ROUND_STATE_CLAIMING;
        };

        event::emit(BuyEvent {
            project: project_id,
            buyer: buyer_address,
            order_value: coin_out_val,
            order_bought: bought_amt,
            total_raised,
            more_token: token_out_val,
            token_bought: order.token_amount,
            participants: state.participants,
            sold_out: (total_raised == state.hard_cap),
            epoch: now_ms
        })
    }

    public fun end_fund_raising<COIN, TOKEN>(
        _adminCap: &AdminCap,
        project: &mut Project<COIN, TOKEN>,
        sclock: &Clock,
        version: &mut Version,
        _ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        validate_end_fundraising(project, clock::timestamp_ms(sclock));
        let projectAddr = id_address(project);

        let launch_state = &mut project.launch_state;
        let total_coin_raised = coin::value<COIN>(&launch_state.coin_raised);
        launch_state.state = if (total_coin_raised < launch_state.soft_cap) {
            ROUND_STATE_REFUNDING
        } else {
            ROUND_STATE_CLAIMING
        };

        event::emit(LaunchStateEvent {
            project: projectAddr,
            total_sold: launch_state.total_token_sold,
            epoch: clock::timestamp_ms(sclock),
            state: launch_state.state,
            end_time: launch_state.end_time
        })
    }

    public fun distribute_raised_fund<COIN, TOKEN>(
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        validate_refund_or_distribute(project, ctx);
        let launch_state = &mut project.launch_state;
        let coin_raised_val = coin::value<COIN>(&launch_state.coin_raised);
        transfer::public_transfer(
            coin::split<COIN>(&mut launch_state.coin_raised, coin_raised_val, ctx),
            project.owner
        );

        event::emit(DistributeRaisedFundEvent {
            project: id_address(project),
            epoch: tx_context::epoch(ctx)
        })
    }

    public fun refund_token_to_owner<COIN, TOKEN>(
        project: &mut Project<COIN, TOKEN>,
        version: &mut Version,
        ctx: &mut TxContext
    ) {
        checkVersion(version, VERSION);
        validate_refund_or_distribute(project, ctx);
        let state = project.launch_state.state;
        let total_token_sold = project.launch_state.total_token_sold;

        let token_fund = &mut project.launch_state.token_fund;
        let token_fund_val = 0;
        if (state == ROUND_STATE_REFUNDING) {
            token_fund_val = coin::value(token_fund);
        };
        if (state == ROUND_STATE_CLAIMING) {
            token_fund_val = coin::value(token_fund) - total_token_sold;
        };
        transfer::public_transfer(coin::split(token_fund, token_fund_val, ctx), project.owner);
    }


    public fun withdraw_token<COIN, TOKEN>(_adminCap: &AdminCap,
                                           project: &mut Project<COIN, TOKEN>,
                                           version: &mut Version,
                                           to: address,
                                           amount: u64,
                                           ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        let token_fund = &mut project.launch_state.token_fund;
        assert!(amount > 0 && coin::value(token_fund) > amount, ENotEnoughTokenFund);
        assert!(to == project.owner, ENotOwner);
        public_transfer(coin::split(token_fund, amount, ctx), to)
    }

    public fun deposit_token<COIN, TOKEN>(tokens: vector<Coin<TOKEN>>,
                                          value: u64,
                                          project: &mut Project<COIN, TOKEN>,
                                          version: &mut Version,
                                          ctx: &mut TxContext) {
        checkVersion(version, VERSION);
        coin::join(&mut project.launch_state.token_fund, payment::take_from(tokens, value, ctx));
        event::emit(ProjectDepositFundEvent {
            project: id_address(project),
            depositor: sender(ctx),
            token_amount: value
        })
    }

    public fun claim_token<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                        clock: &Clock,
                                        version: &mut Version,
                                        ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        validate_claim(project);
        let senderAddr = sender(ctx);
        let state = &mut project.launch_state;
        let orderBook = &mut state.order_book;

        assert!(table::contains(orderBook, senderAddr), ENoOrder);
        let order = table::borrow_mut(orderBook, senderAddr);

        let total_percent = cal_claim_percent(
            &project.vesting,
            clock::timestamp_ms(clock)
        );

        total_percent = math::min(total_percent, ONE_HUNDRED_PERCENT_SCALED);

        assert!(total_percent > 0, EPercentZero);

        let total_token = (order.token_amount * total_percent) / ONE_HUNDRED_PERCENT_SCALED;
        let token_remain = total_token - order.token_released;

        assert!(token_remain > 0, EClaimZero);
        order.token_released = order.token_released + token_remain;
        transfer::public_transfer(coin::split(&mut state.token_fund, token_remain, ctx), senderAddr);

        event::emit(ClaimTokenEvent {
            project: object::id_address(project),
            user: senderAddr,
            token_amount: token_remain
        })
    }

    public fun claim_refund<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                         version: &mut Version,
                                         ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        validate_refund(project);
        let sender = sender(ctx);
        let state = &mut project.launch_state;
        let order_book = &mut state.order_book;
        let order = table::borrow_mut(order_book, sender);
        let refund_amt = order.coin_amount;
        assert!(refund_amt > 0, EClaimZero);
        state.total_token_sold = state.total_token_sold - order.token_amount;
        order.coin_amount = 0;

        transfer::public_transfer(coin::split(&mut state.coin_raised, refund_amt, ctx), sender);
        event::emit(ClaimRefundEvent { project: object::id_address(project), user: sender, coin_fund: refund_amt })
    }

    public fun vote<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>,
                                 version: &mut Version,
                                 ctx: &mut TxContext) {
        checkVersion(version, VERSION);

        let com = &mut project.community;
        let voter_address = sender(ctx);
        assert!(vec_set::contains(&mut com.voters, &voter_address), EVoted);
        com.total_vote = com.total_vote + 1;
        vec_set::insert(&mut com.voters, voter_address);
    }


    /// Internal functions
    fun get_max_allocate<COIN, TOKEN>(user: address, max_allocation: &Table<address, u64>, default: u64): u64 {
        if (table::contains(max_allocation, user)) {
            *table::borrow<address, u64>(max_allocation, user)
        }else {
            default
        }
    }

    //estimate swap token values
    fun swap_token<COIN, TOKEN>(coin_value: u64, project: &Project<COIN, TOKEN>): u64 {
        let swap_ratio_coin = (project.launch_state.swap_ratio_coin as u128);
        let swap_ratio_token = (project.launch_state.swap_ratio_token as u128);
        let decimal_ratio_coin = (math::pow(10, project.coin_decimals) as u128);
        let decimal_ratio_token = (math::pow(10, project.token_decimals) as u128);

        let token_value = (coin_value as u128) * (swap_ratio_token * decimal_ratio_token) / (swap_ratio_coin * decimal_ratio_coin);

        (token_value as u64)
    }

    fun cal_claim_percent(vesting: &Vesting, now: u64): u64 {
        let milestones = &vesting.milestones;
        let tge = vesting.tge;
        let total_percent = 0;

        if (vesting.type == VESTING_TYPE_MILESTONE_CLIFF_FIRST) {
            if (now >= tge + vesting.cliff_time) {
                total_percent = total_percent + vesting.unlock_percent;

                let (i, n) = (0, vector::length(milestones));

                while (i < n) {
                    let milestone = vector::borrow(milestones, i);
                    if (now >= milestone.time) {
                        total_percent = total_percent + milestone.percent;
                    } else {
                        break
                    };
                    i = i + 1;
                };
            };
        }
        else if (vesting.type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST) {
            if (now >= tge) {
                total_percent = total_percent + vesting.unlock_percent;

                if (now >= tge + vesting.cliff_time) {
                    let (i, n) = (0, vector::length(milestones));

                    while (i < n) {
                        let milestone = vector::borrow(milestones, i);
                        if (now >= milestone.time) {
                            total_percent = total_percent + milestone.percent;
                        } else {
                            break
                        };
                        i = i + 1;
                    };
                }
            };
        }
        else if (vesting.type == VESTING_TYPE_LINEAR_UNLOCK_FIRST) {
            if (now >= tge) {
                total_percent = total_percent + vesting.unlock_percent;
                if (now >= tge + vesting.cliff_time) {
                    let delta = now - tge - vesting.cliff_time;
                    total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED - vesting.unlock_percent) / vesting.linear_time;
                }
            };
        }
        else if (vesting.type == VESTING_TYPE_LINEAR_CLIFF_FIRST) {
            if (now >= tge + vesting.cliff_time) {
                total_percent = total_percent + vesting.unlock_percent;
                let delta = now - tge - vesting.cliff_time;
                total_percent = total_percent + delta * (ONE_HUNDRED_PERCENT_SCALED - vesting.unlock_percent) / vesting.linear_time;
            };
        };

        total_percent
    }

    fun sum_milestones_percent(milestones: &vector<VestingMileStone>): u64 {
        let total = 0u64;
        let index = vector::length(milestones);
        while (index > 0) {
            index = index - 1;
            total = total + vector::borrow(milestones, index).percent;
        };
        total
    }

    // - Allow start fundraising even when not enough token fund!
    // - Prevent fund leak with vesting type milestone: total vesting must be 100%
    fun validate_start_fund_raising<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>) {
        let state = project.launch_state.state;
        assert!(state == ROUND_STATE_INIT, EInvalidRoundState);
        let vesting = &project.vesting;
        if (vesting.type == VESTING_TYPE_MILESTONE_UNLOCK_FIRST || vesting.type == VESTING_TYPE_MILESTONE_CLIFF_FIRST) {
            assert!(
                vesting.unlock_percent + sum_milestones_percent(&vesting.milestones) == ONE_HUNDRED_PERCENT_SCALED,
                EInvalidVestingParam
            );
        };
        let token_hard_cap = swap_token(project.launch_state.hard_cap, project);
        assert!(coin::value(&project.launch_state.token_fund) >= token_hard_cap, EInsufficientTokenFund);
    }

    /// -Make sure that sum of all milestone is <= 100%
    /// -Milestones is ordered [min=0 --> max=length-1]
    fun validate_mile_stones(vesting: &Vesting, end_time_ms: u64, now_ms: u64) {
        assert!(
            sum_milestones_percent(&vesting.milestones) + vesting.unlock_percent <= ONE_HUNDRED_PERCENT_SCALED,
            EExceedPercent
        );

        let (i, n) = (0, vector::length(&vesting.milestones));
        while (i < n) {
            let milestone = vector::borrow(&vesting.milestones, i);
            assert!(milestone.time > now_ms && milestone.time > end_time_ms, EInvalidTime);
            assert!((i >= n - 1) || milestone.time < vector::borrow(&vesting.milestones, i + 1).time, ETimeGENext);
            i = i + 1;
        };
    }

    fun validate_buy<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>, buyer_addr: address, now_ms: u64) {
        let state = &project.launch_state;
        assert!(state.state == ROUND_STATE_RASING, EInvalidRoundState);
        assert!(state.start_time <= now_ms && state.end_time >= now_ms, EInvalidTime);
        assert!(!project.use_whitelist || table::contains(&project.whitelist, buyer_addr), ENotWhitelist);
    }

    fun validate_claim<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>) {
        assert!(project.launch_state.state == ROUND_STATE_CLAIMING, EInvalidRoundState);
    }

    fun validate_refund<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>) {
        assert!(project.launch_state.state == ROUND_STATE_REFUNDING, EInvalidRoundState);
    }

    fun validate_end_fundraising<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>, now: u64) {
        let state = &project.launch_state;
        assert!(state.end_time <= now || state.start_time > now, EInvalidTime);
        assert!(state.state == ROUND_STATE_RASING, EInvalidRoundState);
    }

    fun validate_refund_or_distribute<COIN, TOKEN>(project: &mut Project<COIN, TOKEN>, ctx: &mut TxContext) {
        assert!(sender(ctx) == project.owner, EInvalidPermission);
        let state = project.launch_state.state;
        assert!(state == ROUND_STATE_REFUNDING || state == ROUND_STATE_CLAIMING, EInvalidRoundState);
        if (state == ROUND_STATE_CLAIMING) {
            assert!(coin::value<COIN>(&project.launch_state.coin_raised) > 0, ENotEnoughCoinFund);
        }
    }


    /// Events
    fun build_event_create_project<COIN, TOKEN>(project: &Project<COIN, TOKEN>): ProjectCreatedEvent {
        ProjectCreatedEvent {
            project: id_address(project),
            state: project.launch_state.state,
            usewhitelist: project.use_whitelist,
            vesting_type: project.vesting.type,
            vesting_milestones: project.vesting.milestones,
        }
    }

    struct SetupProjectEvent has copy, drop {
        project: address,
        usewhitelist: bool,
        round: u8,
        swap_ratio_coin: u64,
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
        order_value: u64,
        order_bought: u64,
        token_bought: u64,
        more_token: u64,
        total_raised: u64,
        sold_out: bool,
        participants: u64,
        epoch: u64
    }

    struct LaunchStateEvent has copy, drop {
        project: address,
        total_sold: u64,
        epoch: u64,
        state: u8,
        end_time: u64
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

    struct DistributeRaisedFundEvent2 has copy, drop {
        project: address,
        to: address,
        amount: u64,
    }


    struct RefundClosedEvent has copy, drop {
        project: address,
        coin_refunded: u64,
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
    }

    struct AddMaxAllocateEvent has copy, drop {
        project: address,
        user: address,
        max_allocate: u64
    }

    struct RemoveMaxAllocateEvent has copy, drop {
        project: address,
        user: address
    }

    struct ChangeProjectOwnerEvent has copy, drop {
        project: address,
        old_owner: address,
        new_owner: address
    }

    struct ClaimTokenEvent has copy, drop {
        project: address,
        user: address,
        token_amount: u64
    }

    struct ClaimRefundEvent has copy, drop {
        project: address,
        user: address,
        coin_fund: u64
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(PROJECT {}, ctx);
    }

    #[test_only]
    public fun swap_token_for_test<COIN, TOKEN>(coin_value: u64, project: &Project<COIN, TOKEN>): u64 {
        swap_token(coin_value, project)
    }
}

