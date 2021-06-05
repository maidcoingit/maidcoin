// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface NurseRaidInterface {

    function maidCoin() external view returns (address);
    function maids() external view returns (address);

    function createRaid(uint256 entranceFee, uint256 nurseType, uint256 duration) external;
    function removeRaid(uint256 raidId) external;
    
    function enter(uint256 raidId, uint256[] calldata maidIds) external;
    function exit(uint256 raidId) external;
}