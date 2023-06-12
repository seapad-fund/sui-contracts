#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xb022609c3113e62fda04687ecec9b07c34cb5cf1ba62b5795254b802d14fe0b4
export NFT_ADMIN_CAP=0x9e742e5a3c3bd1a6eef8ab1cd6e416e87981ca8f91a4a312ee39c8ad55e81979
export NFT_TREASURY_CAP=0xe1d35be6a9142b266bdaf916556401a932f38daedd95f1456ccdf5f0251e0b77
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_admin" --args  $NFT_ADMIN_CAP $NEW_ADMIN
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN
