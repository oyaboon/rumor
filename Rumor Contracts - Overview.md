# Rumor Contracts - Project Overview

## Project Description

**Rumor Contracts** is a DeFi (Decentralized Finance) protocol built on Polygon that provides automated yield farming strategies through a proxy account system. The project enables users to deploy individual proxy contracts that can execute shared investment strategies across multiple DeFi protocols, specifically focusing on Aave lending and Uniswap token swapping.

## Core Architecture

The project consists of four main smart contracts that work together to provide a seamless DeFi investment experience:

### 1. **ProxyAccount** (`ProxyAccount.sol`)
- **Purpose**: Individual user-owned contract that manages tokens and executes strategies
- **Key Features**:
  - Single owner per proxy account
  - Meta-transaction support for gasless operations
  - Integration with Aave V3 lending protocol
  - Uniswap V3 token swapping capabilities
  - Fee collection mechanism (0.1% default)
  - Emergency token recovery functions
  - Multicall support for batched operations

### 2. **ProxyFactory** (`ProxyFactory.sol`)
- **Purpose**: Factory contract for deploying new ProxyAccount instances
- **Key Features**:
  - One-click proxy deployment for users
  - Standardized configuration across all proxies
  - Tracks deployed proxies per user
  - Immutable protocol addresses (Aave, Uniswap, token addresses)

### 3. **StrategyExecutor** (`StrategyExecutor.sol`)
- **Purpose**: Shared strategy implementation that executes the core investment logic
- **Strategy Logic**:
  1. Splits incoming USDT 50/50
  2. Deposits 50% directly to Aave as USDT (receives aUSDT)
  3. Swaps remaining 50% to USDC via Uniswap V3
  4. Deposits USDC to Aave (receives aUSDC)
- **Key Features**:
  - Slippage protection (0.5% default)
  - Emergency withdrawal functionality
  - Works with any ProxyAccount that approves it

### 4. **LendingStrategy** (`LendingStrategy.sol`)
- **Purpose**: Abstract base contract defining the strategy interface
- **Interface**: Provides `run(uint256 amount)` function signature

## Protocol Integrations

### **Aave V3 (Polygon)**
- **USDT Pool**: Deposits USDT to earn yield through aUSDT tokens
- **USDC Pool**: Deposits USDC to earn yield through aUSDC tokens
- **Lending Pool**: `0x794a61358D6845594F94dc1DB02A252b5b4814aD`

### **Uniswap V3 (Polygon)**
- **Token Swapping**: USDT to USDC conversion with 0.05% fee tier
- **Router**: `0xE592427A0AEce92De3Edee1F18E0157C05861564`
- **Slippage Protection**: 0.5% maximum slippage tolerance

### **Papaya Integration**
- **Purpose**: External yield source integration
- **Functionality**: Users can pull funds from Papaya contracts into their proxy accounts

## User Flow

### **1. Proxy Deployment**
```solidity
// User calls ProxyFactory to create their personal proxy
address proxy = proxyFactory.createProxy(userAddress);
```

### **2. Strategy Execution**
```solidity
// User approves USDT to their proxy
USDT.approve(proxy, amount);

// User executes strategy through their proxy
ProxyAccount(proxy).runStrategy(sharedStrategy, amount);
```

### **3. Yield Claiming**
```solidity
// User claims all yields, automatically converting to USDT
ProxyAccount(proxy).claim();
```

## Smart Contract Features

### **Security Features**
- **ReentrancyGuard**: Prevents reentrancy attacks on critical functions
- **Owner-only Access**: Each proxy is controlled exclusively by its owner
- **Meta-transaction Support**: EIP-712 compliant signatures for gasless operations
- **Emergency Functions**: Token recovery mechanisms for stuck funds

### **Gas Optimization**
- **Multicall**: Batch multiple operations in a single transaction
- **Immutable Variables**: Gas-efficient storage for protocol addresses
- **Shared Strategy**: Single deployed strategy serves all proxy accounts

### **Fee Structure**
- **Strategy Fee**: 0.1% (10 basis points) deducted before strategy execution
- **Fee Recipient**: Configurable address for fee collection
- **Transparent**: All fees clearly documented and emitted in events

## Technical Specifications

### **Blockchain**: Polygon Mainnet
### **Solidity Version**: ^0.8.20
### **Development Framework**: Foundry
### **Dependencies**:
- OpenZeppelin Contracts (security utilities)
- Forge Standard Library (testing)

### **Token Addresses (Polygon)**
- **USDT**: `0xc2132D05D31c914a87C6611C10748AEb04B58e8F`
- **USDC**: `0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`
- **aUSDT**: `0x6ab707Aca953eDAeFBc4fD23bA73294241490620`
- **aUSDC**: `0xA4D94019934D8333Ef880ABFFbF2FDd611C762BD`

## Testing & Validation

### **Test Coverage**
- **Unit Tests**: Individual contract functionality validation
- **Integration Tests**: Full protocol interaction testing
- **Mainnet Forking**: Real-world scenario testing against live protocols
- **Edge Cases**: Fee collection, meta-transactions, emergency scenarios

### **Key Test Scenarios**
- Proxy account deployment and ownership
- Strategy execution with real Aave/Uniswap interactions
- Yield claiming and token conversion
- Fee calculation and distribution
- Meta-transaction signature validation
- Emergency token recovery

## Deployment Information

### **Deployment Script**: `script/Deploy.s.sol`
- Deploys shared StrategyExecutor
- Deploys ProxyFactory with all protocol addresses
- Configures 0.1% fee structure
- Ready for Polygon mainnet deployment

### **Gas Considerations**
- **Proxy Deployment**: ~2.5M gas
- **Strategy Execution**: ~800K gas
- **Yield Claiming**: ~600K gas

## Project Benefits

### **For Users**
- **Simplified DeFi Access**: One-click strategy execution
- **Diversified Yield**: Exposure to both USDT and USDC lending markets
- **Gas Efficiency**: Shared strategy reduces deployment costs
- **Ownership**: Complete control over individual proxy accounts

### **For Protocol**
- **Scalability**: Shared components reduce operational overhead
- **Flexibility**: Modular design allows strategy upgrades
- **Revenue**: Fee collection from all strategy executions
- **Composability**: Easy integration with other DeFi protocols

## Future Enhancements

- **Multiple Strategies**: Support for additional yield farming strategies
- **Cross-chain**: Expansion to other EVM-compatible chains
- **Governance**: DAO-based protocol parameter management
- **Advanced Features**: Stop-loss, automated rebalancing, yield optimization

---

*This project represents a sophisticated approach to democratizing DeFi access through user-owned proxy accounts and shared strategy execution, providing both security and efficiency for yield farming operations.*
