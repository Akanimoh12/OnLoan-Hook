// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../helpers/TestSetup.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookPermissions} from "../../../contracts/src/hook/HookPermissions.sol";
import {OnLoanHook} from "../../../contracts/src/hook/OnLoanHook.sol";

contract HookPermissionsContract is HookPermissions {
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }
}

contract OnLoanHookPermissionsTest is TestSetup {
    function test_hookPermissions_allCallbacksEnabled() public {
        HookPermissionsContract perms = new HookPermissionsContract();
        Hooks.Permissions memory p = perms.getHookPermissions();

        assertTrue(p.beforeInitialize);
        assertTrue(p.afterInitialize);
        assertTrue(p.beforeAddLiquidity);
        assertTrue(p.afterAddLiquidity);
        assertTrue(p.beforeRemoveLiquidity);
        assertTrue(p.afterRemoveLiquidity);
        assertTrue(p.beforeSwap);
        assertTrue(p.afterSwap);
        assertTrue(p.beforeDonate);
        assertTrue(p.afterDonate);
    }

    function test_hookPermissions_noReturnDeltas() public {
        HookPermissionsContract perms = new HookPermissionsContract();
        Hooks.Permissions memory p = perms.getHookPermissions();

        assertFalse(p.beforeSwapReturnDelta);
        assertFalse(p.afterSwapReturnDelta);
        assertFalse(p.afterAddLiquidityReturnDelta);
        assertFalse(p.afterRemoveLiquidityReturnDelta);
    }

    function test_hookFlagBits() public pure {
        uint160 expectedFlags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                | Hooks.BEFORE_DONATE_FLAG | Hooks.AFTER_DONATE_FLAG
        );
        assertEq(expectedFlags, uint160(0x3FF0));
    }
}
