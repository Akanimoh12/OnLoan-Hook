// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

contract LendingReceipt6909 {
    address public owner;
    mapping(address => bool) public authorized;

    mapping(address => mapping(uint256 => uint256)) internal _balances;
    mapping(address => mapping(address => mapping(uint256 => uint256))) internal _allowances;
    mapping(address => mapping(address => bool)) internal _operators;
    mapping(uint256 => uint256) internal _totalSupply;

    event Transfer(address indexed sender, address indexed receiver, uint256 indexed id, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    error Unauthorized();
    error InsufficientBalance();
    error InsufficientAllowance();

    modifier onlyAuthorized() {
        if (!authorized[msg.sender] && msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address _owner) {
        owner = _owner;
    }

    function setAuthorized(address caller, bool status) external onlyOwner {
        authorized[caller] = status;
    }

    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return _balances[account][id];
    }

    function allowance(address account, address spender, uint256 id) external view returns (uint256) {
        return _allowances[account][spender][id];
    }

    function isOperator(address account, address operator) external view returns (bool) {
        return _operators[account][operator];
    }

    function totalSupply(uint256 id) external view returns (uint256) {
        return _totalSupply[id];
    }

    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool) {
        if (_balances[msg.sender][id] < amount) revert InsufficientBalance();
        _balances[msg.sender][id] -= amount;
        _balances[receiver][id] += amount;
        emit Transfer(msg.sender, receiver, id, amount);
        return true;
    }

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool) {
        if (msg.sender != sender && !_operators[sender][msg.sender]) {
            uint256 allowed = _allowances[sender][msg.sender][id];
            if (allowed < amount) revert InsufficientAllowance();
            _allowances[sender][msg.sender][id] = allowed - amount;
        }
        if (_balances[sender][id] < amount) revert InsufficientBalance();
        _balances[sender][id] -= amount;
        _balances[receiver][id] += amount;
        emit Transfer(sender, receiver, id, amount);
        return true;
    }

    function approve(address spender, uint256 id, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender][id] = amount;
        emit Approval(msg.sender, spender, id, amount);
        return true;
    }

    function setOperator(address operator, bool approved) external returns (bool) {
        _operators[msg.sender][operator] = approved;
        emit OperatorSet(msg.sender, operator, approved);
        return true;
    }

    function mint(address to, uint256 id, uint256 amount) external onlyAuthorized {
        _balances[to][id] += amount;
        _totalSupply[id] += amount;
        emit Transfer(address(0), to, id, amount);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyAuthorized {
        if (_balances[from][id] < amount) revert InsufficientBalance();
        _balances[from][id] -= amount;
        _totalSupply[id] -= amount;
        emit Transfer(from, address(0), id, amount);
    }

    function poolIdToTokenId(PoolId poolId) external pure returns (uint256) {
        return uint256(PoolId.unwrap(poolId));
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == 0x01ffc9a7 || interfaceId == 0x0f632fb3;
    }
}
