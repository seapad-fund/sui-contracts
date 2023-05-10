#!/bin/bash
#sui move build
#sui move test
sui client publish --gas-budget 1000000000

##move  call
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x3f665ba1f799c0fa73236c95ea4de1558b5ba692cefb04d960d10610c86b677f
export SPT_TREASURY_CAP=0x203856546ce32071a89a2e789857ea721a54a84e3a404ccc3f3c2d7acf91ef31
export USDT_TEST_TREASURY_CAP=0x58dde186db0423b5ff7e752e5e6a829b58b1f1dd61b5a63724ff587fc3b297f5
export UPGRADE_CAP=0xad2d7fd0b895f7159b7abc36502dbfef4c8a3d8f61d9736a5f688ce9cc6c025f

#sui client call --gas-budget 1000 --package $PACKAGE --module "infinity_dex" --function "swapToken" --args  $POOL $TOKEN_SWAP
