// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IClockInStorage.sol";

contract ClockInSystem is Ownable, Pausable {
    uint256 public checkInCost = 0.0004 ether;
    uint256 public constant COOLDOWN = 4 hours;

    IERC20 public rewardToken;
    IERC20 public usdtToken;
    IClockInStorage public storageContract;

    uint256[] public rewardTiers = [100, 500, 2000, 10000, 30000, 50000, 100000, 300000, 500000, 1000000];
    mapping(uint256 => uint256) public tierToUSDT;
    mapping(uint256 => uint256) public tierToTokens;

    event Registered(address indexed user, address indexed referrer);
    event CheckedIn(address indexed user, uint256 tokens);
    event PointsClaimed(address indexed user, uint256 usdt, uint256 tokens);
    event ETHWithdrawn(address to, uint256 amount);

    constructor(address _rewardToken, address _usdtToken, address _storage) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
        usdtToken = IERC20(_usdtToken);
        storageContract = IClockInStorage(_storage);
        initRewardTable();
    }

    receive() external payable {}

    modifier onlyRegistered() {
        require(storageContract.isRegistered(msg.sender), "Not registered");
        _;
    }

    function setCheckInCost(uint256 newCost) external onlyOwner {
        require(newCost <= 0.01 ether, "Too high");
        checkInCost = newCost;
    }

    function initRewardTable() internal {
        tierToUSDT[100] = 1;
        tierToTokens[100] = 1000;
        tierToUSDT[500] = 5;
        tierToTokens[500] = 10000;
        tierToUSDT[2000] = 20;
        tierToTokens[2000] = 20000;
        tierToUSDT[10000] = 100;
        tierToTokens[10000] = 100000;
        tierToUSDT[30000] = 200;
        tierToTokens[30000] = 200000;
        tierToUSDT[50000] = 300;
        tierToTokens[50000] = 500000;
        tierToUSDT[100000] = 500;
        tierToTokens[100000] = 1000000;
        tierToUSDT[300000] = 2000;
        tierToTokens[300000] = 3000000;
        tierToUSDT[500000] = 2000;
        tierToTokens[500000] = 5000000;
        tierToUSDT[1000000] = 10000;
        tierToTokens[1000000] = 10000000;
    }

    function register(address referrer) external {
        require(!storageContract.isRegistered(msg.sender), "Already registered");
        require(referrer != msg.sender, "Cannot refer yourself");
        if (referrer != address(0)) {
            require(storageContract.isRegistered(referrer), "Invalid referrer");
        }
        storageContract.registerUser(msg.sender, referrer);
        storageContract.incrementRegisteredCount();
        emit Registered(msg.sender, referrer);
    }

    function isConsecutiveDay(uint256 last, uint256 current) internal pure returns (bool) {
        uint256 lastLocalDay = (last + 8 hours) / 1 days;
        uint256 currentLocalDay = (current + 8 hours) / 1 days;
        return currentLocalDay == lastLocalDay || currentLocalDay == lastLocalDay + 1;
    }

    function checkIn() external payable onlyRegistered whenNotPaused {
        require(msg.value == checkInCost, "Incorrect ETH amount");

        IClockInStorage.BasicUser memory user = storageContract.getUser(msg.sender);

        uint256 today = (block.timestamp + 8 hours) / 1 days;

        if (user.lastCheckInDay < today) {
            user.dailyCheckInCount = 0;
            user.lastCheckInDay = today;
        }

        require(user.dailyCheckInCount < 2, "Exceeded daily check-in limit");
        require(block.timestamp >= user.lastCheckIn + COOLDOWN, "Cooldown not finished");
        user.dailyCheckInCount++;

        if (!isConsecutiveDay(user.lastCheckIn, block.timestamp)) {
            user.checkInCountToday = 1;
        } else {
            user.checkInCountToday++;
        }

        user.lastCheckIn = block.timestamp;
        user.checkInTotalCount++;
        storageContract.incrementCheckInCount();

        uint256 tokenReward = 5000 + (user.checkInCountToday - 1) * 500;
        if (tokenReward > 10000) tokenReward = 10000;

        tokenReward = tokenReward;

        user.tokenRewardCount += tokenReward;
        storageContract.addTokenDistributed(tokenReward);

        require( rewardToken.balanceOf(address(this)) >= tokenReward,  "balance is lower than required");

        rewardToken.transfer(msg.sender, tokenReward * 1e6);

        address[] memory uplines = storageContract.getUplines(msg.sender);
        uint256[10] memory tokenPercents = [uint256(30), 20, 5, 5, 5, 5, 5, 5, 5, 5];
        uint256[10] memory pointRewards = [uint256(7), 5, 1, 1, 1, 1, 1, 1, 1, 1];

        for (uint i = 0; i < uplines.length && i < 10; i++) {
            address upline = uplines[i];
            IClockInStorage.BasicUser memory uplineUser = storageContract.getUser(upline);
            uint256 share = (tokenReward * tokenPercents[i]) / 100;
            uplineUser.tokenRewardCount += share;
            uplineUser.pointCount += pointRewards[i];
            storageContract.updateUser(upline, uplineUser);
            storageContract.addTokenDistributed(share);
            storageContract.addPointDistributed(pointRewards[i]);
            // rewardToken.transfer(upline, share * 1e6);
        }

        storageContract.updateUser(msg.sender, user);
        emit CheckedIn(msg.sender, tokenReward);
    }

    //查询用户可领取的奖励 - 新增20250710
    function calcRewards() external view returns (uint256, uint256)  {
        IClockInStorage.BasicUser memory user = storageContract.getUser(msg.sender);
        uint256 totalPoints = user.pointCount;
        uint256 totalUsdt = 0;
        uint256 totalToken = 0;

        for (uint i = 0; i < rewardTiers.length; i++) {
            uint256 tier = rewardTiers[i];
            if (totalPoints >= tier && !storageContract.hasClaimedTier(msg.sender, tier)) {
                totalUsdt += tierToUSDT[tier];
                totalToken += tierToTokens[tier];
            }
        }

        if (totalPoints > 1000000) {
            uint256 extraPoints = totalPoints - 1000000;
            uint256 availableTiers = extraPoints / 100000;
            uint256 newTiers = availableTiers - user.claimedExtraTiers;
            if (newTiers > 0) {
                totalUsdt += newTiers * 1000;
                totalToken += newTiers * 1000000;
            }
        }

        return (totalUsdt, totalToken);
    }

    function claimRewards() external onlyRegistered {
        IClockInStorage.BasicUser memory user = storageContract.getUser(msg.sender);
        uint256 totalPoints = user.pointCount;
        uint256 totalUsdt = 0;
        uint256 totalToken = 0;

        for (uint i = 0; i < rewardTiers.length; i++) {
            uint256 tier = rewardTiers[i];
            if (totalPoints >= tier && !storageContract.hasClaimedTier(msg.sender, tier)) {
                totalUsdt += tierToUSDT[tier];
                totalToken += tierToTokens[tier];
                storageContract.setClaimedTier(msg.sender, tier);
                user.totalPointsClaimed += tier;
            }
        }

        if (totalPoints > 1000000) {
            uint256 extraPoints = totalPoints - 1000000;
            uint256 availableTiers = extraPoints / 100000;
            uint256 newTiers = availableTiers - user.claimedExtraTiers;
            if (newTiers > 0) {
                storageContract.incrementClaimedExtraTiers(msg.sender, newTiers);
                totalUsdt += newTiers * 1000;
                totalToken += newTiers * 1000000;
                user.totalPointsClaimed += newTiers * 100000;
            }
        }

        require(totalUsdt > 0, "No rewards available");

        usdtToken.transfer(msg.sender, totalUsdt * 1e6);
        rewardToken.transfer(msg.sender, totalToken * 1e6);
        storageContract.addTokenDistributed(totalToken);

        storageContract.updateUser(msg.sender, user);
        emit PointsClaimed(msg.sender, totalUsdt * 1e6 , totalToken * 1e6);
    }

    function withdraw(address payable to) external onlyOwner {
        require(to != address(0), "Invalid address");

        uint256 eth = address(this).balance;
        if (eth > 0) {
            to.transfer(eth);
            emit ETHWithdrawn(to, eth);
        }

        uint256 reward = rewardToken.balanceOf(address(this));
        if (reward > 0) {
            rewardToken.transfer(to, reward);
        }

        uint256 usdt = usdtToken.balanceOf(address(this));
        if (usdt > 0) {
            usdtToken.transfer(to, usdt);
        }
    }

    function getGlobalStats() external view returns (
        uint256 totalUsers,
        uint256 totalCheckIns,
        uint256 totalTokens,
        uint256 totalPoints
    ) {
        (uint256 checkIns, uint256 tokens, uint256 points) = storageContract.getGlobalStats();
        return (storageContract.registeredCount(), checkIns, tokens, points);
    }
}
