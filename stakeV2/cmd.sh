#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0x5572c4d7cdf8249db61ea2d5af4017b033f8f94dc6bbe3267cbc0f63bd182a2c
export UPGRADE_CAP=0xf86546046ae7e96672a99167e6755c1e75aec13f78ac2b40b06adc1438553703
export ADMIN_CAP_STAKE=0xcb3ad6aa783d3793c45455a0f1ec6142fa516430a5936dc9cc57622de5d0ecb1
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN
