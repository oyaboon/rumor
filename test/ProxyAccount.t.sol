// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {ProxyAccount} from "../src/ProxyAccount.sol";
import {StrategyExecutor} from "../src/StrategyExecutor.sol";

// Mock ERC20 contract for testing
contract MockERC20 {
    string public name = "Mock Token";
    string public symbol = "MOCK";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
}

// Mock contracts for StrategyExecutor dependencies
contract MockAavePool {
    // Track expected withdrawal amounts for each asset
    mapping(address => uint256) public withdrawalAmounts;
    // Map underlying assets to their corresponding aTokens
    mapping(address => address) public underlyingToAToken;
    
    function setWithdrawalAmount(address asset, uint256 amount) external {
        withdrawalAmounts[asset] = amount;
    }
    
    function setATokenMapping(address underlying, address aToken) external {
        underlyingToAToken[underlying] = aToken;
    }
    
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external {
        // Mock implementation - just accept the call
    }
    
    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        // Get the corresponding aToken for this underlying asset
        address aToken = underlyingToAToken[asset];
        
        // Get withdrawal amount
        uint256 withdrawAmount = withdrawalAmounts[asset];
        
        if (withdrawAmount > 0 && aToken != address(0)) {
            // Burn aTokens from the caller (ProxyAccount)
            // In our mock, we'll transfer aTokens from caller to this contract (simulating burn)
            MockERC20(aToken).transferFrom(msg.sender, address(this), withdrawAmount);
            
            // Mint underlying tokens to recipient
            MockERC20(asset).mint(to, withdrawAmount);
            return withdrawAmount;
        }
        
        // Fallback: if no predefined amount, use requested amount
        uint256 actualAmount;
        if (amount == type(uint256).max) {
            actualAmount = 100 * 10**6; // Default fallback
        } else {
            actualAmount = amount;
        }
        
        // If aToken mapping exists, burn aTokens
        if (aToken != address(0)) {
            MockERC20(aToken).transferFrom(msg.sender, address(this), actualAmount);
        }
        
        MockERC20(asset).mint(to, actualAmount);
        return actualAmount;
    }
}

contract MockUniswapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut) {
        // Mock implementation - transfer tokenIn from caller and mint tokenOut to recipient
        MockERC20(params.tokenIn).transferFrom(msg.sender, address(this), params.amountIn);
        MockERC20(params.tokenOut).mint(params.recipient, params.amountIn); // 1:1 swap
        return params.amountIn;
    }
}

