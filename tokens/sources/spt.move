module seapad::spt {
    use std::ascii::string;
    use std::option;

    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{TxContext, sender};
    use sui::url;
    use sui::transfer::{public_freeze_object};

    const SYMBOL: vector<u8> = b"SPT";
    const NAME: vector<u8> = b"SPT";
    const DESCRIPTION: vector<u8> = b"Seapad launchpad foundation token";
    const DECIMAL: u8 = 9;
    const ICON_URL: vector<u8> = b"https://seapad.s3.ap-southeast-1.amazonaws.com/uploads/TEST/public/media/images/logo_1679906850804.png";

    struct SPT has drop {}

    fun init(witness: SPT, ctx: &mut TxContext) {
        let (treasury_cap, spt_metadata) = coin::create_currency<SPT>(
            witness,
            DECIMAL,
            SYMBOL,
            NAME,
            DESCRIPTION,
            option::some(url::new_unsafe(string(ICON_URL))),
            ctx);

        transfer::public_freeze_object(spt_metadata);
        transfer::public_transfer(treasury_cap, sender(ctx));
    }

    ///CRTICIAL
    public entry fun burn_cap(treasury_cap: TreasuryCap<SPT>, _ctx: &mut TxContext){
        public_freeze_object(treasury_cap);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(SPT {}, ctx);
    }
}
