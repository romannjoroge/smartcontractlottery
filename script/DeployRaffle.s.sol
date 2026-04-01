// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public returns (Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Create subscription if needed
        if (config.subscriptionid == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionid, config.vrfCoordinator) = createSubscription.run();

            // Fund subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundUsingAddress(config.link, config.vrfCoordinator, config.subscriptionid);
        }

        

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.subscriptionid,
            config.vrfCoordinator,
            config.gasLane,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        return (raffle, helperConfig);
    }
}
