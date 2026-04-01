// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <0.9.0;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTests is Test {
    HelperConfig public helperConfig;
    Raffle public raffle;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 public entranceFee;
    uint256 public interval;
    uint256 public subscriptionid;
    address public vrfCoordinator;
    bytes32 public gasLane;
    uint32 public callbackGasLimit;

    event RaffleEntered(address indexed player);

    modifier enterCalculatingState() {
        // Someone should join raffle
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Time interval should pass
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Perform upkeep called
        raffle.performUpkeep("");
        _;
    }

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        subscriptionid = networkConfig.subscriptionid;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        callbackGasLimit = networkConfig.callbackGasLimit;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleStartsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleFailsIfPlayerSendLessThanEntranceFee() public {
        // Arrange
        vm.prank(PLAYER);

        // Act
        vm.expectRevert(Raffle.Raffle__SendMoreETHToEnterRaffle.selector);
        // Assert
        raffle.enterRaffle();
    }

    function testPlayerStoredWhenEnterRaffle() public {
        // Arrange
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        // Act
        raffle.enterRaffle{value: entranceFee}();

        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnterRaffleFailsIfStateNotOpen() public enterCalculatingState {
        // Arrange
        vm.prank(PLAYER);

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__PickingWinner.selector);
        raffle.enterRaffle{value: entranceFee}();
    }
}
