// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionFromConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAddress = helperConfig.getConfig().vrfCoordinator;
        return createSubscriptionFromAddress(vrfCoordinatorAddress);
    }

    function createSubscriptionFromAddress(address vrfCoordinatorAddress) public returns (uint256, address) {
        console.log("Create subscription with vrf: ", vrfCoordinatorAddress);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);
        uint256 subscriptionID = vrfCoordinator.createSubscription();
        vm.stopBroadcast();
        return (subscriptionID, vrfCoordinatorAddress);
    }

    function run() external returns (uint256, address) {
        return createSubscriptionFromConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3e18; // 3 LINK

    function fundUsingAddress(address linkTokenAddress, address vrfCoordinatorAddress, uint256 subscriptionid) public {
        console.log("Funding vrfCoordinator: ", vrfCoordinatorAddress);
        console.log("With Link token: ", linkTokenAddress);
        console.log("With amount: ", FUND_AMOUNT);
        console.log("On chain: ", block.chainid);
        console.log("In subscription: ", subscriptionid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock vrfCoordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);
            vrfCoordinator.fundSubscription(subscriptionid, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken linkToken = LinkToken(linkTokenAddress);
            linkToken.transferAndCall(vrfCoordinatorAddress, FUND_AMOUNT, abi.encode(subscriptionid));
            vm.stopBroadcast();
        }
    }

    function fundUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        address vrfCoordinator = networkConfig.vrfCoordinator;
        if (networkConfig.subscriptionid == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionid, ) = createSubscription.createSubscriptionFromAddress(vrfCoordinator);
        }

        fundUsingAddress(networkConfig.link, vrfCoordinator, networkConfig.subscriptionid);
    }

    function run() external {
        fundUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subscriptionid;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address link = helperConfig.getConfig().link;

        // Create and fund subscription if there isn't one
        if (subId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (subId, ) =  createSubscription.createSubscriptionFromAddress(vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundUsingAddress(link, vrfCoordinator, subId);
        }

        addConsumer(raffle, vrfCoordinator, subId);
    }

    function addConsumer(address consumerAddress, address vrfCoordinator, uint256 subId) public {
        console.log("Adding consumer: ", consumerAddress);
        console.log("To vrfCoordinator: ", vrfCoordinator);
        console.log("With subscription: ", subId);
        console.log("On chain ID: ", block.chainid);

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumerAddress);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffleAddress);
    }
}
