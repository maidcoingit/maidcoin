// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IMaidCoin.sol";

interface IMasterCoin is IERC20 {
    event Claim(address indexed master, uint256 amount);

    function maidCoin() external view returns (IMaidCoin);

    function claimableAmount(address master) external view returns (uint256);

    function claim(address master) external;
}