// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Decentralized Autonomous Organization (DAO)
 * @dev An advanced DAO contract for decentralized governance and decision-making
 */
contract Project {
    
    // Struct to represent a proposal
    struct Proposal {
        uint256 id;
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
        bool passed;
        address proposer;
        ProposalType proposalType;
        address targetAddress;
        uint256 amount;
        mapping(address => VoteChoice) voters;
    }
    
    // Enum for vote choices
    enum VoteChoice { None, For, Against }
    
    // Enum for proposal types
    enum ProposalType { General, Treasury, MembershipChange, Constitutional }
    
    // State variables
    address public owner;
    uint256 public proposalCount;
    uint256 public memberCount;
    uint256 public treasuryBalance;
    uint256 public constant VOTING_PERIOD = 7 days;
    uint256 public quorumPercentage = 30; // 30% of members must vote
    uint256 public passThreshold = 60; // 60% must vote in favor
    bool public paused;
    
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public members;
    mapping(address => uint256) public membershipDate;
    mapping(address => uint256) public memberReputation;
    mapping(address => bool) public blacklisted;
    
    // Events
    event MemberAdded(address indexed member, uint256 timestamp);
    event MemberRemoved(address indexed member, uint256 timestamp);
    event ProposalCreated(uint256 indexed proposalId, string description, address indexed proposer, uint256 deadline, ProposalType proposalType);
    event VoteCast(uint256 indexed proposalId, address indexed voter, VoteChoice choice);
    event ProposalExecuted(uint256 indexed proposalId, bool passed);
    event FundsDeposited(address indexed depositor, uint256 amount);
    event FundsWithdrawn(address indexed recipient, uint256 amount);
    event QuorumUpdated(uint256 newQuorum);
    event ThresholdUpdated(uint256 newThreshold);
    event DAOPaused(bool status);
    event ReputationUpdated(address indexed member, uint256 newReputation);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyMember() {
        require(members[msg.sender], "Only members can perform this action");
        require(!blacklisted[msg.sender], "Member is blacklisted");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "DAO is paused");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        members[msg.sender] = true;
        membershipDate[msg.sender] = block.timestamp;
        memberReputation[msg.sender] = 100;
        memberCount = 1;
    }
    
    /**
     * @dev Receive function to accept ETH deposits
     */
    receive() external payable {
        treasuryBalance += msg.value;
        emit FundsDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Function 1: Add a new member to the DAO
     * @param _member Address of the new member to be added
     */
    function addMember(address _member) public onlyOwner whenNotPaused {
        require(_member != address(0), "Invalid address");
        require(!members[_member], "Already a member");
        
        members[_member] = true;
        membershipDate[_member] = block.timestamp;
        memberReputation[_member] = 50; // Starting reputation
        memberCount++;
        
        emit MemberAdded(_member, block.timestamp);
    }
    
    /**
     * @dev Remove a member from the DAO
     * @param _member Address of the member to be removed
     */
    function removeMember(address _member) public onlyOwner whenNotPaused {
        require(members[_member], "Not a member");
        require(_member != owner, "Cannot remove owner");
        
        members[_member] = false;
        blacklisted[_member] = true;
        memberCount--;
        
        emit MemberRemoved(_member, block.timestamp);
    }
    
    /**
     * @dev Function 2: Create a new proposal for DAO members to vote on
     * @param _description Description of the proposal
     * @param _proposalType Type of proposal
     * @param _targetAddress Target address for treasury proposals
     * @param _amount Amount for treasury proposals
     */
    function createProposal(
        string memory _description,
        ProposalType _proposalType,
        address _targetAddress,
        uint256 _amount
    ) public onlyMember whenNotPaused returns (uint256) {
        require(bytes(_description).length > 0, "Description cannot be empty");
        
        if (_proposalType == ProposalType.Treasury) {
            require(_targetAddress != address(0), "Invalid target address");
            require(_amount > 0 && _amount <= treasuryBalance, "Invalid amount");
        }
        
        proposalCount++;
        uint256 proposalId = proposalCount;
        uint256 deadline = block.timestamp + VOTING_PERIOD;
        
        Proposal storage newProposal = proposals[proposalId];
        newProposal.id = proposalId;
        newProposal.description = _description;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.deadline = deadline;
        newProposal.executed = false;
        newProposal.passed = false;
        newProposal.proposer = msg.sender;
        newProposal.proposalType = _proposalType;
        newProposal.targetAddress = _targetAddress;
        newProposal.amount = _amount;
        
        // Increase proposer's reputation
        memberReputation[msg.sender] += 5;
        emit ReputationUpdated(msg.sender, memberReputation[msg.sender]);
        
        emit ProposalCreated(proposalId, _description, msg.sender, deadline, _proposalType);
        
        return proposalId;
    }
    
    /**
     * @dev Function 3: Vote on an active proposal
     * @param _proposalId ID of the proposal to vote on
     * @param _support True for voting in favor, false for voting against
     */
    function voteOnProposal(uint256 _proposalId, bool _support) public onlyMember whenNotPaused {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp < proposal.deadline, "Voting period has ended");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.voters[msg.sender] == VoteChoice.None, "Already voted on this proposal");
        
        VoteChoice choice = _support ? VoteChoice.For : VoteChoice.Against;
        proposal.voters[msg.sender] = choice;
        
        if (_support) {
            proposal.forVotes++;
        } else {
            proposal.againstVotes++;
        }
        
        // Increase voter's reputation
        memberReputation[msg.sender] += 2;
        emit ReputationUpdated(msg.sender, memberReputation[msg.sender]);
        
        emit VoteCast(_proposalId, msg.sender, choice);
    }
    
    /**
     * @dev Execute a proposal after voting period ends
     * @param _proposalId ID of the proposal to execute
     */
    function executeProposal(uint256 _proposalId) public whenNotPaused {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        require(block.timestamp >= proposal.deadline, "Voting period not ended");
        require(!proposal.executed, "Proposal already executed");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 quorumRequired = (memberCount * quorumPercentage) / 100;
        
        require(totalVotes >= quorumRequired, "Quorum not reached");
        
        uint256 forPercentage = (proposal.forVotes * 100) / totalVotes;
        
        proposal.executed = true;
        
        if (forPercentage >= passThreshold) {
            proposal.passed = true;
            
            // Execute treasury transfer if it's a treasury proposal
            if (proposal.proposalType == ProposalType.Treasury) {
                require(treasuryBalance >= proposal.amount, "Insufficient treasury balance");
                treasuryBalance -= proposal.amount;
                payable(proposal.targetAddress).transfer(proposal.amount);
                emit FundsWithdrawn(proposal.targetAddress, proposal.amount);
            }
            
            // Increase proposer's reputation for successful proposal
            memberReputation[proposal.proposer] += 10;
            emit ReputationUpdated(proposal.proposer, memberReputation[proposal.proposer]);
        }
        
        emit ProposalExecuted(_proposalId, proposal.passed);
    }
    
    /**
     * @dev Update quorum percentage (only owner)
     * @param _newQuorum New quorum percentage (0-100)
     */
    function updateQuorum(uint256 _newQuorum) public onlyOwner {
        require(_newQuorum > 0 && _newQuorum <= 100, "Invalid quorum percentage");
        quorumPercentage = _newQuorum;
        emit QuorumUpdated(_newQuorum);
    }
    
    /**
     * @dev Update pass threshold (only owner)
     * @param _newThreshold New pass threshold percentage (0-100)
     */
    function updatePassThreshold(uint256 _newThreshold) public onlyOwner {
        require(_newThreshold > 50 && _newThreshold <= 100, "Threshold must be > 50%");
        passThreshold = _newThreshold;
        emit ThresholdUpdated(_newThreshold);
    }
    
    /**
     * @dev Pause or unpause the DAO (emergency function)
     * @param _paused True to pause, false to unpause
     */
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
        emit DAOPaused(_paused);
    }
    
    /**
     * @dev Get proposal details
     * @param _proposalId ID of the proposal
     */
    function getProposal(uint256 _proposalId) public view returns (
        uint256 id,
        string memory description,
        uint256 forVotes,
        uint256 againstVotes,
        uint256 deadline,
        bool executed,
        bool passed,
        address proposer,
        ProposalType proposalType
    ) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        
        return (
            proposal.id,
            proposal.description,
            proposal.forVotes,
            proposal.againstVotes,
            proposal.deadline,
            proposal.executed,
            proposal.passed,
            proposal.proposer,
            proposal.proposalType
        );
    }
    
    /**
     * @dev Check voting status of an address on a proposal
     * @param _proposalId ID of the proposal
     * @param _voter Address of the voter
     */
    function getVoteChoice(uint256 _proposalId, address _voter) public view returns (VoteChoice) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        return proposals[_proposalId].voters[_voter];
    }
    
    /**
     * @dev Check if a proposal is active
     * @param _proposalId ID of the proposal
     */
    function isProposalActive(uint256 _proposalId) public view returns (bool) {
        require(_proposalId > 0 && _proposalId <= proposalCount, "Invalid proposal ID");
        
        Proposal storage proposal = proposals[_proposalId];
        return block.timestamp < proposal.deadline && !proposal.executed;
    }
    
    /**
     * @dev Get member information
     * @param _member Address of the member
     */
    function getMemberInfo(address _member) public view returns (
        bool isMember,
        uint256 joinDate,
        uint256 reputation,
        bool isBlacklisted
    ) {
        return (
            members[_member],
            membershipDate[_member],
            memberReputation[_member],
            blacklisted[_member]
        );
    }
    
    /**
     * @dev Get DAO statistics
     */
    function getDAOStats() public view returns (
        uint256 totalMembers,
        uint256 totalProposals,
        uint256 treasury,
        uint256 quorum,
        uint256 threshold,
        bool isPaused
    ) {
        return (
            memberCount,
            proposalCount,
            treasuryBalance,
            quorumPercentage,
            passThreshold,
            paused
        );
    }
}
