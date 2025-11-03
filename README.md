# Rumor Contracts

DeFi protocol for automated yield farming on Polygon using proxy accounts with shared strategy execution.

## Overview

Rumor Contracts enables users to deploy individual proxy contracts that execute shared investment strategies across Aave V3 and Uniswap V3. Each user owns their proxy account while benefiting from a shared strategy executor that splits USDT investments 50/50 between Aave USDT and USDC lending pools.

## Architecture

### Core Contracts

- **`ProxyAccount.sol`** - User-owned contract for token management and strategy execution
  - Owner-only access control
  - Meta-transaction support (EIP-712)
  - Fee collection (0.1% default)
  - Integration with Aave V3 and Uniswap V3

- **`ProxyFactory.sol`** - Factory for deploying standardized proxy accounts
  - One proxy per user
  - Immutable protocol configuration

- **`StrategyExecutor.sol`** - Shared strategy implementation
  - Splits USDT 50/50
  - Deposits 50% to Aave USDT pool (receives aUSDT)
  - Swaps remaining 50% to USDC via Uniswap V3
  - Deposits USDC to Aave (receives aUSDC)
  - Slippage protection: 0.5%

- **`LendingStrategy.sol`** - Abstract interface for strategies

## Protocol Addresses (Polygon)

```
USDT:        0xc2132D05D31c914a87C6611C10748AEb04B58e8F
USDC:        0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359
aUSDT:       0x6ab707Aca953eDAeFBc4fD23bA73294241490620
aUSDC:       0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD
Aave Pool:   0x794a61358D6845594F94dc1DB02A252b5b4814aD
Uniswap V3:  0xE592427A0AEce92De3Edee1F18E0157C05861564
```

## Installation

```bash
forge install
```

## Build

```bash
forge build
```

## Test

```bash
forge test
```

For mainnet fork testing:
```bash
forge test --fork-url https://polygon-rpc.com
```

## Deploy

```bash
forge script script/Deploy.s.sol:Deploy --rpc-url <polygon_rpc_url> --private-key <private_key> --broadcast
```

### 1. Create Proxy Account

```solidity
address proxy = proxyFactory.createProxy();
```

### 2. Execute Strategy

```solidity
// Approve USDT to proxy
IERC20(USDT).approve(proxy, amount);

// Execute strategy
ProxyAccount(proxy).runStrategy(address(0), amount); // address(0) uses default strategy
```

### 3. Claim Yields

```solidity
// Withdraws from Aave, swaps USDC to USDT, transfers to owner
ProxyAccount(proxy).claim();
```

## Features

- **Gas Efficient**: Shared strategy executor reduces deployment costs
- **Owner Control**: Full ownership of individual proxy accounts
- **Meta-transactions**: Gasless operation support
- **Security**: ReentrancyGuard, owner-only access, slippage protection
- **Multicall**: Batch operations in single transaction

## Fee Structure

- Strategy fee: 0.1% (10 basis points)
- Fee recipient: Configurable at deployment
- Fee deducted before strategy execution

## Technical Stack

- **Solidity**: ^0.8.20
- **Framework**: Foundry
- **Dependencies**: OpenZeppelin Contracts, Forge Std
- **Network**: Polygon Mainnet

## License

MIT
