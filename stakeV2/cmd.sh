#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0x21bf85f9f4854c9cd03b4773f1e608f8f056351dfed72531f343a88ff744c57f
export UPGRADE_CAP=0x64d3b8037beabfb53dc2d4f50db1df392ce1c989cb8413149d7ddd27bd182f00
export ADMIN_CAP_STAKE=0x60a926d520b588a5586ebe2be52888b973ebd84b6028e48f9bac68b7ba6709eb
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
