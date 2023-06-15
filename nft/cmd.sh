#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
export ENV_ADDR=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554
export PACKAGE=0xdb5fb5ba83218d5be78733633e27fbf1903af7437af524ff97c4b47f3c51ef95
export NFT_ADMIN_CAP=0xfbd69ac6a0473d01cffa48d6a4b822c6ee5fc8d853e1e48dec33cc28a0457a41
export NFT_TREASURY_CAP=0x6761eb84a7b59ad6074756d6f8e32db3fe65680cc1633d0d25c2f9a2f01d47b6
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

###
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_admin" --args  $NFT_ADMIN_CAP $NEW_ADMIN
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN