#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xa00d14642a0faa3236f80a990568447a57a51d057ca4dc79f623db5b7334f58d
export ADMIN_CAP=0x89f8ca05dd63df070c395432cd0cb0bbc3d61b26eb79868bbb445373ad2ef555
export TOTAL_SUPPLY=100000000000000000

## 2023-08-05 14:00:00 UTC/GMT
export TGE_MS=1691244000000
export CLOCK=0x06
export VERSION=0x4c8921b6b1cc5fcdb390ce07aa3bd804b7f4116177fb43d337510c875f78e297
export SPT_TYPE=0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT

#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "init_tokenomic"  --type-args $SPT_TYPE --args $ADMIN_CAP $TOTAL_SUPPLY $TGE_MS $CLOCK $VERSION

export PIE=0x23a3f3168b0b10dd5da2e73ccc689cf71d1a885d41c44b412a06ec2a0cb49cc0

###Add liquidity funds
export FUND_LIQUIDITY_VESTING_TYPE=3
export FUND_LIQUIDITY_CLIFF=0
export FUND_LIQUIDITY_UNLOCK_PERCENT=3000
export FUND_LIQUIDITY_VESTING_DUR_MS=7776000000
export FUND_LIQUIDITY_WALLET=0xff65b3014225aa68458bc71f289cb72b97c97113bae2101764242d82e28b1c0f
export FUND_LIQUIDITY_SPT_7M=0xf369fd1c3cdc9237f40a55b987070be89f1571b11623e70089f1c55ddd92431c
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_LIQUIDITY_WALLET "FUND LIQUIDITY" $FUND_LIQUIDITY_VESTING_TYPE $TGE_MS $FUND_LIQUIDITY_CLIFF $FUND_LIQUIDITY_SPT_7M $FUND_LIQUIDITY_UNLOCK_PERCENT $FUND_LIQUIDITY_VESTING_DUR_MS $CLOCK $VERSION [] []

##for test only
export FUND_LIQUIDITY_WALLET1=0x9dddaa2cd107862cdd55f128bdc465025a2be82b593a17cd7ff4a3124410146b
export FUND_LIQUIDITY_WALLET2=0x5ce6c7cfe474837026d24b1ddcd63d888ef756c10a67a4eb3c040cee195cbc91
export FUND_LIQUIDITY_SPT_1=0x92c8eb5e277dd4727223cec7c143602e965dabcdf8d79a3fba74e4de9c3883a8
export FUND_LIQUIDITY_SPT_2=0xdf05c3a4c15df1c162ce0747e067269cfd7901e12d5c1c4330637ca9ee6a8277

###Add foundation fund
##linear unlock first
export FUND_FOUNDATION_VESTING_TYPE=3
export FUND_FOUNDATION_UNLOCK_PERCENT=0
##12 months
export FUND_FOUNDATION_CLIFF=31104000000
##48 months
export FUND_FOUNDATION_VESTING_DUR_MS=124416000000
export FUND_FOUNDATION_WALLET=0x2e02f48413347c39e3cd3dd0430dc213f2ff1525af0ebae6e62c3191648d4221
##12m SPT
export FUND_FOUNDATION_SPT=0xe396b90958d29034a7c01d87eaa86675f0941b2006d002862ef209ee90b80ef5
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_FOUNDATION_WALLET "FUND FOUNDATION" $FUND_FOUNDATION_VESTING_TYPE $TGE_MS $FUND_FOUNDATION_CLIFF $FUND_FOUNDATION_SPT $FUND_FOUNDATION_UNLOCK_PERCENT $FUND_FOUNDATION_VESTING_DUR_MS $CLOCK $VERSION [] []


###Add seed fund
##linear unlock first
export FUND_SEED_VESTING_TYPE=3
##3.5%
export FUND_SEED_UNLOCK_PERCENT=350
##2 months
export FUND_SEED_CLIFF=518400000
##18 months
export FUND_SEED_VESTING_DUR_MS=46656000000
export FUND_SEED_WALLET=0xbdfb02eb09e37de28de11b70d58e440bd874642878d46cee778f046bb41ced37
##12m SPT
export FUND_SEED_SPT=0x717903c1e41c9ff5c3ab86f6c291030ae0442c1a649689428fab8e23f0d89b01
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_SEED_WALLET "FUND SEED" $FUND_SEED_VESTING_TYPE $TGE_MS $FUND_SEED_CLIFF $FUND_SEED_SPT $FUND_SEED_UNLOCK_PERCENT $FUND_SEED_VESTING_DUR_MS $CLOCK $VERSION [] []


###Add Advisor/partner fund
##linear unlock first
export FUND_ADVPARTNER_VESTING_TYPE=3
##3.5%
export FUND_ADVPARTNER_UNLOCK_PERCENT=0
##3 months
export FUND_ADVPARTNERD_CLIFF=7776000000
##36 months
export FUND_ADVPARTNER_VESTING_DUR_MS=93312000000

