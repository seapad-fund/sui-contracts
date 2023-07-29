#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xdbc4af0ceb16d1fa7e444129e7a948292e3027bbc0a2e45dc28cb2fbb11a4dde
export ADMIN_CAP=0x4763f2c873a6d7ee1464b51a9355d79266d0eef3b4fecf563a60d1757f79296a
export ADMIN_CAP_VAULT=0x80ca9c141bf4af5071846d7ca53a524a5dfe5baeb22ca56fe25c0a8c5e21435e
export VERSION=0x9b613c37921b1e23ef541a9a19bceb4a384884605156a8923a008e4c5684161c
export VERSION_ADMIN_CAP=0x06ed8748155530d31568cc61187b4f2270a1545933289e3ead7ae51ab6d8317e
export NEW_ADMIN=0x7d0ad419e070245b777ec04461d02a6956afd2d19a3d8f96341dcf26f5053796

##
export PROJECT_BSC=0x
export PROJECT_SPORE=0x
export PROJECT_POOLZ=0x

###move  calls to change admin
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "revokeAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_BSC true
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_SPORE true
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "pauseProject" --args $ADMIN_CAP $PROJECT_POOLZ true