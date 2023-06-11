module seapad::nft_campaign {

    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer::{share_object, public_transfer};
    use seapad::nftbox::NftAdminCap;
    use sui::table::Table;
    use sui::table;
    use std::vector;
    use sui::event::emit;
    use sui::tx_context;
    use sui::address;
    use seapad::nft_private;
    use std::option;
    use std::option::Option;
    use seapad::nft_private::PriNFT;

    struct NFT_CAMPAIGN has drop {}

    const STATE_INIT: u8 = 1;
    const STATE_RUN: u8 = 2;
    const STATE_END: u8 = 3;

    const ErrBadState: u64 = 6100;
    const ErrPermDenied: u64 = 6101;
    const ErrBadParams: u64 = 6102;

    struct Campaign has key, store {
        id: UID,
        state: u8,
        version: u64,
        urls: vector<vector<u8>>,
        whitelist: Table<address, u64>,
        template: Option<Template>
    }

    struct CampaignAddWhitelist has copy, drop {
        id: address,
        users: vector<address>
    }

    struct CampaignMintNft has copy, drop {
        sender: address,
        nft: address
    }

    struct CampaignBurnNft has copy, drop {
        sender: address,
        nft: address
    }

    struct CampaignResetWhitelist has copy, drop {
        id: address,
    }

    struct Template has store {
        name: vector<u8>,
        link: vector<u8>,
        description: vector<u8>,
        project_url: vector<u8>,
        edition: u64,
        thumbnail_url: vector<u8>,
        creator: vector<u8>,
        attributes_names: vector<vector<u8>>,
        attributes_values: vector<vector<u8>>,
    }

    struct CampaignSetUrls has copy, drop {
        id: address,
        urls: vector<vector<u8>>
    }

    fun init(_witness: NFT_CAMPAIGN, ctx: &mut TxContext) {
        let campaign = Campaign {
            id: object::new(ctx),
            state: STATE_INIT,
            version: 0,
            whitelist: table::new(ctx),
            urls: vector::empty(),
            template: option::none()
        };
        share_object(campaign);
    }

    public entry fun setTemplate(name: vector<u8>,
                                 link: vector<u8>,
                                 description: vector<u8>,
                                 project_url: vector<u8>,
                                 edition: u64,
                                 thumbnail_url: vector<u8>,
                                 creator: vector<u8>,
                                 attributes_names: vector<vector<u8>>,
                                 attributes_values: vector<vector<u8>>,
                                 campaign: &mut Campaign) {
        assert!(campaign.state != STATE_RUN, ErrBadState);
        assert!(vector::length(&name) > 0
            && vector::length(&link) > 0
            && vector::length(&description) > 0
            && vector::length(&thumbnail_url) > 0
            && (vector::length(&attributes_names) == vector::length(&attributes_values)), ErrBadParams);

        if (option::is_some(&campaign.template)) {
            let template = option::borrow_mut(&mut campaign.template);
            template.name = name;
            template.link = link;
            template.description = description;
            template.project_url = project_url;
            template.edition = edition;
            template.thumbnail_url = thumbnail_url;
            template.creator = creator;
            template.attributes_names = attributes_names;
            template.attributes_values = attributes_values
        }
        else {
            option::fill(&mut campaign.template, Template {
                name,
                link,
                description,
                project_url,
                edition,
                thumbnail_url,
                creator,
                attributes_names,
                attributes_values,
            })
        }
    }

    public entry fun start(_adminCap: &NftAdminCap, campaign: &mut Campaign, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_RUN && option::is_some(&campaign.template), ErrBadState);
        campaign.state = STATE_RUN;
    }

    public entry fun end(_adminCap: &NftAdminCap, campaign: &mut Campaign, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_END, ErrBadState);
        campaign.state = STATE_END;
    }

    ///Add white list
    public entry fun addWhiteList(
        _adminCap: &NftAdminCap,
        users: vector<address>,
        campaign: &mut Campaign,
        _ctx: &mut TxContext
    ) {
        assert!(campaign.state != STATE_END, ErrBadState);
        let aEvent = CampaignAddWhitelist {
            id: id_address(campaign),
            users
        };

        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            if (!table::contains(&campaign.whitelist, user)) {
                table::add(&mut campaign.whitelist, user, campaign.version);
            }else if (*table::borrow(&campaign.whitelist, user) < campaign.version) {
                table::remove(&mut campaign.whitelist, user);
                table::add(&mut campaign.whitelist, user, campaign.version);
            }
        };

        emit(aEvent);
    }

    ///Clear white list
    ///Soft delete with versioning
    public entry fun resetWhiteList(_adminCap: &NftAdminCap, campaign: &mut Campaign, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_RUN, ErrBadState);
        campaign.version = campaign.version + 1;
        emit(CampaignResetWhitelist {
            id: id_address(campaign)
        });
    }

    ///Clear & set urls
    public entry fun setNftUrls(
        _adminCap: &NftAdminCap,
        urls: vector<vector<u8>>,
        campaign: &mut Campaign,
        _ctx: &mut TxContext
    ) {
        assert!(campaign.state != STATE_RUN, ErrBadState);
        campaign.urls = urls;
        emit(CampaignSetUrls {
            id: id_address(campaign),
            urls
        });
    }

    ///User in whitelist claim NFT
    public entry fun claimNft(campaign: &mut Campaign, ctx: &mut TxContext) {
        assert!(campaign.state == STATE_RUN, ErrBadState);
        let senderAddr = sender(ctx);
        assert!(
            table::contains(&campaign.whitelist, senderAddr) && *table::borrow(
                &campaign.whitelist,
                senderAddr
            ) >= campaign.version,
            ErrPermDenied
        );

        //simply randomize
        let weight = address::to_u256(senderAddr) + (tx_context::epoch_timestamp_ms(ctx) as u256);
        let size = (vector::length(&campaign.urls) as u256);
        let mod = weight - size * (weight / size);
        let url = *vector::borrow(&campaign.urls, (mod as u64));

        //fetch template
        let template = option::borrow_mut(&mut campaign.template);
        let names = &template.attributes_names;
        let values = &template.attributes_values;
        let attrs = table::new(ctx);

        //suff
        let len = vector::length(names);
        while (len > 0) {
            len = len - 1;
            table::add(&mut attrs, *vector::borrow(names, len), *vector::borrow(values, len));
        };

        //mint from template
        let nft = nft_private::mint(
            template.name,
            template.link,
            url,
            template.description,
            template.project_url,
            template.edition,
            template.thumbnail_url,
            template.creator,
            attrs,
            ctx);

        let mEvent = CampaignMintNft {
            sender: senderAddr,
            nft: id_address(&nft)
        };

        public_transfer(nft, senderAddr);

        //remove from whitelist
        table::remove(&mut campaign.whitelist, senderAddr);

        emit(mEvent);
    }

    ///User burn nft
    public entry fun burnNft(nft: PriNFT, ctx: &mut TxContext) {
        let bEvent = CampaignBurnNft {
            sender: sender(ctx),
            nft: id_address(&nft)
        };

        nft_private:: burn(nft);
        emit(bEvent);
    }
}
