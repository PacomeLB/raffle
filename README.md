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

https://sepolia.etherscan.io/tx/0xde655055445eb49b3e189cdef2b5fccc87a1b11bbb7ea4a8d5192a717e5a8141/advanced
