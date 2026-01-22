// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";

contract EvilProposal {
    address governance;

    constructor(address _gov) {
        governance = _gov;
    }

    function emergencyStop() external {
        // This function is called by the Governance contract
        // when the proposal is executed
        selfdestruct(payable(0)); // clears the address
    }

    function executeProposal() external pure returns (bool) {
        // change the 
        console.log("Executing proposal...");
        console.log("This is an evil proposal that can perform malicious operations such as modifying state or transferring funds.");
        console.log("Proposal executed successfully.");
        return true;
    }
}
