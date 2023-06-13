#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
#export ENV_ADDR=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554
export PACKAGE=0x8d20cc25c78dd860dbb2b664fce3a7d49cb102e679e834827967354b20dd78fd
export NFT_ADMIN_CAP=0xdc43eb0a17b0d74762ea2c60463f6c089c215106c926cdf70e75a0b6d487b626
export NFT_TREASURY_CAP=0x49fb4bcceacb4e3c7458f9438441e06995c4f1bf6b5ae1a5f8c1140c4cc8eade
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
##
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_admin" --args  $NFT_ADMIN_CAP $NEW_ADMIN
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN