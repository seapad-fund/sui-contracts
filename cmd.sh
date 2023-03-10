#!/bin/bash
#sui move build
#sui move test
sui client publish --force --with-unpublished-dependencies  --gas-budget 10000 

##move  call
export ENV_ADDR=0x385514285b7b7499455c8c395c4995baf7ab97ba
export PACKAGE=0x502855d90419e3b49b39bc40de930e9eca47e0e0
export ADMIN_CAP=0x138f3da14ced7cd8c8e5e34056889886ac3d5bd9
export TREASURY_CAP=0x86639d365649e6750abfac391b2f663d3a2b814e
export SUI_COIN=0xb7b0aa332da92c8d1b01e59a54ebe0667d2e506b

export POOL=0x90c244ebe334de750021c1bd61766f94ffa1f8ab
export TOKEN_LIQUID=0x32de0f6400d08e6480f93e68707019d7565d25b0
export SUI_LIQUID=0x9ab077632b1720e5a1ddeed433156a3cc0a6f753

export SUI_SWAP=0x95429d6b35783895a021ebb904e93f5152f9801f
export TOKEN_SWAP=0x78e8908de2736a97438173fc9a1f4b575e692654

##create pool with initial liquid
#sui client call --gas-budget 1000 --package $PACKAGE --module "infinity_dex" --function "createPool" --args  $ADMIN_CAP $TREASURY_CAP $SUI_COIN

#mint itself
#sui client call --gas-budget 1000 --package $PACKAGE --module "infinity_dex" --function "mintToken" --args  $ADMIN_CAP $TREASURY_CAP $ENV_ADDR 100000000

## add liquid
#sui client call --gas-budget 1000 --package $PACKAGE --module "infinity_dex" --function "addLiquid" --args  $POOL $TOKEN_LIQUID $SUI_LIQUID

##swap sui
#sui client call --gas-budget 1000 --package $PACKAGE --module "infinity_dex" --function "swapSui" --args  $POOL $SUI_SWAP

##swap token
#sui client call --gas-budget 1000 --package $PACKAGE --module "infinity_dex" --function "swapToken" --args  $POOL $TOKEN_SWAP
