module seapad::project {
    use std::option::Option;
    use std::ascii;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer;
    use sui::object::{UID, ID};
    use sui::object;
    use sui::coin::{CoinMetadata, Coin};
    use sui::coin;
    use std::string;
    use sui::address;
    use std::vector;
    use std::option;
    use sui::linked_table::LinkedTable;
    use sui::linked_table;
    use std::ascii::String;
    use sui::bag;
    use sui::bag::Bag;
    use sui::sui::SUI;
    use sui::vec_map::VecMap;
    use sui::vec_map;

    ///Define model first

    struct SPT_PAD has drop {

    }

    struct PROJECT has drop {

    }

    const ERR_INVALID_VESTING_TYPE: u64 = 1000;
    const ERR_INVALID_ROUND: u64 = 1001;
    const ERR_INVALID_ROUND_STATE: u64 = 1002;
    const ERR_MAX_ALLOCATE: u64 = 1003;
    const ERR_OUTOF_MARKETCAP: u64 = 1004;

    struct ProjectProfile<phantom COIN> has key, store{
        id: UID,
        name: vector<u8>,
        twitter: vector<u8>,
        discord: vector<u8>,
        telegram: vector<u8>,
        website: vector<u8>,
    }

    const ROUND_INIT: u8 = 1;
    const ROUND_SEED: u8 = 2;
    const ROUND_PRIVATE: u8 = 3;
    const ROUND_PUBLIC: u8 = 4;

    const ROUND_STATE_INIT: u8 = 1;
    const ROUND_STATE_PREPARE: u8 = 2;
    const ROUND_STATE_RASING: u8 = 3;
    const ROUND_STATE_ENDED: u8 = 4;

    struct BuyInfo<phantom COIN>  has store{
        buyer: address,
        sui: Coin<SUI>,
        token_total: u64, //total token
        token_released: u64, //released
        token: Option<Coin<COIN>> //all token not released!
    }

    ///@todo how to do vesting ?
    struct VestingRegistry<phantom COIN>  has key, store{
        id: UID,
        //@todo add more field
    }

    struct FundRaisingRegistry<phantom COIN>  has key, store{
        id: UID,
        //@todo add more field
        orders: VecMap<address, BuyInfo<COIN>>
    }

    struct ProjectLaunchState<phantom COIN> has key, store{
        id: UID,
        round: u8, //which round ?
        round_state: u8,
        total_sold: u64, //for each round
        total_raised: u64, // all round
        swap_ratio: u64,
        participants: u64,
        max_allocate: u64, //in sui
        start_time: u64,
        end_time: u64,
        distribute_time: u64,
        init_market_cap: u64, //cap by sui
        market_cap: u64,
        init_token_circulation: u64,
        token_fund: Option<Coin<COIN>>,
        fund_raising_registry: FundRaisingRegistry<COIN>
    }

    ///should refer to object
    struct ProjectContract<phantom COIN> has key, store{
        id: UID,
        coin_metadata: address
    }

    ///lives in launchpad domain
    struct ProjectCommunity<phantom COIN> has key, store{
        id: UID,
        like: u128,
        vote: u128,
        watch: u128
    }

    ///lives in user domain to save gas
    struct ProjectCommunityUser<phantom COIN> has key, store{
        id: UID,
        likes: vector<address>,
        votes: vector<address>,
        watchs: vector<address>,
    }

    const VESTING_TYPE_MILESTONE: u8 = 1;
    const VESTING_TYPE_LINEAR: u8 = 2;

    struct ProjectVestingMileStone has store{
        time: u64,
        percent: u8
    }

    struct ProjectVesting<phantom COIN> has key, store{
        id: UID,
        type: u8,
        init_release_time: u64,
        ///when mode is VESTING_TYPE_MILESTONE
        /// should be optional
        /// @todo should be linked list
        milestones: Option<vector<ProjectVestingMileStone>>
    }

