// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract ROHGame is Ownable, ReentrancyGuard {
    IERC20 public usdcToken;
    uint256 public constant MAX_HEALTH = 100;
    uint256 public constant STAKE_AMOUNT = 5 * 10**6; // 5 USDC (assuming 6 decimals)

    struct Player {
        uint256 health;
        uint256 stakedAmount;
        bool isActive;
    }

    mapping(address => Player) public players;
    uint256 public totalStaked;
    uint256 public contractBalance;

    event PlayerJoined(address player);
    event PlayerLeft(address player);
    event PlayerDied(address player);
    event HealthUpdated(address player, uint256 newHealth);
    event StakeUpdated(address player, uint256 newStake);

    constructor(address _usdcToken) {
        usdcToken = IERC20(_usdcToken);
    }

    function joinGame() external nonReentrant {
        require(!players[msg.sender].isActive, "Player already in game");
        require(usdcToken.transferFrom(msg.sender, address(this), STAKE_AMOUNT), "Stake transfer failed");

        players[msg.sender] = Player({
            health: MAX_HEALTH,
            stakedAmount: STAKE_AMOUNT,
            isActive: true
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
        require(newHealth <= MAX_HEALTH, "Health exceeds maximum");

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

    function getPlayerInfo(address playerAddress) external view returns (uint256 health, uint256 stakedAmount, bool isActive) {
        Player memory player = players[playerAddress];
        return (player.health, player.stakedAmount, player.isActive);
    }

    function getContractInfo() external view returns (uint256 _totalStaked, uint256 _contractBalance) {
        return (totalStaked, contractBalance);
    }
}
