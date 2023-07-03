#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 500000000 --skip-dependency-verification

##move  call
export PACKAGE=0xa18f569b2d7dab8b6a0ed5a867780e393ad249c835514bbf29e165aa182eb648
export V_ADMIN_CAP=0xdd3a857eafbb8881ff0cf25eb69d0f73d39e47de43780c894e6125e7e5573620
export VERSION=0x1acd2b158d6a75fbc8addfe8a9fa5256200a6cb486d3c9f795e29b44003b3678
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1
###
sui client call --gas-budget 200000000 --package $PACKAGE --module "vesting" --function "changeAdmin" --args  $V_ADMIN_CAP $NEW_ADMIN $VERSION