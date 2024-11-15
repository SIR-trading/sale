// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {MockNFT} from "../src/MockNFT.sol";
import {SepoliaSale} from "../src/SepoliaSale.sol";

/// @dev forge script script/DeployToSepolia.s.sol --rpc-url sepolia --chain sepolia --broadcast --slow
contract DeployToSepolia is Script {
    uint256 privateKey;

    function setUp() public {
        privateKey = vm.envUint("SEPOLIA_DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(privateKey);

        // // Deploy mock Mined JPEG and Butterin Cards
        // address minedJpeg = address(new MockNFT("Mined JPEG", "MJ"));
        // address butterinCards = address(
        //     new MockNFT("Butterin Cards", "VITALIK")
        // );
        address minedJpeg = 0x8Cde5620D62E03826b114b307A58EB0B637a888a;
        address butterinCards = 0x5e7a7E1200d378f07Dd3006F99111bb07c12580f;

        // console.log("Mined JPEG address:", minedJpeg);
        // console.log("Butterin Cards address:", butterinCards);

        // Deploy sale contract
        address sale = address(new SepoliaSale(minedJpeg, butterinCards));

        console.log("Sale address:", sale);

        vm.stopBroadcast();
    }
}
