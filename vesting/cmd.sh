#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
#export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xb1a0ef021f6e751aada55ed4b5ce85a32acd099dc0ec91b39c2485d15267d5ad
export ADMIN_CAP=0x5cbfa22bb106efe36cc1520084b5c594a586a199758a0ebcd02d28711373ae3c
export ADMIN_CAP_VAULT=0x528ce6ea64b8fb52d83c03791da9755c518d6b32d36aa78e2692d41509106f36
export VERSION=0x027f051a61bf2741c522f2096863220341ba2f9e8011e6a6189733964845195b
export VERSION_ADMIN_CAP=0xbd593593b8ca0a6fc24ff44a2293001b2de9df1e8dc9a74cc0c62baa9dd43a82
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

###move  calls to change admin
sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "revokeAdmin" --args $ADMIN_CAP_VAULT $VERSION