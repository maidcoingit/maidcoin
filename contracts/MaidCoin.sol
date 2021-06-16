// SPDX-License-Identifier: MIT
pragma solidity =0.5.16;

import "./uniswapv2/UniswapV2ERC20.sol";
import "./interfaces/IMaidCoin.sol";
import "./libraries/Ownable.sol";

contract MaidCoin is IMaidCoin, Ownable, UniswapV2ERC20("MaidCoin", "$MAID") {
    uint256 public constant INITIAL_SUPPLY = 30000 * 1e18;

    constructor() public {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}