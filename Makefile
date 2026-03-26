.PHONY: all build test fmt lint clean deploy verify

all: build test

build:
	forge build

test:
	forge test -vvv

gas:
	forge test --gas-report

snapshot:
	forge snapshot

fmt:
	forge fmt

lint:
	forge fmt --check

clean:
	forge clean

deploy:
	forge script script/Deploy.s.sol --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

verify:
	forge verify-contract --chain-id $(CHAIN_ID) --constructor-args $(cast abi-encode "constructor()") $(CONTRACT_ADDRESS) src/Counter.sol:Counter
