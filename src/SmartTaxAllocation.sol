// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./TaxaToken.sol";

/// @title SmartTaxAllocation
/// @notice Governance contract for the TAXA ecosystem. Citizens vote on
///         public budget projects using TAXA tokens and Quadratic Voting (QV).
///
///   System lifecycle (per round):
///
///     1. Admin starts a voting round with a deadline.
///     2. Citizens allocate TAXA tokens to projects they support.
///        - Tokens are burned immediately upon allocation.
///        - QV weight = floor(sqrt(tokens / 1e18)).
///        - Citizens can split tokens across multiple projects.
///     3. After the deadline, anyone can finalize the round.
///        - On-chain result: each project's share of total QV votes.
///        - Actual budget distribution happens off-chain.
///     4. Tokens are permanently burned. New voting power only comes
///        from newly minted TAXA tied to future tax payments.
///
///   If a round is cancelled, users reclaim their burned tokens
///   via reclaimTokens().
///
///   Project management uses a 2-day timelock for transparency:
///   admin proposes changes, waits, then anyone can execute.
contract SmartTaxAllocation {

    // ─── Types ───────────────────────────────────

    enum Phase { Idle, Voting, Finalized, Cancelled }
    enum ProposalType { AddProject, DeactivateProject }

    struct Round {
        uint256 voteEnd;
        uint256 totalQVVotes;
        bool finalized;
        bool cancelled;
    }

    struct Project {
        string name;
        address wallet;
        bool active;
    }

    struct Proposal {
        ProposalType pType;
        string name;          // for AddProject
        address wallet;       // for AddProject
        uint256 projectId;    // for DeactivateProject
        uint256 executeAfter;
        bool executed;
        bool cancelled;
    }

    // ─── Constants ───────────────────────────────

    uint256 public constant TIMELOCK_DELAY = 2 days;
    uint256 public constant MIN_VOTING_DURATION = 1 hours;

    // ─── State ───────────────────────────────────

    TaxaToken public taxaToken;
    address public admin;

    uint256 public currentRound;
    mapping(uint256 => Round) public rounds;

    Project[] public projects;
    Proposal[] public proposals;

    /// @dev round => user => project => tokens allocated (in wei)
    mapping(uint256 => mapping(address => mapping(uint256 => uint256))) public userProjectAlloc;

    /// @dev round => user => total tokens allocated (for reclaim)
    mapping(uint256 => mapping(address => uint256)) public userTotalAlloc;

    /// @dev round => project => total QV votes
    mapping(uint256 => mapping(uint256 => uint256)) public projectQVVotes;

    /// @dev round => user => whether they reclaimed from a cancelled round
    mapping(uint256 => mapping(address => bool)) public hasReclaimed;

    // ─── Events ──────────────────────────────────

    event AdminTransferred(address indexed previousAdmin, address indexed newAdmin);
    event RoundStarted(uint256 indexed roundId, uint256 voteEnd);
    event RoundCancelled(uint256 indexed roundId);
    event RoundFinalized(uint256 indexed roundId, uint256 totalQVVotes);
    event ProjectAdded(uint256 indexed projectId, string name, address wallet);
    event ProjectDeactivated(uint256 indexed projectId);
    event ProposalCreated(uint256 indexed proposalId, ProposalType pType, uint256 executeAfter);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalCancelled(uint256 indexed proposalId);
    event VotesAllocated(
        uint256 indexed roundId,
        address indexed voter,
        uint256 indexed projectId,
        uint256 tokens,
        uint256 newQVWeight
    );
    event TokensReclaimed(uint256 indexed roundId, address indexed user, uint256 amount);
    event ProjectResult(
        uint256 indexed roundId,
        uint256 indexed projectId,
        uint256 qvVotes,
        uint256 totalQVVotes
    );

    // ─── Modifiers ───────────────────────────────

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    // ─── Constructor ─────────────────────────────

    /// @param _taxaToken Address of the deployed TaxaToken contract.
    constructor(address _taxaToken) {
        require(_taxaToken != address(0), "Invalid token address");
        taxaToken = TaxaToken(_taxaToken);
        admin = msg.sender;
    }

    // ─── Phase resolution ────────────────────────

    /// @notice Derives the current phase from round state.
    ///         Voting phase persists after voteEnd until finalize() or cancelRound().
    function getCurrentPhase() public view returns (Phase) {
        if (currentRound == 0) return Phase.Idle;

        Round storage r = rounds[currentRound];
        if (r.cancelled)  return Phase.Cancelled;
        if (r.finalized)  return Phase.Finalized;
        return Phase.Voting;
    }

    // ─── Admin management ────────────────────────

    /// @notice Transfer admin rights to a new address.
    function transferAdmin(address _newAdmin) external onlyAdmin {
        require(_newAdmin != address(0), "Invalid address");
        require(_newAdmin != admin, "Already admin");

        emit AdminTransferred(admin, _newAdmin);
        admin = _newAdmin;
    }

    // ─── Project proposals (timelocked) ──────────

    /// @notice Propose adding a new project. Executable after TIMELOCK_DELAY.
    /// @param _name   Display name of the project.
    /// @param _wallet Address representing this project (for identification).
    function proposeAddProject(string calldata _name, address _wallet) external onlyAdmin {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(_wallet != address(0), "Invalid wallet");

        uint256 execAfter = block.timestamp + TIMELOCK_DELAY;
        proposals.push(Proposal({
            pType: ProposalType.AddProject,
            name: _name,
            wallet: _wallet,
            projectId: 0,
            executeAfter: execAfter,
            executed: false,
            cancelled: false
        }));

        emit ProposalCreated(proposals.length - 1, ProposalType.AddProject, execAfter);
    }

    /// @notice Propose deactivating an existing project. Executable after TIMELOCK_DELAY.
    /// @param _projectId Index of the project to deactivate.
    function proposeDeactivateProject(uint256 _projectId) external onlyAdmin {
        require(_projectId < projects.length, "Invalid project");
        require(projects[_projectId].active, "Already inactive");

        uint256 execAfter = block.timestamp + TIMELOCK_DELAY;
        proposals.push(Proposal({
            pType: ProposalType.DeactivateProject,
            name: "",
            wallet: address(0),
            projectId: _projectId,
            executeAfter: execAfter,
            executed: false,
            cancelled: false
        }));

        emit ProposalCreated(proposals.length - 1, ProposalType.DeactivateProject, execAfter);
    }

    /// @notice Execute a matured proposal. Callable by anyone after the timelock.
    ///         Cannot execute during an active voting round.
    /// @param _proposalId Index of the proposal to execute.
    function executeProposal(uint256 _proposalId) external {
        require(_proposalId < proposals.length, "Invalid proposal");
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "Already executed");
        require(!p.cancelled, "Proposal cancelled");
        require(block.timestamp >= p.executeAfter, "Timelock not expired");
        require(getCurrentPhase() != Phase.Voting, "Locked during voting");

        p.executed = true;

        if (p.pType == ProposalType.AddProject) {
            projects.push(Project({name: p.name, wallet: p.wallet, active: true}));
            emit ProjectAdded(projects.length - 1, p.name, p.wallet);
        } else {
            require(projects[p.projectId].active, "Already inactive");
            projects[p.projectId].active = false;
            emit ProjectDeactivated(p.projectId);
        }

        emit ProposalExecuted(_proposalId);
    }

    /// @notice Cancel a pending proposal. Only callable by admin.
    /// @param _proposalId Index of the proposal to cancel.
    function cancelProposal(uint256 _proposalId) external onlyAdmin {
        require(_proposalId < proposals.length, "Invalid proposal");
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "Already executed");
        require(!p.cancelled, "Already cancelled");

        p.cancelled = true;
        emit ProposalCancelled(_proposalId);
    }

    // ─── Round management ────────────────────────

    /// @notice Start a new voting round. Previous round must be resolved first.
    /// @param _voteEnd Timestamp when voting closes.
    function startRound(uint256 _voteEnd) external onlyAdmin {
        if (currentRound > 0) {
            Phase phase = getCurrentPhase();
            require(
                phase == Phase.Finalized || phase == Phase.Cancelled,
                "Previous round not resolved"
            );
        }
        require(_voteEnd >= block.timestamp + MIN_VOTING_DURATION, "Voting window too short");
        require(getActiveProjectCount() > 0, "No active projects");

        currentRound++;
        rounds[currentRound] = Round({
            voteEnd: _voteEnd,
            totalQVVotes: 0,
            finalized: false,
            cancelled: false
        });

        emit RoundStarted(currentRound, _voteEnd);
    }

    /// @notice Cancel the current round. Users reclaim burned tokens via reclaimTokens().
    function cancelRound() external onlyAdmin {
        require(currentRound > 0, "No active round");
        Round storage r = rounds[currentRound];
        require(!r.finalized && !r.cancelled, "Round already resolved");

        r.cancelled = true;
        emit RoundCancelled(currentRound);
    }

    // ─── Voting ──────────────────────────────────

    /// @notice Allocate TAXA tokens to a project using Quadratic Voting.
    ///
    ///   Tokens are burned immediately. QV weight = floor(sqrt(totalTokens / 1e18)),
    ///   where totalTokens is the cumulative allocation to this project by this user.
    ///
    ///   Users can allocate to multiple projects and can top up existing allocations.
    ///   Each additional allocation recalculates the QV weight for that user-project pair.
    ///
    /// @param _projectId  Index of the project to vote for (0-based).
    /// @param _tokenAmount Number of TAXA tokens to allocate (in wei, 18 decimals).
    function allocateVotes(uint256 _projectId, uint256 _tokenAmount) external {
        require(currentRound > 0, "No active round");
        Round storage r = rounds[currentRound];
        require(!r.finalized && !r.cancelled, "Round resolved");
        require(block.timestamp < r.voteEnd, "Voting ended");
        require(_projectId < projects.length, "Invalid project");
        require(projects[_projectId].active, "Project not active");
        require(_tokenAmount > 0, "Amount must be > 0");

        // Burn tokens from voter immediately
        taxaToken.burn(msg.sender, _tokenAmount);

        // Recalculate QV weight for this user-project pair
        uint256 oldTokens = userProjectAlloc[currentRound][msg.sender][_projectId];
        uint256 oldWeight = sqrt(oldTokens / 1e18);

        uint256 newTokens = oldTokens + _tokenAmount;
        uint256 newWeight = sqrt(newTokens / 1e18);

        // Update storage
        userProjectAlloc[currentRound][msg.sender][_projectId] = newTokens;
        userTotalAlloc[currentRound][msg.sender] += _tokenAmount;

        // Update QV totals
        uint256 weightDelta = newWeight - oldWeight;
        projectQVVotes[currentRound][_projectId] += weightDelta;
        r.totalQVVotes += weightDelta;

        emit VotesAllocated(currentRound, msg.sender, _projectId, _tokenAmount, newWeight);
    }

    // ─── Finalization ────────────────────────────

    /// @notice Finalize the current round. Callable by anyone once voteEnd has passed.
    ///         Emits each project's QV share for off-chain budget allocation.
    function finalize() external {
        require(currentRound > 0, "No active round");
        Round storage r = rounds[currentRound];
        require(!r.finalized && !r.cancelled, "Round already resolved");
        require(block.timestamp >= r.voteEnd, "Voting still open");
        require(r.totalQVVotes > 0, "No votes cast");

        r.finalized = true;

        // Emit per-project results for off-chain consumption
        for (uint256 i = 0; i < projects.length; i++) {
            uint256 projVotes = projectQVVotes[currentRound][i];
            if (projVotes > 0) {
                emit ProjectResult(currentRound, i, projVotes, r.totalQVVotes);
            }
        }

        emit RoundFinalized(currentRound, r.totalQVVotes);
    }

    // ─── Reclaim (cancelled rounds) ──────────────

    /// @notice Reclaim burned tokens from a cancelled round.
    ///         Re-mints the exact amount the user allocated.
    /// @param _roundId The cancelled round to reclaim from.
    function reclaimTokens(uint256 _roundId) external {
        require(_roundId > 0 && _roundId <= currentRound, "Invalid round");
        require(rounds[_roundId].cancelled, "Round not cancelled");

        uint256 amount = userTotalAlloc[_roundId][msg.sender];
        require(amount > 0, "Nothing to reclaim");
        require(!hasReclaimed[_roundId][msg.sender], "Already reclaimed");

        hasReclaimed[_roundId][msg.sender] = true;
        taxaToken.mintFromAllocation(msg.sender, amount);

        emit TokensReclaimed(_roundId, msg.sender, amount);
    }

    // ─── QV math ─────────────────────────────────

    /// @notice Returns the QV vote weight for a given token amount (in wei).
    ///         weight = floor(sqrt(tokenAmountWei / 1e18))
    function qvWeight(uint256 _tokenAmountWei) public pure returns (uint256) {
        return sqrt(_tokenAmountWei / 1e18);
    }

    /// @dev Babylonian (Heron's) integer square root — floor(sqrt(x)).
    function sqrt(uint256 x) public pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) >> 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) >> 1;
        }
    }

    // ─── View helpers ────────────────────────────

    /// @notice Returns all registered projects.
    function getProjects() external view returns (Project[] memory) {
        return projects;
    }

    /// @notice Returns the number of registered projects.
    function getProjectCount() external view returns (uint256) {
        return projects.length;
    }

    /// @notice Returns how many projects are currently active.
    function getActiveProjectCount() public view returns (uint256 count) {
        for (uint256 i = 0; i < projects.length; i++) {
            if (projects[i].active) count++;
        }
    }

    /// @notice Returns full round configuration and state.
    function getRound(uint256 _roundId) external view returns (Round memory) {
        return rounds[_roundId];
    }

    /// @notice Returns a project's total QV votes for a given round.
    function getProjectVotes(uint256 _roundId, uint256 _projectId) external view returns (uint256) {
        return projectQVVotes[_roundId][_projectId];
    }

    /// @notice Returns how many tokens a user allocated to a project in a round.
    function getUserAllocation(uint256 _roundId, address _user, uint256 _projectId)
        external view returns (uint256)
    {
        return userProjectAlloc[_roundId][_user][_projectId];
    }

    /// @notice Returns the total tokens a user allocated across all projects in a round.
    function getUserTotalAllocated(uint256 _roundId, address _user)
        external view returns (uint256)
    {
        return userTotalAlloc[_roundId][_user];
    }

    /// @notice Returns a proposal by index.
    function getProposal(uint256 _proposalId) external view returns (Proposal memory) {
        return proposals[_proposalId];
    }

    /// @notice Returns the total number of proposals.
    function getProposalCount() external view returns (uint256) {
        return proposals.length;
    }
}
