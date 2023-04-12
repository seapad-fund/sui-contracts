#!/bin/bash
#sui move build
#sui move test
sui client publish --force --with-unpublished-dependencies --gas-budget 1000000000
#sui client publish --force --gas-budget 1000000

##move  call
export ENV_ADDR=0x9d6f2e34e937842df89642cd96fba8509d4e47d297f716ce3a44df3070a79851
export PACKAGE=0xd52ec43bf772a4b0cf80980e519354e5fb7ce2ef