#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0xcb8b2f2c953f45d9b5eb1f3d84a70983bd3940cdb1cd2b67ec5d0beabc5066c7
export UPGRADE_CAP=0xfa80e95cf78292c6b112a12dacd313d9334a6850ae4f7a723f0cdcd4b85355a8
export ADMIN_CAP_STAKE=0xf5e778d22e2febd2c8f934b06b5123d6c05aa6901ea774ee58fde22241e7417f
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
