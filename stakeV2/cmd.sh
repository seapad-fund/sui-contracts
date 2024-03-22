#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 200000000

export PACKAGE=0xf38370af0d236136083e80a2db823b9661ca84f75e3619e1e366f224be3f4c20
export UPGRADE_CAP=0x2e793c67fe65238028ac25ef6681ae6d3f086496358ffe5ac2ff6b5433c89d1d
export ADMIN_CAP_STAKE=0xa67efef451d60625994bd542609e64aeef6cb69b13ded29820c738ef92b1f0b5
export VERSION=0x70fd54bd7473e6dc637e524383927291406aefa6ef669d6519cced24a2a6fca9
export ADMIN_CAP_VERSION=0xe81431ebf31782c424c332fe8c1e72e1029f1597fdc237b9ffc36525c6f85570
export NEW_ADMIN=0x0c5fa0762043c0ed91ddca940890c930947d062e1bea110fe4d7a59ad19297a1

#sui client call --gas-budget 200000000 --package $PACKAGE --module "stake" --function "change_admin" --args  $ADMIN_CAP_STAKE $NEW_ADMIN $VERSION

#upgrade package
sui client upgrade --gas-budget 200000000 --upgrade-capability $UPGRADE_CAP

#Package_after_Updrage
export PACKAGE_NEW = 0xa59716ed4f4b05f227b7d7d1ad09a968ea62162850c594b28098b08911a53eda

