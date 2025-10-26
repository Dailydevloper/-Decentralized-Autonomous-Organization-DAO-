// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Decentralized Autonomous Organization (DAO)
 * @dev A simple DAO contract for decentralized governance and decision-making
 */
contract Project {
    
    // Struct to represent a proposal
    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
        address proposer;
        mapping(address => bool) voters;
    }
    
    // State variables
    address public owner;
    uint256 public proposalCount;
    uint256 public memberCount;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public constant MINIMUM_VOTES = 3;
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;
    mapping(address => uint256) public membershipDate;
    
    // Events
    event MemberAdded(address indexed member, uint256 timestamp);
    event ProposalCreated(uint256 indexed proposalId, string description, address indexed proposer, uint256 deadline);
    event VoteCast(uint256 indexed proposalId, address indexed voter);
    event ProposalExecuted(uint256 indexed proposalId, string description);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyMember() {
        require(members[msg.sender], "Only members can perform this action");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
        membershipDate[msg.sender] = block.timestamp;
        memberCount = 1;
    }
    
    /**
     * @dev Function 1: Add a new member to the DAO
     * @param _member Address of the new member to be added
     */
    function addMember(address _member) public onlyOwner {
        require(_member != address(0), "Invalid address");
        require(!members[_member], "Already a member");
        
        members[_member] = true;
        membershipDate[_member] = block.timestamp;
        memberCount++;
        
        emit MemberAdded(_member, block.timestamp);
    }
    
    /**
     * @dev Function 2: Create a new proposal for DAO members to vote on
     * @param _description Description of the proposal
     */
    function createProposal(string memory _description) public onlyMember returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        uint256 deadline = block.timestamp + VOTING_PERIOD;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = _description;
        newProposal.voteCount = 0;
        newProposal.deadline = deadline;
        newProposal.executed = false;
        newProposal.proposer = msg.sender;
        
        emit ProposalCreated(proposalId, _description, msg.sender, deadline);
        
        return proposalId;
    }
    
    /**
     * @dev Function 3: Vote on an active proposal
     * @param _proposalId ID of the proposal to vote on
     */
    function voteOnProposal(uint256 _proposalId) public onlyMember {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp < proposal.deadline, "Voting period has ended");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.voters[msg.sender], "Already voted on this proposal");
        
        proposal.voters[msg.sender] = true;
        proposal.voteCount++;
        
        emit VoteCast(_proposalId, msg.sender);
        
        // Auto-execute if minimum votes reached
        if (proposal.voteCount >= MINIMUM_VOTES && !proposal.executed) {
            proposal.executed = true;
            emit ProposalExecuted(_proposalId, proposal.description);
        }
    }
    
    /**
     * @dev Get proposal details
     * @param _proposalId ID of the proposal
     */
    function getProposal(uint256 _proposalId) public view returns (
        uint256 id,
        string memory description,
        uint256 voteCount,
        uint256 deadline,
        bool executed,
        address proposer
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        return (
            proposal.id,
            proposal.description,
            proposal.voteCount,
            proposal.deadline,
            proposal.executed,
            proposal.proposer
        );
    }
    
    /**
     * @dev Check if an address has voted on a proposal
     * @param _proposalId ID of the proposal
     * @param _voter Address of the voter
     */
    function hasVoted(uint256 _proposalId, address _voter) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[_proposalId].voters[_voter];
    }
    
    /**
     * @dev Check if a proposal is active (not expired and not executed)
     * @param _proposalId ID of the proposal
     */
    function isProposalActive(uint256 _proposalId) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        return block.timestamp < proposal.deadline && !proposal.executed;
    }
}
