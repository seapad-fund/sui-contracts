#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0x147eb786eab5386f657ea987e1849479929951494f3f8a8333810589be90a5cf
export UPGRADE_CAP=0xe3e454a1a07a4a30024cf5e962e99c4776e2b46b5f9b30499d81c5dadd8c45fd
export ADMIN_CAP_STAKE=0xaef71dc7a000d09cab8a0973201fa1db25de129dd1c91dca5df24692d8766b49
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN