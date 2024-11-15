// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import {MockNFT} from "../src/MockNFT.sol";
import {BaseSale} from "../src/BaseSale.sol";
import {SaleStructs} from "../src/SaleStructs.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);
}

/** @dev cli for localhost:     source .env | forge script script/WithdrawProceeds.s.sol --rpc-url "http://localhost:${PORT}" --unlocked --broadcast --legacy
 */
contract WithdrawProceeds is Script, SaleStructs {
    IERC20 constant usdt = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 constant usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 constant dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    BaseSale sale;
    uint256 privateKey;
    address wallet;

    function setUp() public {
        privateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        wallet = vm.addr(privateKey);
        sale = BaseSale(vm.envAddress("SALE"));
    }

    function run() public {
        // vm.startBroadcast(1);

        // SaleStructs.SaleState memory state = sale.state();
        // console.log(state.timeSaleEnded > 0 ? "Sale is over" : "Sale is live");

        // try sale.withdrawFunds() {
        //     console.log("CRITICAL: Funds withdrawn by", vm.addr(1));
        // } catch {
        //     console.log("Withdrawal by", vm.addr(1), "successfully failed");
        // }

        // vm.stopBroadcast();

        vm.startBroadcast(privateKey);

        // Get balances before withdrawal
        uint256 usdtBalance = usdt.balanceOf(wallet);
        uint256 usdcBalance = usdc.balanceOf(wallet);
        uint256 daiBalance = dai.balanceOf(wallet);

        // Attempt to withdraw funds
        sale.withdrawFunds();

        // Compute received funds
        usdtBalance = usdt.balanceOf(wallet) - usdtBalance;
        usdcBalance = usdc.balanceOf(wallet) - usdcBalance;
        daiBalance = dai.balanceOf(wallet) - daiBalance;

        console.log("Received USDT: ", usdtBalance / 10 ** usdt.decimals());
        console.log("Received USDC: ", usdcBalance / 10 ** usdc.decimals());
        console.log("Received DAI: ", daiBalance / 10 ** dai.decimals());

        vm.stopBroadcast();
    }
}
