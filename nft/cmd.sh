#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
#export ENV_ADDR=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554
export PACKAGE=0xb3abbc6216a0b3060f1427b86adf6da0091989b2f4581504bcc9e622d651b776
export NFT_ADMIN_CAP=0x693d557b4c4f792a38e0694039c72cc0ec0728abf154821db8aaeeee47e49d98
export NFT_TREASURY_CAP=0x13cbec8e78c799c3792313eb2067da183d0089b38920f5e1e772d0e2faadd9b7
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_admin" --args  $NFT_ADMIN_CAP $NEW_ADMIN
sui client call --gas-budget 200000000 --package $PACKAGE --module "nftbox_entries" --function "change_treasury_admin" --args  $NFT_TREASURY_CAP $NEW_ADMIN