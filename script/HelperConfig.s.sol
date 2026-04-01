// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <0.9.0;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    /**
     * VRF mock values
     */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_FEE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;
}

contract HelperConfig is Script, CodeConstants {
    /**
     * Errors
     */
    error HelperConfig__UnrecognizedChainID(uint256 chainId);

    /**
     * Type declarations
     */
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        uint256 subscriptionid;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address link;
    }

    /**
     * State Variables
     */
    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainID => NetworkConfig chainConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaConfig();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getConfigByChainId(uint256 chainId) internal returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            // get or create anvil config
            return getOrCreateLocalConfig();
        } else if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else {
            revert HelperConfig__UnrecognizedChainID(chainId);
        }
    }

    function getSepoliaConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            subscriptionid: 0,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateLocalConfig() internal returns (NetworkConfig memory) {
        // If local config not there create it
        if (localNetworkConfig.vrfCoordinator == address(0)) {
            // Deploy mock Chainlink VRF
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock mockVrf =
                new VRFCoordinatorV2_5Mock(MOCK_BASE_FEE, MOCK_GAS_FEE, MOCK_WEI_PER_UNIT_LINK);
            LinkToken linkToken = new LinkToken();
            vm.stopBroadcast();
            // Return details
            return NetworkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                subscriptionid: 0,
                vrfCoordinator: address(mockVrf),
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                callbackGasLimit: 500000,
                link: address(linkToken)
            });
        } else {
            return localNetworkConfig;
        }
    }
}
