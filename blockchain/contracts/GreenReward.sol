// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

struct RecyclingActivity {
    uint256 weightKg;
    uint8 materialScore;
    uint64 timestamp;
}

contract GreenReward is ERC20, Ownable {
    mapping(address => RecyclingActivity[]) private _activities;
    mapping(string => uint8) public materialWeights;

    event ActivityRecorded(address indexed user, string material, uint256 weightKg, uint256 points);

    constructor() ERC20("Green Reward Token", "GRT") Ownable(msg.sender) {
        materialWeights["plastic"] = 10;
        materialWeights["glass"] = 12;
        materialWeights["paper"] = 8;
        materialWeights["metal"] = 15;
        materialWeights["electronics"] = 20;
    }

    function setMaterialWeight(string calldata material, uint8 weight) external onlyOwner {
        materialWeights[material] = weight;
    }

    function recordActivity(
        address user,
        string calldata material,
        uint256 weightKg
    ) external onlyOwner returns (uint256 reward) {
        uint8 multiplier = materialWeights[material];
        require(multiplier > 0, "Unsupported material");

        reward = weightKg * multiplier;
        _mint(user, reward);

        _activities[user].push(RecyclingActivity({
            weightKg: weightKg,
            materialScore: multiplier,
            timestamp: uint64(block.timestamp)
        }));

        emit ActivityRecorded(user, material, weightKg, reward);
    }

    function getUserActivities(address user) external view returns (RecyclingActivity[] memory) {
        return _activities[user];
    }
}
