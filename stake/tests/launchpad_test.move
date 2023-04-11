#[test_only]
/// Tests for the pool module.
/// They are sequential and based on top of each other.
/// ```
/// * - test_init_pool
/// |   +-- test_creation
/// |       +-- test_swap_sui
/// |           +-- test_swap_tok
/// |               +-- test_withdraw_almost_all
/// |               +-- test_withdraw_all
/// ```
module seapad::dex_tests {
    use sui::sui::SUI;
    use sui::coin::{mint_for_testing as mint, burn_for_testing as burn};
    use sui::test_scenario::{Self as test, Scenario, next_tx, ctx}
    ;
    use seapad::dex::{Self, Pool, LSP};

    /// Gonna be our test token.
    struct BEEP {}

    /// A witness type for the pool creation;
    /// The pool provider's identifier.
    struct POOLEY has drop {}

    const SUI_AMT: u64 = 1000000000;
    const BEEP_AMT: u64 = 1000000;

    // Tests section
    #[test] fun test_init_pool() {
        let scenario = scenario();
        test_init_pool_(&mut scenario);
        test::end(scenario);
    }

    #[test] fun test_add_liquidity() {
        let scenario = scenario();
        test_add_liquidity_(&mut scenario);
        test::end(scenario);
    }

    #[test] fun test_swap_sui() {
        let scenario = scenario();
        test_swap_sui_(&mut scenario);
        test::end(scenario);
    }

    #[test] fun test_swap_tok() {
        let scenario = scenario();
        test_swap_tok_(&mut scenario);
        test::end(scenario);
    }

    #[test] fun test_withdraw_almost_all() {
        let scenario = scenario();
        test_withdraw_almost_all_(&mut scenario);
        test::end(scenario);
    }

    #[test] fun test_withdraw_all() {
        let scenario = scenario();
        test_withdraw_all_(&mut scenario);
        test::end(scenario);
    }

    // Non-sequential tests
    #[test] fun test_math() {
        let scenario = scenario();
        test_math_(&mut scenario);
        test::end(scenario);
    }

    /// Init a Pool with a 1_000_000 BEEP and 1_000_000_000 SUI;
    /// Set the ratio BEEP : SUI = 1 : 1000.
    /// Set LSP token amount to 1000;
    fun test_init_pool_(test: &mut Scenario) {
        let (owner, _) = people();

        next_tx(test, owner);
            {
                dex::init_for_testing(ctx(test));
            };

        next_tx(test, owner);
            {
                let lsp = dex::create_pool(
                    POOLEY {},
                    mint<BEEP>(BEEP_AMT, ctx(test)),
                    mint<SUI>(SUI_AMT, ctx(test)),
                    3,
                    ctx(test)
                );

                assert!(burn(lsp) == 31622000, 0);
            };

        next_tx(test, owner);
            {
                let pool = test::take_shared<Pool<POOLEY, BEEP>>(test);
                let pool_mut = &mut pool;
                let (amt_sui, amt_tok, lsp_supply) = dex::get_amounts(pool_mut);

                assert!(lsp_supply == 31622000, 0);
                assert!(amt_sui == SUI_AMT, 0);
                assert!(amt_tok == BEEP_AMT, 0);

                test::return_shared(pool)
            };
    }

    /// Expect LP tokens to double in supply when the same values passed
    fun test_add_liquidity_(test: &mut Scenario) {
        test_init_pool_(test);

        let (_, theguy) = people();

        next_tx(test, theguy);
            {
                let pool = test::take_shared<Pool<POOLEY, BEEP>>(test);
                let pool_mut = &mut pool;
                let (amt_sui, amt_tok, lsp_supply) = dex::get_amounts(pool_mut);

                let lsp_tokens = dex::add_liquidity(
                    pool_mut,
                    mint<SUI>(amt_sui, ctx(test)),
                    mint<BEEP>(amt_tok, ctx(test)),
                    ctx(test)
                );

                assert!(burn(lsp_tokens) == lsp_supply, 1);

                test::return_shared(pool)
            };
    }

    /// The other guy tries to exchange 5_000_000 sui for ~ 5000 BEEP,
    /// minus the commission that is paid to the pool.
    fun test_swap_sui_(test: &mut Scenario) {
        test_init_pool_(test);

        let (_, the_guy) = people();

        next_tx(test, the_guy);
            {
                let pool = test::take_shared<Pool<POOLEY, BEEP>>(test);
                let pool_mut = &mut pool;

                let token = dex::swap_sui(pool_mut, mint<SUI>(5000000, ctx(test)), ctx(test));

                // Check the value of the coin received by the guy.
                // Due to rounding problem the value is not precise
                // (works better on larger numbers).
                assert!(burn(token) > 4950, 1);

                test::return_shared(pool);
            };
    }

    /// The owner swaps back BEEP for SUI and expects an increase in price.
    /// The sent amount of BEEP is 1000, initial price was 1 BEEP : 1000 SUI;
    fun test_swap_tok_(test: &mut Scenario) {
        test_swap_sui_(test);

        let (owner, _) = people();

        next_tx(test, owner);
            {
                let pool = test::take_shared<Pool<POOLEY, BEEP>>(test);
                let pool_mut = &mut pool;

                let sui = dex::swap_token(pool_mut, mint<BEEP>(1000, ctx(test)), ctx(test));

                // Actual win is 1005971, which is ~ 0.6% profit
                assert!(burn(sui) > 1000000u64, 2);

                test::return_shared(pool);
            };
    }

    /// Withdraw (MAX_LIQUIDITY - 1) from the pool
    fun test_withdraw_almost_all_(test: &mut Scenario) {
        test_swap_tok_(test);

        let (owner, _) = people();

        // someone tries to pass (MINTED_LSP - 1) and hopes there will be just 1 BEEP
        next_tx(test, owner);
            {
                let lsp = mint<LSP<POOLEY, BEEP>>(31622000 - 1, ctx(test));
                let pool = test::take_shared<Pool<POOLEY, BEEP>>(test);
                let pool_mut = &mut pool;

                let (sui, tok) = dex::remove_liquidity(pool_mut, lsp, ctx(test));
                let (sui_reserve, tok_reserve, lsp_supply) = dex::get_amounts(pool_mut);

                assert!(lsp_supply == 1, 3);
                assert!(tok_reserve > 0, 3); // actually 1 BEEP is left
                assert!(sui_reserve > 0, 3);

                burn(sui);
                burn(tok);

                test::return_shared(pool);
            }
    }

    /// The owner tries to withdraw all liquidity from the pool.
    fun test_withdraw_all_(test: &mut Scenario) {
        test_swap_tok_(test);

        let (owner, _) = people();

        next_tx(test, owner);
            {
                let lsp = mint<LSP<POOLEY, BEEP>>(31622000, ctx(test));
                let pool = test::take_shared<Pool<POOLEY, BEEP>>(test);
                let pool_mut = &mut pool;

                let (sui, tok) = dex::remove_liquidity(pool_mut, lsp, ctx(test));
                let (sui_reserve, tok_reserve, lsp_supply) = dex::get_amounts(pool_mut);

                assert!(sui_reserve == 0, 3);
                assert!(tok_reserve == 0, 3);
                assert!(lsp_supply == 0, 3);

                // make sure that withdrawn assets
                assert!(burn(sui) > 1000000000, 3);
                assert!(burn(tok) < 1000000, 3);

                test::return_shared(pool);
            };
    }

    /// This just tests the math.
    fun test_math_(_: &mut Scenario) {
        let u64_max = 18446744073709551615;
        let max_val = u64_max / 10000;

        // Try small values
        assert!(dex::get_input_price(10, 1000, 1000, 0) == 9, 0);

        // Even with 0 commission there's this small loss of 1
        assert!(dex::get_input_price(10000, max_val, max_val, 0) == 9999, 0);
        assert!(dex::get_input_price(1000, max_val, max_val, 0) == 999, 0);
        assert!(dex::get_input_price(100, max_val, max_val, 0) == 99, 0);
    }

    // utilities
    fun scenario(): Scenario { test::begin(@0x1) }

    fun people(): (address, address) { (@0xBEEF, @0x1337) }
}