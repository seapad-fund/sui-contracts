#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0xd56a0073be6e574750d72824f4d04f09cce6a6143eebce77452a9859fe67a739
export UPGRADE_CAP=0x53781ac64ac8618e3cc5402563718d616342b829826fc13023f946f95d323a73
export ADMIN_CAP_STAKE=0x227b59d3ea9ed16b940f8e276943c87cbff7f791aa710760d58f970f496085f0
export VERSION=0x7270be9efdc19f010cc982efecfaae311b00dca9b130ea22007c8edbbf2a3455
export ADMIN_CAP_VERSION=0x9a24e54db68b0e440e24e1771985a81c4e59e3cb651de44dae109b381479565e
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN $VERSION
sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_VERSION $NEW_ADMIN $VERSION

