// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;
import "./Proposal.sol";
import "./EvilProposal.sol";
import "forge-std/console.sol";

interface IDeployer {
    function deployProposal(address) external returns (address);
    function deployEvilProposal(address) external returns (address);
    function emergencyStop() external;
}

// Deployer contract to deploy Proposal and EvilProposal contracts using create
contract Deployer {
    function deployProposal(address gov) external returns (address) {
        ProposalSelfDestruct proposal = new ProposalSelfDestruct(gov);
        console.log("Proposal contract deployed at:", address(proposal));
        return address(proposal);
    }

    function deployEvilProposal(address gov) external returns (address) {
        EvilProposal proposal = new EvilProposal(gov);
        console.log("EvilProposal contract deployed at:", address(proposal));
        return address(proposal);
    }

    function emergencyStop() external {
        // This function can be called to stop the deployment of proposals
        // It can be used to prevent further proposals from being executed
        selfdestruct(payable(0)); // clears the address
    }
}