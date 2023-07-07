#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0x9a4c4ab28f4fc599e5345a8b12ec1c1680df260eaa72865aad1e0e358b6090d8
export ADMIN_CAP_VESTING=0x90240c87d82dd334a3b8732c6a069f3886bbed48b966e5c5ff80832511058b65
export ADMIN_CAP_VERSION=0xb88cff4bb6f8820b4c18273479838676dd15aacad270a11d43946395df7da1e9
export PROJECT_REG=0x7a4e97db549b046e8bf6bdf2d391ed9f8050e7311890692a7622ca11423fa739
export VERSION=0xd67ea207387e3543244cb2f000ee817d74def97dd78ce9ff7cc15b767f941326
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "changeAdmin" --args  $ADMIN_CAP_VESTING $NEW_ADMIN $VERSION
