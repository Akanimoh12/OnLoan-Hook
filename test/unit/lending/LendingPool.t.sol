// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LendingPoolState, PoolConfig, InterestRateConfig} from "../../../contracts/src/types/PoolTypes.sol";
import {Events} from "../../../contracts/src/libraries/Events.sol";
import {
    ZeroAmount,
    PoolNotActive,
    InsufficientPoolLiquidity,
    InsufficientShares,
    CooldownNotElapsed,
    NotAuthorized
} from "../../../contracts/src/types/Errors.sol";

contract LendingPoolTest is TestSetup {
    function test_deposit_mintsCorrectShares() public {
        uint256 shares = _depositToPool(lender1, 10_000e6);
        assertEq(shares, 10_000e6);
        assertEq(lendingPool.getLenderShares(poolId, lender1), 10_000e6);
    }

    function test_deposit_firstDepositor_getsOneToOneShares() public {
        uint256 shares = _depositToPool(lender1, 5000e6);
        assertEq(shares, 5000e6);
    }

    function test_deposit_secondDepositor_proRataShares() public {
        _depositToPool(lender1, 10_000e6);
        uint256 secondShares = _depositToPool(lender2, 5000e6);
        assertEq(secondShares, 5000e6);
    }

    function test_deposit_zeroAmount_reverts() public {
        vm.prank(hookAddress);
        vm.expectRevert(ZeroAmount.selector);
        lendingPool.deposit(poolId, lender1, 0);
    }

    function test_deposit_updatesPoolState() public {
        _depositToPool(lender1, 10_000e6);
        LendingPoolState memory state = lendingPool.getPoolState(poolId);
        assertEq(state.totalDeposited, 10_000e6);
        assertEq(state.totalShares, 10_000e6);
    }

    function test_deposit_mintsReceiptTokens() public {
        _depositToPool(lender1, 10_000e6);
        uint256 tokenId = receiptToken.poolIdToTokenId(poolId);
        assertEq(receiptToken.balanceOf(lender1, tokenId), 10_000e6);
    }

    function test_deposit_emitsEvent() public {
        vm.prank(hookAddress);
        vm.expectEmit(true, true, false, true);
        emit Events.LenderDeposited(poolId, lender1, 10_000e6, 10_000e6);
        lendingPool.deposit(poolId, lender1, 10_000e6);
    }

    function test_withdraw_burnsShares_returnsCorrectAmount() public {
        _depositToPool(lender1, 10_000e6);
        vm.warp(block.timestamp + 2 days);

        vm.prank(hookAddress);
        uint256 amount = lendingPool.withdraw(poolId, lender1, 5000e6);

        assertEq(amount, 5000e6);
        assertEq(lendingPool.getLenderShares(poolId, lender1), 5000e6);
    }

    function test_withdraw_insufficientShares_reverts() public {
        _depositToPool(lender1, 10_000e6);
        vm.warp(block.timestamp + 2 days);

        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(InsufficientShares.selector, 10_000e6, 20_000e6));
        lendingPool.withdraw(poolId, lender1, 20_000e6);
    }

    function test_withdraw_cooldownNotElapsed_reverts() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        vm.expectRevert();
        lendingPool.withdraw(poolId, lender1, 5000e6);
    }

    function test_withdraw_afterCooldown_succeeds() public {
        _depositToPool(lender1, 10_000e6);
        vm.warp(block.timestamp + 1 days + 1);

        vm.prank(hookAddress);
        uint256 amount = lendingPool.withdraw(poolId, lender1, 10_000e6);
        assertEq(amount, 10_000e6);
    }

    function test_withdraw_insufficientLiquidity_reverts() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 8_000e6);

        vm.warp(block.timestamp + 2 days);

        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(InsufficientPoolLiquidity.selector, 2_000e6, 10_000e6));
        lendingPool.withdraw(poolId, lender1, 10_000e6);
    }

    function test_withdraw_burnsReceiptTokens() public {
        _depositToPool(lender1, 10_000e6);
        vm.warp(block.timestamp + 2 days);

        vm.prank(hookAddress);
        lendingPool.withdraw(poolId, lender1, 5000e6);

        uint256 tokenId = receiptToken.poolIdToTokenId(poolId);
        assertEq(receiptToken.balanceOf(lender1, tokenId), 5000e6);
    }

    function test_recordBorrow_increasesTotalBorrowed() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        LendingPoolState memory state = lendingPool.getPoolState(poolId);
        assertEq(state.totalBorrowed, 5000e6);
    }

    function test_recordBorrow_insufficientLiquidity_reverts() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        vm.expectRevert(abi.encodeWithSelector(InsufficientPoolLiquidity.selector, 10_000e6, 15_000e6));
        lendingPool.recordBorrow(poolId, 15_000e6);
    }

    function test_recordBorrow_onlyHookOrAuthorized() public {
        _depositToPool(lender1, 10_000e6);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(NotAuthorized.selector);
        lendingPool.recordBorrow(poolId, 1000e6);
    }

    function test_recordRepayment_decreasesTotalBorrowed() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        vm.prank(hookAddress);
        lendingPool.recordRepayment(poolId, 3000e6, 100e6);

        LendingPoolState memory state = lendingPool.getPoolState(poolId);
        assertEq(state.totalBorrowed, 2000e6);
    }

    function test_recordRepayment_distributesInterest() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        vm.prank(hookAddress);
        lendingPool.recordRepayment(poolId, 5000e6, 500e6);

        LendingPoolState memory state = lendingPool.getPoolState(poolId);
        uint256 protocolFee = (500e6 * 1000) / 10000;
        uint256 lenderInterest = 500e6 - protocolFee;
        assertEq(state.totalDeposited, 10_000e6 + lenderInterest);
        assertEq(state.accumulatedProtocolFees, protocolFee);
    }

    function test_recordRepayment_collectsProtocolFee() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        vm.prank(hookAddress);
        lendingPool.recordRepayment(poolId, 5000e6, 1000e6);

        LendingPoolState memory state = lendingPool.getPoolState(poolId);
        assertEq(state.accumulatedProtocolFees, 100e6);
    }

    function test_getAvailableLiquidity() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 3000e6);

        assertEq(lendingPool.getAvailableLiquidity(poolId), 7000e6);
    }

    function test_getUtilizationRate() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        assertEq(lendingPool.getUtilizationRate(poolId), 5000);
    }

    function test_getCurrentInterestRate() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        uint256 rate = lendingPool.getCurrentInterestRate(poolId);
        assertGt(rate, 0);
    }

    function test_canWithdraw_beforeCooldown() public {
        _depositToPool(lender1, 10_000e6);
        assertFalse(lendingPool.canWithdraw(poolId, lender1));
    }

    function test_canWithdraw_afterCooldown() public {
        _depositToPool(lender1, 10_000e6);
        vm.warp(block.timestamp + 1 days + 1);
        assertTrue(lendingPool.canWithdraw(poolId, lender1));
    }

    function test_canWithdraw_noShares() public view {
        assertFalse(lendingPool.canWithdraw(poolId, lender1));
    }

    function test_initializePool_duplicate_reverts() public {
        PoolConfig memory config = lendingPool.getPoolConfig(poolId);
        vm.prank(hookAddress);
        vm.expectRevert();
        lendingPool.initializePool(poolId, config);
    }

    function test_initializePool_onlyHook() public {
        PoolId newPool = PoolId.wrap(bytes32(uint256(42)));
        PoolConfig memory config = lendingPool.getPoolConfig(poolId);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        lendingPool.initializePool(newPool, config);
    }

    function test_deposit_onlyHook() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        lendingPool.deposit(poolId, lender1, 1000e6);
    }

    function test_withdraw_onlyHook() public {
        _depositToPool(lender1, 10_000e6);
        vm.warp(block.timestamp + 2 days);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        lendingPool.withdraw(poolId, lender1, 5000e6);
    }

    function test_setHook_onlyOwner() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert();
        lendingPool.setHook(rando);
    }

    function test_withdraw_withAccruedInterest_returnsMore() public {
        _depositToPool(lender1, 10_000e6);

        vm.prank(hookAddress);
        lendingPool.recordBorrow(poolId, 5000e6);

        vm.prank(hookAddress);
        lendingPool.recordRepayment(poolId, 5000e6, 500e6);

        vm.warp(block.timestamp + 2 days);

        vm.prank(hookAddress);
        uint256 amount = lendingPool.withdraw(poolId, lender1, 10_000e6);

        assertGt(amount, 10_000e6);
    }
}
