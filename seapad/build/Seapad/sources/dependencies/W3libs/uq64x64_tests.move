#[test_only]
module w3libs::uq64x64_tests {
    use w3libs::uq64x64;

    const MAX_U64: u64 = 18446744073709551615;

    #[test]
    fun test_is_zero() {
        let zero = uq64x64::encode(0);
        assert!(uq64x64::is_zero(&zero), 0);

        let non_zero = uq64x64::encode(1);
        assert!(!uq64x64::is_zero(&non_zero), 1);
    }

    #[test]
    fun test_compare() {
        assert!(uq64x64::compare(&uq64x64::encode(100), &uq64x64::encode(100)) == 0, 0);
        assert!(uq64x64::compare(&uq64x64::encode(200), &uq64x64::encode(100)) == 2, 1);
        assert!(uq64x64::compare(&uq64x64::encode(100), &uq64x64::encode(200)) == 1, 1);
    }

    #[test]
    fun test_encode() {
        let a = uq64x64::encode(100);
        let b = uq64x64::decode(a);
        assert!(b == 100, 0);

        a = uq64x64::encode(MAX_U64);
        b = uq64x64::decode(a);
        assert!(b == MAX_U64, 1);

        a = uq64x64::encode(0);
        b = uq64x64::decode(a);
        assert!(b == 0, 2);
    }

    #[test]
    fun test_mul() {
        let a = uq64x64::encode(500000);
        let z = uq64x64::mul(a, 2);
        assert!(uq64x64::to_u128(z) == 18446744073709551615000000, 0);
        assert!(uq64x64::decode(z) == 1000000, 1);
    }

    #[test]
    fun test_fraction() {
        let a = uq64x64::fraction(256, 8);
        assert!(uq64x64::to_u128(a) == 590295810358705651680, 0);
    }

    #[test]
    #[expected_failure(abort_code = w3libs::uq64x64::ERR_DIVIDE_BY_ZERO)]
    fun test_fail_fraction() {
        let a = uq64x64::fraction(256, 0);
        uq64x64::to_u128(a);
    }

    #[test]
    fun test_div() {
        let a = uq64x64::encode(256);
        let z = uq64x64::div(a, 8);
        assert!(uq64x64::to_u128(z) == 590295810358705651680, 0);
        assert!(uq64x64::decode(z) == 32, 1);
    }


    #[test]
    #[expected_failure(abort_code = w3libs::uq64x64::ERR_DIVIDE_BY_ZERO)]
    fun test_fail_div() {
        let a = uq64x64::encode(1);
        uq64x64::div(a, 0);
    }
}