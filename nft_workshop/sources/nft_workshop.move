module seapad::nft_workshop {

    use sui::object::{UID, id_address};
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::transfer::{share_object, public_transfer};
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

    struct NFT_WORKSHOP has drop {}

    struct NftAdminCap has key, store {
        id: UID
    }

    const STATE_INIT: u8 = 1;
    const STATE_RUN: u8 = 2;
    const STATE_END: u8 = 3;

    const DEFAULT_SUPPLY: u64 = 100000;

    //@fixme change url
    const DEFAULT_THUMNAIL: vector<u8> = b"https://amethyst-careful-angelfish-202.mypinata.cloud/ipfs/QmerJGWjJfYCvXTnzCQn492KKzNUQgxCumCPW9R64pdJhx";
    const DEFAULT_URL: vector<u8> = b"https://amethyst-careful-angelfish-202.mypinata.cloud/ipfs/QmerJGWjJfYCvXTnzCQn492KKzNUQgxCumCPW9R64pdJhx";

    const ErrBadState: u64 = 6100;
    const ErrPermDenied: u64 = 6101;
    const ErrBadParams: u64 = 6102;
    const ErrSoldOut: u64 = 6103;
    const ErrInvalidAdmin: u64 = 6104;

    ///Workshop
    struct Workshop has key, store {
        id: UID,
        state: u8,
        version: u64,
        urls: vector<vector<u8>>,
        whitelist: Table<address, ClaimInfor>,
        template: Option<Template>,
        total_supply: u64,
        total_mint: u64,
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

    ///update ClaimInfor
    struct ClaimInfor has store, drop , copy{
        version: u64,
        claimed: bool
    }

    ///events
    struct AddWhitelistEvent has copy, drop {
        id: address,
        users: vector<address>
    }

    struct MintNftEvent has copy, drop {
        sender: address,
        nft: address
    }

    struct BurnNftEvent has copy, drop {
        sender: address,
        nft: address
    }

    struct ResetWhitelistEvent has copy, drop {
        id: address,
    }


    struct SetUrlsEvent has copy, drop {
        id: address,
        urls: vector<vector<u8>>
    }

    ///Init workshop:
    /// - admin role
    /// - blank workshop(init/no urls/no template/zero supply
    /// - initialize viewer
    fun init(_witness: NFT_WORKSHOP, ctx: &mut TxContext) {

        let workshop = Workshop {
            id: object::new(ctx),
            state: STATE_INIT,
            version: 0,
            whitelist: table::new(ctx),
            urls: vector::empty(),
            template: option::none(),
            total_supply: 0,
            total_mint: 0
        };

        ///setup nft view
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

        ///mint genesis nft for test
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

        ///init admin role
        let adminCap = NftAdminCap { id: object::new(ctx) };

        ///default template
        setTemplate(&adminCap,
            b"Seapad New Year Collection",
            b"https://seapad.fund/nftcampaign",
            b"Seapad New Year Collection",
            b"https://seapad.fund/",
            1,
            DEFAULT_THUMNAIL,
            b"SeaPad Foundation",
            vector::empty<vector<u8>>(),
            vector::empty<vector<u8>>(),
            DEFAULT_SUPPLY,
            &mut workshop
        );

        ///set nft urls
        let urls = vector::empty<vector<u8>>();
        vector::push_back(&mut urls, DEFAULT_URL);

        setNftUrls(
            &adminCap,
            urls,
            &mut workshop,
           ctx
        );

        ///share  or transfer
        share_object(workshop);
        public_transfer(adminCap, sender(ctx));
    }


    ///set template
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
                                 workshop: &mut Workshop) {
        assert!(workshop.state != STATE_RUN, ErrBadState);
        assert!(vector::length(&name) > 0
            && vector::length(&link) > 0
            && vector::length(&description) > 0
            && vector::length(&thumbnail_url) > 0
            && (vector::length(&attributes_names) == vector::length(&attributes_values))
            && total_supply > 0, ErrBadParams);

        if (option::is_some(&workshop.template)) {
            let template = option::borrow_mut(&mut workshop.template);
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
            option::fill(&mut workshop.template, Template {
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

        workshop.total_supply = total_supply;
        workshop.total_mint = 0;
    }

    ///start workshop
    public entry fun start(_adminCap: &NftAdminCap, campaign: &mut Workshop, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_RUN
            && option::is_some(&campaign.template)
            && campaign.total_supply > 0, ErrBadState);
        campaign.state = STATE_RUN;
    }

    ///end workshop
    public entry fun end(_adminCap: &NftAdminCap, campaign: &mut Workshop, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_END, ErrBadState);
        campaign.state = STATE_END;
    }

    ///Add white list
    public entry fun addWhiteList(
        _adminCap: &NftAdminCap,
        users: vector<address>,
        workshop: &mut Workshop,
        _ctx: &mut TxContext
    ) {
        assert!(workshop.state != STATE_END, ErrBadState);
        let addWlEvent = AddWhitelistEvent {
            id: id_address(workshop),
            users
        };

        while (!vector::is_empty(&users)) {
            let user = vector::pop_back(&mut users);
            if (!table::contains(&workshop.whitelist, user)) {
                let myClaimInfor = ClaimInfor {
                    version: workshop.version,
                    claimed: false
                };
                table::add(&mut workshop.whitelist, user, myClaimInfor);
            }else if (table::borrow(&workshop.whitelist, user).version < workshop.version) {
                table::remove(&mut workshop.whitelist, user);
                table::add(&mut workshop.whitelist, user, ClaimInfor {
                    version: workshop.version,
                    claimed: false
                });
            }
        };

        emit(addWlEvent);
    }

    ///Clear white list with versioning soft-delete
    public entry fun resetWhiteList(_adminCap: &NftAdminCap, campaign: &mut Workshop, _ctx: &mut TxContext) {
        assert!(campaign.state != STATE_RUN, ErrBadState);
        campaign.version = campaign.version + 1;
        campaign.total_supply = 0;
        campaign.total_mint = 0;
        emit(ResetWhitelistEvent {
            id: id_address(campaign)
        });
    }

    ///Clear & set urls, user will be randomized with these.
    public entry fun setNftUrls(
        _adminCap: &NftAdminCap,
        urls: vector<vector<u8>>,
        workshop: &mut Workshop,
        _ctx: &mut TxContext
    ) {
        assert!(workshop.state != STATE_RUN, ErrBadState);
        workshop.urls = urls;
        emit(SetUrlsEvent {
            id: id_address(workshop),
            urls
        });
    }

    ///User in whitelist claim NFT
    public entry fun claimNft(campaign: &mut Workshop, ctx: &mut TxContext) {
        //check campaign state
        assert!(campaign.state == STATE_RUN, ErrBadState);
        assert!(campaign.total_mint < campaign.total_supply, ErrSoldOut);
        let senderAddr = sender(ctx);

        //check user perm: in whitelist, not claimed
        assert!(table::contains(&campaign.whitelist, senderAddr)
            && table::borrow(&campaign.whitelist, senderAddr).version >= campaign.version
            && !table::borrow(&campaign.whitelist, senderAddr).claimed ,
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

        let mintEvent = MintNftEvent {
            sender: senderAddr,
            nft: id_address(&nft)
        };

        public_transfer(nft, senderAddr);

        //update value ClaimInfor
        table::borrow_mut(&mut campaign.whitelist, senderAddr).claimed = true;

        //update campaign
        campaign.total_mint = campaign.total_mint + 1;

        emit(mintEvent);
    }

    ///User burn nft
    public entry fun burnNft(nft: PriNFT, ctx: &mut TxContext) {
        let burnEvent = BurnNftEvent {
            sender: sender(ctx),
            nft: id_address(&nft)
        };
        nft_private:: burn(nft);
        emit(burnEvent);
    }
}
