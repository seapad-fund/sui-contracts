#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0x9c5b0ad01821f479aa8582d82d50b23a0d580f83ec0541722da8e3f626f946f6
export UPGRADE_CAP=0x2a1047b0293319e9440c27b85235c510a00554ae71c33b72245c5d9edbab1a77
export ADMIN_CAP_STAKE=0xadceea5b1bfb8b76bae57d7dd7688b25f7c34990948588de96ec557a6151bb7f
export VERSION=0x48d346428ef16eb789a540c7c1dda645806b43530a40b6570fce745a2235e231
export ADMIN_CAP_VERSION=0x4c9cdcd393c9ec437cbeb3b85f5574ab18efa3b06f554d061cf0e754462e4a37
export NEW_ADMIN=0x7d0ad419e070245b777ec04461d02a6956afd2d19a3d8f96341dcf26f5053796

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN $VERSION