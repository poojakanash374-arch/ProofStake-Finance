// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title ProofStake Finance
 * @notice A decentralized ETH staking & reward distribution protocol
 * @dev Users stake ETH and earn rewards. Owner can inject rewards manually.
 */

contract ProofStakeFinance {
    struct StakeInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => StakeInfo) public stakes;
    address public owner;

    uint256 public totalStaked;
    uint256 public accRewardPerShare; // Accumulated rewards per ETH staked (1e12 precision)

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount, uint256 reward);
    event RewardsAdded(uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    // ⭐ STAKE ETH
    // ─────────────────────────────────────────────
    function stake() external payable {
        require(msg.value > 0, "Stake amount required");

        StakeInfo storage user = stakes[msg.sender];

        // Pending rewards calculation
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
            payable(msg.sender).transfer(pending);
        }

        totalStaked += msg.value;
        user.amount += msg.value;

        // Update reward debt
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;

        emit Staked(msg.sender, msg.value);
    }

    // ─────────────────────────────────────────────
    // ⭐ WITHDRAW (UNSTAKE) + CLAIM REWARDS
    // ─────────────────────────────────────────────
    function unstake(uint256 amount) external {
        StakeInfo storage user = stakes[msg.sender];
        require(user.amount >= amount, "Not enough staked");

        // Calculate pending rewards
        uint256 pending = (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;

        // Update totals
        user.amount -= amount;
        totalStaked -= amount;

        // Update reward debt
        user.rewardDebt = (user.amount * accRewardPerShare) / 1e12;

        // Transfer staked amount + rewards
        payable(msg.sender).transfer(amount + pending);

        emit Unstaked(msg.sender, amount, pending);
    }

    // ─────────────────────────────────────────────
    // ⭐ ADD REWARDS TO THE POOL (OWNER ONLY)
    // ─────────────────────────────────────────────
    function addRewards() external payable onlyOwner {
        require(msg.value > 0, "No rewards added");
        require(totalStaked > 0, "No staking yet");

        // Increase reward per share
        accRewardPerShare += (msg.value * 1e12) / totalStaked;

        emit RewardsAdded(msg.value);
    }

    // ─────────────────────────────────────────────
    // ⭐ VIEW FUNCTIONS
    // ─────────────────────────────────────────────
    function pendingRewards(address userAddr) external view returns (uint256) {
        StakeInfo memory user = stakes[userAddr];
        uint256 tempAcc = accRewardPerShare;

        // If owner added rewards but not yet updated
        if (totalStaked > 0) {
            // No pending reward logic here because addRewards updates immediately
        }

        return (user.amount * tempAcc) / 1e12 - user.rewardDebt;
    }

    function contractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
