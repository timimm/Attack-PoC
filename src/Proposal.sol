// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IProposalSelfDestruct {
    function emergencyStop() external;
    function executeProposal() external;
}

contract ProposalSelfDestruct {
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
        // Nothing
        return true;
    }
}
