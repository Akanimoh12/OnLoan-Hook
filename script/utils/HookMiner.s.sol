// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library HookMiner {
    uint160 constant ALL_HOOK_MASK = uint160((1 << 14) - 1);

    uint160 constant REQUIRED_FLAGS = uint160(
        (1 << 13) | // BEFORE_INITIALIZE_FLAG
        (1 << 12) | // AFTER_INITIALIZE_FLAG
        (1 << 11) | // BEFORE_ADD_LIQUIDITY_FLAG
        (1 << 10) | // AFTER_ADD_LIQUIDITY_FLAG
        (1 << 9) |  // BEFORE_REMOVE_LIQUIDITY_FLAG
        (1 << 8) |  // AFTER_REMOVE_LIQUIDITY_FLAG
        (1 << 7) |  // BEFORE_SWAP_FLAG
        (1 << 6) |  // AFTER_SWAP_FLAG
        (1 << 5) |  // BEFORE_DONATE_FLAG
        (1 << 4)    // AFTER_DONATE_FLAG
    );

    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (address hookAddress, bytes32 salt) {
        return find(deployer, flags, creationCode, constructorArgs, 0, type(uint256).max);
    }

    function find(
        address deployer,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs,
        uint256 startSalt,
        uint256 endSalt
    ) internal pure returns (address hookAddress, bytes32 salt) {
        bytes memory initCode = abi.encodePacked(creationCode, constructorArgs);
        bytes32 initCodeHash = keccak256(initCode);

        for (uint256 i = startSalt; i < endSalt; i++) {
            salt = bytes32(i);
            hookAddress = computeAddress(deployer, salt, initCodeHash);
            if (uint160(hookAddress) & ALL_HOOK_MASK == flags) {
                return (hookAddress, salt);
            }
        }

        revert("HookMiner: no valid salt found");
    }

    function computeAddress(
        address deployer,
        bytes32 salt,
        bytes32 initCodeHash
    ) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }
}
