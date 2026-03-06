// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {CollateralInfo} from "../../../contracts/src/types/LoanTypes.sol";
import {Events} from "../../../contracts/src/libraries/Events.sol";
import {
    UnsupportedCollateral,
    ZeroAmount,
    InsufficientCollateral,
    NotAuthorized
} from "../../../contracts/src/types/Errors.sol";

contract CollateralManagerTest is TestSetup {
    function test_depositCollateral_updatesBalance() public {
        _depositCollateral(borrower1, address(weth), 5 ether);
        assertEq(collateralManager.collateralBalances(borrower1, address(weth)), 5 ether);
    }

    function test_depositCollateral_transfersTokens() public {
        uint256 balBefore = weth.balanceOf(address(collateralManager));
        _depositCollateral(borrower1, address(weth), 5 ether);
        uint256 balAfter = weth.balanceOf(address(collateralManager));
        assertEq(balAfter - balBefore, 5 ether);
    }

    function test_depositCollateral_emitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Events.CollateralDeposited(borrower1, address(weth), 5 ether);
        _depositCollateral(borrower1, address(weth), 5 ether);
    }

    function test_depositCollateral_unsupported_reverts() public {
        address fakeToken = makeAddr("fake");
        vm.prank(borrower1);
        vm.expectRevert(abi.encodeWithSelector(UnsupportedCollateral.selector, fakeToken));
        collateralManager.depositCollateral(borrower1, fakeToken, 1 ether);
    }

    function test_depositCollateral_zeroAmount_reverts() public {
        vm.prank(borrower1);
        vm.expectRevert(ZeroAmount.selector);
        collateralManager.depositCollateral(borrower1, address(weth), 0);
    }

    function test_withdrawCollateral_onlyUnlocked() public {
        _depositCollateral(borrower1, address(weth), 10 ether);

        collateralManager.setAuthorized(address(this), true);
        collateralManager.lockCollateral(borrower1, address(weth), 6 ether);

        vm.prank(borrower1);
        collateralManager.withdrawCollateral(borrower1, address(weth), 4 ether);

        assertEq(collateralManager.collateralBalances(borrower1, address(weth)), 6 ether);
    }

    function test_withdrawCollateral_lockedCollateral_reverts() public {
        _depositCollateral(borrower1, address(weth), 10 ether);

        collateralManager.setAuthorized(address(this), true);
        collateralManager.lockCollateral(borrower1, address(weth), 10 ether);

        vm.prank(borrower1);
        vm.expectRevert(abi.encodeWithSelector(InsufficientCollateral.selector, 0, 1 ether));
        collateralManager.withdrawCollateral(borrower1, address(weth), 1 ether);
    }

    function test_withdrawCollateral_zeroAmount_reverts() public {
        vm.prank(borrower1);
        vm.expectRevert(ZeroAmount.selector);
        collateralManager.withdrawCollateral(borrower1, address(weth), 0);
    }

    function test_lockCollateral_updatesLockedBalance() public {
        _depositCollateral(borrower1, address(weth), 10 ether);

        collateralManager.setAuthorized(address(this), true);
        collateralManager.lockCollateral(borrower1, address(weth), 5 ether);

        assertEq(collateralManager.lockedCollateral(borrower1, address(weth)), 5 ether);
    }

    function test_lockCollateral_insufficientAvailable_reverts() public {
        _depositCollateral(borrower1, address(weth), 5 ether);

        collateralManager.setAuthorized(address(this), true);
        vm.expectRevert(abi.encodeWithSelector(InsufficientCollateral.selector, 5 ether, 10 ether));
        collateralManager.lockCollateral(borrower1, address(weth), 10 ether);
    }

    function test_lockCollateral_onlyAuthorized() public {
        _depositCollateral(borrower1, address(weth), 5 ether);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(NotAuthorized.selector);
        collateralManager.lockCollateral(borrower1, address(weth), 1 ether);
    }

    function test_unlockCollateral_updatesLockedBalance() public {
        _depositCollateral(borrower1, address(weth), 10 ether);

        collateralManager.setAuthorized(address(this), true);
        collateralManager.lockCollateral(borrower1, address(weth), 10 ether);
        collateralManager.unlockCollateral(borrower1, address(weth), 5 ether);

        assertEq(collateralManager.lockedCollateral(borrower1, address(weth)), 5 ether);
    }

    function test_seizeCollateral_removesFromLocked() public {
        _depositCollateral(borrower1, address(weth), 10 ether);

        collateralManager.setAuthorized(address(this), true);
        collateralManager.lockCollateral(borrower1, address(weth), 10 ether);
        collateralManager.seizeCollateral(borrower1, address(weth), 10 ether);

        assertEq(collateralManager.collateralBalances(borrower1, address(weth)), 0);
        assertEq(collateralManager.lockedCollateral(borrower1, address(weth)), 0);
    }

    function test_getCollateralValueUSD_correctCalculation() public {
        _depositCollateral(borrower1, address(weth), 5 ether);
        uint256 value = collateralManager.getCollateralValueUSD(borrower1, address(weth));
        assertEq(value, 15000e18);
    }

    function test_getTotalCollateralValueUSD() public {
        _depositCollateral(borrower1, address(weth), 5 ether);
        uint256 total = collateralManager.getTotalCollateralValueUSD(borrower1);
        assertEq(total, 15000e18);
    }

    function test_isCollateralSufficient_atExactLTV() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        uint256 maxBorrow = (10 * 3000e18 * 7500) / 10000;
        assertTrue(collateralManager.isCollateralSufficient(borrower1, address(weth), maxBorrow));
    }

    function test_isCollateralSufficient_aboveLTV() public {
        _depositCollateral(borrower1, address(weth), 10 ether);
        uint256 tooMuch = (10 * 3000e18 * 7500) / 10000 + 1;
        assertFalse(collateralManager.isCollateralSufficient(borrower1, address(weth), tooMuch));
    }

    function test_getAvailableCollateral() public {
        _depositCollateral(borrower1, address(weth), 10 ether);

        collateralManager.setAuthorized(address(this), true);
        collateralManager.lockCollateral(borrower1, address(weth), 3 ether);

        assertEq(collateralManager.getAvailableCollateral(borrower1, address(weth)), 7 ether);
    }

    function test_addSupportedCollateral() public {
        address newToken = makeAddr("newToken");
        CollateralInfo memory info = CollateralInfo({
            token: newToken,
            isSupported: true,
            liquidationThreshold: 7500,
            maxLTV: 7000,
            liquidationBonus: 600
        });

        collateralManager.addSupportedCollateral(newToken, info);
        CollateralInfo memory stored = collateralManager.getCollateralInfo(newToken);
        assertTrue(stored.isSupported);
        assertEq(stored.maxLTV, 7000);
    }

    function test_removeSupportedCollateral() public {
        collateralManager.removeSupportedCollateral(address(weth));
        CollateralInfo memory info = collateralManager.getCollateralInfo(address(weth));
        assertFalse(info.isSupported);
    }

    function test_getCollateralTokenCount() public view {
        assertEq(collateralManager.getCollateralTokenCount(), 2);
    }

    function test_addSupportedCollateral_onlyOwner() public {
        address rando = makeAddr("rando");
        CollateralInfo memory info = CollateralInfo({
            token: address(0x1),
            isSupported: true,
            liquidationThreshold: 8000,
            maxLTV: 7500,
            liquidationBonus: 500
        });

        vm.prank(rando);
        vm.expectRevert();
        collateralManager.addSupportedCollateral(address(0x1), info);
    }
}
