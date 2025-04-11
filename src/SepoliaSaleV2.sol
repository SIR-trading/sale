// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BaseSaleV2} from "./BaseSaleV2.sol";

contract SepoliaSaleV2 is BaseSaleV2 {
    constructor()
        BaseSaleV2(
            0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0, // USDT
            0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // USDC
            0x3e622317f8C93f7328350cF0B56d9eD4C620C5d6 // DAI
        )
    {}
}
