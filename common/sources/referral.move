module common::referral {
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
    use sui::clock::{Clock, timestamp_ms};

    struct REFERRAL has drop {}

    struct AdminCap has key, store {
        id: UID
    }

    const ERR_BAD_STATE: u64 = 1001;
    const ERR_NOT_ENOUGH_FUND: u64 = 1002;
    const ERR_BAD_REFERRAL_INFO: u64 = 1003;
    const ERR_BAD_FUND: u64 = 1004;
    const ERR_DISTRIBUTE_TIME: u64 = 1005;
    const ERR_OUT_OF_FUND: u64 = 1006;

    const STATE_INIT: u8 = 0;
    const STATE_CLAIM: u8 = 1;
    const STATE_CLOSED: u8 = 2;

    struct ReferralCreatedEvent has drop, copy {
        referral: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64,
        distribute_time_ms: u64
    }

    struct ReferralClaimStartedEvent has drop, copy {
        referral: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64
    }

    struct ReferralClosedEvent has drop, copy {
        referral: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64
    }

    struct ReferralUserClaimedEvent has drop, copy {
        referral: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user: address,
        user_claim: u64
    }

    struct ReferralUpsertEvent has drop, copy {
        referral: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64,
        users: vector<address>,
        rewards: vector<u64>
    }

    struct ReferralRemovedEvent has drop, copy {
        referral: address,
        state: u8,
        rewards_total: u64,
        fund_total: u64,
        user_total: u64,
        users: vector<address>,
    }

    struct ReferralDepositEvent has drop, copy {
        referral: address,
        more_reward: u64,
        fund_total: u64,
    }

    struct Referral<phantom COIN> has key, store {
        id: UID,
        state: u8,
        fund: Coin<COIN>,
        rewards: Table<address, u64>,
        rewards_total: u64,
        distribute_time_ms: u64
    }


    fun init(_witness: REFERRAL, ctx: &mut TxContext) {
        let adminCap = AdminCap { id: object::new(ctx) };
        transfer::transfer(adminCap, sender(ctx));
    }

    public entry fun change_admin(admin: AdminCap, to: address) {
        transfer(admin, to);
    }


    public entry fun create_project<COIN>(_admin: &AdminCap, distribute_time_ms: u64, ctx: &mut TxContext) {
        let referral = Referral<COIN> {
            id: object::new(ctx),
            state: STATE_INIT,
            rewards_total: 0,
            fund: coin::zero<COIN>(ctx),
            rewards: table::new<address, u64>(ctx),
            distribute_time_ms
        };

        emit(ReferralCreatedEvent {
            referral: id_address(&referral),
            state: referral.state,
            rewards_total: referral.rewards_total,
            fund_total: coin::value(&referral.fund),
            user_total: table::length(&referral.rewards),
            distribute_time_ms
        });

        share_object(referral);
    }

    public entry fun update_distribute_time<COIN>(
        _admin: &AdminCap,
        distribute_time_ms: u64,
        referral: &mut Referral<COIN>
    ) {
        referral.distribute_time_ms = distribute_time_ms;
    }

    public entry fun upsert_Referral<COIN>(
        _admin: &AdminCap,
        referral: &mut Referral<COIN>,
        users: vector<address>,
        rewards: vector<u64>,
        _ctx: &mut TxContext
    ) {
        assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
        let index = vector::length(&users);
        let rsize = vector::length(&rewards);

        assert!(index == rsize && index > 0, ERR_BAD_REFERRAL_INFO);

        while (index > 0) {
            index = index - 1;
            let user = *vector::borrow(&users, index);
            let reward = *vector::borrow(&rewards, index);
            assert!(reward > 0, ERR_BAD_REFERRAL_INFO);

            if (table::contains(&referral.rewards, user)) {
                let oldReward = table::remove(&mut referral.rewards, user);
                table::add(&mut referral.rewards, user, reward);
                assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
                referral.rewards_total = u256::add_u64(u256::sub_u64(referral.rewards_total, oldReward), reward);
            }
            else {
                table::add(&mut referral.rewards, user, reward);
                referral.rewards_total = u256::add_u64(referral.rewards_total, reward);
            }
        };

        emit(ReferralUpsertEvent {
            referral: id_address(referral),
            state: referral.state,
            rewards_total: referral.rewards_total,
            fund_total: coin::value(&referral.fund),
            user_total: table::length(&referral.rewards),
            users,
            rewards
        })
    }

    public entry fun remove_Referral<COIN>(
        _admin: &AdminCap,
        referral: &mut Referral<COIN>,
        users: vector<address>,
        _ctx: &mut TxContext
    ) {
        assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
        let index = vector::length(&users);

        assert!(index > 0, ERR_BAD_REFERRAL_INFO);

        while (index > 0) {
            index = index - 1;
            let user = *vector::borrow(&users, index);
            assert!(table::contains(&referral.rewards, user), ERR_BAD_REFERRAL_INFO);
            let oldReward = table::remove(&mut referral.rewards, user);
            assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
            referral.rewards_total = referral.rewards_total - oldReward;
        };


        emit(ReferralRemovedEvent {
            referral: id_address(referral),
            state: referral.state,
            rewards_total: referral.rewards_total,
            fund_total: coin::value(&referral.fund),
            user_total: table::length(&referral.rewards),
            users,
        })
    }

    public entry fun start_claim_project<COIN>(_admin: &AdminCap, referral: &mut Referral<COIN>, _ctx: &mut TxContext) {
        assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
        assert!(referral.rewards_total <= coin::value(&referral.fund), ERR_NOT_ENOUGH_FUND);
        referral.state = STATE_CLAIM;

        emit(ReferralClaimStartedEvent {
            referral: id_address(referral),
            state: referral.state,
            rewards_total: referral.rewards_total,
            fund_total: coin::value(&referral.fund),
            user_total: table::length(&referral.rewards)
        })
    }

    public entry fun claim_reward<COIN>(referral: &mut Referral<COIN>, clock: &Clock, ctx: &mut TxContext) {
        let user = sender(ctx);
        assert!(referral.state == STATE_CLAIM, ERR_BAD_STATE);
        assert!(table::contains(&referral.rewards, user), ERR_BAD_REFERRAL_INFO);
        assert!(timestamp_ms(clock) >= referral.distribute_time_ms, ERR_DISTRIBUTE_TIME);

        let reward = table::remove(&mut referral.rewards, user);
        public_transfer(coin::split(&mut referral.fund, reward, ctx), user);
        referral.rewards_total = referral.rewards_total - reward;

        emit(ReferralUserClaimedEvent {
            referral: id_address(referral),
            state: referral.state,
            rewards_total: referral.rewards_total,
            fund_total: coin::value(&referral.fund),
            user,
            user_claim: reward
        })
    }

    public entry fun close_project<COIN>(_admin: &AdminCap, referral: &mut Referral<COIN>, _ctx: &mut TxContext) {
        assert!(referral.state < STATE_CLOSED, ERR_BAD_STATE);
        referral.state = STATE_CLOSED;

        emit(ReferralClosedEvent {
            referral: id_address(referral),
            state: referral.state,
            rewards_total: referral.rewards_total,
            fund_total: coin::value(&referral.fund),
            user_total: table::length(&referral.rewards)
        })
    }

    public entry fun withdraw_project_fund<COIN>(
        _admin: &AdminCap,
        referral: &mut Referral<COIN>,
        value: u64,
        to: address,
        ctx: &mut TxContext
    ) {
        assert!(referral.state == STATE_CLOSED, ERR_BAD_STATE);
        assert!(coin::value(&referral.fund) >= value, ERR_OUT_OF_FUND);
        public_transfer(coin::split(&mut referral.fund, value, ctx), to);
        referral.rewards_total = referral.rewards_total - value;
    }

    public entry fun deposit_project_fund<COIN>(referral: &mut Referral<COIN>, fund: Coin<COIN>) {
        let more_fund = coin::value(&fund);
        assert!(more_fund > 0, ERR_BAD_FUND);
        coin::join(&mut referral.fund, fund);
        referral.rewards_total = referral.rewards_total + more_fund;

        emit(ReferralDepositEvent {
            referral: id_address(referral),
            more_reward: more_fund,
            fund_total: coin::value(&referral.fund)
        })
    }
}
