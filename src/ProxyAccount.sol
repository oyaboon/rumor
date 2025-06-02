// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Aave V3 IPool interface
interface IPool {
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

// Uniswap V3 SwapRouter interface
interface ISwapRouter {
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

    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);
}

/**
 * @title ProxyAccount
 * @dev A contract that allows the owner to execute strategies and transfer tokens
 */
contract ProxyAccount {
    address public owner;
    
    // Contract addresses
    address public aavePool;
    address public uniswapRouter;
    address public usdt;
    address public usdc;
    address public aUsdt;
    address public aUsdc;
    
    // Uniswap V3 fee tier (0.05% = 500)
    uint24 public constant POOL_FEE = 500;

    /**
     * @dev Sets the owner of the contract and protocol addresses
     * @param _owner The address that will own this contract
     * @param _aavePool The Aave V3 Pool address
     * @param _uniswapRouter The Uniswap V3 SwapRouter address
     * @param _usdt The USDT token address
     * @param _usdc The USDC token address
     * @param _aUsdt The aUSDT token address
     * @param _aUsdc The aUSDC token address
     */
    constructor(
        address _owner,
        address _aavePool,
        address _uniswapRouter,
        address _usdt,
        address _usdc,
        address _aUsdt,
        address _aUsdc
    ) {
        owner = _owner;
        aavePool = _aavePool;
        uniswapRouter = _uniswapRouter;
        usdt = _usdt;
        usdc = _usdc;
        aUsdt = _aUsdt;
        aUsdc = _aUsdc;
    }

    /**
     * @dev Modifier to restrict access to owner only
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "ProxyAccount: caller is not the owner");
        _;
    }

    /**
     * @dev Executes a strategy by calling an external contract
     * @param strategy The address of the strategy contract to call
     * @param data The calldata to send to the strategy contract
     */
    function executeStrategy(address strategy, bytes memory data) public onlyOwner {
        (bool success, ) = strategy.call(data);
        require(success, "ProxyAccount: strategy execution failed");
    }

    /**
     * @dev Transfers ERC20 tokens to the owner
     * @param token The address of the ERC20 token contract
     * @param amount The amount of tokens to transfer
     */
    function transferToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner, amount);
    }

    /**
     * @dev Runs a strategy by encoding execute(uint256) call and executing it
     * @param strategy The address of the strategy contract to call
     * @param amount The amount parameter to pass to the execute function
     */
    function runStrategy(address strategy, uint256 amount) external onlyOwner {
        bytes memory callData = abi.encodeWithSignature("execute(uint256)", amount);
        executeStrategy(strategy, callData);
    }

    /**
     * @dev Claims all aUSDT and aUSDC from Aave, swaps USDC to USDT, and transfers total USDT to owner
     */
    function claim() external onlyOwner {
        // Step 1: Get balances of aTokens
        uint256 aUsdtBalance = IERC20(aUsdt).balanceOf(address(this));
        uint256 aUsdcBalance = IERC20(aUsdc).balanceOf(address(this));
        
        // Step 2: Withdraw all aUSDT from Aave (amount type(uint256).max means withdraw all)
        if (aUsdtBalance > 0) {
            IERC20(aUsdt).approve(aavePool, aUsdtBalance);
            IPool(aavePool).withdraw(usdt, type(uint256).max, address(this));
        }
        
        // Step 3: Withdraw all aUSDC from Aave
        if (aUsdcBalance > 0) {
            IERC20(aUsdc).approve(aavePool, aUsdcBalance);
            IPool(aavePool).withdraw(usdc, type(uint256).max, address(this));
        }
        
        // Step 4: Get USDC balance after withdrawal
        uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
        
        // Step 5: Swap all USDC to USDT via Uniswap V3
        if (usdcBalance > 0) {
            IERC20(usdc).approve(uniswapRouter, usdcBalance);
            
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
                tokenIn: usdc,
                tokenOut: usdt,
                fee: POOL_FEE,
                recipient: address(this),
                deadline: block.timestamp + 300, // 5 minutes from now
                amountIn: usdcBalance,
                amountOutMinimum: 0, // Accept any amount of USDT out
                sqrtPriceLimitX96: 0 // No price limit
            });
            
            ISwapRouter(uniswapRouter).exactInputSingle(params);
        }
        
        // Step 6: Transfer all USDT to owner
        uint256 totalUsdtBalance = IERC20(usdt).balanceOf(address(this));
        if (totalUsdtBalance > 0) {
            IERC20(usdt).transfer(owner, totalUsdtBalance);
        }
    }
} 