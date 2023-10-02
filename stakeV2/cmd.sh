#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0x92d12291765e48f4458e5a7bbde920c8173bc0539cd733fabf4a6959e0ba601b
export UPGRADE_CAP=0x6dd7e6f4ddcdd83abac74e6b26eb6f48ca695f657f58dea20401181b32029f39
export ADMIN_CAP_STAKE=0xed71f6501fd98a8300df5de4b2d4a064fe8332f5ff685d96a421bb9be6d6bfe4
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
