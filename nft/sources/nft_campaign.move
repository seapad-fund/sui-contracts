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
    use std::string::utf8;
    use sui::package;
    use sui::display;

    struct NFT_CAMPAIGN has drop {}

    const STATE_INIT: u8 = 1;
    const STATE_RUN: u8 = 2;
    const STATE_END: u8 = 3;

    const ErrBadState: u64 = 6100;
    const ErrPermDenied: u64 = 6101;
    const ErrBadParams: u64 = 6102;
    const ErrSoldOut: u64 = 6102;

    struct Campaign has key, store {
        id: UID,
        state: u8,
        version: u64,
        urls: vector<vector<u8>>,
        whitelist: Table<address, ClaimInfor>,
        template: Option<Template>,
        total_supply: u64,
        total_mint: u64,
    }
    ///update ClaimInfor
    struct ClaimInfor has store, drop , copy{
        version: u64,
        claimed: bool
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
            template: option::none(),
            total_supply: 0,
            total_mint: 0
        };
        share_object(campaign);

        let keys = vector[
            utf8(b"name"),
            utf8(b"link"),
            utf8(b"image_url"),
            utf8(b"description"),
            utf8(b"project_url"),
            utf8(b"creator"),
        ];

        let values = vector[
            utf8(b"{name}"),
            utf8(b"{link}"),
            utf8(b"{image_url}"),
            utf8(b"{description}"),
            utf8(b"{project_url}"),
            utf8(b"{creator}")
        ];

        let publisher = package::claim(_witness, ctx);

        let display = display::new_with_fields<PriNFT>(&publisher, keys, values, ctx);

        display::update_version(&mut display);
        public_transfer(publisher, sender(ctx));
        public_transfer(display, sender(ctx));

        //mint genesis nft
        let nft = nft_private::mint(
            b"Genesis NFT campaign",
            b"https://seapad.fund/nftcampaign",
            b"https://seapad.s3.ap-southeast-1.amazonaws.com/uploads/PROD/public/media/images/logo_1686475080033.png",
            b"Genesis NFT campaign",
            b"https://seapad.fund/",
            1,
            b"https://seapad.s3.ap-southeast-1.amazonaws.com/uploads/PROD/public/media/images/logo_1686475080033.png",
            b"SeaPadFoundation",
            table::new(ctx),
            ctx);

        public_transfer(nft, sender(ctx));
    }

    public entry fun setTemplate(_adminCap: &NftAdminCap,
                                 name: vector<u8>,
                                 link: vector<u8>,
                                 description: vector<u8>,
                                 project_url: vector<u8>,
                                 edition: u64,
                                 thumbnail_url: vector<u8>,
                                 creator: vector<u8>,
                                 attributes_names: vector<vector<u8>>,
                                 attributes_values: vector<vector<u8>>,
                                 total_supply: u64,
                                 campaign: &mut Campaign) {
        assert!(campaign.state != STATE_RUN, ErrBadState);
        assert!(vector::length(&name) > 0
            && vector::length(&link) > 0
            && vector::length(&description) > 0
            && vector::length(&thumbnail_url) > 0
            && (vector::length(&attributes_names) == vector::length(&attributes_values))
            && total_supply > 0, ErrBadParams);

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
        };

        campaign.total_supply = total_supply;
        campaign.total_mint = 0;
    }

    public entry fun start(_adminCap: &NftAdminCap, campaign: &mut Campaign, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_RUN
            && option::is_some(&campaign.template)
            && campaign.total_supply > 0, ErrBadState);
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
                let myClaimInfor = ClaimInfor {
                    version: campaign.version,
                    claimed: false
                };
                table::add(&mut campaign.whitelist, user, myClaimInfor);
            }else if (table::borrow(&campaign.whitelist, user).version < campaign.version) {
                table::remove(&mut campaign.whitelist, user);
                table::add(&mut campaign.whitelist, user,ClaimInfor {
                    version: campaign.version,
                    claimed: false
                });
            }
        };

        emit(aEvent);
    }

    ///Clear white list
    ///Soft delete with versioning
    public entry fun resetWhiteList(_adminCap: &NftAdminCap, campaign: &mut Campaign, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_RUN, ErrBadState);
        campaign.version = campaign.version + 1;
        campaign.total_supply = 0;
        campaign.total_mint = 0;
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
        assert!(campaign.total_mint < campaign.total_supply, ErrSoldOut);
        let senderAddr = sender(ctx);
        assert!(table::contains(&campaign.whitelist, senderAddr)
            && table::borrow(&campaign.whitelist, senderAddr).version >= campaign.version,ErrPermDenied
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

        //update value ClaimInfor
        table::borrow_mut(&mut campaign.whitelist, senderAddr).claimed = true;

        //update campaign
        campaign.total_mint = campaign.total_mint + 1;

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