    struct Project<phantom COIN> has key, store {
        id: UID,
        profile: ProjectProfile<COIN>,
        launchstate: ProjectLaunchState<COIN>,
        contract: ProjectContract<COIN>,
        community: ProjectCommunity<COIN>,
        vesting: ProjectVesting<COIN>
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
    fun init(witness: PROJECT, ctx: &mut TxContext){
        let adminCap = AdminCap { id: object::new(ctx)};
        transfer::transfer(adminCap, sender(ctx));

        //share this registry for anyone to see
        transfer::share_object(Projects<SPT_PAD> {
            id: object::new(ctx),
            projects: vector::empty<address>()
        });

        transfer::share_object(PadConfig{
            id: object::new(ctx),
            adminAddr: sender(ctx)
        })
    }

    ///change admin
    public entry fun changeAdmin(adminCap: AdminCap, to: address, padConfig: &mut PadConfig, ctx: &mut TxContext){
        padConfig.adminAddr = to;
        transfer::transfer(adminCap, to);
    }

    /// add one project
    /// @todo verify params
    public entry fun addProject<COIN>(_adminCap: &AdminCap, projects: &mut Projects<SPT_PAD>,
                                name: vector<u8>,
                                twitter: vector<u8>,
                                discord: vector<u8>,
                                telegram: vector<u8>,
                                website: vector<u8>,
                                swap_ratio: u64,
                                max_allocate: u64,
                                distribute_time: u64,
                                init_market_cap: u64,
                                init_token_circulation: u64,
        vesting_type: u8,
        first_mlst_time: u64,
        first_mlst_percent: u8,
        second_mlst_time: u64,
        second_mlst_percent: u8,
        third_first_mlst_time: u64,
        third_first_mlst_percent: u8,
        fourth_first_mlst_time: u64,
        fourth_first_mlst_percent: u8,
        coin_metadata: &CoinMetadata<COIN>, //@todo fixme : can't be owner of this data
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

        let launchstate = ProjectLaunchState<COIN> {
            id: object::new(ctx),
            round: ROUND_INIT, //which round ?
            round_state: ROUND_STATE_INIT,
            total_sold: 0, //for each round
            total_raised: 0, // all round
            swap_ratio,
            participants: 0,
            max_allocate,
            start_time: 0,
            end_time: 0,
            distribute_time,
            init_market_cap,
            market_cap: 0,
            init_token_circulation,
            token_fund: option::none<Coin<COIN>>(),
            fund_raising_registry: FundRaisingRegistry<COIN> {
                id: object::new(ctx),
                orders: vec_map::empty<address, BuyInfo<COIN>>()
            }
        };
        let contract = ProjectContract {
            id: object::new(ctx),
            coin_metadata: object::id_address(coin_metadata)
        };

        let community = ProjectCommunity<COIN>{
            id: object::new(ctx),
            like: 0,
            vote: 0,
            watch: 0
        };

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
            checkMileStones(&mut vestingMlsts);
        };

        let vesting = ProjectVesting {
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
            vesting
        };

        vector::push_back(&mut projects.projects, object::id_address(&project));

        ///share project
        transfer::share_object(project);
    }

