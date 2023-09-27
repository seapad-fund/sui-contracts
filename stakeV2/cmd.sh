#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0xa58fd5d7a88350cf1f39fbb3dc41f1b5329a7556e7cde865f00c47e0915a5de3
export UPGRADE_CAP=0x36423df6e9d69f518037b2c56abde31f555d2cca4b719b7edf6df9d0041ee5f1
export ADMIN_CAP_STAKE=0xd986c3c66f2a7b1859cdc62ddc61ade0b57c241b716eb42d13d73c038d2ddf23
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
