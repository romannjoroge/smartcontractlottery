// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <0.9.0;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample raffle contract
 * @author Roman Njoroge
 * @notice This contract is for creating a sample raffle
 * @dev Implements Chainlink VRF
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__SendMoreETHToEnterRaffle();
    error Raffle__TooSoonToPickWinner();
    error Raffle__FailedToSendReward();
    error Raffle__PickingWinner();

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    uint256 private immutable I_ENTRANCE_FEE;
    // @dev The time interval t in seconds between raffles
    uint256 private immutable I_INTERVAL;
    // @dev Timestamp of the last time raffle winner was picked
    uint256 private sLastTimestamp;
    address payable[] private sPlayers;
    address payable sRecentWinner;
    RaffleState private sRaffleState;

    // @dev Data needed by Chainlink VRF to pick a random winner
    bytes32 private immutable I_KEYHASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable I_CALLBACK_GAS_LIMIT = 40_000;
    uint32 private constant NUM_WORDS = 1;

    /**
     * Events
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event CalculatingWinner(uint256 timestamp);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        uint256 _subscriptionid,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        I_ENTRANCE_FEE = _entranceFee;
        I_INTERVAL = _interval;
        I_SUBSCRIPTION_ID = _subscriptionid;
        I_KEYHASH = _gasLane;
        I_CALLBACK_GAS_LIMIT = _callbackGasLimit;

        sLastTimestamp = block.timestamp;
        sRaffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__SendMoreETHToEnterRaffle();
        }

        if (sRaffleState != RaffleState.OPEN) {
            revert Raffle__PickingWinner();
        }

        sPlayers.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // Gets a random number, uses it and automatically gets called
    function pickWinner() external {
        // Check that time since last winner was picked is greater than interval
        uint256 timeSinceLastWinnerPicked = block.timestamp - sLastTimestamp;
        if (timeSinceLastWinnerPicked < I_INTERVAL) {
            revert Raffle__TooSoonToPickWinner();
        }

        sRaffleState = RaffleState.CALCULATING;
        emit CalculatingWinner(block.timestamp);

        // Ask for a random number
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: I_KEYHASH,
                subId: I_SUBSCRIPTION_ID,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: I_CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Effects
        uint256 indexOfWinner = randomWords[0] % sPlayers.length;
        address payable recentWinner = sPlayers[indexOfWinner];

        sPlayers = new address payable[](0);
        sRecentWinner = recentWinner;
        sRaffleState = RaffleState.OPEN;
        sLastTimestamp = block.timestamp;
        emit WinnerPicked(recentWinner);
        
        // Interactions
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (success == false) {
            revert Raffle__FailedToSendReward();
        }
    }

    /**
     * Getter Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }
}
