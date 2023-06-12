#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000

##move  call
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x247a45d81bb85cd40e3a56c63c55ae74da7326ee44555e5a25ca9bcbcdefa474
export NFT_ADMIN_CAP=0x64bb8c2a3fdd98ad3c74a0e88a10f444697a9ca6485b217b4417f358857b0e38
export NFT_TREASURY_CAP=0x72ac01b382543a6ec92b12c73a45ad5d68505ce64d9373f9ba9cea3fb7b9ee80
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 500000000 --package $PACKAGE --module "nftbox_entries" --function "change_admin" --args  $NFT_ADMIN_CAP $NEW_ADMIN
