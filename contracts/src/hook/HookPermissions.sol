// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

abstract contract HookPermissions {
    function getHookPermissions() public pure virtual returns (Hooks.Permissions memory);
}
