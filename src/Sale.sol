// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseSale} from "./BaseSale.sol";

contract Sale is BaseSale {
    constructor()
        BaseSale(
            0xdAC17F958D2ee523a2206206994597C13D831ec7, // USDT
            0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // USDC
            0x6B175474E89094C44Da98b954EedeAC495271d0F, // DAI
            0x5726C14663A1EaD4A7D320E8A653c9710b2A2E89, // Butterin Cards
            0x7cd51FA7E155805C34F333ba493608742A67Da8e // Mined JPEG
        )
    {}
}