    /// if you want more milestones
    public entry fun addMileStone<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, time: u64, percent: u8){
        let vesting = &mut project.vesting;
        assert!(vesting.type == VESTING_TYPE_MILESTONE, ERR_INVALID_VESTING_TYPE);
        let milestone = option::borrow_mut(&mut vesting.milestones);
        vector::push_back(milestone, ProjectVestingMileStone{ time, percent });
        checkMileStones(milestone);
    }

    public entry fun updateProjectLaunch<COIN>(_adminCap: &AdminCap,
                                         project: &mut Project<COIN>,
                                         swap_ratio: u64,
                                         max_allocate: u64,
                                         start_time: u64,
                                         distribute_time: u64,
                                         init_market_cap: u64,
                                         init_token_circulation: u64,
                                         ctx: &mut TxContext){
        let lState = &mut project.launchstate;
        lState.swap_ratio = swap_ratio;
        lState.max_allocate = max_allocate;
        lState.start_time = start_time;
        lState.distribute_time = distribute_time;
        lState.init_market_cap = init_market_cap;
        lState.init_token_circulation = init_token_circulation;
    }

    ///@todo
    /// - make sure coin merged
    /// - should limit to the one that register project ?
    /// - make sure token deposit match the market cap & swap ratio
    public entry fun userDepositProjectFundToken<COIN>(_adminCap: &AdminCap, token: Coin<COIN>, project: &mut Project<COIN>, ctx: &mut TxContext){
        if(option::is_some(&project.launchstate.token_fund)){
            let before = option::borrow_mut(&mut project.launchstate.token_fund);
            coin::join(before, token);
        }
        else {
            option::fill(&mut project.launchstate.token_fund, token);
        }
    }

    ///@todo
    public entry fun startFundRaising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, round: u8){
        validateLaunchRound(project, round);
        project.launchstate.round = round;
        project.launchstate.round_state = ROUND_STATE_RASING;
    }

    ///@todo
    /// - implement token buy
    /// - with someone need to do KYC, check KYC objects
    /// - validate market cap in sui: reject all orders that is:
    ///   * reach max_allocate
    ///   * already full market cap
    /// - @todo move distribute function here to decrease gas cost
    public entry fun buy<COIN>(suiCoin: Coin<SUI>, project: &mut Project<COIN>, ctx: &mut TxContext){
        validateStateForBuy(project);
        let lState = &mut project.launchstate;

        assert!(coin::value(&suiCoin) <= lState.max_allocate, ERR_MAX_ALLOCATE);
        assert!(lState.market_cap >= lState.total_sold + coin::value(&suiCoin), ERR_OUTOF_MARKETCAP);

        let registry = &mut lState.fund_raising_registry;
        lState.participants  = lState.participants + 1;
        lState.total_sold = lState.total_sold + coin::value(&suiCoin);

        //one sui cost [ratio] token @todo check overflow
        let tokenAmt = coin::value(&suiCoin) * lState.swap_ratio;
        let tokenDistributed = coin::split(option::borrow_mut<Coin<COIN>>(&mut lState.token_fund), tokenAmt, ctx);

        vec_map::insert(&mut registry.orders, sender(ctx), BuyInfo<COIN> {
            buyer: sender(ctx),
            sui: suiCoin, //just bid
            token_total: tokenAmt, //not distributed
            token_released: 0, //not released
            token: option::some<Coin<COIN>>(tokenDistributed) //not released yet
        })
    }

    ///@todo end fund raising of one project
    public entry fun endFundRaising<COIN>(_adminCap: &AdminCap, project: &mut Project<COIN>, ctx: &mut TxContext){
        project.launchstate.round_state = ROUND_STATE_ENDED;
    }

    ///@todo user vesting token, how to do that ?
    public entry fun vesting<COIN>(project: &mut Project<COIN>, ctx: &mut TxContext){
        validateVesting(project);
        let sender = sender(ctx);
        let orders = &mut project.launchstate.fund_raising_registry.orders;
        let order = vec_map::get_mut(orders, &sender(ctx));
        //@todo make vesting ...
    }

    ///@todo
    public entry fun vote<COIN>(project: &mut Project<COIN>,  ctx: &mut TxContext){

    }

    ///@todo
    public entry fun like<COIN>(project: &mut Project<COIN>,  ctx: &mut TxContext){

    }

    ///@todo
    public entry fun watch<COIN>(project: &mut Project<COIN>,  ctx: &mut TxContext){

    }

    ///@todo validate mile stone:
    /// -make sure that: sum of all milestone is <= 100%
    /// -valid times
    fun checkMileStones(_milestone: &vector<ProjectVestingMileStone>){
       
    }

    ///@todo
    /// round must not be started, running ...
    fun validateLaunchRound<COIN>(project: &mut Project<COIN>, round: u8){
        assert!((round >= ROUND_SEED) && (round <= ROUND_PUBLIC), ERR_INVALID_ROUND);
        assert!(round > project.launchstate.round, ERR_INVALID_ROUND);
        assert!(project.launchstate.round_state >= ROUND_STATE_ENDED, ERR_INVALID_ROUND_STATE);
    }

    fun validateStateForBuy<COIN>(project: &mut Project<COIN>){
        assert!(project.launchstate.round_state == ROUND_STATE_RASING, ERR_INVALID_ROUND_STATE);
    }

    fun validateVesting<COIN>(project: &mut Project<COIN>){
        assert!(project.launchstate.round_state == ROUND_STATE_ENDED, ERR_INVALID_ROUND_STATE);
    }
}
