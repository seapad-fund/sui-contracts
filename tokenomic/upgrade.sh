#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xa00d14642a0faa3236f80a990568447a57a51d057ca4dc79f623db5b7334f58d
export UPGRADE_CAP=0x772c8390d65654f39ab8dcdd6c8324baf4c1b5e911ff47283e3ead1a7916cbac
export ADMIN_CAP=0x89f8ca05dd63df070c395432cd0cb0bbc3d61b26eb79868bbb445373ad2ef555
export TOTAL_SUPPLY=100000000000000000

## 2023-08-05 14:00:00 UTC/GMT
export TGE_MS=1691244000000
export CLOCK=0x06
export VERSION=0x4c8921b6b1cc5fcdb390ce07aa3bd804b7f4116177fb43d337510c875f78e297
export SPT_TYPE=0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT

#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "init_tokenomic"  --type-args $SPT_TYPE --args $ADMIN_CAP $TOTAL_SUPPLY $TGE_MS $CLOCK $VERSION
export PIE=0x23a3f3168b0b10dd5da2e73ccc689cf71d1a885d41c44b412a06ec2a0cb49cc0

#upgrade package
sui client upgrade --gas-budget 200000000 --upgrade-capability $UPGRADE_CAP