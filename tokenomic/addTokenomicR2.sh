#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
##package v1
#export PACKAGE=0xa00d14642a0faa3236f80a990568447a57a51d057ca4dc79f623db5b7334f58d
##package v2
export PACKAGE=0x2f0b6610e03738a9dcf03e9db273e61c4e40f30b1c604406545777a3cbe4feb6;
export ADMIN_CAP=0x89f8ca05dd63df070c395432cd0cb0bbc3d61b26eb79868bbb445373ad2ef555
export TOTAL_SUPPLY=100000000000000000

## 2023-08-05 14:00:00 UTC/GMT
export TGE_MS=1691244000000
export CLOCK=0x06
export VERSION=0x4c8921b6b1cc5fcdb390ce07aa3bd804b7f4116177fb43d337510c875f78e297
export SPT_TYPE=0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT

#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "init_tokenomic"  --type-args $SPT_TYPE --args $ADMIN_CAP $TOTAL_SUPPLY $TGE_MS $CLOCK $VERSION

export PIE=0x23a3f3168b0b10dd5da2e73ccc689cf71d1a885d41c44b412a06ec2a0cb49cc0

###Add foundation fund
##linear unlock first
export FUND_FOUNDATION_VESTING_TYPE=3
export FUND_FOUNDATION_UNLOCK_PERCENT=0
##12 months
export FUND_FOUNDATION_CLIFF=31104000000
##48 months
export FUND_FOUNDATION_VESTING_DUR_MS=124416000000

##----------------wallets---------------
###CMO wallet with 3M SPT
export FUND_FOUNDATION_WALLET=0x65ee5c2f989cf419ad9be62e5c64e47373f45b8a593006f54e2183d8dc89ada9
export FUND_FOUNDATION_SPT=0x5dea6849a8c5bc5a1d78c4723105449451cf6b720266e7c7fa7493e093d62850
sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_FOUNDATION_WALLET "FUND FOUNDATION" $FUND_FOUNDATION_VESTING_TYPE $TGE_MS $FUND_FOUNDATION_CLIFF $FUND_FOUNDATION_SPT $FUND_FOUNDATION_UNLOCK_PERCENT $FUND_FOUNDATION_VESTING_DUR_MS $CLOCK $VERSION [] []


##claim  at explorer:
### https://suiexplorer.com/object/0x2f0b6610e03738a9dcf03e9db273e61c4e40f30b1c604406545777a3cbe4feb6?module=tokenomic_entries
### params:
### - Type0: 0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT
### - Arg0: 0x23a3f3168b0b10dd5da2e73ccc689cf71d1a885d41c44b412a06ec2a0cb49cc0
### - Arg1: 0x06
### - Arg2: 0x4c8921b6b1cc5fcdb390ce07aa3bd804b7f4116177fb43d337510c875f78e297