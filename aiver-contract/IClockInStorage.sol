// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IClockInStorage {
    struct BasicUser {
        address[] uplines;
        address[] downlines;
        uint256 lastCheckIn;
        uint8 checkInCountToday;
        uint256 tokenRewardCount;
        uint256 pointCount;
        uint256 totalPointsClaimed;
        uint256 checkInTotalCount;
        uint256 claimedExtraTiers;
        uint8 dailyCheckInCount;
        uint256 lastCheckInDay;
        uint256 pendingTokenRewards;
    }

    function isRegistered(address user) external view returns (bool);
    function registerUser(address user, address referrer) external;
    function getUser(address user) external view returns (BasicUser memory);
    function updateUser(address user, BasicUser calldata data) external;
    function updateUserRewards(address user, uint256 pointCount, uint256 pendingTokenRewards) external;
    function claimUplineRewards(address user, uint256 amount) external;
    function incrementRegisteredCount() external;
    function setClaimedTier(address user, uint256 tier) external;
    function hasClaimedTier(address user, uint256 tier) external view returns (bool);
    function getUplines(address user) external view returns (address[] memory);
    function getDownlines(address user) external view returns (address[] memory);
    function incrementClaimedExtraTiers(address user, uint256 count) external;

    function getGlobalStats() external view returns (
        uint256 checkInCount,
        uint256 tokenDistributed,
        uint256 pointDistributed
    );
    function incrementCheckInCount() external;
    function addTokenDistributed(uint256 amount) external;
    function addPointDistributed(uint256 amount) external;

    function registeredCount() external view returns (uint256);
}