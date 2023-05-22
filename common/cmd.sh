#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##move  call
export ENV_ADDR=0x9d6f2e34e937842df89642cd96fba8509d4e47d297f716ce3a44df3070a79851
export PACKAGE=0x69890bfad2acd57a787b5265d5519ca6b711a06f9ba597213fd047fb4575c777
export ADMIN_CAP_TIER=0x3f390503f5c6d492d51dc270a416a0314cf820ccd944ab7f3934e9ed836eb291
export ADMIN_CAP_REFER=0xcc94f6f296252c3a015e3c37366edd931f96faae1c1683f32314d47b7fb83bfe
export ADMIN_CAP_KYC=0xff3de3bde9aa046d2e44dde67545b921de142c50497036bc61be83564e5dfb09
export UPGRADE_CAP=0xb83faf41ff51c68a2d8a098283a5200fc01adb29497a13aaeeca5b570d613a7e
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "tier" --function "change_admin" --args  $ADMIN_CAP_TIER $NEW_ADMIN
#sui client call --gas-budget 200000000 --package $PACKAGE --module "config" --function "change_admin" --args  $ADMIN_CAP $NEW_ADMIN
#sui client upgrade --gas-budget 200000000 --upgrade-capability $UPGRADE_CAP