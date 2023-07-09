#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0x95194a886ce8f058033857f4374b522a75578d38971addda7d9bbb96eecbca7b
export ADMIN_CAP_VESTING=0xe37af4263b6de0f79d772e23c9b229399b7d4a3a0c543bd114e1ee6fc9e0787f
export ADMIN_CAP_VERSION=0x46540f469578c57a2b01fdf97d50a219b39c466843e1bb6949f2c4d44baed3c5
export PROJECT_REG=0x89f0ffd5bd748b53834564c5c277d0548d305137f83ea40c4921db515ed5773c
export VERSION=0x137ab36aae2248b01faa95b98aea128cfb88602c7414b1a2fe3c1d72e2609f0c
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "changeAdmin" --args  $ADMIN_CAP_VESTING $NEW_ADMIN $VERSION
