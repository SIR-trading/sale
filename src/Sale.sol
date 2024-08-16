// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
    - Accepts USDT, USDC & DAI
    - Users can lock Buterin Cards or Mined JPEGs
    - Create withdrawal function for any ERC20 token for safety
    - BC or MJ can be locked up to 5 at any time before the sale, after that the contract stops.
    - Sale is over once we got 500k USDT+USDC+DAI, no more tokens are accepted.
    - Sale can be ended by the owner
    - Use events to track deposits
 */
contract Sale {
    uint256 public number;

    function setNumber(uint256 newNumber) public {
        number = newNumber;
    }

    function increment() public {
        number++;
    }
}
