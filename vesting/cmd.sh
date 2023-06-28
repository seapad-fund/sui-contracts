#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0xa1c7cf758dd728ba69766a0910925ab2512dc5789bd26fb3e0105a1590ae60f4
export V_ADMIN_CAP=0xc6a0e170e302139d2e0d3378863f0d0263a8e8b2512496e8a0065de5f39479ac
export VERSION=0x063bed28bb24d6308dafae1ba374cf4fe1a6f8dcbf69fd7c123968fa956e2a3d
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "change_admin" --args  $V_ADMIN_CAP $NEW_ADMIN $VERSION
