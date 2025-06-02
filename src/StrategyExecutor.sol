// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Aave V3 IPool interface
interface IPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
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
 * @title StrategyExecutor
 * @dev A contract that executes a strategy involving USDT/USDC splitting, Aave deposits, and Uniswap swaps
 */
contract StrategyExecutor {
    address public proxy;
    
    IERC20 public immutable usdt;
    IERC20 public immutable usdc;
    IPool public immutable aavePool;
    ISwapRouter public immutable uniswapRouter;
    
    // Uniswap V3 fee tier (0.05% = 500)
    uint24 public constant POOL_FEE = 500;

    /**
     * @dev Sets the proxy address and token addresses
     * @param _proxy The ProxyAccount contract address
     * @param _usdt The USDT token address
     * @param _usdc The USDC token address
     * @param _aavePool The Aave V3 Pool address
     * @param _uniswapRouter The Uniswap V3 SwapRouter address
     */
    constructor(
        address _proxy,
        address _usdt,
        address _usdc,
        address _aavePool,
        address _uniswapRouter
    ) {
        proxy = _proxy;
        usdt = IERC20(_usdt);
        usdc = IERC20(_usdc);
        aavePool = IPool(_aavePool);
        uniswapRouter = ISwapRouter(_uniswapRouter);
    }

    /**
     * @dev Executes the strategy:
     * 1. Transfers USDT from proxy to this contract
     * 2. Splits into two equal parts
     * 3. Deposits half into Aave USDT pool
     * 4. Swaps other half to USDC via Uniswap V3
     * 5. Deposits USDC into Aave USDC pool
     * @param amount The total amount of USDT to process
     */
    function execute(uint256 amount) external {
        // Step 1: Transfer USDT from proxy to this contract
        require(usdt.transferFrom(proxy, address(this), amount), "USDT transfer failed");
        
        // Step 2: Split amount into two equal parts
        uint256 halfAmount = amount / 2;
        uint256 remainingAmount = amount - halfAmount; // Handle odd amounts
        
        // Step 3: Approve and deposit half into Aave USDT pool
        usdt.approve(address(aavePool), halfAmount);
        aavePool.deposit(address(usdt), halfAmount, proxy, 0);
        
        // Step 4: Swap remaining USDT to USDC via Uniswap V3
        usdt.approve(address(uniswapRouter), remainingAmount);
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: address(usdt),
            tokenOut: address(usdc),
            fee: POOL_FEE,
            recipient: address(this),
            deadline: block.timestamp + 300, // 5 minutes from now
            amountIn: remainingAmount,
            amountOutMinimum: 0, // Accept any amount of USDC out
            sqrtPriceLimitX96: 0 // No price limit
        });
        
        uint256 usdcReceived = uniswapRouter.exactInputSingle(params);
        
        // Step 5: Approve and deposit USDC into Aave USDC pool
        usdc.approve(address(aavePool), usdcReceived);
        aavePool.deposit(address(usdc), usdcReceived, proxy, 0);
    }
    
    /**
     * @dev Emergency function to recover any tokens stuck in the contract
     * @param token The token address to recover
     * @param amount The amount to recover
     */
    function emergencyWithdraw(address token, uint256 amount) external {
        require(msg.sender == proxy, "Only proxy can call emergency withdraw");
        IERC20(token).transfer(proxy, amount);
    }
} 