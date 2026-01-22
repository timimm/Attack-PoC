// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/console.sol";
interface IProposal {
    function emergencyStop() external returns (bool);
    function executeProposal() external returns (bool);
}

contract Governance {
    function execute(address proposalContract) public returns (bool) {
        // Execute the proposal
        bool success = IProposal(proposalContract).executeProposal();
        require(success, "proposal execution failed");
        return true;
    }
}
