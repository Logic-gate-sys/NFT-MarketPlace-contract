// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import{ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import{Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice Mock USDC token with 6 decimals, owner-restricted mint for tests
contract MockUSDC is ERC20, Ownable {
    constructor() ERC20("Mock USDC", "mUSDC")Ownable(msg.sender) {}

    /// @dev USDC uses 6 decimals
    function decimals() public pure override returns (uint8) {
        return 6; // i USD = 1e6 wei
    }

    /// @notice mint tokens (owner only)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice explicit transfer implementation (calls ERC20)
    function transfer(address to, uint256 amount) public override returns (bool) {
        return super.transfer(to, amount);
    }
}
// ...existing