// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ProxyAccount
 * @dev A contract that allows the owner to execute strategies and transfer tokens
 */
contract ProxyAccount {
    address public owner;

    /**
     * @dev Sets the owner of the contract
     * @param _owner The address that will own this contract
     */
    constructor(address _owner) {
        owner = _owner;
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
} 