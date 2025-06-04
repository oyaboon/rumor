// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title LendingStrategy
 * @dev Abstract contract defining the interface for lending strategies
 */
abstract contract LendingStrategy {
    
    /**
     * @dev Invest amount of token according to strategy
     * @param amount The amount of tokens to invest in the strategy
     */
    function run(uint256 amount) external virtual;
    
    /**
     * @dev Convert strategy result back into base token (e.g. USDT)
     * Withdraws all positions and converts everything back to the base token
     */
    function claim() external virtual;
    
    /**
     * @dev Return estimated return for given amount and duration (can be a mock)
     * @param amount The amount of tokens to calculate yield for
     * @param duration The duration in seconds to calculate yield for
     * @return The estimated yield/return amount
     */
    function getExpectedYield(uint256 amount, uint256 duration) external view virtual returns (uint256);
} 