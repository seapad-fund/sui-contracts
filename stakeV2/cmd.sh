#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0xe3cfa4f457a2eab9a9f37edda4d062c5d54ead7f03b93c19cfd015e7cd865cc1
export UPGRADE_CAP=0xb318f273f204ab47880730eccbdcef94a592662c83ab4d7ff9be3e0063223685
export ADMIN_CAP_STAKE=0xf083f016ea859a5af370e90d72715fd6eef414800e9e858ffcde3a5481044ca2
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
