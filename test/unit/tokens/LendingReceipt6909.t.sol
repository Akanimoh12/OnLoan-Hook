// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {LendingReceipt6909} from "../../../contracts/src/tokens/LendingReceipt6909.sol";

contract LendingReceipt6909Test is TestSetup {
    address minter;
    uint256 tokenId;

    function setUp() public override {
        super.setUp();
        minter = makeAddr("minter");
        receiptToken.setAuthorized(minter, true);
        tokenId = receiptToken.poolIdToTokenId(poolId);
    }

    function test_mint_onlyAuthorized() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);
        assertEq(receiptToken.balanceOf(lender1, tokenId), 1000);
    }

    function test_mint_unauthorizedReverts() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(LendingReceipt6909.Unauthorized.selector);
        receiptToken.mint(lender1, tokenId, 1000);
    }

    function test_burn_onlyAuthorized() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);

        vm.prank(minter);
        receiptToken.burn(lender1, tokenId, 500);
        assertEq(receiptToken.balanceOf(lender1, tokenId), 500);
    }

    function test_burn_unauthorizedReverts() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);

        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(LendingReceipt6909.Unauthorized.selector);
        receiptToken.burn(lender1, tokenId, 500);
    }

    function test_burn_insufficientBalanceReverts() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 500);

        vm.prank(minter);
        vm.expectRevert(LendingReceipt6909.InsufficientBalance.selector);
        receiptToken.burn(lender1, tokenId, 1000);
    }

    function test_transfer_updatesBalances() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);

        vm.prank(lender1);
        receiptToken.transfer(lender2, tokenId, 400);

        assertEq(receiptToken.balanceOf(lender1, tokenId), 600);
        assertEq(receiptToken.balanceOf(lender2, tokenId), 400);
    }

    function test_transfer_insufficientBalanceReverts() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 100);

        vm.prank(lender1);
        vm.expectRevert(LendingReceipt6909.InsufficientBalance.selector);
        receiptToken.transfer(lender2, tokenId, 200);
    }

    function test_transferFrom_withApproval() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);

        vm.prank(lender1);
        receiptToken.approve(lender2, tokenId, 500);

        vm.prank(lender2);
        receiptToken.transferFrom(lender1, borrower1, tokenId, 300);

        assertEq(receiptToken.balanceOf(lender1, tokenId), 700);
        assertEq(receiptToken.balanceOf(borrower1, tokenId), 300);
        assertEq(receiptToken.allowance(lender1, lender2, tokenId), 200);
    }

    function test_transferFrom_insufficientAllowanceReverts() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);

        vm.prank(lender1);
        receiptToken.approve(lender2, tokenId, 100);

        vm.prank(lender2);
        vm.expectRevert(LendingReceipt6909.InsufficientAllowance.selector);
        receiptToken.transferFrom(lender1, borrower1, tokenId, 200);
    }

    function test_transferFrom_byOperator() public {
        vm.prank(minter);
        receiptToken.mint(lender1, tokenId, 1000);

        vm.prank(lender1);
        receiptToken.setOperator(lender2, true);

        vm.prank(lender2);
        receiptToken.transferFrom(lender1, borrower1, tokenId, 500);

        assertEq(receiptToken.balanceOf(lender1, tokenId), 500);
        assertEq(receiptToken.balanceOf(borrower1, tokenId), 500);
    }

    function test_totalSupply_tracksCorrectly() public {
        vm.startPrank(minter);
        receiptToken.mint(lender1, tokenId, 1000);
        receiptToken.mint(lender2, tokenId, 2000);
        assertEq(receiptToken.totalSupply(tokenId), 3000);

        receiptToken.burn(lender1, tokenId, 500);
        assertEq(receiptToken.totalSupply(tokenId), 2500);
        vm.stopPrank();
    }

    function test_approve_setsAllowance() public {
        vm.prank(lender1);
        receiptToken.approve(lender2, tokenId, 5000);
        assertEq(receiptToken.allowance(lender1, lender2, tokenId), 5000);
    }

    function test_setOperator_toggles() public {
        vm.prank(lender1);
        receiptToken.setOperator(lender2, true);
        assertTrue(receiptToken.isOperator(lender1, lender2));

        vm.prank(lender1);
        receiptToken.setOperator(lender2, false);
        assertFalse(receiptToken.isOperator(lender1, lender2));
    }

    function test_poolIdToTokenId() public view {
        uint256 id = receiptToken.poolIdToTokenId(poolId);
        assertEq(id, uint256(PoolId.unwrap(poolId)));
    }

    function test_supportsInterface() public view {
        assertTrue(receiptToken.supportsInterface(0x01ffc9a7));
        assertTrue(receiptToken.supportsInterface(0x0f632fb3));
        assertFalse(receiptToken.supportsInterface(0xffffffff));
    }

    function test_setAuthorized_onlyOwner() public {
        address rando = makeAddr("rando");
        vm.prank(rando);
        vm.expectRevert(LendingReceipt6909.Unauthorized.selector);
        receiptToken.setAuthorized(rando, true);
    }
}
