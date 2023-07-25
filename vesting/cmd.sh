#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0x9cff04a86a2bed0ffe85823ae03c1aefba3c94efaf9b28b96fecc75d2ca11f9a
export ADMIN_CAP_VESTING=0xd5dd5b20acfff21dee462d8232b3c87dbfbabb25da10b24aa719a23f41bf7da9
export ADMIN_CAP_VERSION=0xfbf7632f985c739b50fbaa89cba0fae33f6ff2a4f2acf3ea03bf346774e95144
export PROJECT_REG=0x6201eee98a8f9f330a3c0908637209e3e177bcd1123ec491da294be4a29cb0ce
export VERSION=0xe1ac1e9058e1f1dd95045dab3381ff77c9bd56d7be49572a234a6c5cc9deb7d4
export ADMIN_CAP_VAULT=0xd85e68507f4e302efb6e8719c7d23835e6a19c761372208481b329e516c1c75b
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP_VESTING $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION

