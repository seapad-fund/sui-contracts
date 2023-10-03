#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0x1bffe1d15b8e91f9e691b74d3e4fbfa8df938e2b638ab6096d83634ee866d6eb
export UPGRADE_CAP=0x287fc163585176f794780fdfb953db0aef3066fe599b80927dd36c048a4c285f
export ADMIN_CAP_STAKE=0x2f045eab52af4a51a19e26e7ff01cc8064f99f93285ecb5027b5856ae084ad7a
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
