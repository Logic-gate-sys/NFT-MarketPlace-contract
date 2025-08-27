
# Load environment variables
-include .env

# Default values
DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# PHONY targets
.PHONY: all test clean deploy fund help install snapshot format anvil \
        mint deployMood mintMoodNft flipMoodNft deploy_sepolia deploy_anvil

# Help message
help:
	@echo "Usage:"
	@echo "  make deploy ARGS=\"--network sepolia\""
	@echo "  make mint ARGS=\"--network sepolia\""
	@echo "  make deployMood ARGS=\"--network sepolia\""
	@echo "  make flipMoodNft ARGS=\"--network sepolia\""
	@echo "  make test | clean | build | install | snapshot | format"

# Full clean and rebuild
all: clean remove install update build

# Basic commands
clean: ; forge clean
remove: ; rm -rf .gitmodules lib .git/modules/* && touch .gitmodules && git add . && git commit -m "modules reset"
install: ; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && \
           forge install foundry-rs/forge-std@v1.5.3 --no-commit && \
           forge install openzeppelin/openzeppelin-contracts@v4.8.3 --no-commit
update: ; forge update
build: ; forge build
test: ; forge test
snapshot: ; forge snapshot
format: ; forge fmt

# Run local anvil node
anvil:
	anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# Set default network args to anvil
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

# Override if deploying to Sepolia
ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) \
                    --private-key $(PRIVATE_KEY) \
                    --broadcast \
                    --verify \
                    --etherscan-api-key $(ETHERSCAN_API_KEY) \
                    -vvvv
endif

# Deployment scripts
deploy:
	@forge script script/DeployBasicNFT.s.sol:DeployBasicNFT $(NETWORK_ARGS) $(ARGS)

deploy_sepolia:
	@forge script script/DeployCollectionAndCollectionFactory.s..sol:DeployCollectionAndCollectionFactory \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--private-key $(PRIVATE_KEY) \
		--broadcast \
		--chain-id 11155111 \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY)

deploy_anvil:
	@forge script script/DeployCollectionAndCollectionFactory.s..sol:DeployCollectionAndCollectionFactory \
		--rpc-url $(ANVIL_RPC_URL) \
		--private-key $(ANVIL_PRIVATE_KEY) \
		--broadcast

# NFT actions
mint:
	@forge script script/Interactions.s.sol:MintNFT $(NETWORK_ARGS) $(ARGS)

deployMood:
	@forge script script/DeployMoodNft.s.sol:DeployMoodNft $(NETWORK_ARGS) $(ARGS)

mintMoodNft:
	@forge script script/Interactions.s.sol:MintMoodNft $(NETWORK_ARGS) $(ARGS)

flipMoodNft:
	@forge script script/Interactions.s.sol:FlipMoodNft $(NETWORK_ARGS) $(ARGS)

# Show help by default
.DEFAULT_GOAL := help