contract ProxyAccountTest is Test {
    ProxyAccount public proxyAccount;
    MockERC20 public mockToken;
    MockERC20 public mockUSDT;
    MockERC20 public mockUSDC;
    MockERC20 public mockAUSDT;  // Separate aToken contracts
    MockERC20 public mockAUSDC;  // Separate aToken contracts
    MockAavePool public mockAavePool;
    MockUniswapRouter public mockUniswapRouter;
    
    function setUp() public {
        // Deploy mock ERC20 tokens
        mockToken = new MockERC20();
        mockUSDT = new MockERC20();
        mockUSDC = new MockERC20();
        mockAUSDT = new MockERC20();  // Separate aUSDT contract
        mockAUSDC = new MockERC20();  // Separate aUSDC contract
        
        // Deploy mock Aave pool and Uniswap router
        mockAavePool = new MockAavePool();
        mockUniswapRouter = new MockUniswapRouter();
        
        // Deploy ProxyAccount with all required constructor parameters
        proxyAccount = new ProxyAccount(
            address(mockUSDT),          // usdt
            address(mockUSDC),          // usdc
            address(mockAavePool),      // aavePool
            address(mockAUSDT),         // aUsdt (separate contract)
            address(mockAUSDC),         // aUsdc (separate contract)
            address(mockUniswapRouter)  // uniswapRouter
        );
    }
    
    function testOwnerIsSetCorrectly() public {
        // Check if the owner is set to address(this)
        assertEq(proxyAccount.owner(), address(this));
    }
    
    function testTransferToken() public {
        uint256 mintAmount = 1000 * 10**18; // 1000 tokens
        
        // Mint mock ERC20 tokens to the ProxyAccount
        mockToken.mint(address(proxyAccount), mintAmount);
        
        // Verify ProxyAccount received the tokens
        assertEq(mockToken.balanceOf(address(proxyAccount)), mintAmount);
        
        // Get initial balance of test contract
        uint256 initialBalance = mockToken.balanceOf(address(this));
        
        // Call transferToken() from the ProxyAccount to transfer tokens to owner (this test contract)
        proxyAccount.transferToken(address(mockToken), mintAmount);
        
        // Assert that the test contract received the tokens
        assertEq(mockToken.balanceOf(address(this)), initialBalance + mintAmount);
        
        // Assert that ProxyAccount no longer has the tokens
        assertEq(mockToken.balanceOf(address(proxyAccount)), 0);
    }
    
    function testOnlyOwnerCanExecuteStrategy() public {
        // Create a different address to test access control
        address notOwner = address(0x123);
        
        // Try to call executeStrategy from non-owner address
        vm.prank(notOwner);
        vm.expectRevert("ProxyAccount: caller is not the owner");
        proxyAccount.executeStrategy(address(mockToken), "");
    }
    
    function testOnlyOwnerCanTransferToken() public {
        // Create a different address to test access control
        address notOwner = address(0x123);
        
        // Try to call transferToken from non-owner address
        vm.prank(notOwner);
        vm.expectRevert("ProxyAccount: caller is not the owner");
        proxyAccount.transferToken(address(mockToken), 100);
    }
    
    function testExecuteStrategySuccess() public {
        uint256 mintAmount = 1000 * 10**18;
        
        // Mint tokens to ProxyAccount
        mockToken.mint(address(proxyAccount), mintAmount);
        
        // Encode transfer call data
        bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", address(this), mintAmount);
        
        // Execute strategy to transfer tokens
        proxyAccount.executeStrategy(address(mockToken), data);
        
        // Verify the strategy execution worked
        assertEq(mockToken.balanceOf(address(this)), mintAmount);
        assertEq(mockToken.balanceOf(address(proxyAccount)), 0);
    }
    
    function testExecuteStrategyFailure() public {
        // Try to execute a strategy that will fail (calling non-existent function)
        bytes memory invalidData = abi.encodeWithSignature("nonExistentFunction()");
        
        // Expect the call to revert
        vm.expectRevert("ProxyAccount: strategy execution failed");
        proxyAccount.executeStrategy(address(mockToken), invalidData);
    }
    
    function testRunStrategy() public {
        // Deploy StrategyExecutor with mock addresses
        StrategyExecutor strategyExecutor = new StrategyExecutor(
            address(proxyAccount),    // proxy
            address(mockUSDT),        // USDT
            address(mockUSDC),        // USDC
            address(mockAavePool),    // Aave pool
            address(mockUniswapRouter) // Uniswap router
        );
        
        uint256 testAmount = 1000 * 10**6; // 1000 USDT (6 decimals)
        
        // Mint USDT tokens to ProxyAccount
        mockUSDT.mint(address(proxyAccount), testAmount);
        
        // Verify ProxyAccount has USDT
        assertEq(mockUSDT.balanceOf(address(proxyAccount)), testAmount);
        
        // Approve the strategy to spend USDT from ProxyAccount
        // We need to do this via executeStrategy since we can't directly approve from ProxyAccount
        bytes memory approveData = abi.encodeWithSignature(
            "approve(address,uint256)", 
            address(strategyExecutor), 
            testAmount
        );
        proxyAccount.executeStrategy(address(mockUSDT), approveData);
        
        // Call runStrategy - this should execute without reverting
        proxyAccount.runStrategy(address(strategyExecutor), testAmount);
        
        // Assert that the function completed successfully (no revert occurred)
        // We can verify this by checking that the USDT balance changed
        assertEq(mockUSDT.balanceOf(address(proxyAccount)), 0, "ProxyAccount should have transferred all USDT");
    }
    
    function testClaim() public {
        uint256 aUsdtAmount = 500 * 10**6;  // 500 aUSDT
        uint256 aUsdcAmount = 300 * 10**6;  // 300 aUSDC
        
        // Configure MockAavePool to return specific amounts for each asset
        mockAavePool.setWithdrawalAmount(address(mockUSDT), aUsdtAmount);
        mockAavePool.setWithdrawalAmount(address(mockUSDC), aUsdcAmount);
        
        // Configure aToken mappings so the pool knows which aTokens to burn
        mockAavePool.setATokenMapping(address(mockUSDT), address(mockAUSDT));
        mockAavePool.setATokenMapping(address(mockUSDC), address(mockAUSDC));
        
        // Mint aTokens to ProxyAccount (using separate contracts)
        mockAUSDT.mint(address(proxyAccount), aUsdtAmount);
        mockAUSDC.mint(address(proxyAccount), aUsdcAmount);
        
        // Get initial owner USDT balance
        uint256 initialOwnerBalance = mockUSDT.balanceOf(address(this));
        
        // Call claim function
        proxyAccount.claim();
        
        // After claim, owner should receive:
        // - aUSDT amount (withdrawn as USDT)
        // - aUSDC amount (withdrawn as USDC, then swapped to USDT 1:1)
        uint256 expectedTotal = aUsdtAmount + aUsdcAmount; // 500 + 300 = 800
        assertEq(mockUSDT.balanceOf(address(this)), initialOwnerBalance + expectedTotal, "Owner should receive all USDT");
        
        // Verify ProxyAccount has no aTokens left (they should be burned during withdrawal)
        assertEq(mockAUSDT.balanceOf(address(proxyAccount)), 0, "ProxyAccount should have no aUSDT left");
        assertEq(mockAUSDC.balanceOf(address(proxyAccount)), 0, "ProxyAccount should have no aUSDC left");
    }
    
    function testOnlyOwnerCanClaim() public {
        // Create a different address to test access control
        address notOwner = address(0x123);
        
        // Try to call claim from non-owner address
        vm.prank(notOwner);
        vm.expectRevert("ProxyAccount: caller is not the owner");
        proxyAccount.claim();
    }
} 