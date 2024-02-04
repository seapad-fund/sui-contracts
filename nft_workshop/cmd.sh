#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x88a5787010d0d0844a7254f0d45bc0f9530e91d61abc71094663388eaab30224
export WORKSHOP=0x57bc10610594eb5762d5802e9a538d5985fe6440a632c4e16f34eb577662f078
export NFT_ADMIN_CAP=0xa56d10b7abce9efe8ad341adf048e370a2198921e56ee81c871e3146209acd9b

#export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
#
####
#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "start" --args  $NFT_ADMIN_CAP $WORKSHOP
#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "end" --args  $NFT_ADMIN_CAP $WORKSHOP
sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "addWhiteList" --args  $NFT_ADMIN_CAP [$ENV_ADDR] $WORKSHOP
#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN