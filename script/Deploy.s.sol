// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/TaxaToken.sol";
import "../src/SmartTaxAllocation.sol";

/// @notice Deployment script for the TAXA governance system.
///
///   After running this script, you must wait TIMELOCK_DELAY (2 days)
///   before executing the project proposals. Use ExecuteProposals.s.sol
///   or call executeProposal() manually via cast.
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // 1. Deploy TaxaToken — deployer becomes the owner (admin)
        TaxaToken token = new TaxaToken(msg.sender);
        console.log("TaxaToken deployed at:", address(token));

        // 2. Deploy SmartTaxAllocation — deployer becomes the admin
        SmartTaxAllocation allocation = new SmartTaxAllocation(address(token));
        console.log("SmartTaxAllocation deployed at:", address(allocation));

        // 3. Authorize the allocation contract to burn/re-mint tokens
        token.setAllocationContract(address(allocation));
        console.log("Allocation contract set on token");

        // 4. Propose initial projects (timelocked — executable after 2 days)
        allocation.proposeAddProject("Roads",      address(0x100));
        allocation.proposeAddProject("Schools",    address(0x200));
        allocation.proposeAddProject("Healthcare", address(0x300));
        console.log("3 project proposals created (execute after 2-day timelock)");

        vm.stopBroadcast();
    }
}
