// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <0.9.0;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig, CodeConstants} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function createSubscriptionFromConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAddress = helperConfig.getConfig().vrfCoordinator;
        return createSubscriptionFromAddress(vrfCoordinatorAddress);
    }

    function createSubscriptionFromAddress(address vrfCoordinatorAddress) public returns (uint256, address) {
        VRFCoordinatorV2_5Mock vrfCoordinator = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress);
        uint256 subscriptionID = vrfCoordinator.createSubscription();
        console.log("Create subscription with id: ", subscriptionID, "on vrf with address: ", vrfCoordinatorAddress);
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

    /**
     * @dev This function assumes that the network config has a subscription already configured. It should thus be called
     * after CreateSubscription
     */
    function fundUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();
        if (networkConfig.subscriptionid == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionid, networkConfig.vrfCoordinator) = createSubscription.run();
        }

        fundUsingAddress(networkConfig.link, networkConfig.vrfCoordinator, networkConfig.subscriptionid);
    }

    function run() external {
        fundUsingConfig();
    }
}
