#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0xa4cd67b89082a95f9fb9bf95c2b20e26ebd0caf0d34527e81299bfe1f5794f5c
export V_ADMIN_CAP=0xbb879daa042e1bc32a55124a7116e59fa0d7dd61494213caf650f07ed8b07e3d
export VERSION=0x78096d0628465be837fd1565cf13b6bb854349b996c0f9865fb138c8bba7565a
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "change_admin" --args  $V_ADMIN_CAP $NEW_ADMIN $VERSION