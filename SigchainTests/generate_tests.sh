#!/bin/sh

rm -f test.db
sed -i.bak -e '8,11d' sigchain/Cargo.toml
DATABASE_URL=test.db cargo run --manifest-path sigchain/sigchain_client/Cargo.toml --bin block_validator | tee generated_test_cases.json

