module seapad::nft_private {
    friend seapad::nftbox;

    use sui::url::{Self, Url};
    use std::string;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{TxContext};
    use std::vector;

    /// An example NFT that can be minted by anybody
    /// Allow custome attributes
    struct PriNFT has key, store {
        id: UID,
        /// Name for the token
        name: string::String,
        /// Description of the token
        description: string::String,
        /// URL for the token
        url: Url,
    }

    struct MintNFTEvent has copy, drop {
        // The Object ID of the NFT
        object_id: ID,
        // The creator of the NFT
        creator: address,
        // The name of the NFT
        name: string::String,
    }

    /// Create a new NFT
    public(friend) fun mint(
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ): PriNFT {
         PriNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
            url: url::new_unsafe_from_bytes(url)
        }
    }

    #[test_only]
    public fun mint_for_test(name: vector<u8>,
                    description: vector<u8>,
                    url: vector<u8>,
                    ctx: &mut TxContext): PriNFT{
        mint(name, description, url, ctx)
    }

    public(friend) fun mint_batch(
        count: u64,
        name: vector<u8>,
        description: vector<u8>,
        url: vector<u8>,
        ctx: &mut TxContext
    ): vector<PriNFT> {
        assert!(count > 0, 1);

        let nfts  = vector::empty<PriNFT>();
        while (count > 0){
            vector::push_back(&mut nfts, mint(name, description, url, ctx));
            count = count -1;
        };

        nfts
    }

    /// Update the `description` of `nft` to `new_description`
    public(friend) fun update_description(
        nft: &mut PriNFT,
        new_description: vector<u8>,
    ) {
        nft.description = string::utf8(new_description)
    }

    #[test_only]
    public fun update_description_for_test(
        nft: &mut PriNFT,
        new_description: vector<u8>,
    ) {
        nft.description = string::utf8(new_description)
    }

    /// Permanently delete `nft`
    public(friend) fun burn(nft: PriNFT) {
        let PriNFT { id, name: _, description: _, url: _ } = nft;
        object::delete(id)
    }

    #[test_only]
    public fun burn_for_test(nft: PriNFT) {
        let PriNFT { id, name: _, description: _, url: _ } = nft;
        object::delete(id)
    }

    /// Get the NFT's `name`
    public fun name(nft: &PriNFT): &string::String {
        &nft.name
    }

    /// Get the NFT's `description`
    public fun description(nft: &PriNFT): &string::String {
        &nft.description
    }

    /// Get the NFT's `url`
    public fun url(nft: &PriNFT): &Url {
        &nft.url
    }
}

#[test_only]
module seapad::private_nftTests {
    use seapad::nft_private::{Self, PriNFT};
    use sui::test_scenario as ts;
    use sui::transfer;
    use std::string;

    #[test]
    fun mint_transfer_update() {
        let addr1 = @0xA;
        let addr2 = @0xB;
        // create the NFT
        let scenario = ts::begin(addr1);
            {
                let nft = nft_private::mint_for_test(b"test", b"a test", b"https://www.sui.io", ts::ctx(&mut scenario));
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
