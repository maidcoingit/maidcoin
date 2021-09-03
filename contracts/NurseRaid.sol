// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/INurseRaid.sol";

contract NurseRaid is Ownable, INurseRaid {
    struct Raid {
        uint256 entranceFee;
        uint256 nursePart;
        uint256 maxRewardCount;
        uint256 duration;
        uint256 endBlock;
    }

    struct Challenger {
        uint256 enterBlock;
        IMaids maids;
        uint256 maidId;
    }

    Raid[] public raids;
    mapping(uint256 => mapping(address => Challenger)) public challengers;

    mapping(IMaids => bool) public override maidsApproved;

    IMaidCoin public immutable override maidCoin;
    IMaidCafe public override maidCafe;
    INursePart public immutable override nursePart;
    IRNG public override rng;

    uint256 public override maidPowerToRaidReducedBlock = 100;

    constructor(
        IMaidCoin _maidCoin,
        IMaidCafe _maidCafe,
        INursePart _nursePart,
        IRNG _rng
    ) {
        maidCoin = _maidCoin;
        maidCafe = _maidCafe;
        nursePart = _nursePart;
        rng = _rng;
    }

    function changeMaidPowerToRaidReducedBlock(uint256 value) external onlyOwner {
        maidPowerToRaidReducedBlock = value;
        emit ChangeMaidPowerToRaidReducedBlock(value);
    }

    function setMaidCafe(IMaidCafe _maidCafe) external onlyOwner {
        maidCafe = _maidCafe;
    }

    function approveMaids(IMaids maids) external onlyOwner {
        maidsApproved[maids] = true;
    }

    function disapproveMaids(IMaids maids) external onlyOwner {
        maidsApproved[maids] = false;
    }

    modifier onlyApprovedMaids(IMaids maids) {
        require(address(maids) == address(0) || maidsApproved[maids], "NurseRaid: The maids is not approved.");
        _;
    }

    function changeRNG(address addr) external onlyOwner {
        rng = IRNG(addr);
    }

    function raidCount() external view override returns (uint256) {
        return raids.length;
    }

    function create(
        uint256 entranceFee,
        uint256 _nursePart,
        uint256 maxRewardCount,
        uint256 duration,
        uint256 endBlock
    ) external override onlyOwner returns (uint256 id) {
        require(maxRewardCount < 255, "NurseRaid: Invalid number");
        id = raids.length;
        raids.push(
            Raid({
                entranceFee: entranceFee,
                nursePart: _nursePart,
                maxRewardCount: maxRewardCount,
                duration: duration,
                endBlock: endBlock
            })
        );
        emit Create(id, entranceFee, _nursePart, maxRewardCount, duration, endBlock);
    }

    function enterWithPermitAll(
        uint256 id,
        IMaids maids,
        uint256 maidId,
        uint256 deadline,
        uint8 v1,
        bytes32 r1,
        bytes32 s1,
        uint8 v2,
        bytes32 r2,
        bytes32 s2
    ) external override {
        maidCoin.permit(msg.sender, address(this), type(uint256).max, deadline, v1, r1, s1);
        maids.permitAll(msg.sender, address(this), deadline, v2, r2, s2);
        enter(id, maids, maidId);
    }

    function enter(
        uint256 id,
        IMaids maids,
        uint256 maidId
    ) public override onlyApprovedMaids(maids) {
        Raid storage raid = raids[id];
        require(block.number < raid.endBlock, "NurseRaid: Raid has ended");
        require(challengers[id][msg.sender].enterBlock == 0, "NurseRaid: Raid is in progress");
        challengers[id][msg.sender] = Challenger({enterBlock: block.number, maids: maids, maidId: maidId});
        if (address(maids) != address(0)) {
            maids.transferFrom(msg.sender, address(this), maidId);
        }
        uint256 _entranceFee = raid.entranceFee;
        maidCoin.transferFrom(msg.sender, address(this), _entranceFee);
        uint256 feeToCafe = _entranceFee * 3 / 1000;
        _feeTransfer(feeToCafe);
        maidCoin.burn(_entranceFee - feeToCafe);
        emit Enter(msg.sender, id, maids, maidId);
    }

    function checkDone(uint256 id) public view override returns (bool) {
        Raid memory raid = raids[id];
        Challenger memory challenger = challengers[id][msg.sender];

        return _checkDone(raid.duration, challenger);
    }

    function _checkDone(uint256 duration, Challenger memory challenger) internal view returns (bool) {
        if (address(challenger.maids) == address(0)) {
            return block.number - challenger.enterBlock >= duration;
        } else {
            return
                block.number -
                    challenger.enterBlock +
                    (challenger.maids.powerOf(challenger.maidId) * maidPowerToRaidReducedBlock) /
                    100 >=
                duration;
        }
    }

    function exit(uint256 id) external override {
        Challenger memory challenger = challengers[id][msg.sender];
        require(challenger.enterBlock != 0, "NurseRaid: Not participating in the raid");

        Raid storage raid = raids[id];

        if (_checkDone(raid.duration, challenger)) {
            uint256 rewardCount = _randomReward(id, raid.maxRewardCount, msg.sender);
            nursePart.mint(msg.sender, raid.nursePart, rewardCount);
        }

        if (address(challenger.maids) != address(0)) {
            challenger.maids.transferFrom(address(this), msg.sender, challenger.maidId);
        }

        delete challengers[id][msg.sender];

        emit Exit(msg.sender, id);
    }

    function _randomReward(
        uint256 _id,
        uint256 _maxRewardCount,
        address sender
    ) internal returns (uint256 rewardCount) {
        uint256 totalNumber = 2 * (2**_maxRewardCount - 1);
        uint256 randomNumber = (rng.generateRandomNumber(_id, sender) % totalNumber) + 1;

        uint256 ceil;
        uint256 i = 0;

        while (randomNumber > ceil) {
            i += 1;
            ceil = (2**(_maxRewardCount + 1)) - (2**(_maxRewardCount + 1 - i));
        }

        rewardCount = i;
    }

    function _feeTransfer(uint256 feeToCafe) internal {
        maidCoin.transfer(address(maidCafe), feeToCafe);
    }
}
