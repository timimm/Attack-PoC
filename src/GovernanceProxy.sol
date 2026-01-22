// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGovernanceProxy {
    function upgradeTo(address _impl) external;
    function execute(address proposal) external;
}

contract GovernanceProxy {
    address public implementation;
    address public admin;

    constructor(address _impl) {
        implementation = _impl;
        admin = msg.sender;
    }

    fallback() external {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function upgradeTo(address _impl) external {
        require(msg.sender == admin, "not admin");
        implementation = _impl;
    }
}

