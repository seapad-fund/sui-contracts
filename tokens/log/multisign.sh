#!/bin/bash
#sui move build
#sui move test
#sui client publish --force --with-unpublished-dependencies  --gas-budget 100000000
sui client publish --force  --gas-budget 100000000
export MULTISIG_ADDR_1=0x0dd0106a909560b8f2e0262e9946008e307ae7758fde5277853088d25b0b6c7f
export MULTISIG_ADDR_2=0x89e0d7a3e0ce46a8bab075dfe81b84790c8f3b0860a88b8ba09d27e87b50073e
export MULTISIG_ADDR_3=0x38a7ccc61dcbbe36c9b02d8781322041d9e727ce55b1161010d0946468984679

export TARGET=0x901455b327d26f4df19c82ab313db5fd32f4704d30b7674050fc265442868f23
export SOURCE_SUI=0xcbe6e1ec14bdbb7a77f22437bb10bea6e8a0b66567f2b49132920dbab120dea2

export PK_1=ALDZ3oU0WiIuxJzxG6nRlB4XnyuqXwEFNYs6n+dDQ2HT
export PK_2=AACYAp/vl9BOBX3AFPasDXRsvjOSycBYylKV2gaQ81NC
export PK_3=AEthhjN8E58q8fp29mHNm1gwKg+rN3XEu1ecfk3I0jEU

#sui keytool multi-sig-address --pks $PK_1 $PK_2 $PK_3 --weights 1 3 2 --threshold 3

#export MULTISIG_ADDR=0x31efef81b6121a1b02fd7c5dc8e862bc1809ef00424c7c19e478b25641c2a59b
#sui client switch --env mainet

## serialize any tx to tx_bytes
#sui client transfer --to $TARGET --object-id $SOURCE_SUI --gas-budget 100000000 --serialize-output

#export TX_BYTES=AAACACCQFFWzJ9JvTfGcgqsxPbX9MvRwTTC3Z0BQ/CZUQoaPIwEAy+bh7BS9u3p38iQ3uxC+puigtmVn8rSRMpINurEg3qISHToAAAAAACCsuMmAyBDXjYGEzapw2KdJ1Gnmmv42IQzrp/N3KFApwAEBAQEBAAEAAE7qBVHVP0jex6p/8b7zgC6dy1PrTzCv1HtOM9g7edHwATSCmjLibWkr+lup8Vs/1aO0DHkGMNS1GQcRw9zH2c89Eh06AAAAAAAgMzzZNwcEO8OLwagfv+cNgusYfU23dOjFkP9vLNgGvV5O6gVR1T9I3seqf/G+84AunctT608wr9R7TjPYO3nR8E0DAAAAAAAAAOH1BQAAAAAA
## sign with wallets
#sui keytool sign --address $MULTISIG_ADDR_1 --data $TX_BYTES
#sui keytool sign --address $MULTISIG_ADDR_2 --data $TX_BYTES

#export SIG_1=AA0gZe3YkTnHB1qQL681s9N1knCYLr/HJxlBfRwDnmTnMeEweIg838xj8FeBAy8zRVqHPBpeASplyQKPlX2lZQGw2d6FNFoiLsSc8Rup0ZQeF58rql8BBTWLOp/nQ0Nh0w==
#export SIG_2=ALy6UDenQ2sdAK3eb8meqf/ijwM4D5P9thu+azgIo8Kn4Dy/SNhgEw0TgXcxPdXHkoJpiaHXHhPpE3ymW4Oz6gYAmAKf75fQTgV9wBT2rA10bL4zksnAWMpSldoGkPNTQg==

##combine sigs

#sui keytool multi-sig-combine-partial-sig --pks $PK_1 $PK_2 $PK_3 --weights 1 2 3 --threshold 3 --sigs $SIG_1 $SIG_2

#export MULTI_SIG=AwIADSBl7diROccHWpAvrzWz03WScJguv8cnGUF9HAOeZOcx4TB4iDzfzGPwV4EDLzNFWoc8Gl4BKmXJAo+VfaVlAQC8ulA3p0NrHQCt3m/Jnqn/4o8DOA+T/bYbvms4CKPCp+A8v0jYYBMNE4F3MT3Vx5KCaYmh1x4T6RN8pluDs+oGFDowAAABAAAAAAABABAAAAAAAAEAAyxBTERaM29VMFdpSXV4Snp4RzZuUmxCNFhueXVxWHdFRk5ZczZuK2REUTJIVAEsQUFDWUFwL3ZsOUJPQlgzQUZQYXNEWFJzdmpPU3ljQll5bEtWMmdhUTgxTkMCLEFFdGhoak44RTU4cThmcDI5bUhObTFnd0tnK3JOM1hFdTFlY2ZrM0kwakVVAwMA
#
#sui client execute-signed-tx --tx-bytes $TX_BYTES --signatures $MULTI_SIG