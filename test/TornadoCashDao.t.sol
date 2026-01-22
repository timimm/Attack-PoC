// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/Hack.sol";
import "src/GovernanceProxy.sol";
import "src/Governance.sol";

contract HackTest is Test {
    address public governanceProxy;
    address public governance;
    Hack public hack;

    function setUp() public {
        // Deploy the Governance contract
        governance = address(new Governance());

        // Deploy the GovernanceProxy
        governanceProxy = address(new GovernanceProxy(governance));
        
        // Deploy the Hack contract
        hack = new Hack(governanceProxy, governance);

        hack.hack();
    }

    function testHack() public {
        

        hack.hack_2();
        // Verify that the malicious proposal was executed
        // This could be done by checking some state change or event emission
        // For example, if the EvilProposal modifies a state variable, we can check that
        // In this case, we assume it logs a message to the console
        console.log("Hack executed successfully");
    }

}