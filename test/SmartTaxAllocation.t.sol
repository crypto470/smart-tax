// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/TaxaToken.sol";
import "../src/SmartTaxAllocation.sol";

contract SmartTaxAllocationTest is Test {
    TaxaToken public token;
    SmartTaxAllocation public taxContract;

    address admin = address(this);
    address alice = address(0xA);
    address bob   = address(0xB);
    address carol = address(0xC);

    address roadsWallet      = address(0x100);
    address schoolsWallet    = address(0x200);
    address healthcareWallet = address(0x300);

    uint256 constant TAXA = 1e18;
    uint256 voteEnd;

    function setUp() public {
        vm.warp(10_000);

        token = new TaxaToken(admin);
        taxContract = new SmartTaxAllocation(address(token));
        token.setAllocationContract(address(taxContract));

        // Propose and execute 3 projects through the timelock
        taxContract.proposeAddProject("Roads",      roadsWallet);
        taxContract.proposeAddProject("Schools",    schoolsWallet);
        taxContract.proposeAddProject("Healthcare", healthcareWallet);
        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(0);
        taxContract.executeProposal(1);
        taxContract.executeProposal(2);

        // Mint tokens to test users
        token.mint(alice, 10_000 * TAXA);
        token.mint(bob,    5_000 * TAXA);
        token.mint(carol,  3_000 * TAXA);

        voteEnd = block.timestamp + 2 days;
    }

    // ─── Helpers ─────────────────────────────────

    function _startRound() internal {
        taxContract.startRound(voteEnd);
    }

    function _allocate(address user, uint256 projectId, uint256 amount) internal {
        vm.prank(user);
        taxContract.allocateVotes(projectId, amount);
    }

    function _runFullRound() internal {
        _startRound();
        _allocate(alice, 0, 6_000 * TAXA);
        _allocate(bob,   1, 3_000 * TAXA);
        _allocate(carol, 2, 1_000 * TAXA);
        vm.warp(voteEnd + 1);
        taxContract.finalize();
    }

    // ══════════════════════════════════════════════
    //  Constructor
    // ══════════════════════════════════════════════

    function test_constructor() public view {
        assertEq(address(taxContract.taxaToken()), address(token));
        assertEq(taxContract.admin(), admin);
        assertEq(taxContract.currentRound(), 0);
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Idle));
    }

    function test_constructor_revertZeroAddress() public {
        vm.expectRevert("Invalid token address");
        new SmartTaxAllocation(address(0));
    }

    // ══════════════════════════════════════════════
    //  transferAdmin
    // ══════════════════════════════════════════════

    function test_transferAdmin() public {
        taxContract.transferAdmin(alice);
        assertEq(taxContract.admin(), alice);
    }

    function test_transferAdmin_revertNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert("Only admin");
        taxContract.transferAdmin(alice);
    }

    function test_transferAdmin_revertZeroAddress() public {
        vm.expectRevert("Invalid address");
        taxContract.transferAdmin(address(0));
    }

    function test_transferAdmin_revertSameAdmin() public {
        vm.expectRevert("Already admin");
        taxContract.transferAdmin(admin);
    }

    // ══════════════════════════════════════════════
    //  Project proposals (timelock)
    // ══════════════════════════════════════════════

    function test_proposeAddProject() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        assertEq(taxContract.getProposalCount(), 4); // 3 from setUp + 1
    }

    function test_proposeAddProject_revertNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert("Only admin");
        taxContract.proposeAddProject("Transport", address(0x400));
    }

    function test_proposeAddProject_revertEmptyName() public {
        vm.expectRevert("Name cannot be empty");
        taxContract.proposeAddProject("", address(0x400));
    }

    function test_proposeAddProject_revertZeroWallet() public {
        vm.expectRevert("Invalid wallet");
        taxContract.proposeAddProject("Transport", address(0));
    }

    function test_executeAddProject_afterTimelock() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;

        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(pid);

        assertEq(taxContract.getProjectCount(), 4);
        SmartTaxAllocation.Project[] memory all = taxContract.getProjects();
        assertEq(all[3].name, "Transport");
        assertTrue(all[3].active);
    }

    function test_executeProposal_revertBeforeTimelock() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;

        vm.expectRevert("Timelock not expired");
        taxContract.executeProposal(pid);
    }

    function test_executeProposal_revertDuringVoting() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;

        // Warp past timelock AND start a round
        vm.warp(block.timestamp + 2 days + 1);
        voteEnd = block.timestamp + 2 days;
        _startRound();

        vm.expectRevert("Locked during voting");
        taxContract.executeProposal(pid);
    }

    function test_proposeDeactivateProject() public {
        taxContract.proposeDeactivateProject(0);
        uint256 pid = taxContract.getProposalCount() - 1;
        SmartTaxAllocation.Proposal memory p = taxContract.getProposal(pid);
        assertEq(uint256(p.pType), uint256(SmartTaxAllocation.ProposalType.DeactivateProject));
        assertEq(p.projectId, 0);
    }

    function test_proposeDeactivateProject_revertAlreadyInactive() public {
        // First deactivate via timelock
        taxContract.proposeDeactivateProject(0);
        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(taxContract.getProposalCount() - 1);

        // Now proposing again should revert
        vm.expectRevert("Already inactive");
        taxContract.proposeDeactivateProject(0);
    }

    function test_executeDeactivateProject() public {
        taxContract.proposeDeactivateProject(1);
        uint256 pid = taxContract.getProposalCount() - 1;

        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(pid);

        SmartTaxAllocation.Project[] memory all = taxContract.getProjects();
        assertFalse(all[1].active);
    }

    function test_cancelProposal() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;

        taxContract.cancelProposal(pid);

        SmartTaxAllocation.Proposal memory p = taxContract.getProposal(pid);
        assertTrue(p.cancelled);
    }

    function test_executeProposal_revertCancelled() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;
        taxContract.cancelProposal(pid);

        vm.warp(block.timestamp + 2 days + 1);
        vm.expectRevert("Proposal cancelled");
        taxContract.executeProposal(pid);
    }

    function test_cancelProposal_revertAlreadyExecuted() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;
        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(pid);

        vm.expectRevert("Already executed");
        taxContract.cancelProposal(pid);
    }

    function test_cancelProposal_revertAlreadyCancelled() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;
        taxContract.cancelProposal(pid);

        vm.expectRevert("Already cancelled");
        taxContract.cancelProposal(pid);
    }

    function test_cancelProposal_revertNotAdmin() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;

        vm.prank(alice);
        vm.expectRevert("Only admin");
        taxContract.cancelProposal(pid);
    }

    function test_executeProposal_permissionless() public {
        taxContract.proposeAddProject("Transport", address(0x400));
        uint256 pid = taxContract.getProposalCount() - 1;

        vm.warp(block.timestamp + 2 days + 1);

        // Anyone (not just admin) can execute
        vm.prank(alice);
        taxContract.executeProposal(pid);
        assertEq(taxContract.getProjectCount(), 4);
    }

    // ══════════════════════════════════════════════
    //  startRound
    // ══════════════════════════════════════════════

    function test_startRound() public {
        _startRound();

        assertEq(taxContract.currentRound(), 1);
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Voting));

        SmartTaxAllocation.Round memory r = taxContract.getRound(1);
        assertEq(r.voteEnd, voteEnd);
    }

    function test_startRound_revertNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert("Only admin");
        taxContract.startRound(voteEnd);
    }

    function test_startRound_revertVotingTooShort() public {
        vm.expectRevert("Voting window too short");
        taxContract.startRound(block.timestamp + 30 minutes);
    }

    function test_startRound_revertNoActiveProjects() public {
        // Deactivate all 3 projects
        taxContract.proposeDeactivateProject(0);
        taxContract.proposeDeactivateProject(1);
        taxContract.proposeDeactivateProject(2);
        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(taxContract.getProposalCount() - 3);
        taxContract.executeProposal(taxContract.getProposalCount() - 2);
        taxContract.executeProposal(taxContract.getProposalCount() - 1);

        voteEnd = block.timestamp + 2 days;
        vm.expectRevert("No active projects");
        taxContract.startRound(voteEnd);
    }

    function test_startRound_revertPreviousNotResolved() public {
        _startRound();

        vm.expectRevert("Previous round not resolved");
        taxContract.startRound(voteEnd + 3 days);
    }

    function test_startRound_afterFinalization() public {
        _runFullRound();

        uint256 newVoteEnd = block.timestamp + 2 days;
        taxContract.startRound(newVoteEnd);
        assertEq(taxContract.currentRound(), 2);
    }

    function test_startRound_afterCancellation() public {
        _startRound();
        taxContract.cancelRound();

        uint256 newVoteEnd = block.timestamp + 2 days;
        taxContract.startRound(newVoteEnd);
        assertEq(taxContract.currentRound(), 2);
    }

    // ══════════════════════════════════════════════
    //  allocateVotes
    // ══════════════════════════════════════════════

    function test_allocateVotes() public {
        _startRound();
        _allocate(alice, 0, 2_000 * TAXA);

        // QV weight = floor(sqrt(2000)) = 44
        uint256 expectedWeight = taxContract.qvWeight(2_000 * TAXA);
        assertEq(taxContract.getProjectVotes(1, 0), expectedWeight);
        assertEq(taxContract.getUserAllocation(1, alice, 0), 2_000 * TAXA);
        assertEq(taxContract.getUserTotalAllocated(1, alice), 2_000 * TAXA);
        // Tokens should be burned
        assertEq(token.balanceOf(alice), 8_000 * TAXA);
    }

    function test_allocateVotes_multipleProjects() public {
        _startRound();
        _allocate(alice, 0, 4_000 * TAXA);
        _allocate(alice, 1, 3_000 * TAXA);
        _allocate(alice, 2, 2_000 * TAXA);

        assertEq(taxContract.getUserTotalAllocated(1, alice), 9_000 * TAXA);
        assertEq(token.balanceOf(alice), 1_000 * TAXA);

        // Each project has correct QV weight
        assertEq(taxContract.getProjectVotes(1, 0), taxContract.qvWeight(4_000 * TAXA));
        assertEq(taxContract.getProjectVotes(1, 1), taxContract.qvWeight(3_000 * TAXA));
        assertEq(taxContract.getProjectVotes(1, 2), taxContract.qvWeight(2_000 * TAXA));
    }

    function test_allocateVotes_sameProjectTwice() public {
        _startRound();
        _allocate(alice, 0, 100 * TAXA);
        _allocate(alice, 0, 300 * TAXA);

        // Total allocation = 400 TAXA, QV weight = sqrt(400) = 20
        assertEq(taxContract.getUserAllocation(1, alice, 0), 400 * TAXA);
        assertEq(taxContract.getProjectVotes(1, 0), 20); // sqrt(400)
        assertEq(token.balanceOf(alice), 9_600 * TAXA);
    }

    function test_allocateVotes_qvWeightCorrect() public {
        _startRound();
        // 10000 TAXA → sqrt(10000) = 100 QV votes
        _allocate(alice, 0, 10_000 * TAXA);
        assertEq(taxContract.getProjectVotes(1, 0), 100);

        // 900 TAXA → sqrt(900) = 30 QV votes
        _allocate(bob, 1, 900 * TAXA);
        assertEq(taxContract.getProjectVotes(1, 1), 30);
    }

    function test_allocateVotes_revertNoRound() public {
        vm.prank(alice);
        vm.expectRevert("No active round");
        taxContract.allocateVotes(0, 100 * TAXA);
    }

    function test_allocateVotes_revertAfterVoteEnd() public {
        _startRound();
        vm.warp(voteEnd + 1);

        vm.prank(alice);
        vm.expectRevert("Voting ended");
        taxContract.allocateVotes(0, 100 * TAXA);
    }

    function test_allocateVotes_revertInvalidProject() public {
        _startRound();

        vm.prank(alice);
        vm.expectRevert("Invalid project");
        taxContract.allocateVotes(99, 100 * TAXA);
    }

    function test_allocateVotes_revertInactiveProject() public {
        // Deactivate project 2
        taxContract.proposeDeactivateProject(2);
        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(taxContract.getProposalCount() - 1);

        voteEnd = block.timestamp + 2 days;
        _startRound();

        vm.prank(alice);
        vm.expectRevert("Project not active");
        taxContract.allocateVotes(2, 100 * TAXA);
    }

    function test_allocateVotes_revertZeroAmount() public {
        _startRound();

        vm.prank(alice);
        vm.expectRevert("Amount must be > 0");
        taxContract.allocateVotes(0, 0);
    }

    function test_allocateVotes_revertInsufficientBalance() public {
        _startRound();

        vm.prank(carol); // carol has 3000 TAXA
        vm.expectRevert();
        taxContract.allocateVotes(0, 5_000 * TAXA);
    }

    function test_allocateVotes_revertRoundResolved() public {
        _runFullRound();

        vm.prank(alice);
        vm.expectRevert("Round resolved");
        taxContract.allocateVotes(0, 100 * TAXA);
    }

    // ══════════════════════════════════════════════
    //  finalize
    // ══════════════════════════════════════════════

    function test_finalize() public {
        _runFullRound();
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Finalized));

        // Check QV totals
        uint256 qv0 = taxContract.qvWeight(6_000 * TAXA); // sqrt(6000) = 77
        uint256 qv1 = taxContract.qvWeight(3_000 * TAXA); // sqrt(3000) = 54
        uint256 qv2 = taxContract.qvWeight(1_000 * TAXA); // sqrt(1000) = 31
        uint256 totalQV = qv0 + qv1 + qv2;

        assertEq(taxContract.getProjectVotes(1, 0), qv0);
        assertEq(taxContract.getProjectVotes(1, 1), qv1);
        assertEq(taxContract.getProjectVotes(1, 2), qv2);

        SmartTaxAllocation.Round memory r = taxContract.getRound(1);
        assertEq(r.totalQVVotes, totalQV);
        assertTrue(r.finalized);
    }

    function test_finalize_permissionless() public {
        _startRound();
        _allocate(alice, 0, 1_000 * TAXA);
        vm.warp(voteEnd + 1);

        // Carol (non-admin, non-voter) can finalize
        vm.prank(carol);
        taxContract.finalize();

        assertTrue(taxContract.getRound(1).finalized);
    }

    function test_finalize_revertVotingOpen() public {
        _startRound();
        _allocate(alice, 0, 1_000 * TAXA);

        vm.expectRevert("Voting still open");
        taxContract.finalize();
    }

    function test_finalize_revertNoVotes() public {
        _startRound();
        vm.warp(voteEnd + 1);

        vm.expectRevert("No votes cast");
        taxContract.finalize();
    }

    function test_finalize_revertAlreadyResolved() public {
        _runFullRound();

        vm.expectRevert("Round already resolved");
        taxContract.finalize();
    }

    function test_finalize_revertNoRound() public {
        vm.expectRevert("No active round");
        taxContract.finalize();
    }

    function test_finalize_tokensBurned() public {
        _startRound();
        uint256 aliceBefore = token.balanceOf(alice);
        _allocate(alice, 0, 5_000 * TAXA);

        // Tokens burned immediately at allocation time
        assertEq(token.balanceOf(alice), aliceBefore - 5_000 * TAXA);

        vm.warp(voteEnd + 1);
        taxContract.finalize();

        // Still burned after finalization — no refund
        assertEq(token.balanceOf(alice), aliceBefore - 5_000 * TAXA);
    }

    // ══════════════════════════════════════════════
    //  cancelRound + reclaimTokens
    // ══════════════════════════════════════════════

    function test_cancelRound() public {
        _startRound();
        taxContract.cancelRound();

        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Cancelled));
        assertTrue(taxContract.getRound(1).cancelled);
    }

    function test_cancelRound_afterVotes() public {
        _startRound();
        _allocate(alice, 0, 5_000 * TAXA);

        // Admin can still cancel even after votes
        taxContract.cancelRound();
        assertTrue(taxContract.getRound(1).cancelled);
    }

    function test_cancelRound_revertNotAdmin() public {
        _startRound();

        vm.prank(alice);
        vm.expectRevert("Only admin");
        taxContract.cancelRound();
    }

    function test_cancelRound_revertAlreadyResolved() public {
        _runFullRound();

        vm.expectRevert("Round already resolved");
        taxContract.cancelRound();
    }

    function test_cancelRound_revertNoRound() public {
        vm.expectRevert("No active round");
        taxContract.cancelRound();
    }

    function test_reclaimTokens() public {
        _startRound();
        _allocate(alice, 0, 5_000 * TAXA);
        _allocate(bob,   1, 2_000 * TAXA);

        taxContract.cancelRound();

        uint256 aliceBefore = token.balanceOf(alice);
        uint256 bobBefore   = token.balanceOf(bob);

        vm.prank(alice);
        taxContract.reclaimTokens(1);
        vm.prank(bob);
        taxContract.reclaimTokens(1);

        // Tokens re-minted
        assertEq(token.balanceOf(alice), aliceBefore + 5_000 * TAXA);
        assertEq(token.balanceOf(bob),   bobBefore   + 2_000 * TAXA);
    }

    function test_reclaimTokens_revertNotCancelled() public {
        _runFullRound();

        vm.prank(alice);
        vm.expectRevert("Round not cancelled");
        taxContract.reclaimTokens(1);
    }

    function test_reclaimTokens_revertNothingToReclaim() public {
        _startRound();
        _allocate(alice, 0, 1_000 * TAXA);
        taxContract.cancelRound();

        vm.prank(carol); // carol didn't allocate
        vm.expectRevert("Nothing to reclaim");
        taxContract.reclaimTokens(1);
    }

    function test_reclaimTokens_revertDoubleReclaim() public {
        _startRound();
        _allocate(alice, 0, 1_000 * TAXA);
        taxContract.cancelRound();

        vm.prank(alice);
        taxContract.reclaimTokens(1);

        vm.prank(alice);
        vm.expectRevert("Already reclaimed");
        taxContract.reclaimTokens(1);
    }

    function test_reclaimTokens_revertInvalidRound() public {
        vm.prank(alice);
        vm.expectRevert("Invalid round");
        taxContract.reclaimTokens(0);
    }

    // ══════════════════════════════════════════════
    //  QV math
    // ══════════════════════════════════════════════

    function test_qvWeight() public view {
        assertEq(taxContract.qvWeight(100 * TAXA), 10);    // sqrt(100) = 10
        assertEq(taxContract.qvWeight(400 * TAXA), 20);    // sqrt(400) = 20
        assertEq(taxContract.qvWeight(10_000 * TAXA), 100); // sqrt(10000) = 100
        assertEq(taxContract.qvWeight(1 * TAXA), 1);        // sqrt(1) = 1
        assertEq(taxContract.qvWeight(0), 0);                // sqrt(0) = 0
    }

    function test_sqrt() public view {
        assertEq(taxContract.sqrt(0), 0);
        assertEq(taxContract.sqrt(1), 1);
        assertEq(taxContract.sqrt(4), 2);
        assertEq(taxContract.sqrt(9), 3);
        assertEq(taxContract.sqrt(10), 3); // floor
        assertEq(taxContract.sqrt(15), 3);
        assertEq(taxContract.sqrt(16), 4);
        assertEq(taxContract.sqrt(1000000), 1000);
    }

    // ══════════════════════════════════════════════
    //  View helpers
    // ══════════════════════════════════════════════

    function test_getProjects() public view {
        SmartTaxAllocation.Project[] memory all = taxContract.getProjects();
        assertEq(all.length, 3);
        assertEq(all[0].name, "Roads");
        assertEq(all[1].name, "Schools");
        assertEq(all[2].name, "Healthcare");
    }

    function test_getProjectCount() public view {
        assertEq(taxContract.getProjectCount(), 3);
    }

    function test_getActiveProjectCount() public {
        assertEq(taxContract.getActiveProjectCount(), 3);

        taxContract.proposeDeactivateProject(0);
        vm.warp(block.timestamp + 2 days + 1);
        taxContract.executeProposal(taxContract.getProposalCount() - 1);

        assertEq(taxContract.getActiveProjectCount(), 2);
    }

    function test_constants() public view {
        assertEq(taxContract.TIMELOCK_DELAY(), 2 days);
        assertEq(taxContract.MIN_VOTING_DURATION(), 1 hours);
    }

    // ══════════════════════════════════════════════
    //  Phase transitions
    // ══════════════════════════════════════════════

    function test_phase_idle() public view {
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Idle));
    }

    function test_phase_voting() public {
        _startRound();
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Voting));
    }

    function test_phase_votingPastDeadline() public {
        _startRound();
        vm.warp(voteEnd + 1);
        // Still Voting until finalize() or cancelRound()
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Voting));
    }

    function test_phase_finalized() public {
        _runFullRound();
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Finalized));
    }

    function test_phase_cancelled() public {
        _startRound();
        taxContract.cancelRound();
        assertEq(uint256(taxContract.getCurrentPhase()), uint256(SmartTaxAllocation.Phase.Cancelled));
    }

    // ══════════════════════════════════════════════
    //  Multi-round
    // ══════════════════════════════════════════════

    function test_multiRound_fullFlow() public {
        // Round 1: normal flow
        _runFullRound();

        // Mint fresh tokens for round 2
        token.mint(alice, 5_000 * TAXA);
        token.mint(bob,   5_000 * TAXA);

        // Round 2
        uint256 r2VoteEnd = block.timestamp + 2 days;
        taxContract.startRound(r2VoteEnd);
        assertEq(taxContract.currentRound(), 2);

        _allocate(alice, 1, 5_000 * TAXA);
        _allocate(bob,   1, 5_000 * TAXA);

        vm.warp(r2VoteEnd + 1);
        taxContract.finalize();

        // Schools (project 1) got all votes in round 2
        uint256 expectedQV = taxContract.qvWeight(5_000 * TAXA);
        assertEq(taxContract.getProjectVotes(2, 1), expectedQV * 2);
        assertEq(taxContract.getProjectVotes(2, 0), 0);

        // Round 1 data preserved
        assertEq(taxContract.getProjectVotes(1, 0), taxContract.qvWeight(6_000 * TAXA));
    }

    function test_multiRound_afterCancel() public {
        // Round 1: cancelled
        _startRound();
        _allocate(alice, 0, 3_000 * TAXA);
        taxContract.cancelRound();

        vm.prank(alice);
        taxContract.reclaimTokens(1);

        // Round 2: succeeds
        uint256 r2VoteEnd = block.timestamp + 2 days;
        taxContract.startRound(r2VoteEnd);
        _allocate(alice, 0, 2_000 * TAXA);
        vm.warp(r2VoteEnd + 1);
        taxContract.finalize();

        assertEq(taxContract.getProjectVotes(2, 0), taxContract.qvWeight(2_000 * TAXA));
    }

    // ══════════════════════════════════════════════
    //  Budget share calculation (off-chain verified)
    // ══════════════════════════════════════════════

    function test_budgetShareCalculation() public {
        _startRound();

        // Alice → Roads: 6000 TAXA (sqrt(6000)=77)
        // Bob   → Schools: 3000 TAXA (sqrt(3000)=54)
        // Carol → Healthcare: 1000 TAXA (sqrt(1000)=31)
        _allocate(alice, 0, 6_000 * TAXA);
        _allocate(bob,   1, 3_000 * TAXA);
        _allocate(carol, 2, 1_000 * TAXA);

        vm.warp(voteEnd + 1);
        taxContract.finalize();

        uint256 qv0 = taxContract.getProjectVotes(1, 0); // 77
        uint256 qv1 = taxContract.getProjectVotes(1, 1); // 54
        uint256 qv2 = taxContract.getProjectVotes(1, 2); // 31
        uint256 total = taxContract.getRound(1).totalQVVotes;

        // Budget percentages (integer math, off-chain would use decimals):
        // Roads: 77/162 ≈ 47.5%
        // Schools: 54/162 ≈ 33.3%
        // Healthcare: 31/162 ≈ 19.1%
        assertEq(total, qv0 + qv1 + qv2);
        assertTrue(qv0 > qv1);
        assertTrue(qv1 > qv2);
    }
}
