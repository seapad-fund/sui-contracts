#[test_only]
module seapad::nft_private_test {
    use seapad::nft_private::{Self, PriNFT};
    use sui::test_scenario as ts;
    use sui::transfer;
    use std::string;
    use sui::table;
    use sui::test_scenario;

    #[test]
    fun mint_transfer_update() {
        let addr1 = @0xA;
        let addr2 = @0xB;
        // create the NFT
        let scenario = ts::begin(addr1);
        {
            let nft = nft_private::mint_for_test(
                b"name",
                b"link",
                b"image_url",
                b"description",
                b"project_url",
                1,
                b"thumbnail_url",
                b"creator",
                table::new<vector<u8>,  vector<u8>>(test_scenario::ctx(&mut scenario))
                , ts::ctx(&mut scenario));
            transfer::public_transfer(nft,  addr1);
        };
        // send it from A to B
        ts::next_tx(&mut scenario, addr1);
        {
            let nft = ts::take_from_sender<PriNFT>(&mut scenario);
            transfer::public_transfer(nft, addr2);
        };
        // update its description
        ts::next_tx(&mut scenario, addr2);
        {
            let nft = ts::take_from_sender<PriNFT>(&mut scenario);
            nft_private::update_description_for_test(&mut nft, b"a new description") ;
            assert!(*string::bytes(nft_private::description(&nft)) == b"a new description", 0);
            ts::return_to_sender(&mut scenario, nft);
        };
        // burn it
        ts::next_tx(&mut scenario, addr2);
        {
            let nft = ts::take_from_sender<PriNFT>(&mut scenario);
            nft_private::burn_for_test(nft)
        };
        ts::end(scenario);
    }
}