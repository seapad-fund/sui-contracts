#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

##ENV_ADDR also the publisher
export ENV_ADDR=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554
export PACKAGE=0x824336292f328ce8ed02e51835bfa630c3082b935d5acf3bc2f42919deb015b0
export UPGRADE_CAP=0xfa7342fe935a134edd1f6835103b481d1a874f62087b74f15e33301de867c6c6
export CONFIG=0xc78e0bc2c9ebeca971493292497b195c7384c317c8bfbc50b364961b35020f94
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
export TREASURY_ADMIN=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554
export EMERGENCY_ADMIN=0xc37ce899eb568f490a521590787b167e65300d15819c85c4a12ee8480f2c3554

#
sui client call --gas-budget 20000000 --package $PACKAGE --module "stake_entries" --function "set_treasury_admin_address" --args $CONFIG $NEW_ADMIN
sui client call --gas-budget 20000000 --package $PACKAGE --module "stake_entries" --function "set_emergency_admin_address" --args $CONFIG $NEW_ADMIN