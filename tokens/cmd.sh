#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca
export TREASURY_CAP=0x69e484dee6ca45f1f9056df7bf1e3ec7664ca2133c520343d148eb52b7859747
export COIN_METADATA=0x5075594c01d46f3bcbc4a7ef1462058273bece7793eebd0464963597c9fd0935
export SUI=0x02
export AARON_FUND1=0x697f8ea1c05efebda0ee72d7db7fa794b8a920cd816f8e16a666432af7c4b820
export SPT_TYPE=0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT
#export SPT_BURN=
export TM_WALLET_PRIVATE=0x4335958e123b9504e023e58c4630a817d5a17f1334e51cba5c99f3d130799c4c
export TM_AMT_PRIVATE=11000000000000000
export TM_WALLET_PUBLIC_IDO=0x96854f77810cb9730090f6aa4cd40f5828012c02497afdf27996a3671e8826b6
export TM_AMT_PUBLIC_IDO=14000000000000000
#export ENV_AMOUNT=7000000000000000
#export ENV_AMOUNT=1000000000
#export ENV_AMOUNT=12000000000000000
#export ENV_AMOUNT=4000000000000000
#export ENV_AMOUNT=9000000000000000
export ENV_AMOUNT=10000000000000000

##move  callS
#sui client call --gas-budget 20000000 --package $SUI --module "coin" --function "mint_and_transfer" --type-args $SPT_TYPE --args  $TREASURY_CAP $TM_AMT_PRIVATE $TM_WALLET_PRIVATE
#sui client call --gas-budget 20000000 --package $SUI --module "coin" --function "mint_and_transfer" --type-args $SPT_TYPE --args  $TREASURY_CAP $TM_AMT_PUBLIC_IDO $TM_WALLET_PUBLIC_IDO
#sui client call --gas-budget 20000000 --package $SUI --module "coin" --function "mint_and_transfer" --type-args $SPT_TYPE --args  $TREASURY_CAP  $ENV_AMOUNT $ENV_ADDR
#sui client call --gas-budget 20000000 --package $SUI --module "coin" --function "mint_and_transfer" --type-args $SPT_TYPE --args  $TREASURY_CAP  $ENV_AMOUNT $ENV_ADDR