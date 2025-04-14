// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {MockNFT} from "../src/MockNFT.sol";
import {SepoliaSaleV2} from "../src/SepoliaSaleV2.sol";
import {SaleV2} from "../src/SaleV2.sol";

/// @dev forge script script/DeploySaleV2.s.sol --rpc-url sepolia --chain sepolia --broadcast --slow
contract DeploySaleV2 is Script {
    uint256 privateKey;

    function setUp() public {
        privateKey = vm.envUint("SEPOLIA_DEPLOYER_PRIVATE_KEY");

        if (block.chainid == 11155111) {
            privateKey = vm.envUint("SEPOLIA_DEPLOYER_PRIVATE_KEY");
        } else if (block.chainid != 1) {
            revert("Network not supported");
        }
    }

    function run() public {
        vm.startBroadcast(privateKey);

        // Deploy sale contract
        address sale = block.chainid == 11155111
            ? address(new SepoliaSaleV2())
            : address(new SaleV2());

        console.log("Sale address:", sale);

        vm.stopBroadcast();
    }
}
