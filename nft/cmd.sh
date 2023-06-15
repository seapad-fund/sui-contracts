#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
#export ENV_ADDR=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554
export PACKAGE=0x25455b821b352c16202bec068b17cb80ed9a53f93093a468019d154e252f2f6c
export NFT_ADMIN_CAP=0x440d86dadbea71e93453cbfd86811aad50e3b84dedc20c40a66857caeb0e90dc
export NFT_TREASURY_CAP=0x1b34b72cd8cbfc63ddf01f60c70b90acace5fcdce7812a4d5ad0b4e6c99470cc
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

###
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_admin" --args  $NFT_ADMIN_CAP $NEW_ADMIN
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN