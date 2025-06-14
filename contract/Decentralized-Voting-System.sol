// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VotingSystem
 * @dev Decentralized voting system with transparent, tamper-proof elections
 */
contract VotingSystem {
    
    struct Candidate {
        uint256 id;
        string name;
        string party;
        string manifesto;
        uint256 voteCount;
        bool isActive;
    }
    
    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint256 votedCandidateId;
        uint256 registrationTime;
    }
    
    struct Election {
        string title;
        string description;
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        bool resultsPublished;
        uint256[] candidateIds;
        uint256 totalVotes;
        uint256 winnerCandidateId;
    }
    
    address public electionCommission;
    Election public currentElection;
    
    mapping(uint256 => Candidate) public candidates;
    mapping(address => Voter) public voters;
    mapping(address => bool) public authorizedRegistrars;
    
    uint256 public candidateCounter;
    uint256 public registeredVotersCount;
    uint256 public totalVotesCast;
    
    // Events
    event ElectionCreated(
        string title,
        uint256 startTime,
        uint256 endTime
    );
    
    event CandidateRegistered(
        uint256 indexed candidateId,
        string name,
        string party
    );
    
    event VoterRegistered(
        address indexed voter,
        uint256 registrationTime
    );
    
    event VoteCast(
        address indexed voter,
        uint256 indexed candidateId,
        uint256 timestamp
    );
    
    event ElectionEnded(
        uint256 totalVotes,
        uint256 winnerCandidateId,
        string winnerName
    );
    
    event ResultsPublished(
        uint256 winnerCandidateId,
        uint256 winningVoteCount
    );
    
    // Modifiers
    modifier onlyElectionCommission() {
        require(
            msg.sender == electionCommission,
            "Only Election Commission can perform this action"
        );
        _;
    }
    
    modifier onlyAuthorizedRegistrar() {
        require(
            authorizedRegistrars[msg.sender] || msg.sender == electionCommission,
            "Only authorized registrars can perform this action"
        );
        _;
    }
    
    modifier onlyRegisteredVoter() {
        require(voters[msg.sender].isRegistered, "Voter not registered");
        _;
    }
    
    modifier electionActive() {
        require(currentElection.isActive, "No active election");
        require(
            block.timestamp >= currentElection.startTime &&
            block.timestamp <= currentElection.endTime,
            "Election not in voting period"
        );
        _;
    }
    
    modifier electionNotActive() {
        require(
            !currentElection.isActive ||
            block.timestamp > currentElection.endTime,
            "Election is currently active"
        );
        _;
    }
    
    modifier hasNotVoted() {
        require(!voters[msg.sender].hasVoted, "Voter has already voted");
        _;
    }
    
    constructor() {
        electionCommission = msg.sender;
        authorizedRegistrars[msg.sender] = true;
    }
    
    /**
     * @dev Create a new election
     * @param _title Election title
     * @param _description Election description
     * @param _durationInHours Election duration in hours
     */
    function createElection(
        string memory _title,
        string memory _description,
        uint256 _durationInHours
    ) external onlyElectionCommission electionNotActive {
        require(_durationInHours > 0, "Duration must be greater than 0");
        require(bytes(_title).length > 0, "Title cannot be empty");
        
        // Reset previous election data
        if (currentElection.candidateIds.length > 0) {
            for (uint256 i = 0; i < currentElection.candidateIds.length; i++) {
                delete candidates[currentElection.candidateIds[i]];
            }
        }
        
        // Reset counters
        candidateCounter = 0;
        totalVotesCast = 0;
        
        // Create new election
        currentElection = Election({
            title: _title,
            description: _description,
            startTime: block.timestamp,
            endTime: block.timestamp + (_durationInHours * 1 hours),
            isActive: true,
            resultsPublished: false,
            candidateIds: new uint256[](0),
            totalVotes: 0,
            winnerCandidateId: 0
        });
        
        emit ElectionCreated(_title, currentElection.startTime, currentElection.endTime);
    }
    
    /**
     * @dev Register a candidate for the current election
     * @param _name Candidate name
     * @param _party Political party
     * @param _manifesto Candidate manifesto/platform
     */
    function registerCandidate(
        string memory _name,
        string memory _party,
        string memory _manifesto
    ) external onlyElectionCommission {
        require(currentElection.isActive, "No active election");
        require(
            block.timestamp < currentElection.startTime,
            "Registration period has ended"
        );
        require(bytes(_name).length > 0, "Name cannot be empty");
        
        uint256 candidateId = candidateCounter++;
        
        candidates[candidateId] = Candidate({
            id: candidateId,
            name: _name,
            party: _party,
            manifesto: _manifesto,
            voteCount: 0,
            isActive: true
        });
        
        currentElection.candidateIds.push(candidateId);
        
        emit CandidateRegistered(candidateId, _name, _party);
    }
    
    /**
     * @dev Register a voter
     * @param _voterAddress Address of the voter to register
     */
    function registerVoter(address _voterAddress) 
        external 
        onlyAuthorizedRegistrar 
    {
        require(_voterAddress != address(0), "Invalid voter address");
        require(!voters[_voterAddress].isRegistered, "Voter already registered");
        
        voters[_voterAddress] = Voter({
            isRegistered: true,
            hasVoted: false,
            votedCandidateId: 0,
            registrationTime: block.timestamp
        });
        
        registeredVotersCount++;
        
        emit VoterRegistered(_voterAddress, block.timestamp);
    }
    
    /**
     * @dev Cast a vote for a candidate
     * @param _candidateId ID of the candidate to vote for
     */
    function castVote(uint256 _candidateId) 
        external 
        onlyRegisteredVoter 
        electionActive 
        hasNotVoted 
    {
        require(_candidateId < candidateCounter, "Invalid candidate ID");
        require(candidates[_candidateId].isActive, "Candidate not active");
        
        // Record the vote
        voters[msg.sender].hasVoted = true;
        voters[msg.sender].votedCandidateId = _candidateId;
        
        // Update candidate vote count
        candidates[_candidateId].voteCount++;
        
        // Update election totals
        currentElection.totalVotes++;
        totalVotesCast++;
        
        emit VoteCast(msg.sender, _candidateId, block.timestamp);
    }
    
    /**
     * @dev End the current election and calculate results
     */
    function endElection() external onlyElectionCommission {
        require(currentElection.isActive, "No active election");
        require(
            block.timestamp >= currentElection.endTime,
            "Election period not yet ended"
        );
        
        currentElection.isActive = false;
        
        // Find winner
        uint256 maxVotes = 0;
        uint256 winnerId = 0;
        
        for (uint256 i = 0; i < currentElection.candidateIds.length; i++) {
            uint256 candidateId = currentElection.candidateIds[i];
            if (candidates[candidateId].voteCount > maxVotes) {
                maxVotes = candidates[candidateId].voteCount;
                winnerId = candidateId;
            }
        }
        
        currentElection.winnerCandidateId = winnerId;
        
        emit ElectionEnded(
            currentElection.totalVotes,
            winnerId,
            candidates[winnerId].name
        );
    }
    
    /**
     * @dev Publish election results (makes results publicly viewable)
     */
    function publishResults() external onlyElectionCommission {
        require(!currentElection.isActive, "Election still active");
        require(!currentElection.resultsPublished, "Results already published");
        
        currentElection.resultsPublished = true;
        
        emit ResultsPublished(
            currentElection.winnerCandidateId,
            candidates[currentElection.winnerCandidateId].voteCount
        );
    }
    
    // View Functions
    function getElectionDetails() external view returns (
        string memory title,
        string memory description,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        bool resultsPublished,
        uint256 totalVotes,
        uint256 candidateCount
    ) {
        return (
            currentElection.title,
            currentElection.description,
            currentElection.startTime,
            currentElection.endTime,
            currentElection.isActive,
            currentElection.resultsPublished,
            currentElection.totalVotes,
            currentElection.candidateIds.length
        );
    }
    
    function getCandidateDetails(uint256 _candidateId) external view returns (
        uint256 id,
        string memory name,
        string memory party,
        string memory manifesto,
        uint256 voteCount,
        bool isActive
    ) {
        require(_candidateId < candidateCounter, "Invalid candidate ID");
        Candidate memory candidate = candidates[_candidateId];
        return (
            candidate.id,
            candidate.name,
            candidate.party,
            candidate.manifesto,
            candidate.voteCount,
            candidate.isActive
        );
    }
    
    function getVoterStatus(address _voter) external view returns (
        bool isRegistered,
        bool hasVoted,
        uint256 votedCandidateId,
        uint256 registrationTime
    ) {
        Voter memory voter = voters[_voter];
        return (
            voter.isRegistered,
            voter.hasVoted,
            voter.votedCandidateId,
            voter.registrationTime
        );
    }
    
    function getElectionResults() external view returns (
        uint256 winnerCandidateId,
        string memory winnerName,
        uint256 winningVoteCount,
        uint256 totalVotes
    ) {
        require(!currentElection.isActive, "Election still active");
        require(currentElection.resultsPublished, "Results not yet published");
        
        return (
            currentElection.winnerCandidateId,
            candidates[currentElection.winnerCandidateId].name,
            candidates[currentElection.winnerCandidateId].voteCount,
            currentElection.totalVotes
        );
    }
    
    function getAllCandidates() external view returns (uint256[] memory) {
        return currentElection.candidateIds;
    }
    
    function getVotingStats() external view returns (
        uint256 totalRegisteredVoters,
        uint256 totalVotesCast,
        uint256 turnoutPercentage
    ) {
        uint256 turnout = 0;
        if (registeredVotersCount > 0) {
            turnout = (totalVotesCast * 100) / registeredVotersCount;
        }
        
        return (registeredVotersCount, totalVotesCast, turnout);
    }
    
    // Admin functions
    function addAuthorizedRegistrar(address _registrar) external onlyElectionCommission {
        authorizedRegistrars[_registrar] = true;
    }
    
    function removeAuthorizedRegistrar(address _registrar) external onlyElectionCommission {
        require(_registrar != electionCommission, "Cannot remove election commission");
        authorizedRegistrars[_registrar] = false;
    }
    
    function transferElectionCommission(address _newCommission) external onlyElectionCommission {
        require(_newCommission != address(0), "Invalid address");
        electionCommission = _newCommission;
        authorizedRegistrars[_newCommission] = true;
    }
    
    // Emergency functions
    function emergencyPause() external onlyElectionCommission {
        currentElection.isActive = false;
    }
    
    function emergencyResume() external onlyElectionCommission {
        require(block.timestamp <= currentElection.endTime, "Election period has ended");
        currentElection.isActive = true;
    }
}
