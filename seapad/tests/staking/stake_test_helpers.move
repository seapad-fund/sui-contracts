#[test_only]
module staking::stake_test_helpers {
//    use std::signer;
//    use std::string::{String, utf8};
//
//    use aptos_framework::account;
//    use aptos_framework::coin::{Self, Coin, MintCapability, BurnCapability};
//
//    // Coins.
//
    struct RewardCoin has drop{}

    struct StakeCoin has drop{}
//
//    struct Capabilities<phantom CoinType> has key {
//        mint_cap: MintCapability<CoinType>,
//        burn_cap: BurnCapability<CoinType>,
//    }
//
//    public fun initialize_coin<CoinType>(
//        admin: &signer,
//        name: String,
//        symbol: String,
//        decimals: u8,
//    ) {
//        let (b, f, m) = coin::initialize<CoinType>(
//            admin,
//            name,
//            symbol,
//            decimals,
//            true
//        );
//
//        coin::destroy_freeze_cap(f);
//
//        move_to(admin, Capabilities<CoinType> {
//            mint_cap: m,
//            burn_cap: b,
//        });
//    }
//
//    public fun initialize_reward_coin(account: &signer, decimals: u8) {
//        initialize_coin<RewardCoin>(
//            account,
//            utf8(b"Reward Coin"),
//            utf8(b"RC"),
//            decimals
//        );
//    }
//
//    public fun initialize_stake_coin(account: &signer, decimals: u8) {
//        initialize_coin<StakeCoin>(
//            account,
//            utf8(b"Stake Coin"),
//            utf8(b"SC"),
//            decimals
//        );
//    }
//
//    public fun initialize_default_stake_reward_coins(coin_admin: &signer) {
//        initialize_stake_coin(coin_admin, 6);
//        initialize_reward_coin(coin_admin, 6);
//    }
//
//    public fun mint_coin<CoinType>(admin: &signer, amount: u64): Coin<CoinType> acquires Capabilities {
//        let admin_addr = signer::address_of(admin);
//        let caps = borrow_global<Capabilities<CoinType>>(admin_addr);
//        coin::mint(amount, &caps.mint_cap)
//    }
//
//    public fun mint_default_coin<CoinType>(amount: u64): Coin<CoinType> acquires Capabilities {
//        let caps = borrow_global<Capabilities<CoinType>>(@harvest);
//        coin::mint(amount, &caps.mint_cap)
//    }
//
//    // Accounts.
//
//    public fun new_account(account_addr: address): signer {
//        if (!account::exists_at(account_addr)) {
//            account::create_account_for_test(account_addr)
//        } else {
//            let cap = account::create_test_signer_cap(account_addr);
//            account::create_signer_with_capability(&cap)
//        }
//    }
//
//    public fun new_account_with_stake_coins(account_addr: address, amount: u64): signer acquires Capabilities {
//        let account = account::create_account_for_test(account_addr);
//        let stake_coins = mint_default_coin<StakeCoin>(amount);
//        coin::register<StakeCoin>(&account);
//        coin::deposit(account_addr, stake_coins);
//        account
//    }
//
//    // Math.
//
//    public fun to_u128(num: u64): u128 {
//        (num as u128)
//    }
}
