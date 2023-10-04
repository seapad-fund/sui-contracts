#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0xef363d2d73a0c13eaf9aab96beda1d9cf76b46ab68fa7e179cac49214a20c31e
export UPGRADE_CAP=0xeeb7c0b44fd47d2680ca7012041230bc1e748081172f8b3ecfe6d663f0625cc2
export ADMIN_CAP_STAKE=0x3936f27a14f76ae5e9fa40145eb789b4e8d02985a7911cca7fdaaf533ad6227e
export VERSION=0xb15e80f700bfe01033111bf1928c682a2c63279481ff161d5b149f7b530190e7
export ADMIN_CAP_VERSION=0x01984fefef5a2180ba5ee363d14a362bf9333fd25275ec8ccd72ee58064eb85d
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN $VERSION