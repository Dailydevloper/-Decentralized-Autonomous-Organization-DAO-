// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Decentralized Autonomous Organization (DAO)
/// @notice Minimal DAO: create proposals, vote, and execute when quorum & threshold met
/// @dev Proposal struct contains a mapping for voters; mapping of proposals is NOT public
contract Project {
    // --- TYPES ---
    enum ProposalState { Active, Executed, Expired }

    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        address proposer;
        // voters mapping to prevent double voting
        mapping(address => bool) voters;
    }

    // --- STATE ---
    address public owner;
    uint256 public proposalCount;
    uint256 public memberCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MINIMUM_VOTES = 3; // absolute threshold
    uint256 public quorumPercent = 34; // e.g., needs 34% of members as quorum

    // Note: proposals cannot be public because Proposal has a mapping
    mapping(uint256 => Proposal) internal proposals;
    mapping(address => bool) public members;
    mapping(address => uint256) public membershipDate;

    // --- EVENTS ---
    event MemberAdded(address indexed member, uint256 timestamp);
    event ProposalCreated(uint256 indexed proposalId, string description, address indexed proposer, uint256 deadline);
    event VoteCast(uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(uint256 indexed proposalId, string description);
    event QuorumPercentUpdated(uint256 newQuorum);

    // --- MODIFIERS ---
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyMember() {
        require(members[msg.sender], "Only members");
        _;
    }

    // --- CONSTRUCTOR ---
    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
        membershipDate[msg.sender] = block.timestamp;
        memberCount = 1;
    }

    // --- MEMBERSHIP ---
    /// @notice Add a new member (owner only)
    function addMember(address _member) external onlyOwner {
        require(_member != address(0), "Invalid address");
        require(!members[_member], "Already member");
        members[_member] = true;
        membershipDate[_member] = block.timestamp;
        memberCount++;
        emit MemberAdded(_member, block.timestamp);
    }

    /// @notice Update quorum percent (owner only)
    function setQuorumPercent(uint256 _percent) external onlyOwner {
        require(_percent > 0 && _percent <= 100, "Invalid percent");
        quorumPercent = _percent;
        emit QuorumPercentUpdated(_percent);
    }

    // --- PROPOSALS ---
    /// @notice Create a new proposal (members only)
    function createProposal(string calldata _description) external onlyMember returns (uint256) {
        require(bytes(_description).length > 0, "Empty description");
        proposalCount++;
        uint256 id = proposalCount;
        uint256 deadline = block.timestamp + VOTING_PERIOD;

        Proposal storage p = proposals[id];
        p.id = id;
        p.description = _description;
        p.voteCount = 0;
        p.deadline = deadline;
        p.executed = false;
        p.proposer = msg.sender;

        emit ProposalCreated(id, _description, msg.sender, deadline);
        return id;
    }

    /// @notice Vote on an active proposal (members only)
    function voteOnProposal(uint256 _proposalId) external onlyMember {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid id");
        Proposal storage p = proposals[_proposalId];
        require(block.timestamp < p.deadline, "Voting ended");
        require(!p.executed, "Already executed");
        require(!p.voters[msg.sender], "Already voted");

        p.voters[msg.sender] = true;
        p.voteCount++;
        emit VoteCast(_proposalId, msg.sender);
    }

    /// @notice Execute a proposal after voting period if quorum and min votes are met
    /// @dev Callable by anyone once conditions satisfied (keeps it decentralized)
    function executeProposal(uint256 _proposalId) external {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid id");
        Proposal storage p = proposals[_proposalId];
        require(!p.executed, "Already executed");
        require(block.timestamp >= p.deadline, "Voting still active");

        // check vote thresholds
        require(p.voteCount >= MINIMUM_VOTES, "Not enough votes (min)");
        uint256 requiredForQuorum = (memberCount * quorumPercent + 99) / 100; // ceil
        require(p.voteCount >= requiredForQuorum, "Quorum not reached");

        p.executed = true;
        emit ProposalExecuted(_proposalId, p.description);
        // If proposal required transfers or actions, handle here (not implemented in minimal DAO)
    }

    // --- VIEWS & HELPERS ---
    /// @notice Get proposal summary fields
    function getProposal(uint256 _proposalId)
        external
        view
        returns (
            uint256 id,
            string memory description,
            uint256 voteCount,
            uint256 deadline,
            bool executed,
            address proposer,
            ProposalState state
        )
    {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid id");
        Proposal storage p = proposals[_proposalId];
        state = _computeState(p);
        return (p.id, p.description, p.voteCount, p.deadline, p.executed, p.proposer, state);
    }

    /// @notice Check if an address has voted on a given proposal
    function hasVoted(uint256 _proposalId, address _voter) external view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid id");
        return proposals[_proposalId].voters[_voter];
    }

    function _computeState(Proposal storage p) internal view returns (ProposalState) {
        if (p.executed) return ProposalState.Executed;
        if (block.timestamp >= p.deadline) return ProposalState.Expired;
        return ProposalState.Active;
    }

    // --- OPTIONAL: OWNER RENOUNCE (uncomment if desired) ---
    // function renounceOwnership() external onlyOwner {
    //     owner = address(0);
    // }
}
