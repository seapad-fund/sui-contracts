module common::referal {
    use sui::object::{UID, id_address};
    use sui::coin::Coin;
    use sui::table::Table;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer;
    use sui::transfer::{transfer, share_object, public_transfer};
    use sui::coin;
    use sui::table;
    use sui::event::emit;
    use std::vector;
    use w3libs::u256;

    struct REFERAL has drop {}

    struct AdminCap has key, store {
        id: UID
    }

    const ERR_ALREADY_KYC: u64 = 1001;
    const ERR_NOT_KYC: u64 = 1002;
    const ERR_REFERAL_STATE: u64 = 1003;
    const ERR_NOT_ENOUGH_FUND: u64 = 1004;
    const ERR_BAD_REFERAL_INFO: u64 = 1005;

    const STATE_INIT: u8 = 0;
    const STATE_CLAIM: u8 = 1;
    const STATE_DONE: u8 = 2;

    struct Referal<phantom COIN> has key, store {
        id: UID,
        state: u8,
        fund: Coin<COIN>,
        rewards: Table<address, u64>,
        rewards_total: u64
    }


    fun init(_witness: REFERAL, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::transfer(adminCap, sender(ctx));
    }

    public entry fun change_admin(admin_cap: AdminCap, to: address) {
        transfer(admin_cap, to);
    }

    struct ReferalCreatedEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64
    }

    struct ReferalClaimStartedEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64
    }

    struct ReferalDoneEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64
    }

    struct ReferalUserClaimEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user: address,
        user_claim: u64
    }

    struct ReferalUpsertEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64,
        users: vector<address>,
        users_rewards: vector<u64>
    }

    struct ReferalRemovedEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64,
        users: vector<address>,
    }

    public entry fun create_referal<COIN>(ctx: &mut TxContext){
        let referal = Referal<COIN> {
            id: object::new(ctx),
            state: STATE_INIT,
            rewards_total: 0,
            fund: coin::zero<COIN>(ctx),
            rewards: table::new<address, u64>(ctx)
        };


        emit(ReferalCreatedEvent {
            referal: id_address(&referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards)
        });

        share_object(referal);
    }

    public entry fun upsert_referal<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, users: vector<address>, userRewards: vector<u64>, ctx: &mut TxContext){
        assert!(referal.state == STATE_INIT , ERR_REFERAL_STATE);
        let index = vector::length(&users);
        let rsize = vector::length(&userRewards);

        assert!(index == rsize && index > 0, ERR_BAD_REFERAL_INFO);

        while (index > 0){
            index = index - 1;
            let userAddr = *vector::borrow(&users, index);
            let userReward = *vector::borrow(&userRewards, index);
            assert!(userReward > 0, ERR_BAD_REFERAL_INFO);

            if(table::contains(&referal.rewards, userAddr)){
                let oldReward = table::remove(&mut referal.rewards, userAddr);
                table::add(&mut referal.rewards, userAddr, userReward);
                referal.rewards_total = u256::add_u64(u256::sub_u64(referal.rewards_total, oldReward), userReward);
            }
            else {
                table::add(&mut referal.rewards, userAddr, userReward);
                referal.rewards_total = u256::add_u64(referal.rewards_total, userReward);
            }
        };


        emit(ReferalUpsertEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards),
            users,
            users_rewards: userRewards
        })
    }

    public entry fun remove_referal<COIN>(referal: &mut Referal<COIN>, users: vector<address>, _ctx: &mut TxContext){
        assert!(referal.state == STATE_INIT , ERR_REFERAL_STATE);
        let index = vector::length(&users);

        assert!(index > 0, ERR_BAD_REFERAL_INFO);

        while (index > 0){
            index = index - 1;
            let userAddr = *vector::borrow(&users, index);
            assert!(table::contains(&referal.rewards, userAddr), ERR_BAD_REFERAL_INFO);
            let oldReward = table::remove(&mut referal.rewards, userAddr);
            referal.rewards_total = referal.rewards_total - oldReward;
        };


        emit(ReferalRemovedEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards),
            users,
        })
    }

    public entry fun start_claim_referal<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, _ctx: &mut TxContext){
        assert!(referal.state == STATE_INIT, ERR_REFERAL_STATE);
        assert!(referal.rewards_total <= coin::value(&referal.fund), ERR_NOT_ENOUGH_FUND);
        referal.state = STATE_CLAIM;

        emit(ReferalClaimStartedEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards)
        })
    }


    public entry fun claim_referal<COIN>(referal: &mut Referal<COIN>, ctx: &mut TxContext){
        let user = sender(ctx);
        assert!(referal.state == STATE_CLAIM , ERR_REFERAL_STATE);
        assert!(table::contains(&referal.rewards, user), ERR_BAD_REFERAL_INFO);

        let reward = table::remove(&mut referal.rewards, user);
        public_transfer(coin::split(&mut referal.fund, reward, ctx), user);
        referal.rewards_total = referal.rewards_total - reward;

        emit(ReferalUserClaimEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user,
            user_claim: reward
        })
    }

    public entry fun done_referal<COIN>(referal: &mut Referal<COIN>, ctx: &mut TxContext){
        assert!(referal.state < STATE_DONE , ERR_REFERAL_STATE);
        referal.state = STATE_DONE;

        emit(ReferalDoneEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards)
        })
    }

    // public entry fun withdraw_fund<COIN>(referal: &mut Referal<COIN>, ctx: &mut TxContext){
    //     assert!(referal.state < STATE_DONE , ERR_REFERAL_STATE);
    //     referal.state = STATE_DONE;
    //
    //     emit(ReferalDoneEvent {
    //         referal: id_address(referal),
    //         state: referal.state,
    //         rewards_total: referal.rewards_total,
    //         fund_total: coin::value(&referal.fund),
    //         user_total: table::length(&referal.rewards)
    //     })
    // }
}
