------------------------------------------------
    ------------------------------------------------
    struct Validator {
        address addr;              total stake by validator
        bool active;               token people stake
    IERC20 public rewardToken;     accumulated reward per staked token (scaled)
    uint256 public constant PRECISION = 1e18;

    mapping(address => uint256) public stakeOf;
    mapping(address => uint256) public rewardDebt;

    mapping(address => Validator) public validators;
    address[] public validatorList;

    uint256 public unstakeCooldownBlocks = 1000; ------------------------------------------------
    ------------------------------------------------
    event Staked(address indexed user, uint256 amount);
    event UnstakeRequested(address indexed user, uint256 amount, uint256 requestBlock);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPoolFunded(address indexed funder, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event ValidatorRegistered(address indexed validator);
    event ValidatorDeregistered(address indexed validator);
    event ValidatorSlashed(address indexed validator, uint256 amount);

    MODIFIERS
    ------------------------------------------------
    ------------------------------------------------
    constructor(address _collateralToken, address _rewardToken) {
        owner = msg.sender;
        collateralToken = IERC20(_collateralToken);
        rewardToken = IERC20(_rewardToken);
    }

    STAKING & REWARD LOGIC
    update reward debt
        rewardDebt[msg.sender] = (stakeOf[msg.sender] * rewardPerStakeStored) / PRECISION;

        emit Staked(msg.sender, amount);
    }

    function requestUnstake(uint256 amount) external {
        require(stakeOf[msg.sender] >= amount, "Too much unstake");

        unstakeRequestBlock[msg.sender] = block.number;
        unstakeRequestedAmount[msg.sender] = amount;

        emit UnstakeRequested(msg.sender, amount, block.number);
    }

    function withdrawUnstaked() external {
        uint256 reqBlock = unstakeRequestBlock[msg.sender];
        uint256 amount = unstakeRequestedAmount[msg.sender];
        require(amount > 0, "No pending unstake");
        require(block.number >= reqBlock + unstakeCooldownBlocks, "Cooldown not passed");

        _updateRewards();
        _claimReward(msg.sender);

        stakeOf[msg.sender] -= amount;
        totalStaked -= amount;

        unstakeRequestedAmount[msg.sender] = 0;
        unstakeRequestBlock[msg.sender] = 0;

        collateralToken.transfer(msg.sender, amount);

        emit Unstaked(msg.sender, amount);
    }

    function fundRewardPool(uint256 amount) external {
        require(amount > 0, "Zero fund");
        rewardToken.transferFrom(msg.sender, address(this), amount);
        Just emit event
        emit RewardPoolFunded(msg.sender, amount);
    }

    function claimReward() external {
        _updateRewards();
        _claimReward(msg.sender);
    }

    function _claimReward(address user) internal {
        uint256 acc = (stakeOf[user] * rewardPerStakeStored) / PRECISION;
        uint256 debt = rewardDebt[user];
        if (acc <= debt) return;

        uint256 payout = acc - debt;
        rewardDebt[user] = acc;
        rewardToken.transfer(user, payout);

        emit RewardClaimed(user, payout);
    }

    function _updateRewards() internal {
        uint256 bal = rewardToken.balanceOf(address(this));
        if (totalStaked == 0 || bal == 0) return;
        over all stakes. In production, you'd have more controlled emission logic.
        rewardPerStakeStored += (bal * PRECISION) / totalStaked;
    }

    VALIDATOR REGISTRY & SLASHING
    Note: does not auto-withdraw stake ? stake remains for user
        emit ValidatorDeregistered(validatorAddr);
    }

    /Update global rewards before changing stake
        _updateRewards();
        _claimReward(validatorAddr);

        stakeOf[validatorAddr] -= slashAmount;
        totalStaked -= slashAmount;
        v.stakeAmount = stakeOf[validatorAddr];

        ------------------------------------------------
    ------------------------------------------------
    function pendingReward(address user) external view returns (uint256) {
        uint256 stored = rewardPerStakeStored;
        uint256 bal = rewardToken.balanceOf(address(this));
        if (totalStaked > 0 && bal > 0) {
            stored += (bal * PRECISION) / totalStaked;
        }
        uint256 acc = (stakeOf[user] * stored) / PRECISION;
        uint256 debt = rewardDebt[user];
        return (acc > debt ? acc - debt : 0);
    }

    function getValidatorList() external view returns (address[] memory) {
        return validatorList;
    }

    ADMIN
    // ------------------------------------------------
    function updateUnstakeCooldown(uint256 blocks) external onlyOwner {
        unstakeCooldownBlocks = blocks;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}
// 
Contract End
// 
