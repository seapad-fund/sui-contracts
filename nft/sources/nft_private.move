// Copyright (c) Web3 Labs, Inc.
// SPDX-License-Identifier: GPL-3.0

module seapad::nft_private {
    friend seapad::nftbox;
    friend seapad::nft_campaign;

    use sui::url::{Self, Url};
    use std::string;
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{TxContext};
    use std::vector;
    use sui::table::Table;
    use sui::vec_map::VecMap;
    use sui::table;
    use sui::vec_map;

    /// Allow custome attributes
    struct PriNFT has key, store {
        id: UID,
        name: string::String, //"{name}",
        link: Url, //"https://nft-heroes.io/hero/{id}",
        image_url: Url, //"ipfs://{img_url}",
        description: string::String, //"A true Hero of the Sui ecosystem!",
        project_url: Url, //"https://sui-heroes.io",
        edition: u64, //101
        thumbnail_url: Url, //"{thumbnail_image_url",
        creator: string::String, //"Unknown NFT Fan"
        attributes: Table<vector<u8>,  vector<u8>>
    }

    struct MintNFTEvent has copy, drop {
        object_id: ID,
        creator: address,
        name: string::String,
        project_url: Url,
    }

    public(friend) fun mint(
        name: vector<u8>,
        link: vector<u8>,
        image_url: vector<u8>,
        description: vector<u8>,
        project_url: vector<u8>,
        edition: u64,
        thumbnail_url: vector<u8>,
        creator: vector<u8>,
        attributes: Table<vector<u8>,  vector<u8>>,
        ctx: &mut TxContext
    ): PriNFT {
        PriNFT {
            id: object::new(ctx),
            name: string::utf8(name),
            link: url::new_unsafe_from_bytes(link),
            image_url: url::new_unsafe_from_bytes(image_url),
            description: string::utf8(description),
            project_url: url::new_unsafe_from_bytes(project_url),
            edition,
            thumbnail_url: url::new_unsafe_from_bytes(thumbnail_url),
            creator: string::utf8(creator),
            attributes
        }
    }


    #[test_only]
    public fun mint_for_test(
        name: vector<u8>,
        link: vector<u8>,
        image_url: vector<u8>,
        description: vector<u8>,
        project_url: vector<u8>,
        edition: u64,
        thumbnail_url: vector<u8>,
        creator: vector<u8>,
        attributes: Table<vector<u8>,  vector<u8>>,
        ctx: &mut TxContext): PriNFT{
        mint(name, link, image_url, description, project_url, edition, thumbnail_url, creator, attributes, ctx)
    }

    public(friend) fun mint_batch(
        count: u64,
        name: vector<u8>,
        link: vector<u8>,
        image_url: vector<u8>,
        description: vector<u8>,
        project_url: vector<u8>,
        edition: u64,
        thumbnail_url: vector<u8>,
        creator: vector<u8>,
        attributes: &VecMap<vector<u8>, vector<u8>>,
        ctx: &mut TxContext
    ): vector<PriNFT> {
        assert!(count > 0, 1);
        let nfts  = vector::empty<PriNFT>();

        while (count > 0){
            vector::push_back(
                &mut nfts,
                mint(name, link, image_url, description,
                    project_url, edition, thumbnail_url, creator,
                    vec2map<vector<u8>, vector<u8>>(attributes, ctx), ctx));
            count = count -1;
        };

        nfts
    }

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
       update_description(nft, new_description)
    }

    public(friend) fun burn(nft: PriNFT) {
        let PriNFT { id,
            name: _name,
            link: _link,
            image_url: _image_url,
            description:_description,
            project_url:_project_url,
            edition:_edition,
            thumbnail_url: _thumbnail_url,
            creator: _creator,
            attributes
        } = nft;
        table::drop(attributes);
        object::delete(id);
    }


    #[test_only]
    public fun burn_for_test(nft: PriNFT) {
       burn(nft);
    }

    public fun name(nft: &PriNFT): &string::String {
        &nft.name
    }

    public fun description(nft: &PriNFT): &string::String {
        &nft.description
    }

    public fun image_url(nft: &PriNFT): &Url {
        &nft.image_url
    }

    public fun project_url(nft: &PriNFT): &Url {
        &nft.project_url
    }

    public fun creator(nft: &PriNFT): &string::String {
        &nft.creator
    }


    fun vec2map<K: copy + drop + store, V: store + copy>(vdata: &VecMap<K, V>, ctx: &mut TxContext): Table<K, V>{
        let keys = vec_map::keys(vdata);
        let ksize = vector::length<K>(&keys);
        let tab = table::new<K,V>(ctx);
        while (ksize > 0){
            ksize = ksize -1;
            let key = vector::pop_back(&mut keys);
            table::add(&mut tab, key, *vec_map::get(vdata, &key))
        };
        tab
    }
}
