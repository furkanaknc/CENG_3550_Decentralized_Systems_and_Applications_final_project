// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PickupManager
 * @notice Manages pickup requests and courier assignments on-chain
 */
contract PickupManager is Ownable {
    enum PickupStatus { Pending, Assigned, Completed, Cancelled }
    
    enum UserRole { None, User, Courier, Admin }

    struct Pickup {
        string pickupId;          // Off-chain pickup ID for reference
        address user;             // User who created the pickup
        address courier;          // Assigned courier (0x0 if not assigned)
        PickupStatus status;      // Current status
        string material;          // Type of material
        uint256 weightKg;         // Weight in kg (scaled by 100, e.g., 150 = 1.5kg)
        uint256 createdAt;        // Timestamp when created
        uint256 assignedAt;       // Timestamp when assigned to courier
        uint256 completedAt;      // Timestamp when completed
    }

    // Mapping from pickup ID (hash of off-chain ID) to Pickup struct
    mapping(bytes32 => Pickup) public pickups;
    
    // Mapping from address to user role
    mapping(address => UserRole) public userRoles;
    
    // List of all pickup IDs
    bytes32[] public pickupIds;
    
    // Mapping from courier address to their active pickup count
    mapping(address => uint256) public courierActivePickups;

    // Events
    event PickupCreated(
        bytes32 indexed pickupIdHash,
        string pickupId,
        address indexed user,
        string material,
        uint256 weightKg
    );
    
    event PickupAssigned(
        bytes32 indexed pickupIdHash,
        string pickupId,
        address indexed courier,
        uint256 timestamp
    );
    
    event PickupCompleted(
        bytes32 indexed pickupIdHash,
        string pickupId,
        address indexed courier,
        uint256 timestamp
    );
    
    event RoleAssigned(address indexed user, UserRole role);

    constructor() Ownable(msg.sender) {
        // Assign admin role to contract deployer
        userRoles[msg.sender] = UserRole.Admin;
        emit RoleAssigned(msg.sender, UserRole.Admin);
    }

    modifier onlyRole(UserRole requiredRole) {
        require(userRoles[msg.sender] == requiredRole, "Unauthorized: insufficient role");
        _;
    }

    modifier onlyCourier() {
        require(
            userRoles[msg.sender] == UserRole.Courier || userRoles[msg.sender] == UserRole.Admin,
            "Unauthorized: courier role required"
        );
        _;
    }

    /**
     * @notice Assign a role to a user (admin only)
     */
    function assignRole(address user, UserRole role) external onlyOwner {
        require(user != address(0), "Invalid address");
        userRoles[user] = role;
        emit RoleAssigned(user, role);
    }

    /**
     * @notice Create a new pickup request
     */
    function createPickup(
        string calldata pickupId,
        string calldata material,
        uint256 weightKg
    ) external returns (bytes32) {
        require(bytes(pickupId).length > 0, "Invalid pickup ID");
        require(weightKg > 0, "Weight must be greater than 0");
        
        // If user doesn't have a role, assign 'User' role automatically
        if (userRoles[msg.sender] == UserRole.None) {
            userRoles[msg.sender] = UserRole.User;
            emit RoleAssigned(msg.sender, UserRole.User);
        }

        bytes32 pickupIdHash = keccak256(bytes(pickupId));
        
        require(pickups[pickupIdHash].createdAt == 0, "Pickup already exists");

        pickups[pickupIdHash] = Pickup({
            pickupId: pickupId,
            user: msg.sender,
            courier: address(0),
            status: PickupStatus.Pending,
            material: material,
            weightKg: weightKg,
            createdAt: block.timestamp,
            assignedAt: 0,
            completedAt: 0
        });

        pickupIds.push(pickupIdHash);

        emit PickupCreated(pickupIdHash, pickupId, msg.sender, material, weightKg);
        
        return pickupIdHash;
    }

    /**
     * @notice Assign a pickup to a courier (courier can self-assign)
     */
    function acceptPickup(string calldata pickupId) external onlyCourier {
        bytes32 pickupIdHash = keccak256(bytes(pickupId));
        Pickup storage pickup = pickups[pickupIdHash];

        require(pickup.createdAt > 0, "Pickup does not exist");
        require(pickup.status == PickupStatus.Pending, "Pickup not available");

        pickup.courier = msg.sender;
        pickup.status = PickupStatus.Assigned;
        pickup.assignedAt = block.timestamp;
        
        courierActivePickups[msg.sender]++;

        emit PickupAssigned(pickupIdHash, pickupId, msg.sender, block.timestamp);
    }

    /**
     * @notice Complete a pickup (only assigned courier can complete)
     */
    function completePickup(string calldata pickupId) external onlyCourier {
        bytes32 pickupIdHash = keccak256(bytes(pickupId));
        Pickup storage pickup = pickups[pickupIdHash];

        require(pickup.createdAt > 0, "Pickup does not exist");
        require(pickup.status == PickupStatus.Assigned, "Pickup not assigned");
        require(pickup.courier == msg.sender, "Not the assigned courier");

        pickup.status = PickupStatus.Completed;
        pickup.completedAt = block.timestamp;
        
        if (courierActivePickups[msg.sender] > 0) {
            courierActivePickups[msg.sender]--;
        }

        emit PickupCompleted(pickupIdHash, pickupId, msg.sender, block.timestamp);
    }

    /**
     * @notice Get pickup details by ID
     */
    function getPickup(string calldata pickupId) external view returns (Pickup memory) {
        bytes32 pickupIdHash = keccak256(bytes(pickupId));
        require(pickups[pickupIdHash].createdAt > 0, "Pickup does not exist");
        return pickups[pickupIdHash];
    }

    /**
     * @notice Get total number of pickups
     */
    function getPickupCount() external view returns (uint256) {
        return pickupIds.length;
    }

    /**
     * @notice Get pickup by index
     */
    function getPickupByIndex(uint256 index) external view returns (Pickup memory) {
        require(index < pickupIds.length, "Index out of bounds");
        return pickups[pickupIds[index]];
    }

    /**
     * @notice Get user's role
     */
    function getRole(address user) external view returns (UserRole) {
        return userRoles[user];
    }
}

