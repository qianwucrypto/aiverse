// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IClockInStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract ClockInStorage is Ownable,IClockInStorage {
    struct User {
        address[] uplines;
        address[] downlines;
        uint256 lastCheckIn;
        uint8 checkInCountToday;
        uint256 tokenRewardCount;
        uint256 pointCount;
        uint256 totalPointsClaimed;
        uint256 checkInTotalCount;
        mapping(uint256 => bool) claimedTiers;
        uint256 claimedExtraTiers;
        uint8 dailyCheckInCount;
        uint256 lastCheckInDay;
    }

    mapping(address => User) private users;
    mapping(address => bool) private registered;
    uint256 public override registeredCount;

    uint256 private totalCheckInCount;
    uint256 private totalTokenDistributed;
    uint256 private totalPointDistributed;

    address public logic;

    modifier onlyLogic() {
        require(msg.sender == logic, "Not authorized");
        _;
    }

    constructor() Ownable(msg.sender){}

    function setLogic(address _logic) external onlyOwner {
        // require(msg.sender == logic, "Only current logic can update");
        logic = _logic;
    }

    function isRegistered(address user) external view override returns (bool) {
        return registered[user];
    }

    function registerUser(address user, address referrer) external override onlyLogic {
        require(!registered[user], "Already registered");
        registered[user] = true;
        if (referrer != address(0)) {
            users[referrer].downlines.push(user);
            users[user].uplines.push(referrer);
            address current = referrer;
            for (uint i = 1; i < 10; i++) {
                if (users[current].uplines.length == 0) break;
                current = users[current].uplines[0];
                users[user].uplines.push(current);
            }
        }
    }

    function incrementRegisteredCount() external override onlyLogic {
        registeredCount++;
    }

    function getUser(address user) external view override returns (BasicUser memory) {
        User storage u = users[user];
        return BasicUser({
            uplines: u.uplines,
            downlines: u.downlines,
            lastCheckIn: u.lastCheckIn,
            checkInCountToday: u.checkInCountToday,
            tokenRewardCount: u.tokenRewardCount,
            pointCount: u.pointCount,
            totalPointsClaimed: u.totalPointsClaimed,
            checkInTotalCount: u.checkInTotalCount,
            claimedExtraTiers: u.claimedExtraTiers,
            dailyCheckInCount: u.dailyCheckInCount,
            lastCheckInDay: u.lastCheckInDay
        });
    }

    function updateUser(address user, BasicUser calldata data) external override onlyLogic {
        User storage u = users[user];
        u.lastCheckIn = data.lastCheckIn;
        u.checkInCountToday = data.checkInCountToday;
        u.tokenRewardCount = data.tokenRewardCount;
        u.pointCount = data.pointCount;
        u.totalPointsClaimed = data.totalPointsClaimed;
        u.checkInTotalCount = data.checkInTotalCount;
        u.claimedExtraTiers = data.claimedExtraTiers;
        u.dailyCheckInCount = data.dailyCheckInCount;
        u.lastCheckInDay = data.lastCheckInDay;
    }

    function setClaimedTier(address user, uint256 tier) external override onlyLogic {
        users[user].claimedTiers[tier] = true;
    }

    function hasClaimedTier(address user, uint256 tier) external view override returns (bool) {
        return users[user].claimedTiers[tier];
    }

    function getUplines(address user) external view override returns (address[] memory) {
        return users[user].uplines;
    }

    function getDownlines(address user) external view override returns (address[] memory) {
        return users[user].downlines;
    }

    function incrementClaimedExtraTiers(address user, uint256 count) external override onlyLogic {
        users[user].claimedExtraTiers += count;
    }

    function getGlobalStats() external view override returns (
        uint256 checkInCount,
        uint256 tokenDistributed,
        uint256 pointDistributed
    ) {
        return (totalCheckInCount, totalTokenDistributed, totalPointDistributed);
    }

    function incrementCheckInCount() external override onlyLogic {
        totalCheckInCount++;
    }

    function addTokenDistributed(uint256 amount) external override onlyLogic {
        totalTokenDistributed += amount;
    }

    function addPointDistributed(uint256 amount) external override onlyLogic {
        totalPointDistributed += amount;
    }
}
