// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract UniStake is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;
    using Address for address;
    using Math for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    uint256 public constant ETH_PID = 0;

    struct Pool {
        // Address of staking token 质押代币的地址
        address stTokenAddress;
        // Weight of pool 不同资金池所占的权重
        uint256 poolWeight;
        // Last block number that UniToken distribution occurs for pool
        uint256 lastRewardBlock;
        // Accumulated UniToken per staking token of pool
        uint256 accUniTokenPerST;
        // Staking token amount
        uint256 stTokenAmount;
        // Min staking amount
        uint256 minDepositAmount;
        // Withdraw locked blocks
        uint256 unstakeLockedBlocks;
    }

    struct UnstakeRequest {
        // Request withdraw amount
        uint256 amount;
        // The blocks when the request withdraw amount can be released
        uint256 unlockBlocks;
    }

    struct User {
        // User address 用户地址
        address userAddress;
        // Staking token amount that user provided
        uint256 stAmount;
        // Finished distributed UniToken to user 最终 UniToken 得到的数量
        uint256 finishedUniToken;
        // Pending to claim UniToken 当前可取数量
        uint256 pendingUniToken;
        // Withdraw request list
        UnstakeRequest[] requests;
    }

    // First block that UniStake will start from
    uint256 public startBlock;
    // First block that UniStake will end from
    uint256 public endBlock;
    // UniToken distributed per block
    uint256 public uniTokenPerBlock;
    // Pause the withdraw function
    bool public withdrawPaused;
    // Pause the claim function
    bool public claimPaused;

    IERC20 public uniToken;

    uint256 public totalPoolWeight;
    Pool[] public pools;

    // pool id => user address => user info
    mapping(uint256 => mapping(address => User)) public user;

    // ************************************** EVENT **************************************

    event SetUniToken(IERC20 indexed uniToken);

    event PauseWithdraw();

    event UnpauseWithdraw();

    event PauseClaim();

    event UnpauseClaim();

    event SetStartBlock(uint256 indexed startBlock);

    event SetEndBlock(uint256 indexed endBlock);

    event SetUniTokenPerBlock(uint256 indexed uniTokenPerBlock);

    event AddPool(
        address indexed stTokenAddress,
        uint256 indexed poolWeight,
        uint256 indexed lastRewardBlock,
        uint256 minDepositAmount,
        uint256 unstakeLockedBlocks
    );

    event UpdatePoolInfo(
        uint256 indexed poolId,
        uint256 indexed minDepositAmount,
        uint256 indexed unstakeLockedBlocks
    );

    event SetPoolWeight(
        uint256 indexed poolId,
        uint256 indexed poolWeight,
        uint256 totalPoolWeight
    );

    event UpdatePool(
        uint256 indexed poolId,
        uint256 indexed lastRewardBlock,
        uint256 totalUniTokenPerST
    );

    event Deposit(address indexed user, uint256 indexed poolId, uint256 amount);

    event RequestUnstake(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount
    );

    event Withdraw(
        address indexed user,
        uint256 indexed poolId,
        uint256 amount,
        uint256 indexed blockNumber
    );

    event Claim(
        address indexed user,
        uint256 indexed poolId,
        uint256 uniTokenReward
    );

    // ************************************** MODIFIER **************************************

    modifier checkPID(uint256 _pid) {
        require(_pid < pools.length, "UniStake: pool not exist");
        _;
    }

    modifier whenNotClaimPaused() {
        require(!claimPaused, "UniStake: claim is paused");
        _;
    }

    modifier whenNotWithdrawPaused() {
        require(!withdrawPaused, "UniStake: withdraw is paused");
        _;
    }

    function initialize(
        IERC20 _uniToken,
        uint256 _startBlock,
        uint256 _endBlock,
        uint256 _uniTokenPerBlock
    ) public initializer {
        require(
            _startBlock < _endBlock,
            "UniStake: start block must be less than end block"
        );
        require(
            _uniTokenPerBlock > 0,
            "UniStake: uniToken per block must be greater than 0"
        );

        __AccessControl_init();
        __Pausable_init();
        __UUPSUpgradeable_init();

        startBlock = _startBlock;
        endBlock = _endBlock;
        uniTokenPerBlock = _uniTokenPerBlock;
        uniToken = _uniToken;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(UPGRADER_ROLE, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // ************************************** ADMIN FUNCTION **************************************

    function setUniToken(IERC20 _uniToken) internal onlyRole(ADMIN_ROLE) {
        uniToken = _uniToken;
        emit SetUniToken(uniToken);
    }

    function pauseWithdraw() internal onlyRole(ADMIN_ROLE) {
        withdrawPaused = true;
        emit PauseWithdraw();
    }

    function unpauseWithdraw() internal onlyRole(ADMIN_ROLE) {
        withdrawPaused = false;
        emit UnpauseWithdraw();
    }

    function pauseClaim() internal onlyRole(ADMIN_ROLE) {
        claimPaused = true;
        emit PauseClaim();
    }

    function unpauseClaim() internal onlyRole(ADMIN_ROLE) {
        claimPaused = false;
        emit UnpauseClaim();
    }

    function setStartBlock(uint256 _startBlock) internal onlyRole(ADMIN_ROLE) {
        require(
            _startBlock < endBlock,
            "UniStake: start block must be less than end block"
        );
        startBlock = _startBlock;
        emit SetStartBlock(startBlock);
    }

    function setEndBlock(uint256 _endBlock) internal onlyRole(ADMIN_ROLE) {
        require(
            startBlock < _endBlock,
            "UniStake: end block must be greater than start block"
        );
        endBlock = _endBlock;
        emit SetEndBlock(endBlock);
    }

    function setUniTokenPerBlock(
        uint256 _uniTokenPerBlock
    ) internal onlyRole(ADMIN_ROLE) {
        require(
            _uniTokenPerBlock > 0,
            "UniStake: uniToken per block must be greater than 0"
        );
        uniTokenPerBlock = _uniTokenPerBlock;
        emit SetUniTokenPerBlock(uniTokenPerBlock);
    }

    function addPool(
        address _stTokenAddress,
        uint256 _poolWeight,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks,
        bool _withUpdate
    ) public onlyRole(ADMIN_ROLE) {
        require(
            pools.length == 0 && _stTokenAddress == address(0),
            "UniStake: the first pool must be ETH"
        );
        require(
            pools.length > 0 && _stTokenAddress != address(0),
            "UniStake: the other pool must not be ETH"
        );
        require(
            _unstakeLockedBlocks > 0,
            "UniStake: unstake locked blocks must be greater than 0"
        );
        require(
            block.number < endBlock,
            "UniStake: can not add pool after end block"
        );

        if (_withUpdate) {
            massUpdatePools();
        }

        lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalPoolWeight += _poolWeight;

        pools.push(
            Pool({
                stTokenAddress: _stTokenAddress,
                poolWeight: _poolWeight,
                lastRewardBlock: lastRewardBlock,
                accUniTokenPerST: 0,
                stTokenAmount: 0,
                minDepositAmount: _minDepositAmount,
                unstakeLockedBlocks: _unstakeLockedBlocks
            })
        );

        emit AddPool(
            _stTokenAddress,
            _poolWeight,
            lastRewardBlock,
            _minDepositAmount,
            _unstakeLockedBlocks
        );
    }

    function updatePoolInfo(
        uint256 _pid,
        uint256 _minDepositAmount,
        uint256 _unstakeLockedBlocks
    ) public onlyRole(ADMIN_ROLE) checkPID {
        Pool storage pool = pools[_pid];
        pool.minDepositAmount = _minDepositAmount;
        pool.unstakeLockedBlocks = _unstakeLockedBlocks;

        emit UpdatePoolInfo(_pid, _minDepositAmount, _unstakeLockedBlocks);
    }

    function setPoolWeight(
        uint256 _pid,
        uint256 _poolWeight,
        bool withUpdate
    ) public onlyRole(ADMIN_ROLE) checkPID {
        require(
            block.number < endBlock,
            "UniStake: can not set pool weight after end block"
        );

        require(
            _poolWeight > 0,
            "UniStake: pool weight must be greater than 0"
        );

        if (withUpdate) {
            massUpdatePools();
        }

        Pool storage pool = pools[_pid];
        totalPoolWeight = totalPoolWeight - pool.poolWeight + _poolWeight;
        pool.poolWeight = _poolWeight;

        emit SetPoolWeight(_pid, _poolWeight);
    }

    // 查询函数

    function poolLength() public view returns (uint256) {
        return pools.length;
    }

    // query multiplier over the given from to to block, which will be used to calculate reward from from block to to block
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        require(
            _from <= _to,
            "UniStake: from block must be less than or equal to to block"
        );
        if (_from < startBlock) {
            _from = startBlock;
        }
        if (_to > endBlock) {
            _to = endBlock;
        }
        require(
            _from <= _to,
            "UniStake: from block must be less than or equal to to block after adjustment"
        );
        unint256 multiplier = (_to - _from) * tryMul(uniTokenPerBlock);
        return multiplier;
    }

    // query pending UniToken reward, which can be used to display pending reward for user in frontend
    function pendingUniToken(
        uint256 _pid,
        address _user
    ) public view checkPID(_pid) returns (uint256) {
        return pendingUniTokenByBlockNumber(_pid, _user, block.number);
    }

    // query pending UniToken reward by specific block number, which can be used to query pending reward at past block or future block
    function pendingUniTokenByBlockNumber(
        uint256 _pid,
        address _user,
        uint256 _blockNumber
    ) public view checkPID(_pid) returns (uint256) {
        Pool storage pool = pools[_pid];
        User storage userInfo = user[_pid][_user];
        uint256 accUniTokenPerST = pool.accUniTokenPerST;
        uint256 stAmount = userInfo.stAmount;
        if (_blockNumber > pool.lastRewardBlock && stAmount > 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                _blockNumber
            );
            uint256 uniTokenReward = (multiplier * pool.poolWeight) /
                totalPoolWeight;
            accUniTokenPerST += (uniTokenReward * 1e18) / stAmount;
        }
        return
            userInfo.pendingUniToken +
            (stAmount * accUniTokenPerST) /
            1e18 -
            userInfo.finishedUniToken;
    }

    function stakingBalance(
        uint256 _pid,
        address _user
    ) public view checkPID(_pid) returns (uint256) {
        User storage userInfo = user[_pid][_user];
        return userInfo.stAmount;
    }

    function withdrawAmount(
        uint256 _pid,
        address _user
    )
        public
        view
        checkPID(_pid)
        returns (uint256 requestAmount, uint256 pendingWithdrawAmount)
    {
        User storage userInfo = user[_pid][_user];
        uint256 totalRequestAmount = 0;
        uint256 pendingWithdrawAmount = 0;
        for (uint256 i = 0; i < userInfo.requests.length; i++) {
            UnstakeRequest storage request = userInfo.requests[i];
            totalRequestAmount += request.amount;
            if (block.number >= request.unlockBlocks) {
                pendingWithdrawAmount += request.amount;
            }
        }
        return (totalRequestAmount, pendingWithdrawAmount);
    }

    // ************************************** USER FUNCTION **************************************

    // ************************************** PUBLIC FUNCTION **************************************

    function updatePool(uint256 _pid) public checkPID(_pid) {
        if (block.number <= pools[_pid].lastRewardBlock) {
            return;
        }
        // calculate pool total reward from last reward block to current block
        Pool storage pool = pools[_pid];
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 uniTokenReward = (multiplier * pool.poolWeight) /
            totalPoolWeight;
        if (pool.stTokenAmount == 0) {
            pool.lastRewardBlock = block.number;
            emit UpdatePool(_pid, pool.lastRewardBlock, 0);
            return;
        }
        pool.accUniTokenPerST =
            pool.accUniTokenPerST +
            (uniTokenReward * 1e18) /
            pool.stTokenAmount;
        pool.lastRewardBlock = block.number;

        emit UpdatePool(_pid, pool.lastRewardBlock, uniTokenReward);
    }

    function massUpdatePools() public {
        uint256 length = pools.length;
        for (uint256 pid = 0; pid < length; pid++) {
            updatePool(pid);
        }
    }

    // ********************************* INTERNAL FUNCTION **************************************
}
