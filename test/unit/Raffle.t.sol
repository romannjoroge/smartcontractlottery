// SPDX-License-Identifier: MIT
pragma solidity >=0.8.18 <0.9.0;

import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTests is Test {
    HelperConfig public helperConfig;
    Raffle public raffle;
    HelperConfig.NetworkConfig public networkConfig;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        networkConfig = helperConfig.getConfig();
    }

    function testRaffleStartsOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
}
