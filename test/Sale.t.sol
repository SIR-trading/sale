// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Sale.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC721Enumerable} from "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";
import {SaleStructs} from "../src/SaleStructs.sol";

contract SaleTest is SaleStructs, Test {
    Sale sale;

    uint40 timeSaleStarted;

    address alice;

    function setUp() public {
        sale = new Sale();
        timeSaleStarted = uint40(block.timestamp);

        alice = address(0x123);
    }

    function test_initialParams() public view {
        assertEq(sale.owner(), address(this));
        assertEq(sale.MAX_CONTRIBUTIONS_NO_DECIMALS(), 0.5e6);

        SaleState memory state = sale.state();
        assertEq(state.timeSaleEnded, 0);
        assertEq(state.totalContributionsNoDecimals, 0);

        Contribution memory aliceContribution = sale.contributions(alice);
        assertEq(aliceContribution.amountFinalNoDecimals, 0);
        assertEq(aliceContribution.amountWithdrawableNoDecimals, 0);
        assertEq(aliceContribution.timeLastContribution, 0);
    }

    function testFuzz_endSale(uint40 timeElapsed) public {
        timeElapsed = uint40(
            _bound(timeElapsed, 0, type(uint40).max - timeSaleStarted)
        );

        // Skip time
        skip(timeElapsed);

        // End sale
        vm.expectEmit();
        emit SaleEnded(timeSaleStarted + timeElapsed);
        sale.endSale();

        // Check state
        SaleState memory state = sale.state();
        assertEq(state.timeSaleEnded, timeSaleStarted + timeElapsed);
    }

    function testFuzz_endSaleByWrongCaller(
        uint40 timeElapsed,
        address caller
    ) public {
        timeElapsed = uint40(
            _bound(timeElapsed, 0, type(uint40).max - timeSaleStarted)
        );

        vm.assume(caller != address(this));

        // Skip time
        skip(timeElapsed);

        // End sale
        vm.prank(caller);
        vm.expectRevert();
        sale.endSale();
    }

    function testFuzz_endSaleTwice(uint40 timeElapsed) public {
        testFuzz_endSale(timeElapsed);

        // End sale again
        vm.expectRevert(SaleIsOver.selector);
        sale.endSale();
    }
}

/// @notice Make sure nft_user is the address of someone holding Buterin Cards and Mined JPEGs
contract SaleTestTokens is SaleStructs, Test {
    IERC20 private constant _USDT =
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 private constant _USDC =
        IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 private constant _DAI =
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    IERC721Enumerable private constant _BUTERIN_CARDS =
        IERC721Enumerable(0x5726C14663A1EaD4A7D320E8A653c9710b2A2E89);
    IERC721Enumerable private constant _MINED_JPEG =
        IERC721Enumerable(0x7cd51FA7E155805C34F333ba493608742A67Da8e);

    Sale sale;

    uint40 timeSaleStarted;

    address alice;
    address bob;
    address nft_user;

    function setUp() public {
        vm.createSelectFork("mainnet", 20568633);

        sale = new Sale();
        timeSaleStarted = uint40(block.timestamp);

        alice = address(0x123);
        bob = address(0x456);
        nft_user = vm.envAddress("NFT_HOLDER");
    }

    struct NftsToLock {
        uint16 numButerinCards;
        uint8 numMinedJpegs;
        uint40 timeElapsed;
    }

    // TEST NO APPROVE

    // TEST safeTransferFrom TO Sale FAILS

    function testFuzz_lockNfts(NftsToLock[5] memory nftsToLock) public {
        vm.startPrank(nft_user);

        // NFT user approve contract
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Make repeated calls to lockNfts
        uint256 totalNftsLocked;
        for (uint256 i = 0; i < nftsToLock.length; i++) {
            // Skip time
            nftsToLock[i].timeElapsed = uint40(
                _bound(
                    nftsToLock[i].timeElapsed,
                    0,
                    type(uint40).max - block.timestamp
                )
            );
            skip(nftsToLock[i].timeElapsed);

            // Lock NFTs
            uint256 numButerinCards = _BUTERIN_CARDS.balanceOf(nft_user) <
                nftsToLock[i].numButerinCards
                ? _BUTERIN_CARDS.balanceOf(nft_user)
                : nftsToLock[i].numButerinCards;
            uint256 numMinedJpegs = _MINED_JPEG.balanceOf(nft_user) <
                nftsToLock[i].numMinedJpegs
                ? _MINED_JPEG.balanceOf(nft_user)
                : nftsToLock[i].numMinedJpegs;

            // TokenIds of NFTs to be locked
            uint16[] memory buterinCardIds = new uint16[](numButerinCards);
            for (uint256 j = 0; j < numButerinCards; j++) {
                buterinCardIds[j] = uint16(
                    _BUTERIN_CARDS.tokenOfOwnerByIndex(nft_user, j)
                );
            }
            uint8[] memory minedJpegIds = new uint8[](numMinedJpegs);
            for (uint256 j = 0; j < numMinedJpegs; j++) {
                minedJpegIds[j] = uint8(
                    _MINED_JPEG.tokenOfOwnerByIndex(nft_user, j)
                );
            }

            // Check if we expect revert
            if (totalNftsLocked + numButerinCards + numMinedJpegs > 5) {
                vm.expectRevert(TooManyNfts.selector);
            } else {
                totalNftsLocked += numButerinCards + numMinedJpegs;
            }

            // Lock NFTs
            sale.lockNfts(buterinCardIds, minedJpegIds);

            // Check state
            SaleState memory state = sale.state();
            assertEq(
                state.totalContributionsNoDecimals,
                0,
                "wrong totalContributionsNoDecimals"
            );
            assertEq(state.timeSaleEnded, 0, "wrong timeSaleEnded");

            // Check contributor's state
            Contribution memory contribution = sale.contributions(nft_user);
            assertEq(
                contribution.amountFinalNoDecimals,
                0,
                "wrong amountFinalNoDecimals"
            );
            assertEq(
                contribution.amountWithdrawableNoDecimals,
                0,
                "wrong amountWithdrawableNoDecimals"
            );
            assertEq(
                contribution.timeLastContribution,
                0,
                "wrong timeLastContribution"
            );
            assertEq(
                contribution.lockedButerinCards.number +
                    contribution.lockedMinedJpegs.number,
                totalNftsLocked,
                "NFTs locked do not match"
            );
        }
    }
}
