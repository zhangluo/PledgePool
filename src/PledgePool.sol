// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract PledgePool {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // 事件定义
    event DepositLend(address indexed user, uint256 amount, uint256 poolId);
    event RefundLend(address indexed user, uint256 amount, uint256 interest, uint256 poolId);
    event ClaimLend(address indexed user, uint256 interest, uint256 poolId);
    event DepositBorrow(address indexed user, uint256 amount, uint256 poolId);
    event RefundBorrow(address indexed user, uint256 amount, uint256 poolId);
    event WithdrawLend(address indexed user, uint256 amount, uint256 poolId);
    event WithdrawBorrow(address indexed user, uint256 amount, uint256 poolId);
    event FeeManagement(uint256 poolId, uint256 fee);
    event Pause();
    event Unpause();

    // 借贷池结构体
    struct Pool {
        uint256 id;
        uint256 interestRate; // 利率，以1e18为单位表示
        uint256 feeRate; // 费用率，以1e18为单位表示
        uint256 maxLend; // 最大贷款金额
        uint256 maxBorrow; // 最大借款金额
        uint256 totalLend;
        uint256 totalBorrow;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
    }

    // 用户结构体
    struct User {
        uint256 lendAmount;
        uint256 borrowAmount;
        uint256 depositTime; // 存款时间
    }

    // 状态变量
    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(uint256 => User)) public users;
    uint256 public nextPoolId;
    address public admin;
    IERC20 public token;
    bool public paused;

    // 构造函数
    constructor(address _token) {
        admin = msg.sender;
        token = IERC20(_token); // 将 address 类型的参数转换为 IERC20
        paused = false;
    }

    // 修饰符
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    // 暂停合约
    function pause() external onlyAdmin {
        paused = true;
        emit Pause();
    }

    // 恢复合约
    function unpause() external onlyAdmin {
        paused = false;
        emit Unpause();
    }

    // 创建新的借贷池
    function createPool(uint256 interestRate, uint256 feeRate, uint256 maxLend, uint256 maxBorrow, uint256 startTime, uint256 endTime) external onlyAdmin {
        require(startTime < endTime, "Start time must be before end time");
        if (interestRate == 0) interestRate = 1e18; // 设置默认值
        if (feeRate == 0) feeRate = 1e18; // 设置默认值

        pools[nextPoolId] = Pool(nextPoolId, interestRate, feeRate, maxLend, maxBorrow, 0, 0, startTime, endTime, true);
        nextPoolId++;
    }

    // 贷款操作
    function depositLend(uint256 poolId, uint256 amount) external whenNotPaused {
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool is not active");
        require(block.timestamp >= pool.startTime && block.timestamp <= pool.endTime, "Pool is not in active period");
        require(pool.totalLend + amount <= pool.maxLend, "Exceeds maximum lend amount");

        uint256 fee = amount * pool.feeRate / 1e18;
        uint256 netAmount = amount - fee;

        // 将费用转移到管理员账户
        token.safeTransferFrom(msg.sender, admin, fee);

        // 将净额转移到合约中
        token.safeTransferFrom(msg.sender, address(this), netAmount);

        users[msg.sender][poolId].lendAmount += netAmount;
        users[msg.sender][poolId].depositTime = block.timestamp;
        pool.totalLend += netAmount;

        emit DepositLend(msg.sender, netAmount, poolId);
        emit FeeManagement(poolId, fee);
    }

    // 还款操作
    function refundLend(uint256 poolId, uint256 amount) external whenNotPaused {
        Pool storage pool = pools[poolId];
        User storage user = users[msg.sender][poolId];
        require(user.lendAmount >= amount, "Insufficient lend amount");

        uint256 interest = user.lendAmount * pool.interestRate / 1e18; // 按固定利率计算

        require(amount >= interest, "Amount is less than the interest");
        uint256 principalAmount = amount - interest;

        user.lendAmount -= principalAmount;

        // 将利息和本金转移到合约中
        token.safeTransferFrom(msg.sender, address(this), interest);
        token.safeTransferFrom(msg.sender, address(this), principalAmount);

        emit RefundLend(msg.sender, principalAmount, interest, poolId);
    }

    // 借款操作
    function depositBorrow(uint256 poolId, uint256 amount) external whenNotPaused {
        Pool storage pool = pools[poolId];
        require(pool.isActive, "Pool is not active");
        require(block.timestamp >= pool.startTime && block.timestamp <= pool.endTime, "Pool is not in active period");
        require(pool.totalBorrow + amount <= pool.maxBorrow, "Exceeds maximum borrow amount");

        uint256 fee = amount * pool.feeRate / 1e18;
        uint256 netAmount = amount - fee;

        // 将费用转移到管理员账户
        token.safeTransferFrom(msg.sender, admin, fee);

        // 将净额转移到用户
        token.safeTransfer(msg.sender, netAmount);

        users[msg.sender][poolId].borrowAmount += netAmount;
        pool.totalBorrow += netAmount;

        emit DepositBorrow(msg.sender, netAmount, poolId);
        emit FeeManagement(poolId, fee);
    }

    // 还款操作
    function refundBorrow(uint256 poolId, uint256 amount) external whenNotPaused {
        Pool storage pool = pools[poolId];
        User storage user = users[msg.sender][poolId];
        require(user.borrowAmount >= amount, "Insufficient borrow amount");

        user.borrowAmount -= amount;
        pool.totalBorrow -= amount;

        // 将还款金额转移到合约中
        token.safeTransferFrom(msg.sender, address(this), amount);

        emit RefundBorrow(msg.sender, amount, poolId);
    }

    // 提取贷款
    function withdrawLend(uint256 poolId, uint256 amount) external whenNotPaused {
        Pool storage pool = pools[poolId];
        User storage user = users[msg.sender][poolId];
        require(user.lendAmount >= amount, "Insufficient lend amount");

        user.lendAmount -= amount;

        // 将金额转移到用户
        token.safeTransfer(msg.sender, amount);

        emit WithdrawLend(msg.sender, amount, poolId);
    }

    // 提取借款
    function withdrawBorrow(uint256 poolId, uint256 amount) external whenNotPaused {
        Pool storage pool = pools[poolId];
        User storage user = users[msg.sender][poolId];
        require(user.borrowAmount >= amount, "Insufficient borrow amount");

        user.borrowAmount -= amount;

        // 将金额转移到用户
        token.safeTransfer(msg.sender, amount);

        emit WithdrawBorrow(msg.sender, amount, poolId);
    }

    // 计算利息并索取奖励
    function claimLend(uint256 poolId) external whenNotPaused {
        User storage user = users[msg.sender][poolId];
        Pool storage pool = pools[poolId];
        require(user.lendAmount > 0, "No lend amount");

        uint256 interest = user.lendAmount * pool.interestRate / 1e18; // 简化为固定利率计算
        uint256 fee = interest * pool.feeRate / 1e18;
        uint256 netInterest = interest - fee;

        user.lendAmount = 0;

        // 将净利息转移到用户
        token.safeTransfer(msg.sender, netInterest);

        emit ClaimLend(msg.sender, netInterest, poolId);
        emit FeeManagement(poolId, fee);
    }

    // 设置借贷池状态
    function setPoolStatus(uint256 poolId, bool isActive) external onlyAdmin {
        pools[poolId].isActive = isActive;
    }

    // 获取用户信息
    function getUserInfo(address user, uint256 poolId) external view returns (uint256 lendAmount, uint256 borrowAmount, uint256 depositTime) {
        User storage userInfo = users[user][poolId];
        return (userInfo.lendAmount, userInfo.borrowAmount, userInfo.depositTime);
    }

    // 获取池信息
    function getPoolInfo(uint256 poolId) external view returns (uint256 id, uint256 interestRate, uint256 feeRate, uint256 maxLend, uint256 maxBorrow, uint256 totalLend, uint256 totalBorrow, uint256 startTime, uint256 endTime, bool isActive) {
        Pool storage pool = pools[poolId];
        return (pool.id, pool.interestRate, pool.feeRate, pool.maxLend, pool.maxBorrow, pool.totalLend, pool.totalBorrow, pool.startTime, pool.endTime, pool.isActive);
    }
}
