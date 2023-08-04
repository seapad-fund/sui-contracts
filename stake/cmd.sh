#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
export PACKAGE=0x86171a64a40410157588776303de9557ee8618f595782b87af5c62cf25d5d359
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export CONFIG=0x99e7d09908ef67a376573622c540ddb01f17b139f74d011276752bf8daa1f355
export NEW_ADMIN=0x7d0ad419e070245b777ec04461d02a6956afd2d19a3d8f96341dcf26f5053796


##
sui client call --gas-budget 20000000 --package $PACKAGE --module "stake_entries" --function "set_treasury_admin_address" --args $CONFIG $NEW_ADMIN
sui client call --gas-budget 20000000 --package $PACKAGE --module "stake_entries" --function "set_emergency_admin_address" --args $CONFIG $NEW_ADMIN