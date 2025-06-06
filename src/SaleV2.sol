// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseSaleV2} from "./BaseSaleV2.sol";

contract SaleV2 is BaseSaleV2 {
    constructor()
        BaseSaleV2(
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
            0x6B175474E89094C44Da98b954EedeAC495271d0F // DAI
        )
    {}
}
