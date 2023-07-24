#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0x31aa890693e286e35339a796ad4082ffc04f9ee7acf9804be15afd5d5ed9cb30
export ADMIN_CAP_VESTING=0x09b4a6ff0a6792b06e574b3de1eb8a7c33d38defe2aefe2de67fffede80ab502
export ADMIN_CAP_VERSION=0xe40dd0a230cd0af85b662cd93dacf449170384936d9cb53146522710550aa169
export PROJECT_REG=0xf351e55d93ffd59b0dcddc0e4a830498b1bc5c6236a9c9b74b047c385090aa71
export VERSION=0x14cefbfd46683127644211546ba7a374a891eda59db5034cd0bd6f40ee31ba07
export ADMIN_CAP_VAULT=0x4058f11a8f17aa6fb4dfcc5631b931e496d91a4e2d4701bac66e52ed07d34fe0
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP_VESTING $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION

