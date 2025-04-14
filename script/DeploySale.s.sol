// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {MockNFT} from "../src/MockNFT.sol";
import {SepoliaSale} from "../src/SepoliaSale.sol";
import {Sale} from "../src/Sale.sol";

/// @dev forge script script/DeploySale.s.sol --rpc-url sepolia --chain sepolia --broadcast --slow
contract DeploySale is Script {
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

        address minedJpeg;
        address butterinCards;
        if (block.chainid == 11155111) {
            // // Deploy mock Mined JPEG and Butterin Cards
            // address minedJpeg = address(new MockNFT("Mined JPEG", "MJ"));
            // address butterinCards = address(
            //     new MockNFT("Butterin Cards", "VITALIK")
            // );
            minedJpeg = 0x8Cde5620D62E03826b114b307A58EB0B637a888a;
            butterinCards = 0x5e7a7E1200d378f07Dd3006F99111bb07c12580f;
        } else {
            minedJpeg = 0x7cd51FA7E155805C34F333ba493608742A67Da8e;
            butterinCards = 0x5726C14663A1EaD4A7D320E8A653c9710b2A2E89;
        }

        // Deploy sale contract
        address sale = block.chainid == 11155111
            ? address(new SepoliaSale(minedJpeg, butterinCards))
            : address(new Sale(minedJpeg, butterinCards));

        console.log("Sale address:", sale);

        vm.stopBroadcast();
    }
}
