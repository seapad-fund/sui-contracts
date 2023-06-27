#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0xc1f4e7ed528f065c019049fefb6d963e0edbb9e84460662b3fcb6310d79a2b9c
export V_ADMIN_CAP=0x69365cdcbb116061dc45ad0e0de100a1e6687dd06543778b6695e404b0660bbd
export VERSION=0xa563c686206adbd0f2f88b47ee0b9b83548b9243b11d57b3a47e8a35a3f172c3
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "change_admin" --args  $V_ADMIN_CAP $NEW_ADMIN $VERSION