export FUND_ADVPARTNER_WALLET=0x38a7ccc61dcbbe36c9b02d8781322041d9e727ce55b1161010d0946468984679

##4m SPT
export FUND_ADVPARTNER_SPT=0x7080d12fd810610c60166e15fcd69f3aab3183b2f2472fee628ed854bbb6a0c4
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_ADVPARTNER_WALLET "FUND ADVISOR PARTNER" $FUND_ADVPARTNER_VESTING_TYPE $TGE_MS $FUND_ADVPARTNERD_CLIFF $FUND_ADVPARTNER_SPT $FUND_ADVPARTNER_UNLOCK_PERCENT $FUND_ADVPARTNER_VESTING_DUR_MS $CLOCK $VERSION [] []


###Add marketing fund
##linear unlock first
export FUND_MARKETING_VESTING_TYPE=3
##3.5%
export FUND_MARKETING_UNLOCK_PERCENT=500
##0 months
export FUND_MARKETING_CLIFF=0
##36 months
export FUND_MARKETING_VESTING_DUR_MS=93312000000

export FUND_MARKETING_WALLET=0x697f8ea1c05efebda0ee72d7db7fa794b8a920cd816f8e16a666432af7c4b820

##9m SPT
export FUND_MARKETING_SPT=0x6d649175244e1f8ab14b0df42acee682db575e6f863ffec281730230d2475148
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_MARKETING_WALLET "FUND MARKETING" $FUND_MARKETING_VESTING_TYPE $TGE_MS $FUND_MARKETING_CLIFF $FUND_MARKETING_SPT $FUND_MARKETING_UNLOCK_PERCENT $FUND_MARKETING_VESTING_DUR_MS $CLOCK $VERSION [] []

###Add Ecosystem fund
##linear unlock first
export FUND_ECOSYSTEM_VESTING_TYPE=3
##3.5%
export FUND_ECOSYSTEM_UNLOCK_PERCENT=0
##6 months
export FUND_ECOSYSTEM_CLIFF=15552000000
##36 months
export FUND_ECOSYSTEM_VESTING_DUR_MS=93312000000

export FUND_ECOSYSTEM_WALLET=0x89e0d7a3e0ce46a8bab075dfe81b84790c8f3b0860a88b8ba09d27e87b50073e

##10M SPT
export FUND_ECOSYSTEM_SPT=0x74a7993a2ae75e86ec5f5a1d00ba322bc04099570c85a62be1a890a86c70eb06
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_ECOSYSTEM_WALLET "FUND ECOSYSTEM" $FUND_ECOSYSTEM_VESTING_TYPE $TGE_MS $FUND_ECOSYSTEM_CLIFF $FUND_ECOSYSTEM_SPT $FUND_ECOSYSTEM_UNLOCK_PERCENT $FUND_ECOSYSTEM_VESTING_DUR_MS $CLOCK $VERSION [] []


###Add Farm/stake fund
##linear unlock first
export FUND_FARM_VESTING_TYPE=3
##3.5%
export FUND_FARM_UNLOCK_PERCENT=0
##0 months
export FUND_FARM_CLIFF=0
##36 months
export FUND_FARM_VESTING_DUR_MS=93312000000

export FUND_FARM_WALLET=0x901455b327d26f4df19c82ab313db5fd32f4704d30b7674050fc265442868f23

##10M SPT
export FUND_FARM_SPT=0xd9e906de068e4be920fb1c96bd08bd7078cde73b09ca0e549cd03e5d7a1a4ce9
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_FARM_WALLET "FUND STAKING/FARM" $FUND_FARM_VESTING_TYPE $TGE_MS $FUND_FARM_CLIFF $FUND_FARM_SPT $FUND_FARM_UNLOCK_PERCENT $FUND_FARM_VESTING_DUR_MS $CLOCK $VERSION [] []

###Add DAO fund
##linear unlock first
export FUND_DAO_VESTING_TYPE=3
##0%
export FUND_DAO_UNLOCK_PERCENT=0
##12 months
export FUND_DAO_CLIFF=31104000000
##36 months
export FUND_DAO_VESTING_DUR_MS=93312000000

export FUND_DAO_WALLET=0xaae5239262cf56f30b933fe6deb3f5b006a3e909d21e40e106835cdba34276eb

##10M SPT
export FUND_DAO_SPT=0x29c9d045ac5be1e39dc01d05a584aaceb778790a4cd841baee29619e332b079c
#sui client call --gas-budget 200000000 --package $PACKAGE --module "tokenomic_entries" --function "addFund"  --type-args $SPT_TYPE --args $ADMIN_CAP $PIE $FUND_DAO_WALLET "FUND DAO" $FUND_DAO_VESTING_TYPE $TGE_MS $FUND_DAO_CLIFF $FUND_DAO_SPT $FUND_DAO_UNLOCK_PERCENT $FUND_DAO_VESTING_DUR_MS $CLOCK $VERSION [] []