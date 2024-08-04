// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/PledgePool.sol";

// 模拟 ERC20 代币合约
contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PledgePoolTest is Test {
    PledgePool public pledgePool;
    ERC20Mock public token;
    address public admin;
    address public user1;
    address public user2;

    function setUp() public {
        // 设置账户
        admin = address(this);
        user1 = address(0x123);
        user2 = address(0x456);

        // 部署 ERC20 代币合约
        token = new ERC20Mock("MockToken", "MTK");
        token.mint(admin, 1e24); // 初始代币分配给 admin

        // 部署 PledgePool 合约
        pledgePool = new PledgePool(address(token));

        // 预先将一些代币分配给用户
        token.transfer(user1, 1e18);
        token.transfer(user2, 1e18);
    }

    function testCreatePool() public {
        uint256 startTime = block.timestamp + 1000; // 当前时间 + 1000秒
        uint256 endTime = startTime + 3600; // 1小时后

        pledgePool.createPool(1e16, 1e16, 1e18, 1e18, startTime, endTime);

        (uint256 id, uint256 interestRate, uint256 feeRate, uint256 maxLend, uint256 maxBorrow, uint256 totalLend, uint256 totalBorrow, uint256 poolStartTime, uint256 poolEndTime, bool isActive) = pledgePool.getPoolInfo(0);

        assertEq(interestRate, 1e16);
        assertEq(feeRate, 1e16);
        assertEq(maxLend, 1e18);
        assertEq(maxBorrow, 1e18);
        assertEq(poolStartTime, startTime);
        assertEq(poolEndTime, endTime);
        assertTrue(isActive);
    }

    function testDepositLend() public {
        uint256 startTime = block.timestamp + 1000; // 当前时间 + 1000秒
        uint256 endTime = startTime + 3600; // 1小时后

        pledgePool.createPool(1e16, 1e16, 1e18, 1e18, startTime, endTime);

        vm.startPrank(user1);
        token.approve(address(pledgePool), 1e18);
        pledgePool.depositLend(0, 1e18);

        (uint256 lendAmount, uint256 borrowAmount, uint256 depositTime) = pledgePool.getUserInfo(user1, 0);
        assertEq(lendAmount, 1e18);

        vm.stopPrank();
    }

    function testRefundLend() public {
        uint256 startTime = block.timestamp + 1000; // 当前时间 + 1000秒
        uint256 endTime = startTime + 3600; // 1小时后

        pledgePool.createPool(1e16, 1e16, 1e18, 1e18, startTime, endTime);

        vm.startPrank(user1);
        token.approve(address(pledgePool), 1e18);
        pledgePool.depositLend(0, 1e18);

        token.approve(address(pledgePool), 1e18);
        pledgePool.refundLend(0, 1e18);

        (uint256 lendAmount, uint256 borrowAmount, uint256 depositTime) = pledgePool.getUserInfo(user1, 0);
        assertEq(lendAmount, 0);

        vm.stopPrank();
    }

    function testDepositBorrow() public {
        uint256 startTime = block.timestamp + 1000; // 当前时间 + 1000秒
        uint256 endTime = startTime + 3600; // 1小时后

        pledgePool.createPool(1e16, 1e16, 1e18, 1e18, startTime, endTime);

        vm.startPrank(user1);
        token.approve(address(pledgePool), 1e18);
        pledgePool.depositBorrow(0, 1e18);

        (uint256 lendAmount, uint256 borrowAmount, uint256 depositTime) = pledgePool.getUserInfo(user1, 0);
        assertEq(borrowAmount, 1e18);

        vm.stopPrank();
    }

    function testRefundBorrow() public {
        uint256 startTime = block.timestamp + 1000; // 当前时间 + 1000秒
        uint256 endTime = startTime + 3600; // 1小时后

        pledgePool.createPool(1e16, 1e16, 1e18, 1e18, startTime, endTime);

        vm.startPrank(user1);
        token.approve(address(pledgePool), 1e18);
        pledgePool.depositBorrow(0, 1e18);

        token.approve(address(pledgePool), 1e18);
        pledgePool.refundBorrow(0, 1e18);

        (uint256 lendAmount, uint256 borrowAmount, uint256 depositTime) = pledgePool.getUserInfo(user1, 0);
        assertEq(borrowAmount, 0);

        vm.stopPrank();
    }
}
