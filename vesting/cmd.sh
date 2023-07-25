#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0x88682b28974ebfb3c6e1508982f0e8a2e8f4be48319e9d1eb3ba5c45a67ff800
export ADMIN_CAP_VESTING=0x8c85dc4dab44f22760f36ab6b300409dab54b07790298efb153e5df9a9776501
export ADMIN_CAP_VERSION=0x13f526d30ff26300291e51a78864e9d53d03662107b2931e991cc2d521e740c2
export PROJECT_REG=0x3e9b1011db034d7bfca0aa818b9658ed901f48148f532c0ec8061fb3e1ea05d3
export VERSION=0x07c5de50c4abe7c0b5e18595ba891f9ad4fc0a3b3abcfc60b5621853d80c8f52
export ADMIN_CAP_VAULT=0x78dd299f3266e59e34de6a41cf2700fde5595e23595e66aeba9de035728b1c6e
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP_VESTING $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION

