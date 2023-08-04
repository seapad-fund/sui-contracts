#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
#export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x507abb53382cca50151f8cc0e2b846555abe83fa6aa99ac275de0793991084aa
export ADMIN_CAP=0x43ea166621bcb2111799db0896ce4f9ea09b4e912b560919acfb7db37e627cea
export ADMIN_CAP_VAULT=0x0604dce5d348490cf5a0a613cea26b4f3a75862d6b454bd8287482bf290f1465
export VERSION=0xc1687a84d0d47cd908eb9f6478cf8d5be99c8ebde1f80cfa49f0b331dab5b465
export VERSION_ADMIN_CAP=0x03c62c8ee6d195b359820097f8a0fdfe435e9c434f4c22ef7f38ac2687cbad2a
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

###move  calls to change admin
sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "revokeAdmin" --args $ADMIN_CAP_VAULT $VERSION