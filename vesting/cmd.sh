#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xea30bcadc535bd75b72e64806194a37e28affab12188741d86c97bad2df5887c
export ADMIN_CAP=0x138d6e303c5f9339a64e7602ed762887791a3d18ae1849e37788d9c5e016bd3a
export ADMIN_CAP_VAULT=0x131e91501cbb7cb6bc96d33c082254547263610feb67d6a586ad281f95b86b43
export VERSION=0x8210881f4da74229827e0515b359f9ee8a0c10aa5b8498c545c771614a81a754
export VERSION_ADMIN_CAP=0xc559003b9f8ad524d57f5185f7022707bbb7b8b7a257bd6249d28bf76d10efad
export PROJECT_REGISTRY=0x18aa2163286005f32e7a158b0ff5c839448c9d81f014a2104a137711060ef43d
export NEW_ADMIN=0x7d0ad419e070245b777ec04461d02a6956afd2d19a3d8f96341dcf26f5053796

##
export PROJECT_BSC=0x
export PROJECT_SPORE=0x
export PROJECT_POOLZ=0x

###move  calls to change admin
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION
#https://suiexplorer.com/object/0xea30bcadc535bd75b72e64806194a37e28affab12188741d86c97bad2df5887c?module=vesting
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "revokeAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_BSC true
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_SPORE true
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_POOLZ true