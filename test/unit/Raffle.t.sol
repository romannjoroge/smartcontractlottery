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

    /*//////////////////////////////////////////////////////////////
                            STATE MODIFIERS
    //////////////////////////////////////////////////////////////*/

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

    modifier enterRaffle() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
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
    /*//////////////////////////////////////////////////////////////
                        RAFFLE CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function testRaffleStartsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                           ENTER RAFFLE TESTS
    //////////////////////////////////////////////////////////////*/

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

    /*//////////////////////////////////////////////////////////////
                           CHECK UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/

    function testCheckUpKeepReturnsFalseIfNotOpen() public enterCalculatingState {
       // Act
       (bool upkeepNeeded, ) = raffle.checkUpkeep("");

       // Assert
       assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfContractHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfIntervalNotPassed() public enterRaffle {
        // Arrange / Act
        (bool upKeedNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeedNeeded);
    }

    function testCheckUpKeepReturnsFalseIfNoPlayers() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upKeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upKeepNeeded);
    }

    function testCheckUpKeepReturnsTrueIfPlayersBalanceOpen() public enterRaffle {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                          PERFORM UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/

    function testPerformUpkeepFailsIfCheckUpkeepFalse() public enterRaffle{
        // Arrange / Assert
        uint256 currentBalance = entranceFee;
        uint256 numPlayers = 1;
        uint256 raffleState = uint256(raffle.getRaffleState());

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, raffleState, currentBalance, numPlayers)
        );

        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRunsIfCheckUpkeepTrue() public enterRaffle {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        raffle.performUpkeep("");
    }

    /*//////////////////////////////////////////////////////////////
                         RECEIVE FALLBACK TESTS
    //////////////////////////////////////////////////////////////*/

    function testIfSomeoneSendsETHEnterRaffleCalled() public {
        // Arrange / Assert
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);

        // Act
        (bool success,) = payable(address(raffle)).call{value: entranceFee}("");
        require(success, "Could not make payment");
    }
}
