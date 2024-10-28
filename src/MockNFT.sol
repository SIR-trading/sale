// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC721Enumerable, ERC721} from "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";

contract MockNFT is ERC721Enumerable {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {}

    function mint() external {
        uint256 supply = totalSupply();
        _safeMint(msg.sender, supply);
        _safeMint(msg.sender, supply + 1);
        _safeMint(msg.sender, supply + 2);
        _safeMint(msg.sender, supply + 3);
        _safeMint(msg.sender, supply + 4);
        _safeMint(msg.sender, supply + 5);
        _safeMint(msg.sender, supply + 6);
        _safeMint(msg.sender, supply + 7);
        _safeMint(msg.sender, supply + 8);
        _safeMint(msg.sender, supply + 9);
    }
}
