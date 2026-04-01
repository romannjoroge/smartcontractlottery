// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address vrfCoordinator = config.vrfCoordinator;
        uint256 subId = config.subscriptionid;

        // Create subscription if needed
        if (subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (subId, ) = createSubscription.createSubscriptionFromAddress(vrfCoordinator);

            // Fund subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundUsingAddress(config.link, vrfCoordinator, subId);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            subId,
            vrfCoordinator,
            config.gasLane,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        // Add raffle as consumer
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subId);

        return (raffle, helperConfig);
    }
}
