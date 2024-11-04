// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {MockNFT} from "../src/MockNFT.sol";
import {BaseSale} from "../src/BaseSale.sol";
import {SaleStructs} from "../src/SaleStructs.sol";

/** @dev cli for localhost:     source .env | forge script script/FindContribution.s.sol --rpc-url "http://localhost:${PORT}" --unlocked --broadcast --legacy
    @dev cli for Sepolia:       forge script script/FindContribution.s.sol --rpc-url sepolia --chain sepolia --broadcast --slow
 */
contract FindContribution is Script, SaleStructs {
    BaseSale sale;
    uint256 privateKey;
    address wallet;

    function setUp() public {
        if (block.chainid == 11155111) {
            privateKey = vm.envUint("SEPOLIA_DEPLOYER_PRIVATE_KEY");
        } else if (block.chainid == vm.envUint("CHAIN_ID")) {
            privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        }

        wallet = vm.addr(privateKey);
        sale = BaseSale(vm.envAddress("SALE"));
    }

    function run() public {
        vm.startBroadcast(privateKey);

        Contribution memory contribution = sale.contributions(wallet);

        /**
            struct Contribution {
                Stablecoin stablecoin;
                uint24 amountFinalNoDecimals;
                uint24 amountWithdrawableNoDecimals;
                uint40 timeLastContribution;
                LockedButerinCards lockedButerinCards;
                LockedMinedJpegs lockedMinedJpegs;
            }
         */
        console.log("Stablecoin of choice:", uint256(contribution.stablecoin));
        console.log(
            "Finalized contributed amount:",
            contribution.amountFinalNoDecimals
        );
        console.log(
            "Withdrawable contributed amount:",
            contribution.amountWithdrawableNoDecimals
        );
        console.log(
            "Unix time of last contribution:",
            contribution.timeLastContribution
        );
        console.log(
            "# locked Buterin Cards:",
            contribution.lockedButerinCards.number
        );
        console.log(
            "# locked Mined JPEGs:",
            contribution.lockedMinedJpegs.number
        );

        vm.stopBroadcast();
    }
}
