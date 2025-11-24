State variables
    address public owner;
    uint256 public totalStaked;
    uint256 public rewardRate; Lock period in seconds
    uint256 public totalRewardsDistributed;
    
    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 rewardsClaimed;
        bool active;
    }
    
    mapping(address => Stake) public stakes;
    mapping(address => bool) public isStaker;
    address[] public stakers;
    
    Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier hasStake() {
        require(stakes[msg.sender].active, "No active stake found");
        _;
    }
    
    /**
     * @dev Constructor to initialize the staking contract
     * @param _rewardRate Reward rate in basis points (e.g., 100 = 1% daily)
     * @param _minStakeAmount Minimum stake amount in Wei (e.g., 100000000000000000 = 0.1 ETH)
     * @param _lockPeriod Lock period in seconds (e.g., 86400 = 1 day)
     * 
     * Example deployment values:
     * - Testing: (50, 100000000000000000, 86400) = 0.5% daily, 0.1 ETH min, 1 day lock
     * - Production: (100, 1000000000000000000, 604800) = 1% daily, 1 ETH min, 7 days lock
     */
    constructor(uint256 _rewardRate, uint256 _minStakeAmount, uint256 _lockPeriod) {
        require(_rewardRate > 0 && _rewardRate <= 10000, "Invalid reward rate");
        require(_minStakeAmount > 0, "Minimum stake must be greater than 0");
        require(_lockPeriod > 0, "Lock period must be greater than 0");
        
        owner = msg.sender;
        rewardRate = _rewardRate;
        minStakeAmount = _minStakeAmount;
        lockPeriod = _lockPeriod;
    }
    
    /**
     * @dev Function 1: Stake ETH into the contract
     */
    function stake() external payable {
        require(msg.value > 0, "Amount must be greater than zero");
        require(msg.value >= minStakeAmount, "Amount below minimum stake");
        require(!stakes[msg.sender].active, "Already have an active stake");
        
        stakes[msg.sender] = Stake({
            amount: msg.value,
            timestamp: block.timestamp,
            rewardsClaimed: 0,
            active: true
        });
        
        if (!isStaker[msg.sender]) {
            stakers.push(msg.sender);
            isStaker[msg.sender] = true;
        }
        
        totalStaked += msg.value;
        emit Staked(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Function 2: Unstake and withdraw funds with rewards
     */
    function unstake() external hasStake {
        Stake storage userStake = stakes[msg.sender];
        require(block.timestamp >= userStake.timestamp + lockPeriod, "Lock period not ended");
        
        uint256 rewards = calculateRewards(msg.sender);
        uint256 totalAmount = userStake.amount + rewards;
        
        require(address(this).balance >= totalAmount, "Insufficient contract balance");
        
        uint256 stakedAmount = userStake.amount;
        totalStaked -= stakedAmount;
        totalRewardsDistributed += rewards;
        userStake.active = false;
        
        payable(msg.sender).transfer(totalAmount);
        
        emit Unstaked(msg.sender, stakedAmount, rewards, block.timestamp);
    }
    
    /**
     * @dev Function 3: Calculate pending rewards for a staker
     * @param staker Address of the staker
     * @return Pending rewards amount
     */
    function calculateRewards(address staker) public view returns (uint256) {
        if (!stakes[staker].active) return 0;
        
        Stake memory userStake = stakes[staker];
        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 periods = stakingDuration / 1 days;
        
        uint256 totalRewards = (userStake.amount * rewardRate * periods) / 10000;
        return totalRewards - userStake.rewardsClaimed;
    }
    
    /**
     * @dev Function 4: Claim rewards without unstaking
     */
    function claimRewards() external hasStake {
        uint256 rewards = calculateRewards(msg.sender);
        require(rewards > 0, "No rewards available");
        require(address(this).balance >= rewards, "Insufficient contract balance");
        
        stakes[msg.sender].rewardsClaimed += rewards;
        totalRewardsDistributed += rewards;
        
        payable(msg.sender).transfer(rewards);
        
        emit RewardsClaimed(msg.sender, rewards, block.timestamp);
    }
    
    /**
     * @dev Function 5: Get stake details for a user
     * @param staker Address of the staker
     * @return amount Staked amount
     * @return timestamp Stake timestamp
     * @return rewardsClaimed Total rewards claimed
     * @return active Stake status
     * @return pendingRewards Pending rewards
     * @return timeUntilUnlock Seconds until unlock (0 if unlocked)
     */
    function getStakeDetails(address staker) external view returns (
        uint256 amount,
        uint256 timestamp,
        uint256 rewardsClaimed,
        bool active,
        uint256 pendingRewards,
        uint256 timeUntilUnlock
    ) {
        Stake memory userStake = stakes[staker];
        uint256 unlockTime = userStake.timestamp + lockPeriod;
        uint256 timeLeft = 0;
        
        if (block.timestamp < unlockTime) {
            timeLeft = unlockTime - block.timestamp;
        }
        
        return (
            userStake.amount,
            userStake.timestamp,
            userStake.rewardsClaimed,
            userStake.active,
            calculateRewards(staker),
            timeLeft
        );
    }
    
    /**
     * @dev Function 6: Update reward rate (only owner)
     * @param newRate New reward rate in basis points
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        require(newRate > 0 && newRate <= 10000, "Invalid reward rate");
        require(newRate <= 1000, "Rate cannot exceed 10%");
        
        uint256 oldRate = rewardRate;
        rewardRate = newRate;
        
        emit RewardRateUpdated(oldRate, newRate);
    }
    
    /**
     * @dev Function 7: Update minimum stake amount (only owner)
     * @param newAmount New minimum stake amount
     */
    function updateMinStakeAmount(uint256 newAmount) external onlyOwner {
        require(newAmount > 0, "Amount must be greater than zero");
        
        uint256 oldAmount = minStakeAmount;
        minStakeAmount = newAmount;
        
        emit MinStakeAmountUpdated(oldAmount, newAmount);
    }
    
    /**
     * @dev Function 8: Update lock period (only owner)
     * @param newPeriod New lock period in seconds
     */
    function updateLockPeriod(uint256 newPeriod) external onlyOwner {
        require(newPeriod > 0, "Period must be greater than zero");
        
        uint256 oldPeriod = lockPeriod;
        lockPeriod = newPeriod;
        
        emit LockPeriodUpdated(oldPeriod, newPeriod);
    }
    
    /**
     * @dev Function 9: Get contract statistics
     * @return _totalStaked Total amount staked
     * @return _rewardRate Current reward rate
     * @return _minStakeAmount Minimum stake requirement
     * @return _lockPeriod Lock period duration
     * @return contractBalance Contract ETH balance
     * @return activeStakers Number of active stakers
     * @return _totalRewardsDistributed Total rewards distributed
     */
    function getContractStats() external view returns (
        uint256 _totalStaked,
        uint256 _rewardRate,
        uint256 _minStakeAmount,
        uint256 _lockPeriod,
        uint256 contractBalance,
        uint256 activeStakers,
        uint256 _totalRewardsDistributed
    ) {
        uint256 _activeStakers = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakes[stakers[i]].active) {
                _activeStakers++;
            }
        }
        
        return (
            totalStaked,
            rewardRate,
            minStakeAmount,
            lockPeriod,
            address(this).balance,
            _activeStakers,
            totalRewardsDistributed
        );
    }
    
    /**
     * @dev Function 10: Transfer ownership
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        
        address previousOwner = owner;
        owner = newOwner;
        
        emit OwnershipTransferred(previousOwner, newOwner);
    }
    
    /**
     * @dev Get all active stakers
     * @return Array of active staker addresses
     */
    function getActiveStakers() external view returns (address[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakes[stakers[i]].active) {
                activeCount++;
            }
        }
        
        address[] memory activeStakersList = new address[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < stakers.length; i++) {
            if (stakes[stakers[i]].active) {
                activeStakersList[index] = stakers[i];
                index++;
            }
        }
        
        return activeStakersList;
    }
    
    /**
     * @dev Get staker info by index
     * @param stakerAddress Address of the staker
     * @return Liquidity provider balance
     */
    function getStakerBalance(address stakerAddress) external view returns (uint256) {
        return stakes[stakerAddress].amount;
    }
    
    /**
     * @dev Deposit funds for rewards pool (only owner)
     */
    function depositRewardsPool() external payable onlyOwner {
        require(msg.value > 0, "Must send ETH");
        emit RewardsDeposited(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Emergency withdraw function (only owner) - for contract upgrades or emergencies
     * @param amount Amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient balance");
        
        payable(owner).transfer(amount);
    }
    
    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        emit RewardsDeposited(msg.sender, msg.value, block.timestamp);
    }
}
// 
End
// 
