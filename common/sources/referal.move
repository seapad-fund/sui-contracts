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

    const ERR_BAD_STATE: u64 = 1001;
    const ERR_NOT_ENOUGH_FUND: u64 = 1002;
    const ERR_BAD_REFERAL_INFO: u64 = 1003;
    const ERR_BAD_FUND: u64 = 1004;

    const STATE_INIT: u8 = 0;
    const STATE_CLAIM: u8 = 1;
    const STATE_CLOSED: u8 = 2;

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

    struct ReferalClosedEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64
    }

    struct ReferalUserClaimedEvent has drop, copy {
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
        rewards: vector<u64>
    }

    struct ReferalRemovedEvent has drop, copy {
        referal: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64,
        users: vector<address>,
    }

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

    public entry fun change_admin(admin: AdminCap, to: address) {
        transfer(admin, to);
    }

    public entry fun create_project<COIN>(_admin: &AdminCap, ctx: &mut TxContext){
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

    public entry fun upsert_referal<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, users: vector<address>, rewards: vector<u64>, _ctx: &mut TxContext){
        assert!(referal.state == STATE_INIT , ERR_BAD_STATE);
        let index = vector::length(&users);
        let rsize = vector::length(&rewards);

        assert!(index == rsize && index > 0, ERR_BAD_REFERAL_INFO);

        while (index > 0){
            index = index - 1;
            let user = *vector::borrow(&users, index);
            let reward = *vector::borrow(&rewards, index);
            assert!(reward > 0, ERR_BAD_REFERAL_INFO);

            if(table::contains(&referal.rewards, user)){
                let oldReward = table::remove(&mut referal.rewards, user);
                table::add(&mut referal.rewards, user, reward);
                assert!(referal.rewards_total >= oldReward, ERR_BAD_REFERAL_INFO);
                referal.rewards_total = u256::add_u64(u256::sub_u64(referal.rewards_total, oldReward), reward);
            }
            else {
                table::add(&mut referal.rewards, user, reward);
                referal.rewards_total = u256::add_u64(referal.rewards_total, reward);
            }
        };

        emit(ReferalUpsertEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards),
            users,
            rewards
        })
    }

    public entry fun remove_referal<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, users: vector<address>, _ctx: &mut TxContext){
        assert!(referal.state == STATE_INIT , ERR_BAD_STATE);
        let index = vector::length(&users);

        assert!(index > 0, ERR_BAD_REFERAL_INFO);

        while (index > 0){
            index = index - 1;
            let user = *vector::borrow(&users, index);
            assert!(table::contains(&referal.rewards, user), ERR_BAD_REFERAL_INFO);
            let oldReward = table::remove(&mut referal.rewards, user);
            assert!(referal.rewards_total >= oldReward, ERR_BAD_REFERAL_INFO);
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

    public entry fun start_claim_project<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, _ctx: &mut TxContext){
        assert!(referal.state == STATE_INIT, ERR_BAD_STATE);
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

    public entry fun claim_reward<COIN>(referal: &mut Referal<COIN>, ctx: &mut TxContext){
        let user = sender(ctx);
        assert!(referal.state == STATE_CLAIM , ERR_BAD_STATE);
        assert!(table::contains(&referal.rewards, user), ERR_BAD_REFERAL_INFO);

        let reward = table::remove(&mut referal.rewards, user);
        public_transfer(coin::split(&mut referal.fund, reward, ctx), user);
        referal.rewards_total = referal.rewards_total - reward;

        emit(ReferalUserClaimedEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user,
            user_claim: reward
        })
    }

    public entry fun close_project<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, _ctx: &mut TxContext){
        assert!(referal.state < STATE_CLOSED, ERR_BAD_STATE);
        referal.state = STATE_CLOSED;

        emit(ReferalClosedEvent {
            referal: id_address(referal),
            state: referal.state,
            rewards_total: referal.rewards_total,
            fund_total: coin::value(&referal.fund),
            user_total: table::length(&referal.rewards)
        })
    }

    public entry fun withdraw_project_fund<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, to: address, ctx: &mut TxContext){
        assert!(referal.state == STATE_CLOSED, ERR_BAD_STATE);
        let total = coin::value(&referal.fund);
        public_transfer(coin::split(&mut referal.fund, total, ctx), to);
    }

    public entry fun deposit_project_fund<COIN>(_admin: &AdminCap, referal: &mut Referal<COIN>, fund: Coin<COIN>, _ctx: &mut TxContext){
        assert!(coin::value(&fund) > 0, ERR_BAD_FUND);
        coin::join(&mut referal.fund, fund);
    }
}
