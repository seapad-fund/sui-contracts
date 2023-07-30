#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x1c84563579d45c2974042a043ba834d008ba468ceac82a6563d19a43e4a0b4e7
export ADMIN_CAP=0xeda788ce0d657890b27a062791611a33e070be21b0170e75945b90493cff7289
export ADMIN_CAP_VAULT=0x265db4d156f06402185eb668e00648ecb4d7b7bebd3c1d1d9813491cd068a941
export VERSION=0xe239c8efb3051daa4f09637baa14643dd771799b9ffc3e27956bfba914c48562
export VERSION_ADMIN_CAP=0x7121f6d66e55998febaefb798612c0b762c8e7560f8c5a41305084390a01d18e
export NEW_ADMIN=0x7d0ad419e070245b777ec04461d02a6956afd2d19a3d8f96341dcf26f5053796

##
export PROJECT_BSC=0x
export PROJECT_SPORE=0x
export PROJECT_POOLZ=0x

###move  calls to change admin
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "revokeAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_BSC true
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_SPORE true
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_POOLZ true