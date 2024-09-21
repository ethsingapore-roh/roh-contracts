// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract ROHGame is Ownable, ReentrancyGuard {
    IERC20 public usdcToken;
    uint256 public constant START_HEALTH = 100;
    uint256 public constant STAKE_AMOUNT = 5 * 10**6; // 5 USDC (assuming 6 decimals)

    struct Player {
        uint256 health;
        uint256 stakedAmount;
        bool isActive;
        uint256[] attributeIds;
    }

    struct Attribute {
        string description;
        int256 healthChange;
    }

    mapping(address => Player) public players;
    mapping(uint256 => Attribute) public attributes;
    uint256 public attributeCounter;

    uint256 public totalStaked;
    uint256 public contractBalance;

    event PlayerJoined(address player);
    event PlayerLeft(address player);
    event PlayerDied(address player);
    event HealthUpdated(address player, uint256 newHealth);
    event StakeUpdated(address player, uint256 newStake);
    event AttributeCreated(uint256 attributeId, string description, int256 healthChange);
    event AttributeModified(uint256 attributeId, int256 newHealthChange);
    event AttributeAddedToPlayer(address player, uint256 attributeId);
    event AttributeRemovedFromPlayer(address player, uint256 attributeId);

    constructor(address _usdcToken) Ownable(msg.sender) {
        usdcToken = IERC20(_usdcToken);
    }

    function joinGame() external nonReentrant {
        require(!players[msg.sender].isActive, "Player already in game");
        require(usdcToken.transferFrom(msg.sender, address(this), STAKE_AMOUNT), "Stake transfer failed");
        players[msg.sender] = Player({
            health: START_HEALTH,
            stakedAmount: STAKE_AMOUNT,
            isActive: true,
            attributeIds: new uint256[](0)
        });
        totalStaked += STAKE_AMOUNT;
        contractBalance += STAKE_AMOUNT;
        emit PlayerJoined(msg.sender);
    }

    function leaveGame() external nonReentrant {
        Player storage player = players[msg.sender];
        require(player.isActive, "Player not in game");
        uint256 amountToReturn = player.stakedAmount;
        delete players[msg.sender];
        totalStaked -= amountToReturn;
        contractBalance -= amountToReturn;
        require(usdcToken.transfer(msg.sender, amountToReturn), "Return transfer failed");
        emit PlayerLeft(msg.sender);
    }

    function updateHealth(address playerAddress, uint256 newHealth) external onlyOwner {
        Player storage player = players[playerAddress];
        require(player.isActive, "Player not in game");
        player.health = newHealth;
        if (newHealth == 0) {
            uint256 stakedAmount = player.stakedAmount;
            delete players[playerAddress];
            totalStaked -= stakedAmount;
            emit PlayerDied(playerAddress);
        } else {
            emit HealthUpdated(playerAddress, newHealth);
        }
    }

    function updateStake(address playerAddress, uint256 newStake) external onlyOwner {
        Player storage player = players[playerAddress];
        require(player.isActive, "Player not in game");
        require(newStake <= contractBalance, "Insufficient contract balance");
        uint256 stakeDifference = newStake > player.stakedAmount ? 
            newStake - player.stakedAmount : 
            player.stakedAmount - newStake;
        if (newStake > player.stakedAmount) {
            totalStaked += stakeDifference;
            contractBalance -= stakeDifference;
        } else {
            totalStaked -= stakeDifference;
            contractBalance += stakeDifference;
        }
        player.stakedAmount = newStake;
        emit StakeUpdated(playerAddress, newStake);
    }

    function getPlayerInfo(address playerAddress) external view returns (uint256 health, uint256 stakedAmount, bool isActive, uint256[] memory attributeIds) {
        Player memory player = players[playerAddress];
        return (player.health, player.stakedAmount, player.isActive, player.attributeIds);
    }

    function getContractInfo() external view returns (uint256, uint256) {
        return (totalStaked, contractBalance);
    }

    // New functions for attribute management

    function createAttribute(string memory description, int256 healthChange) external onlyOwner {
        attributeCounter++;
        attributes[attributeCounter] = Attribute(description, healthChange);
        emit AttributeCreated(attributeCounter, description, healthChange);
    }

    function modifyAttribute(uint256 attributeId, int256 newHealthChange) external onlyOwner {
        require(attributes[attributeId].healthChange != 0, "Attribute does not exist");
        attributes[attributeId].healthChange = newHealthChange;
        emit AttributeModified(attributeId, newHealthChange);
    }

    function addAttributeToPlayer(address playerAddress, uint256 attributeId) external onlyOwner {
        Player storage player = players[playerAddress];
        require(player.isActive, "Player not in game");
        require(attributes[attributeId].healthChange != 0, "Attribute does not exist");

        player.attributeIds.push(attributeId);
        updatePlayerHealth(playerAddress, int256(attributes[attributeId].healthChange));
        emit AttributeAddedToPlayer(playerAddress, attributeId);
    }

    function removeAttributeFromPlayer(address playerAddress, uint256 attributeId) external onlyOwner {
        Player storage player = players[playerAddress];
        require(player.isActive, "Player not in game");

        for (uint i = 0; i < player.attributeIds.length; i++) {
            if (player.attributeIds[i] == attributeId) {
                player.attributeIds[i] = player.attributeIds[player.attributeIds.length - 1];
                player.attributeIds.pop();
                updatePlayerHealth(playerAddress, -int256(attributes[attributeId].healthChange));
                emit AttributeRemovedFromPlayer(playerAddress, attributeId);
                break;
            }
        }
    }

    function updatePlayerHealth(address playerAddress, int256 healthChange) private {
        Player storage player = players[playerAddress];
        if (healthChange > 0) {
            player.health = player.health + uint256(healthChange);
        } else {
            player.health = player.health > uint256(-healthChange) ? player.health - uint256(-healthChange) : 0;
        }

        if (player.health == 0) {
            uint256 stakedAmount = player.stakedAmount;
            delete players[playerAddress];
            totalStaked -= stakedAmount;
            emit PlayerDied(playerAddress);
        } else {
            emit HealthUpdated(playerAddress, player.health);
        }
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
