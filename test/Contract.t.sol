// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Contract.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUSDC is IERC20 {
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;

    function transfer(address to, uint256 amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowances[from][msg.sender] >= amount, "Insufficient allowance");
        allowances[from][msg.sender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }

    function decimals() external pure returns (uint8) {
        return 6;
    }

    function symbol() external pure returns (string memory) {
        return "USDC";
    }

    function name() external pure returns (string memory) {
        return "USD Coin";
    }
}

contract ROHGameTest is Test {
    ROHGame public game;
    MockUSDC public usdc;
    address public owner;
    address public player1;
    address public player2;

    uint256 constant STAKE_AMOUNT = 5 * 10**6; // 5 USDC

    function setUp() public {
        usdc = new MockUSDC();
        owner = address(this);
        player1 = address(0x1);
        player2 = address(0x2);

        game = new ROHGame(owner , address(usdc));

        // Mint some USDC for players
        usdc.mint(player1, STAKE_AMOUNT * 10);
        usdc.mint(player2, STAKE_AMOUNT * 10);
    }

    function testJoinGame() public {
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        (uint256 health, uint256 stakedAmount, bool isActive, ) = game.getPlayerInfo(player1);
        assertEq(health, 100);
        assertEq(stakedAmount, STAKE_AMOUNT);
        assertTrue(isActive);
    }

    function testLeaveGame() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();

        // Then leave the game
        game.leaveGame();
        vm.stopPrank();

        (uint256 health, uint256 stakedAmount, bool isActive, ) = game.getPlayerInfo(player1);
        assertEq(health, 0);
        assertEq(stakedAmount, 0);
        assertFalse(isActive);
        uint256 balance = usdc.balanceOf(player1);
        assertEq(balance,  STAKE_AMOUNT * 10);
    }

    function testUpdateHealth() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        // Update health
        vm.startPrank(owner);
        game.updateHealth(player1, 50);
        vm.stopPrank();

        (uint256 health, , , ) = game.getPlayerInfo(player1);
        assertEq(health, 50);
    }

    function testUpdateStake() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        // Update stake
        uint256 newStake = STAKE_AMOUNT / 2;
        vm.startPrank(owner);
        game.updateStake(player1, newStake);
        vm.stopPrank();

        (, uint256 stakedAmount, , ) = game.getPlayerInfo(player1);
        assertEq(stakedAmount, newStake);
        uint256 restStaked = game.totalStaked();
        assertEq(restStaked, STAKE_AMOUNT / 2);
    }

    function testCreateAttribute() public {
        vm.startPrank(owner);
        game.createAttribute("Hungry", -10);
        vm.stopPrank();
        (string memory description, int256 healthChange) = game.attributes(1);
        assertEq(description, "Hungry");
        assertEq(healthChange, -10);
    }

    function testModifyAttribute() public {
        vm.startPrank(owner);
        game.createAttribute("Hungry", -10);
        game.modifyAttribute(1, -15);
        (, int256 healthChange) = game.attributes(1);
        assertEq(healthChange, -15);
        vm.stopPrank();
    }

    function testAddAttributeToPlayer() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        // Create and add attribute
        vm.startPrank(owner);
        game.createAttribute("Hungry", -10);
        game.addAttributeToPlayer(player1, 1);
        vm.stopPrank();

        (uint256 health, , , uint256[] memory attributeIds) = game.getPlayerInfo(player1);
        assertEq(health, 90);
        assertEq(attributeIds.length, 1);
        assertEq(attributeIds[0], 1);
    }

    function testRemoveAttributeFromPlayer() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        // Create and add attribute
        vm.startPrank(owner);
        game.createAttribute("Hungry", -10);
        game.addAttributeToPlayer(player1, 1);

        // Remove attribute
        game.removeAttributeFromPlayer(player1, 1);

        (uint256 health, , , uint256[] memory attributeIds) = game.getPlayerInfo(player1);
        assertEq(health, 100);
        assertEq(attributeIds.length, 0);
        vm.stopPrank();
    }

    function testMultipleAttributes() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        // Create and add multiple attributes
        vm.startPrank(owner);
        game.createAttribute("Hungry", -10);
        game.createAttribute("Poisoned", -20);
        game.createAttribute("Healed", 15);

        game.addAttributeToPlayer(player1, 1);
        game.addAttributeToPlayer(player1, 2);
        game.addAttributeToPlayer(player1, 3);
        vm.stopPrank();

        (uint256 health, , , uint256[] memory attributeIds) = game.getPlayerInfo(player1);
        assertEq(health, 85);
        assertEq(attributeIds.length, 3);
    }

    function testPlayerDeath() public {
        // First join the game
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        // Create and add a lethal attribute
        vm.startPrank(owner);
        game.createAttribute("Instant Death", -100);
        game.addAttributeToPlayer(player1, 1);

        (, , bool isActive, ) = game.getPlayerInfo(player1);
        assertFalse(isActive);
    }

    function testGetContractInfo() public {
        vm.startPrank(player1);
        usdc.approve(address(game), STAKE_AMOUNT);
        game.joinGame();
        vm.stopPrank();

        (uint256 totalStaked, uint256 contractBalance) = game.getContractInfo();
        assertEq(totalStaked, STAKE_AMOUNT);
        assertEq(contractBalance, STAKE_AMOUNT);
    }
}
