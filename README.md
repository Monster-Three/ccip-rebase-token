
# Chainlink CCIP Rebase Token

This repository implements a **Cross-Chain Rebase Token Protocol** using the **Foundry** smart contract development framework. The project leverages **Chainlink's Cross-Chain Interoperability Protocol (CCIP)** to enable the secure and reliable transfer of the elastic-supply token across different EVM blockchains.

The core idea is to create a token where the balance automatically adjusts (rebases) to reflect accrued rewards (interest) over time, and to ensure this unique balance-tracking mechanism functions seamlessly when tokens are bridged between chains via CCIP.

## 🌟 Features

* **Rebase Mechanism:** Implements an elastic supply token where user balances automatically increase over time, reflecting earned interest/rewards.
* **Cross-Chain Interoperability (CCIP):** Integrates Chainlink CCIP to enable secure, programmable token transfers (Burn/Mint) between a Layer 1 (L1) and a Layer 2 (L2) or other EVM chains.
* **Interest Rate Propagation:** Crucially, the system is designed to bridge the user's specific **interest rate** along with the token transfer, ensuring that the rebase rewards continue correctly on the destination chain.
* **Foundry Tooling:** Utilizes Foundry for fast, robust development, testing, and deployment scripts.

## 💡 Protocol Design Summary

The protocol logic follows a Burn/Mint mechanism for cross-chain transfers:
1.  **Source Chain (e.g., Ethereum Sepolia):** A user calls a function to bridge their tokens. The tokens are **burned**, and a CCIP message is sent to the destination chain.
2.  **CCIP Message:** The message includes the amount to mint and the user's current **static interest rate** (captured at the time of bridging).
3.  **Destination Chain (e.g., Avalanche Fuji):** A corresponding smart contract receives the CCIP message, verifies its authenticity, and **mints** the tokens to the recipient's address, while also setting their specific, guaranteed interest rate.

## 🛠️ Getting Started

### Prerequisites

1.  **Git**
2.  **Foundry** (Install via `curl -L https://foundry.paradigm.xyz | bash` and run `foundryup`)
3.  A modern **RPC URL** for at least two testnets (e.g., Sepolia and Avalanche Fuji) to simulate the cross-chain environment.
4.  A **Private Key** with testnet ETH/tokens for gas.

### Quickstart

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/Monster-Three/ccip-rebase-token.git](https://github.com/Monster-Three/ccip-rebase-token.git)
    cd ccip-rebase-token
    ```

2.  **Install dependencies (Submodules):**
    ```bash
    forge install
    ```

3.  **Set up Environment Variables:**
    Create a file named `.env` in the root directory and configure your variables.

    ```bash
    # Example .env content
    PRIVATE_KEY="YOUR_PRIVATE_KEY_HERE"
    # RPC URLs for the two chains used for CCIP transfers
    SEPOLIA_RPC_URL="YOUR_SEPOLIA_RPC_URL_HERE"
    FUJI_RPC_URL="YOUR_FUJI_RPC_URL_HERE"
    # Optional: for contract verification
    ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY"
    ```

## 🚀 Usage & Deployment

### 1. Run Tests

Ensure the core logic, especially the rebase calculations and CCIP-related functions, is working correctly.

```bash
forge test -vvvv

## ⚠️ Known Issues and Limitations

This section documents known design choices, potential centralization vectors, and identified bugs in the current protocol implementation.

### Protocol Known Limitations

1.  **Inaccurate `totalSupply`:**
    * The `totalSupply()` function (which maps to `principleBalanceOf()` in `RebaseToken.sol`) only returns the initial *principal* amount of tokens minted.
    * It **does not include the accrued interest**, meaning the reported supply does not reflect the actual, total balance held by users (the "elastic" supply).

2.  **Centralization Risk via `MINT_AND_BURN_ROLE`:**
    * The `Owner` can grant the `MINT_AND_BURN_ROLE` to any address, including their own, by calling `grantMintAndBurnRole` in `RebaseToken.sol`.
    * This capability introduces a degree of **centralization**, as the owner has the unilateral power to delegate the critical ability to manipulate the token supply.

### Identified Bugs (Logic Flaws)

1.  **Interest Rate Inheritance on First Transfer:**
    * When an account (Alice) receives a transfer of tokens, if Alice has never interacted with the protocol (i.e., her balance is 0), she will **inherit the sender's interest rate**.
    * *(See `RebaseToken.sol`'s `transfer` function: `if (balanceOf(_recipient) == 0)`).*
    * If this `if` statement were removed, the transferred amount would be stored at an implied 0% interest rate, potentially losing the sender's current reward rate. The current implementation's benefit of maintaining the higher rate for the funds must be weighed against the side effect of granting the sender's rate to a new user.

2.  **Transfer-Based Interest Rate Adjustment (Recipient's Rate Dominance):**
    * When Account A transfers tokens to Account B:
        * If Account B's existing interest rate is **lower** than Account A's, the transferred amount will be stored under **Account B's lower rate**.
        * Conversely, if Account B transfers to Account A and Account A's rate is **higher**, the transferred amount will be stored under **Account A's higher rate**.
    * This logic means the **recipient's existing interest rate** governs how the incoming amount is recorded, which might not be the intended design for preserving the value represented by the sender's tokens.
