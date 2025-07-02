# 🎟️ Raffle Smart Contract

A decentralized raffle system built with Solidity, featuring secure ownership patterns, token interoperability, and on-chain randomness. This project demonstrates modern Solidity development practices with integrations from Uniswap and Chainlink.

---

## 🚀 Features

-   **Secure Smart Contract Architecture**

    -   `Ownable`: Restrict access to contract owner functions
    -   `ReentrancyGuard`: Protect against reentrancy attacks
    -   Custom **modifiers** for flexible access control
    -   Solidity **inheritance** for modular contract design

-   **Token Handling with Uniswap V4 and Permit2**

    -   Accept **ERC20 tokens** for raffle entries
    -   Swap tokens via **Uniswap V4** directly in-contract
    -   Use **Permit2** off-chain signatures for gasless approvals

-   **Ticket Minting with NFTs (ERC721)**

    -   Each raffle entry mints an **ERC721 ticket**
    -   NFT images hosted on **IPFS** https://app.pinata.cloud/ipfs/files

-   **Fair Winner Selection with Chainlink VRF**

    -   Random winner is chosen using **Chainlink VRF Oracle**
    -   Ensures tamper-proof and verifiable randomness

-   **Local Testing and Simulation**
    -   Fork the **Sepolia testnet** locally using **Anvil**
    -   Simulate contract interactions and Uniswap behavior

---

## 🧱 Tech Stack

-   **Solidity** for smart contract development
-   **Foundry** for testing and deployment
-   **Chainlink VRF** for randomness
-   **Uniswap V4** for token swaps
-   **Permit2** for ERC20 signature-based approvals
-   **IPFS** for NFT metadata and images
-   **Anvil** for Sepolia chain forking and testing

---

## 📦 Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/PacomeLB/raffle.git
    cd raffle-contract
    ```
