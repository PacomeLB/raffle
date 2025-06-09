## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### Deploying

source .env

# VRF

forge script --chain sepolia script/VrfRaffle.s.sol:VrfRaffleScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1

# Raffle

forge script --chain sepolia script/RaffleAdminPayTaxVrf.s.sol:RaffleAdminPayTaxVrfScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1

forge script --chain sepolia script/SwapERC20ToEthUniSwapV4.s.sol:SwapERC20ToEthUniSwapV4Script --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1

forge script --chain sepolia script/PriceUtils.s.sol:PriceUtilsScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv --interactives 1

https://sepolia.etherscan.io/tx/0xde655055445eb49b3e189cdef2b5fccc87a1b11bbb7ea4a8d5192a717e5a8141/advanced

# fork sepolia to local with chain id 31337 / 11155111 (same as sepolia to use permit 2)

anvil --fork-url https://eth-sepolia.g.alchemy.com/v2/GBm__wLDvs_zeYjXn7L5Krw2RXBHWMeO --chain-id 11155111

# Deploy on local fork (change private key to avoid contract colision: use my wallet key)

forge script script/PriceUtils.s.sol:PriceUtilsScript --rpc-url http://127.0.0.1:8545 --broadcast -vvvv --slow --private-key "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

forge script script/SwapERC20ToEthUniSwapV4.s.sol:SwapERC20ToEthUniSwapV4Script --rpc-url http://127.0.0.1:8545 --broadcast -vvvv --slow --private-key $PRIVATE_KEY_SEPOLIA

# interact with contract on the fork

cast code 0x782aEd4c8571fbD6B7BC7b6b2613fd6550d66C5d --rpc-url http://127.0.0.1:8545
cast balance 0x782aEd4c8571fbD6B7BC7b6b2613fd6550d66C5d --rpc-url http://127.0.0.1:8545

cast call 0xContractAddress "function_signature()" \
 --rpc-url http://127.0.0.1:8545

cast call 0x434b002AEa2D9721104bCAb8eAE8576FE884Ffe4 "MAX_LIQUIDITY_CHANGE()" --rpc-url http://127.0.0.1:8545

cast call 0x434b002AEa2D9721104bCAb8eAE8576FE884Ffe4 "getMinAmountInFromErc20ToEth(address,uint256)((address, uint8, uint256, uint24,(uint256,uint256))[])" 0x779877A7B0D9E8603169DdbD7836e478b4624789 143774531092198 --rpc-url http://127.0.0.1:8545

cast call 0x434b002AEa2D9721104bCAb8eAE8576FE884Ffe4 "getBestPool(address,uint256)((address, uint8, uint256, uint24,(uint256,uint256)))" 0x779877A7B0D9E8603169DdbD7836e478b4624789 143774531092198 --rpc-url http://127.0.0.1:8545

# Usage of cast for debuging

export swap=0x4dD3f964dC618d58569f70a1C8f57905D94bc4e0 // Swap contract address
export paco=0x7a79A7c9338032B116051e9CC4459600F95fc35E // perso wallet address
export unlucky=0xca4365A099eE5E9f20a1Dc8d325Ae8751A0cd87F // random wallet that has link
export link=0x779877A7B0D9E8603169DdbD7836e478b4624789 // Link token address

cast call $link "balanceOf(address)(uint256)" $paco // Call view / pure function on $link contract

cast rpc anvil_impersonateAccount $paco // get control of account $paco in the fork
cast rpc anvil_impersonateAccount $unlucky // get control of account $unlucky in the fork

cast send $link --from $unlucky "transfer(address,uint256)(bool)" $paco 29000000000000000000 --unlocked // Send 29000000000000000000 Link token from $unlucky to paco

// use fonction payWithLink on contract $swap
// send to create a transaction, --unlocked to use controller account from anvil_impersonateAccount
cast send $swap --from $paco --unlocked "payWithLink(bytes, address, uint256, uint256, uint256)" 0x64cdd75b9e2bcb6cc6474b6f23a0a39b3b707d362dc74a566fa2019cfd1f23b20dc6c95e44e56f0822c43571061c4188829702ee571001c734f1f15ae12a00d81b 0x7a79A7c9338032B116051e9CC4459600F95fc35E 1000000000000000000 1 1746716465

// Debug transaction 0xf6efcd00ca724eed0177fd2eb276d597c11a12bb2ad92bca9dccb628954cbd31 from the fork
cast run --debug 0xf6efcd00ca724eed0177fd2eb276d597c11a12bb2ad92bca9dccb628954cbd31
