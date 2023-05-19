#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 700000000

#move  call
export ENV_ADDR=0x9d6f2e34e937842df89642cd96fba8509d4e47d297f716ce3a44df3070a79851
export PACKAGE=0x650b87a6d59e8d9953e7b06201077cca26227c10fc6eacc01af15a9fd24a21a0
export UPGRADE_CAP=0x2b5e750b1e90eee5b7a04f8aea5c11438e687756cf27cd6468a28e2296e07b1f

export SPT_TREASURY_CAP=0x618bb91edbd5b77c25ff5b180fe6a7d972bd4c2ccf048400f3667b8a769a9710
export VADMIN_CAP=0x2c1417dcb14a09a2cc5eea3510dccdc719e4d76a8dc267e218861bf2cc1bb75b
export TADMIN_CAP=0xed2aa41ef30e473013c8a7a070ec842a7b23e96f57a549812a0e4ba1f0dcb54b
export USDT_TREASURY_CAP=0x6602887fc302428fa5f12fe508c1600a80ec06e21ad8b2d11fd75c9003c240b1
export PROJECT_ADMIN_CAP=0xecf7a5d1dce2a5b2967dbfec6ea75592d56fff13a15e4702c494e1ca137f680f
export VERSION_REG=0x30b7bf9ca8d5dad6eab722a9e13611c040203b11766b827dbb97549e603ea9d1

export NEW_ADMIN_ADDR=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

export PACKAGE2=0x0605e98e31fe9e289f1447fbf16b6bfd0405cd1d4dbf31e2cf5827550c530be5
export PACKAGE3=0xdc3fa209b2315298f0c43f5517cfb69d180647700c5d34e3b1793cc338fdd966
export PACKAGE4=0xa538d1af7af5cbc22831931b744b865a964939a43105950c7d9f9b5233f89e50
export PACKAGE5=0x62a98d9a10730b2e94e4af551fe555464841eaa4584eeddc110f0a2b5532c80d
export MINTO=0x9d6f2e34e937842df89642cd96fba8509d4e47d297f716ce3a44df3070a79851
export NEW_ADMIN=0xcac5265f3537de36118f7257968fc7b60445e040124c17201af3824606ca5f21


#sui client call --gas-budget 100000000 --package $PACKAGE --module "project_entries" --function "change_admin" --args  $PROJECT_ADMIN_CAP $NEW_ADMIN_ADDR $VERSION_REG
##upgrade package
#sui client upgrade --gas-budget 900000000 --upgrade-capability $UPGRADE_CAP

##mint spt
#sui client call --gas-budget 700000000 --package $PACKAGE --module "spt" --function "minto" --args  $SPT_TREASURY_CAP $MINTO 10000000

##upgrade part 2
#sui client upgrade --gas-budget 700000000 --upgrade-capability $UPGRADE_CAP

#sui client call --gas-budget 700000000 --package $PACKAGE3 --module "spt" --function "minto" --args  $SPT_TREASURY_CAP $MINTO 10000000

#sui client call --gas-budget 700000000 --package $PACKAGE2 --module "spt" --function "minto" --args  $SPT_TREASURY_CAP $MINTO 10000000
#sui client call --gas-budget 700000000 --package $PACKAGE --module "spt" --function "minto" --args  $SPT_TREASURY_CAP $MINTO 10000000

sui client upgrade --gas-budget 400000000 --upgrade-capability $UPGRADE_CAP

##change admind but failed because version!
#sui client call --gas-budget 400000000 --package $PACKAGE5 --module "project_entries" --function "change_admin" --args  $PROJECT_ADMIN_CAP $NEW_ADMIN  $VERSION_REG


