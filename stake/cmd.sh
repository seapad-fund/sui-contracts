#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x71132189cb802b0265ad21634fe841f7f36d2cf4aa6f3d2d839706af39e572c6
export UPGRADE_CAP=0xfddc9b1cbbef93b34675a6d36855b228644596b43313a281eae47051fee9a0b6
export CONFIG=0x278fca0d6d027797d8960c10eb9d3b7faae8a86c767a9ae55f89c6a50062bc9f
export NEW_ADMIN=0x7d0ad419e070245b777ec04461d02a6956afd2d19a3d8f96341dcf26f5053796
export TREASURY_ADMIN=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export EMERGENCY_ADMIN=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f

#
#sui client call --gas-budget 20000000 --package $PACKAGE --module "stake_entries" --function "set_treasury_admin_address" --args $CONFIG $NEW_ADMIN
#sui client call --gas-budget 20000000 --package $PACKAGE --module "stake_entries" --function "set_emergency_admin_address" --args $CONFIG $NEW_ADMIN