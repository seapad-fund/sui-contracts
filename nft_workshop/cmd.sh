#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x47dd5043c4f2ecb0a79882a7a20a9bc3eef5265e553befc67e87fb34c2a7d81b
export WORKSHOP=0x3598e0ca75f6f80fa11f5ad1a7f54a3be1aeb88f06c841109aac591970ed82b7
export NFT_ADMIN_CAP=0xc6525933cb80b256ffcd437fde5bf340f7ca242d0d5620a07599d5c8bffc39d2
export BATCH_RECEIVER=0xc088e371ab0e039f4048cc3320458a460edbdebc411097e6548af3fd65642c4e

#export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
#
####
#echo "start nft_workshop..."
#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "start" --args  $NFT_ADMIN_CAP $WORKSHOP
echo "mint batch to $BATCH_RECEIVER ..."
sui client call --gas-budget 4000000000 --package $PACKAGE --module "nft_workshop" --function "mintBatch" --args  $NFT_ADMIN_CAP $WORKSHOP $BATCH_RECEIVER 96

#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "end" --args  $NFT_ADMIN_CAP $WORKSHOP
#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "addWhiteList" --args  $NFT_ADMIN_CAP [$ENV_ADDR] $WORKSHOP
#sui client call --gas-budget 200000000 --package $PACKAGE --module "nft_workshop" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN