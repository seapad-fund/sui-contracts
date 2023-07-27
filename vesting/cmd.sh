#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
#export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x88682b28974ebfb3c6e1508982f0e8a2e8f4be48319e9d1eb3ba5c45a67ff800
export ADMIN_CAP=0x8c85dc4dab44f22760f36ab6b300409dab54b07790298efb153e5df9a9776501
export ADMIN_CAP_VAULT=0x78dd299f3266e59e34de6a41cf2700fde5595e23595e66aeba9de035728b1c6e
export VERSION=0x07c5de50c4abe7c0b5e18595ba891f9ad4fc0a3b3abcfc60b5621853d80c8f52
export VERSION_ADMIN_CAP=0x13f526d30ff26300291e51a78864e9d53d03662107b2931e991cc2d521e740c2
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

###move  calls to change admin
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "transferAdmin" --args  $ADMIN_CAP $NEW_ADMIN $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "acceptAdmin" --args $ADMIN_CAP_VAULT $VERSION
#sui client call --gas-budget 20000000 --package $PACKAGE --module "vesting" --function "revokeAdmin" --args $ADMIN_CAP_VAULT $VERSION