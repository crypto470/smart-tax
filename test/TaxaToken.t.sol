// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TaxaToken.sol";

contract TaxaTokenTest is Test {
    TaxaToken public token;

    address owner    = address(this);
    address alice    = address(0xA);
    address bob      = address(0xB);
    address allocContract = address(0xACC);

    function setUp() public {
        token = new TaxaToken(owner);
        token.setAllocationContract(allocContract);
    }

    // ══════════════════════════════════════════════
    //  Metadata
    // ══════════════════════════════════════════════

    function test_name() public view {
        assertEq(token.name(), "TAXA");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "TAXA");
    }

    function test_decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_initialSupplyIsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    // ══════════════════════════════════════════════
    //  Ownership
    // ══════════════════════════════════════════════

    function test_ownerIsSetCorrectly() public view {
        assertEq(token.owner(), owner);
    }

    // ══════════════════════════════════════════════
    //  setAllocationContract
    // ══════════════════════════════════════════════

    function test_setAllocationContract() public {
        address newAlloc = address(0xBEEF);
        token.setAllocationContract(newAlloc);
        assertEq(token.allocationContract(), newAlloc);
    }

    function test_setAllocationContract_revertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.setAllocationContract(address(0xBEEF));
    }

    function test_setAllocationContract_revertZeroAddress() public {
        vm.expectRevert("Invalid address");
        token.setAllocationContract(address(0));
    }

    // ══════════════════════════════════════════════
    //  Minting (owner only)
    // ══════════════════════════════════════════════

    function test_mint() public {
        token.mint(alice, 1_000e18);
        assertEq(token.balanceOf(alice), 1_000e18);
        assertEq(token.totalSupply(), 1_000e18);
    }

    function test_mint_multipleCalls() public {
        token.mint(alice, 500e18);
        token.mint(alice, 300e18);
        assertEq(token.balanceOf(alice), 800e18);
    }

    function test_mint_revertNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1_000e18);
    }

    function test_mint_revertZeroAddress() public {
        vm.expectRevert("Invalid recipient");
        token.mint(address(0), 1_000e18);
    }

    function test_mint_revertZeroAmount() public {
        vm.expectRevert("Amount must be > 0");
        token.mint(alice, 0);
    }

    // ══════════════════════════════════════════════
    //  Burning (allocation contract only)
    // ══════════════════════════════════════════════

    function test_burn() public {
        token.mint(alice, 1_000e18);

        vm.prank(allocContract);
        token.burn(alice, 400e18);

        assertEq(token.balanceOf(alice), 600e18);
        assertEq(token.totalSupply(), 600e18);
    }

    function test_burn_revertNotAllocationContract() public {
        token.mint(alice, 1_000e18);

        vm.prank(alice);
        vm.expectRevert("Not authorized");
        token.burn(alice, 100e18);
    }

    function test_burn_revertNotAuthorizedOwner() public {
        token.mint(alice, 1_000e18);

        // Even owner can't burn — only allocation contract
        vm.expectRevert("Not authorized");
        token.burn(alice, 100e18);
    }

    function test_burn_revertInsufficientBalance() public {
        token.mint(alice, 100e18);

        vm.prank(allocContract);
        vm.expectRevert();
        token.burn(alice, 200e18);
    }

    // ══════════════════════════════════════════════
    //  mintFromAllocation
    // ══════════════════════════════════════════════

    function test_mintFromAllocation() public {
        vm.prank(allocContract);
        token.mintFromAllocation(alice, 500e18);

        assertEq(token.balanceOf(alice), 500e18);
    }

    function test_mintFromAllocation_revertNotAllocationContract() public {
        vm.prank(alice);
        vm.expectRevert("Not authorized");
        token.mintFromAllocation(alice, 500e18);
    }

    // ══════════════════════════════════════════════
    //  Non-transferability
    // ══════════════════════════════════════════════

    function test_transfer_reverts() public {
        token.mint(alice, 1_000e18);

        vm.prank(alice);
        vm.expectRevert("Transfers disabled");
        token.transfer(bob, 100e18);
    }

    function test_transferFrom_reverts() public {
        token.mint(alice, 1_000e18);

        vm.prank(alice);
        token.approve(bob, 500e18);

        vm.prank(bob);
        vm.expectRevert("Transfers disabled");
        token.transferFrom(alice, bob, 500e18);
    }

    // ══════════════════════════════════════════════
    //  Approve still works (for interface compat)
    // ══════════════════════════════════════════════

    function test_approve() public {
        token.mint(alice, 1_000e18);

        vm.prank(alice);
        token.approve(allocContract, 1_000e18);

        assertEq(token.allowance(alice, allocContract), 1_000e18);
    }
}
