#!/bin/bash
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

###ENV_ADDR also the publisher
export ENV_ADDR=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export PACKAGE=0x62460cd9a5a404e15612a3b6f15e259a42fa42cf6ecf8adcfbbeec74dc45cfc9
export ADMIN_CAP=0x6a9b6e39815986a0909d64975e00a09c6ba560b0247c6db03fd78fbb9dfc9fbe
export ADMIN_CAP_VAULT=0xe29876d72f97ad56d47c3c25aa3166eb826467c99a1a7344bdc2740d0b7de051
export VERSION=0x3a4e97d5bd6e4fa8a1ae54d67b2de9aca511647f4cb1c944afcb0b75cfb5f294
export VERSION_ADMIN_CAP=0x3268a9fe4b355b71db3121c8523eb810b00a12c090b19fe4088b9e29b89eab77
export PROJECT_REGISTRY=0xb7b7d40c111719de2ddc8a69ae248fc9db9560a478a2db9ef5fbe2a5a5a874bc
export SPT_TYPE=0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT
export PROJECT_NAME="SPT reward vault"
export CLOCK=0x06
export PROJECT_SPT=0xdcee393950507db6ceee81e9cff0e3955b7460137b79136ee3cc48729385dc05
### create project
#sui client call --gas-budget 20000000 --package $PACKAGE --module "reward" --function "createProject" --type-args $SPT_TYPE --args $ADMIN_CAP $PROJECT_NAME $CLOCK $VERSION $PROJECT_REGISTRY

### add reward: https://suiexplorer.com/object/0x62460cd9a5a404e15612a3b6f15e259a42fa42cf6ecf8adcfbbeec74dc45cfc9?module=reward
#0xb779486cfd6c19e9218cc7dc17c453014d2d9ba12d2ee4dbb0ec4e1e02ae1cca::spt::SPT
#0x6a9b6e39815986a0909d64975e00a09c6ba560b0247c6db03fd78fbb9dfc9fbe
#<custom: dia chi nhan fund> 0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
#<custom: fund coin>
#<custom: tge> 1703244223000
#<vesting duration> 60000
#0xdcee393950507db6ceee81e9cff0e3955b7460137b79136ee3cc48729385dc05
#0xb7b7d40c111719de2ddc8a69ae248fc9db9560a478a2db9ef5fbe2a5a5a874bc
#0x3a4e97d5bd6e4fa8a1ae54d67b2de9aca511647f4cb1c944afcb0b75cfb5f294

