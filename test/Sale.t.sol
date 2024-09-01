// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Sale.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC721Enumerable} from "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";
import {SaleStructs} from "../src/SaleStructs.sol";

/// @dev The environment varible NFT_HOLDER must be set to the address of someone holding at least 6 Buterin Cards and Mined JPEGs in total.
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

    // function testFuzz_withdrawExoticERC20ByWrongCaller(uint256 amount) public {
    //     // Deploy ERC20
    //     address erc20 = address(new ERC20("Exotic", "EXOTIC"));

    //     // Deposit
    //     deal(erc20, address(sale), amount, true);

    //     // Withdraw
    //     sale.withdrawExoticERC20(address(this));
    // }
}

contract SaleTestTokens is SaleStructs, Test {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

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

        // Ensure nft_user holds NFTs
        assert(_BUTERIN_CARDS.balanceOf(nft_user) > 0);
        assert(_MINED_JPEG.balanceOf(nft_user) > 0);
        assert(
            _BUTERIN_CARDS.balanceOf(nft_user) +
                _MINED_JPEG.balanceOf(nft_user) >
                5
        );
    }

    struct NftsToLock {
        uint16 numButerinCards;
        uint8 numMinedJpegs;
        uint40 timeElapsed;
    }

    function test_safeTransferToSaleFails() public {
        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(
                NftsToLock({
                    numButerinCards: 1,
                    numMinedJpegs: 1,
                    timeElapsed: 0
                })
            );

        // Start prank
        vm.startPrank(nft_user);

        // Safe transfers fail
        vm.expectRevert();
        _BUTERIN_CARDS.safeTransferFrom(
            nft_user,
            address(sale),
            buterinCardIds[0]
        );
        vm.expectRevert();
        _MINED_JPEG.safeTransferFrom(nft_user, address(sale), minedJpegIds[0]);

        // Unsafe transfers work
        vm.expectEmit();
        emit Transfer(nft_user, address(sale), buterinCardIds[0]);
        _BUTERIN_CARDS.transferFrom(nft_user, address(sale), buterinCardIds[0]);
        vm.expectEmit();
        emit Transfer(nft_user, address(sale), minedJpegIds[0]);
        _MINED_JPEG.transferFrom(nft_user, address(sale), minedJpegIds[0]);
    }

    function testFuzz_lockUnapprovedNfts(NftsToLock memory nftsToLock) public {
        vm.startPrank(nft_user);

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock);

        // Lock NFTs
        if (buterinCardIds.length + minedJpegIds.length > 0) {
            vm.expectRevert();
            sale.lockNfts(buterinCardIds, minedJpegIds);
        }
    }

    function testFuzz_lockNftsWhenSaleIsOver(
        NftsToLock memory nftsToLock
    ) public {
        vm.startPrank(nft_user);

        // NFT user approve contract
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock);

        // End sale
        vm.stopPrank();
        vm.prank(address(this));
        sale.endSale();

        // Lock NFTs
        vm.expectRevert(SaleIsOver.selector);
        sale.lockNfts(buterinCardIds, minedJpegIds);
    }

    function testFuzz_lockNfts(NftsToLock[5] memory nftsToLock) public {
        vm.startPrank(nft_user);

        // NFT user approve contract
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Make repeated calls to lockNfts
        uint256 totalNftsLocked;
        for (uint256 i = 0; i < nftsToLock.length; i++) {
            // Get tokenIds of NFTs to be locked
            (
                uint16[] memory buterinCardIds,
                uint8[] memory minedJpegIds
            ) = _getTokenIds(nftsToLock[i]);

            // Check if we expect revert
            if (
                totalNftsLocked + buterinCardIds.length + minedJpegIds.length >
                5
            ) {
                vm.expectRevert(TooManyNfts.selector);
            } else {
                for (uint256 j = 0; j < buterinCardIds.length; j++) {
                    vm.expectEmit();
                    emit ButerinCardLocked(buterinCardIds[j]);
                }
                for (uint256 j = 0; j < minedJpegIds.length; j++) {
                    vm.expectEmit();
                    emit MinedJpegLocked(minedJpegIds[j]);
                }
            }

            // Lock NFTs
            sale.lockNfts(buterinCardIds, minedJpegIds);

            // Check owner of NFTs
            if (
                totalNftsLocked + buterinCardIds.length + minedJpegIds.length <=
                5
            ) {
                for (uint256 j = 0; j < buterinCardIds.length; j++) {
                    assertEq(
                        _BUTERIN_CARDS.ownerOf(buterinCardIds[j]),
                        address(sale),
                        "wrong owner of Buterin Card"
                    );
                }
                for (uint256 j = 0; j < minedJpegIds.length; j++) {
                    assertEq(
                        _MINED_JPEG.ownerOf(minedJpegIds[j]),
                        address(sale),
                        "wrong owner of Mined JPEG"
                    );
                }

                totalNftsLocked += buterinCardIds.length + minedJpegIds.length;
            }

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

        vm.stopPrank();
    }

    function test_lockSameNftsTwice() public {
        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(
                NftsToLock({
                    numButerinCards: 1,
                    numMinedJpegs: 1,
                    timeElapsed: 0
                })
            );

        // NFT user approve contract
        vm.startPrank(nft_user);
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Lock NFTs
        sale.lockNfts(buterinCardIds, minedJpegIds);

        // Lock same NFTs again
        vm.expectRevert();
        sale.lockNfts(buterinCardIds, minedJpegIds);
    }

    function testFuzz_depositNothingAndLockNfts(
        uint256 stablecoin,
        NftsToLock memory nftsToLock
    ) public {
        stablecoin = _bound(stablecoin, 0, 2);

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deposit and lock NFTs
        vm.expectRevert(NullDeposit.selector);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin),
            0,
            buterinCardIds,
            minedJpegIds
        );
    }

    function testFuzz_depositAndLockNftsWhenSaleIsOver(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    ) public {
        stablecoin = _bound(stablecoin, 0, 2);

        amountNoDecimals = uint24(
            _bound(amountNoDecimals, 1, type(uint24).max)
        );

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock);

        // End sale
        vm.stopPrank();
        vm.prank(address(this));
        sale.endSale();

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals);

        // Deposit and lock NFTs
        vm.expectRevert(SaleIsOver.selector);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin),
            amountNoDecimals,
            buterinCardIds,
            minedJpegIds
        );
    }

    function testFuzz_depositAndLockTooManyNfts(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    ) public {
        stablecoin = _bound(stablecoin, 0, 2);
        nftsToLock.numButerinCards = uint16(
            _bound(nftsToLock.numButerinCards, 6, type(uint16).max)
        );

        amountNoDecimals = uint24(
            _bound(amountNoDecimals, 1, type(uint24).max)
        );

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock);
        vm.assume(buterinCardIds.length + minedJpegIds.length > 5);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals);

        // Deposit and lock NFTs
        // if (buterinCardIds.length + minedJpegIds.length > 5)
        vm.expectRevert(TooManyNfts.selector);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin),
            amountNoDecimals,
            buterinCardIds,
            minedJpegIds
        );
    }

    function testFuzz_depositAndLockNfts(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    ) public returns (uint24) {
        stablecoin = _bound(stablecoin, 0, 2);

        amountNoDecimals = uint24(
            _bound(amountNoDecimals, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );

        nftsToLock.numButerinCards = uint16(
            _bound(nftsToLock.numButerinCards, 0, 5)
        );
        nftsToLock.numMinedJpegs = uint8(
            _bound(nftsToLock.numMinedJpegs, 0, 5 - nftsToLock.numButerinCards)
        );

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals);
        uint256 oldBalance = (
            stablecoin == 0 ? _USDT : stablecoin == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);

        // Deposit and lock NFTs
        for (uint256 i = 0; i < buterinCardIds.length; i++) {
            vm.expectEmit();
            emit ButerinCardLocked(buterinCardIds[i]);
        }
        for (uint256 i = 0; i < minedJpegIds.length; i++) {
            vm.expectEmit();
            emit MinedJpegLocked(minedJpegIds[i]);
        }
        emit Deposit(Stablecoin(stablecoin), amountNoDecimals);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin),
            amountNoDecimals,
            buterinCardIds,
            minedJpegIds
        );

        // Check if deposit was substracted from the user's oldBalance
        uint256 newBalance = (
            stablecoin == 0 ? _USDT : stablecoin == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);
        assertEq(
            newBalance,
            oldBalance - _addDecimals(stablecoin, amountNoDecimals)
        );

        vm.stopPrank();
        return amountNoDecimals;
    }

    function testFuzz_depositAndLockNftsEndsSale(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    )
        public
        returns (uint16[] memory buterinCardIds, uint8[] memory minedJpegIds)
    {
        stablecoin = _bound(stablecoin, 0, 2);

        amountNoDecimals = uint24(
            _bound(
                amountNoDecimals,
                MAX_CONTRIBUTIONS_NO_DECIMALS,
                type(uint24).max
            )
        );

        nftsToLock.numButerinCards = uint16(
            _bound(nftsToLock.numButerinCards, 0, 5)
        );
        nftsToLock.numMinedJpegs = uint8(
            _bound(nftsToLock.numMinedJpegs, 0, 5 - nftsToLock.numButerinCards)
        );

        // Get tokenIds of NFTs to be locked
        (buterinCardIds, minedJpegIds) = _getTokenIds(nftsToLock);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals);
        uint256 oldBalance = (
            stablecoin == 0 ? _USDT : stablecoin == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);

        // Deposit and lock NFTs
        if (amountNoDecimals > MAX_CONTRIBUTIONS_NO_DECIMALS) {
            vm.expectEmit();
            emit DepositWasReduced();
        }
        emit SaleEnded(uint40(block.timestamp));
        for (uint256 i = 0; i < buterinCardIds.length; i++) {
            vm.expectEmit();
            emit ButerinCardLocked(buterinCardIds[i]);
        }
        for (uint256 i = 0; i < minedJpegIds.length; i++) {
            vm.expectEmit();
            emit MinedJpegLocked(minedJpegIds[i]);
        }
        emit Deposit(Stablecoin(stablecoin), amountNoDecimals);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin),
            amountNoDecimals,
            buterinCardIds,
            minedJpegIds
        );

        // Check if deposit was substracted from the user's oldBalance
        uint256 newBalance = (
            stablecoin == 0 ? _USDT : stablecoin == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);
        assertEq(
            newBalance,
            oldBalance - _addDecimals(stablecoin, MAX_CONTRIBUTIONS_NO_DECIMALS)
        );

        // Check sale actually ended
        SaleState memory state = sale.state();
        assertEq(state.timeSaleEnded, uint40(block.timestamp));
        assertEq(
            state.totalContributionsNoDecimals,
            MAX_CONTRIBUTIONS_NO_DECIMALS
        );
        vm.stopPrank();
    }

    function testFuzz_redepositWrongStablecoin(
        uint256 stablecoin1,
        uint24 amountNoDecimals1,
        NftsToLock memory nftsToLock1,
        uint256 stablecoin2,
        uint24 amountNoDecimals2,
        NftsToLock memory nftsToLock2
    ) public {
        stablecoin1 = _bound(stablecoin1, 0, 2);

        amountNoDecimals1 = testFuzz_depositAndLockNfts(
            stablecoin1,
            amountNoDecimals1,
            nftsToLock1
        );

        stablecoin2 = _bound(stablecoin2, 0, 2);
        vm.assume(stablecoin1 != stablecoin2);

        amountNoDecimals2 = uint24(
            _bound(amountNoDecimals2, 1, type(uint24).max)
        );

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock2);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals2);

        // Deposit and lock NFTs
        vm.expectRevert(WrongStablecoin.selector);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin2),
            amountNoDecimals2,
            buterinCardIds,
            minedJpegIds
        );
    }

    function testFuzz_redepositAndLockTooManyNfts(
        uint256 stablecoin1,
        uint24 amountNoDecimals1,
        NftsToLock memory nftsToLock1,
        uint256 stablecoin2,
        uint24 amountNoDecimals2,
        NftsToLock memory nftsToLock2
    ) public {
        stablecoin1 = _bound(stablecoin1, 0, 2);

        amountNoDecimals1 = testFuzz_depositAndLockNfts(
            stablecoin1,
            amountNoDecimals1,
            nftsToLock1
        );

        stablecoin2 = stablecoin1;

        amountNoDecimals2 = uint24(
            _bound(amountNoDecimals2, 1, type(uint24).max)
        );

        nftsToLock2.numButerinCards = uint16(
            _bound(
                nftsToLock2.numButerinCards,
                nftsToLock2.numMinedJpegs > 6
                    ? 0
                    : 6 - nftsToLock2.numMinedJpegs,
                type(uint16).max
            )
        );

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock2);
        vm.assume(buterinCardIds.length + minedJpegIds.length > 5);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals2);

        // Deposit and lock NFTs
        vm.expectRevert(TooManyNfts.selector);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin2),
            amountNoDecimals2,
            buterinCardIds,
            minedJpegIds
        );
    }

    function testFuzz_redepositAndLockNfts(
        uint256 stablecoin1,
        uint24 amountNoDecimals1,
        NftsToLock memory nftsToLock1,
        uint256 stablecoin2,
        uint24 amountNoDecimals2,
        NftsToLock memory nftsToLock2
    ) public {
        stablecoin1 = _bound(stablecoin1, 0, 2);

        amountNoDecimals1 = testFuzz_depositAndLockNfts(
            stablecoin1,
            amountNoDecimals1,
            nftsToLock1
        );

        stablecoin2 = stablecoin1;

        amountNoDecimals2 = uint24(
            _bound(amountNoDecimals2, 1, type(uint24).max)
        );

        // Ensure no more than 5 NFTs are locked
        Contribution memory contribution = sale.contributions(nft_user);
        nftsToLock2.numButerinCards = uint16(
            _bound(
                nftsToLock2.numButerinCards,
                0,
                5 -
                    contribution.lockedButerinCards.number -
                    contribution.lockedMinedJpegs.number
            )
        );
        nftsToLock2.numMinedJpegs = uint8(
            _bound(
                nftsToLock2.numMinedJpegs,
                0,
                5 -
                    contribution.lockedButerinCards.number -
                    contribution.lockedMinedJpegs.number -
                    nftsToLock2.numButerinCards
            )
        );

        // Get tokenIds of NFTs to be locked
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = _getTokenIds(nftsToLock2);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        // Approve sale contract to transfer NFTs
        _BUTERIN_CARDS.setApprovalForAll(address(sale), true);
        _MINED_JPEG.setApprovalForAll(address(sale), true);

        // Deal stablecoin
        _dealStablecoins(amountNoDecimals2);
        uint256 oldBalance = (
            stablecoin2 == 0 ? _USDT : stablecoin2 == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);

        // Deposit and lock NFTs
        bool depositReduced = uint256(amountNoDecimals1) + amountNoDecimals2 >
            MAX_CONTRIBUTIONS_NO_DECIMALS;
        if (depositReduced) {
            vm.expectEmit();
            emit DepositWasReduced();
        }
        for (uint256 i = 0; i < buterinCardIds.length; i++) {
            vm.expectEmit();
            emit ButerinCardLocked(buterinCardIds[i]);
        }
        for (uint256 i = 0; i < minedJpegIds.length; i++) {
            vm.expectEmit();
            emit MinedJpegLocked(minedJpegIds[i]);
        }
        emit Deposit(Stablecoin(stablecoin2), amountNoDecimals2);
        sale.depositAndLockNfts(
            Stablecoin(stablecoin2),
            amountNoDecimals2,
            buterinCardIds,
            minedJpegIds
        );

        // Check if deposit was substracted from the user's oldBalance
        uint256 newBalance = (
            stablecoin2 == 0 ? _USDT : stablecoin2 == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);
        assertEq(
            newBalance,
            oldBalance -
                _addDecimals(
                    stablecoin2,
                    depositReduced
                        ? MAX_CONTRIBUTIONS_NO_DECIMALS - amountNoDecimals1
                        : amountNoDecimals2
                )
        );
    }

    function testFuzz_withdrawFailsCuzSaleIsOver(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    ) public {
        testFuzz_depositAndLockNftsEndsSale(
            stablecoin,
            amountNoDecimals,
            nftsToLock
        );

        // Withdraw
        vm.prank(nft_user);
        vm.expectRevert(SaleIsOver.selector);
        sale.withdraw();
    }

    function test_withdrawFailsCuzNoDeposit() public {
        // Withdraw
        vm.prank(nft_user);
        vm.expectRevert(NullDeposit.selector);
        sale.withdraw();
    }

    function testFuzz_withdraw(
        uint256 stablecoin,
        uint24[4] memory amountNoDecimals,
        uint40[4] memory timeElapsed
    ) public {
        stablecoin = _bound(stablecoin, 0, 2);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        uint24 cumulativeAmountNoDecimals;
        uint24 cumulativeWithdrawableAmountNoDecimals;
        for (uint256 i = 0; i < amountNoDecimals.length; i++) {
            // To make sure the sale doesn't end
            amountNoDecimals[i] = uint24(
                _bound(
                    amountNoDecimals[i],
                    1,
                    MAX_CONTRIBUTIONS_NO_DECIMALS -
                        cumulativeAmountNoDecimals -
                        4 +
                        i
                )
            );

            // Deal stablecoin
            _dealStablecoins(amountNoDecimals[i]);

            // Deposit
            sale.depositAndLockNfts(
                Stablecoin(stablecoin),
                amountNoDecimals[i],
                new uint16[](0),
                new uint8[](0)
            );

            // Skip time
            timeElapsed[i] = uint40(
                _bound(timeElapsed[i], 0, type(uint40).max - block.timestamp)
            );
            skip(timeElapsed[i]);

            // Update cumulative amounts
            cumulativeAmountNoDecimals += amountNoDecimals[i];
            if (timeElapsed[i] < 24 hours) {
                cumulativeWithdrawableAmountNoDecimals += amountNoDecimals[i];
            } else {
                cumulativeWithdrawableAmountNoDecimals = 0;
            }
        }

        // Balance
        uint256 oldBalance = (
            stablecoin == 0 ? _USDT : stablecoin == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);

        // Withdraw
        if (cumulativeWithdrawableAmountNoDecimals == 0) {
            vm.expectRevert(NullDeposit.selector);
        } else {
            vm.expectEmit();
            emit Withdrawal(
                Stablecoin(stablecoin),
                cumulativeWithdrawableAmountNoDecimals
            );
        }
        sale.withdraw();

        // New balance
        uint256 newBalance = (
            stablecoin == 0 ? _USDT : stablecoin == 1 ? _USDC : _DAI
        ).balanceOf(nft_user);
        assertEq(
            newBalance,
            oldBalance +
                10 ** (stablecoin == 0 ? 6 : stablecoin == 1 ? 6 : 18) *
                uint256(cumulativeWithdrawableAmountNoDecimals)
        );
    }

    function testFuzz_withdrawAndRedepositDifferentStablecoin(
        uint256 stablecoinA,
        uint24 amountNoDecimalsA,
        uint40 timeElapsedA,
        uint256 stablecoinB,
        uint24 amountNoDecimalsB
    ) public {
        stablecoinA = _bound(stablecoinA, 0, 2);
        stablecoinB = _bound(stablecoinB, 0, 2);
        vm.assume(stablecoinA != stablecoinB);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(nft_user);
        _approveStablecoins();

        amountNoDecimalsA = uint24(
            _bound(amountNoDecimalsA, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );

        // Deal stablecoin
        _dealStablecoins(amountNoDecimalsA);

        // Deposit
        sale.depositAndLockNfts(
            Stablecoin(stablecoinA),
            amountNoDecimalsA,
            new uint16[](0),
            new uint8[](0)
        );

        // Withdraw
        sale.withdraw();

        // Skip time
        skip(timeElapsedA);

        amountNoDecimalsB = uint24(
            _bound(amountNoDecimalsB, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );

        // Deal stablecoin
        _dealStablecoins(amountNoDecimalsB);

        // Deposit
        sale.depositAndLockNfts(
            Stablecoin(stablecoinB),
            amountNoDecimalsB,
            new uint16[](0),
            new uint8[](0)
        );
    }

    function testFuzz_withdrawNftsAfterInsufficientTime(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock,
        uint40 timeElapsed
    ) public {
        // Lock NFTs and end sale
        testFuzz_depositAndLockNftsEndsSale(
            stablecoin,
            amountNoDecimals,
            nftsToLock
        );

        // Skip insufficient time after sale ends
        timeElapsed = uint40(_bound(timeElapsed, 0, 365 days - 1));
        skip(timeElapsed);

        // Try to withdraw NFTs
        vm.expectRevert(NftsLocked.selector);
        vm.prank(nft_user);
        sale.withdrawNfts();
    }

    function testFuzz_withdrawNftsAfterInsufficientTime(
        NftsToLock[5] memory nftsToLock
    ) public {
        // Lock NFTs
        testFuzz_lockNfts(nftsToLock);

        // End sale
        vm.prank(address(this));
        sale.endSale();

        // Skip 1 year - 1 second
        skip(365 days - 1);

        // Withdraw NFTs
        vm.prank(nft_user);
        vm.expectRevert(NftsLocked.selector);
        sale.withdrawNfts();
    }

    function testFuzz_withdrawMissingNfts(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        uint40 timeElapsed
    ) public {
        // Lock NFTs and end sale
        testFuzz_depositAndLockNftsEndsSale(
            stablecoin,
            amountNoDecimals,
            NftsToLock({numButerinCards: 0, numMinedJpegs: 0, timeElapsed: 0})
        );

        // Skip insufficient time after sale ends
        timeElapsed = uint40(_bound(timeElapsed, 365 days, type(uint40).max));
        skip(timeElapsed);

        // Try to withdraw NFTs
        vm.expectRevert(NoNfts.selector);
        vm.prank(nft_user);
        sale.withdrawNfts();
    }

    function testFuzz_withdrawMissingNfts(
        NftsToLock[5] memory nftsToLock,
        address user
    ) public {
        // Lock NFTs
        testFuzz_lockNfts(nftsToLock);

        // End sale
        vm.prank(address(this));
        sale.endSale();

        // Skip 1 year - 1 second
        skip(365 days - 1);

        // Withdraw NFTs
        vm.assume(user != nft_user);
        vm.prank(user);
        vm.expectRevert();
        sale.withdrawNfts();
    }

    function testFuzz_withdrawNfts(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    ) public {
        // Lock NFTs and end sale
        (
            uint16[] memory buterinCardIds,
            uint8[] memory minedJpegIds
        ) = testFuzz_depositAndLockNftsEndsSale(
                stablecoin,
                amountNoDecimals,
                nftsToLock
            );
        vm.assume(buterinCardIds.length + minedJpegIds.length > 0);

        // Skip insufficient time after sale ends
        nftsToLock.timeElapsed = uint40(
            _bound(nftsToLock.timeElapsed, 365 days, type(uint40).max)
        );
        skip(nftsToLock.timeElapsed);

        // Try to withdraw NFTs
        for (uint256 i = 0; i < buterinCardIds.length; i++) {
            vm.expectEmit();
            emit ButerinCardUnlocked(buterinCardIds[i]);
        }
        for (uint256 i = 0; i < minedJpegIds.length; i++) {
            vm.expectEmit();
            emit MinedJpegUnlocked(minedJpegIds[i]);
        }
        vm.prank(nft_user);
        sale.withdrawNfts();

        // Check NFTs are withdrawn
        _checkNftsAreWithdrawn(buterinCardIds, minedJpegIds);
    }

    function testFuzz_withdrawNfts(NftsToLock[5] memory nftsToLock) public {
        // Lock NFTs
        testFuzz_lockNfts(nftsToLock);

        // End sale
        vm.prank(address(this));
        sale.endSale();

        // Skip 1 year
        skip(365 days);

        // Withdraw NFTs
        uint16[] memory buterinCardIds = new uint16[](
            _BUTERIN_CARDS.balanceOf(address(sale))
        );
        for (uint256 i = 0; i < buterinCardIds.length; i++) {
            buterinCardIds[i] = uint16(
                _BUTERIN_CARDS.tokenOfOwnerByIndex(address(sale), i)
            );
            vm.expectEmit();
            emit ButerinCardUnlocked(buterinCardIds[i]);
        }
        uint8[] memory minedJpegIds = new uint8[](
            _MINED_JPEG.balanceOf(address(sale))
        );
        for (uint256 i = 0; i < minedJpegIds.length; i++) {
            minedJpegIds[i] = uint8(
                _MINED_JPEG.tokenOfOwnerByIndex(address(sale), i)
            );
            vm.expectEmit();
            emit MinedJpegUnlocked(minedJpegIds[i]);
        }
        if (buterinCardIds.length + minedJpegIds.length == 0) {
            vm.expectRevert(NoNfts.selector);
        }
        vm.prank(nft_user);
        sale.withdrawNfts();

        // Check NFTs are withdrawn
        _checkNftsAreWithdrawn(buterinCardIds, minedJpegIds);
    }

    function testFuzz_withdrawNftsWhileSaleIsLive(
        NftsToLock[5] memory nftsToLock
    ) public {
        // Lock NFTs
        testFuzz_lockNfts(nftsToLock);

        // Skip 1 year
        skip(365 days);

        // Withdraw NFTs
        vm.prank(nft_user);
        vm.expectRevert(NftsLocked.selector);
        sale.withdrawNfts();
    }

    function testFuzz_withdrawNftsTwice(
        NftsToLock[5] memory nftsToLock
    ) public {
        // Lock NFTs
        testFuzz_withdrawNfts(nftsToLock);

        // Withdraw NFTs again
        vm.prank(nft_user);
        vm.expectRevert(NoNfts.selector);
        sale.withdrawNfts();
    }

    function testFuzz_withdrawFundsWhileSaleIsLive(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock,
        address to
    ) public {
        vm.assume(to != address(0));

        // Deposit and lock NFTs
        testFuzz_depositAndLockNfts(stablecoin, amountNoDecimals, nftsToLock);

        // Withdraw
        vm.expectRevert(SaleIsLive.selector);
        sale.withdrawFunds(to);
    }

    function testFuzz_withdrawFundsByWrongCaller(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock,
        address caller,
        address to
    ) public {
        vm.assume(caller != address(this));
        vm.assume(to != address(0));

        // Deposit and lock NFTs
        testFuzz_depositAndLockNftsEndsSale(
            stablecoin,
            amountNoDecimals,
            nftsToLock
        );

        // Withdraw
        vm.prank(caller);
        vm.expectRevert();
        sale.withdrawFunds(to);
    }

    function testFuzz_withdrawFundsTo0AddressFails(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        NftsToLock memory nftsToLock
    ) public {
        // Deposit and lock NFTs
        testFuzz_depositAndLockNftsEndsSale(
            stablecoin,
            amountNoDecimals,
            nftsToLock
        );

        // Withdraw
        vm.expectRevert(NullAddress.selector);
        sale.withdrawFunds(address(0));
    }

    function testFuzz_withdrawFunds(
        uint256 stablecoinA,
        uint24 amountNoDecimalsA,
        NftsToLock memory nftsToLockA,
        address user,
        uint256 stablecoinB,
        uint24 amountNoDecimalsB,
        address to
    ) public {
        vm.assume(user != nft_user);
        vm.assume(to != address(0));

        stablecoinA = _bound(stablecoinA, 0, 2);
        stablecoinB = _bound(stablecoinB, 0, 2);

        amountNoDecimalsA = uint24(
            _bound(amountNoDecimalsA, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );
        amountNoDecimalsB = uint24(
            _bound(
                amountNoDecimalsB,
                MAX_CONTRIBUTIONS_NO_DECIMALS - amountNoDecimalsA,
                type(uint24).max
            )
        );

        // NFT user deposits and lock NFTs
        testFuzz_depositAndLockNfts(
            stablecoinA,
            amountNoDecimalsA,
            nftsToLockA
        );

        // Deal stablecoin
        deal(address(_USDT), user, uint256(amountNoDecimalsB) * 1e6, true);
        deal(address(_USDC), user, uint256(amountNoDecimalsB) * 1e6, true);
        deal(address(_DAI), user, uint256(amountNoDecimalsB) * 1e18, true);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(user);
        SafeERC20.forceApprove(
            stablecoinB == 0 ? _USDT : stablecoinB == 1 ? _USDC : _DAI,
            address(sale),
            type(uint256).max
        );

        // User deposits and lock NFTs
        sale.depositAndLockNfts(
            Stablecoin(stablecoinB),
            amountNoDecimalsB,
            new uint16[](0),
            new uint8[](0)
        );
        vm.stopPrank();

        // Withdraw
        uint256 usdtBalance = _USDT.balanceOf(to);
        uint256 usdcBalance = _USDC.balanceOf(to);
        uint256 daiBalance = _DAI.balanceOf(to);
        sale.withdrawFunds(to);

        // Check balances
        if (stablecoinA == stablecoinB) {
            uint256 balanceOld = (
                stablecoinA == 0 ? usdtBalance : stablecoinA == 1
                    ? usdcBalance
                    : daiBalance
            );
            IERC20 stablecoin = stablecoinA == 0 ? _USDT : stablecoinA == 1
                ? _USDC
                : _DAI;
            assertEq(
                stablecoin.balanceOf(to),
                balanceOld +
                    _addDecimals(stablecoinA, MAX_CONTRIBUTIONS_NO_DECIMALS)
            );
        } else {
            {
                uint256 balanceOldA = (
                    stablecoinA == 0 ? usdtBalance : stablecoinA == 1
                        ? usdcBalance
                        : daiBalance
                );
                IERC20 stableA = stablecoinA == 0 ? _USDT : stablecoinA == 1
                    ? _USDC
                    : _DAI;
                assertEq(
                    stableA.balanceOf(to),
                    balanceOldA + _addDecimals(stablecoinA, amountNoDecimalsA)
                );
            }
            uint256 balanceOldB = (
                stablecoinB == 0 ? usdtBalance : stablecoinB == 1
                    ? usdcBalance
                    : daiBalance
            );
            IERC20 stableB = stablecoinB == 0 ? _USDT : stablecoinB == 1
                ? _USDC
                : _DAI;
            assertEq(
                stableB.balanceOf(to),
                balanceOldB +
                    _addDecimals(
                        stablecoinB,
                        MAX_CONTRIBUTIONS_NO_DECIMALS - amountNoDecimalsA
                    )
            );
        }
    }

    function _addDecimals(
        uint256 stablecoin,
        uint amountNoDecimals
    ) private pure returns (uint256) {
        if (stablecoin > 2) revert("Invalid stablecoin");
        return
            amountNoDecimals *
            (stablecoin == 0 ? 1e6 : stablecoin == 1 ? 1e6 : 1e18);
    }

    ////////////////////////////////////////////////////////////////////////////////
    /////////////////////// P R I V A T E  F U N C T I O N S //////////////////////
    //////////////////////////////////////////////////////////////////////////////

    function _checkNftsAreWithdrawn(
        uint16[] memory buterinCardIds,
        uint8[] memory minedJpegIds
    ) private view {
        // Check owner of NFTs
        for (uint256 i = 0; i < buterinCardIds.length; i++) {
            assertEq(
                _BUTERIN_CARDS.ownerOf(buterinCardIds[i]),
                nft_user,
                "wrong owner of Buterin Card"
            );
        }
        for (uint256 i = 0; i < minedJpegIds.length; i++) {
            assertEq(
                _MINED_JPEG.ownerOf(minedJpegIds[i]),
                nft_user,
                "wrong owner of Mined JPEG"
            );
        }

        // Check contributor's state
        Contribution memory contribution = sale.contributions(nft_user);
        assertEq(
            contribution.lockedButerinCards.number +
                contribution.lockedMinedJpegs.number,
            0,
            "NFTs locked do not match"
        );
    }

    function _getTokenIds(
        NftsToLock memory nftsToLock
    )
        private
        returns (uint16[] memory buterinCardIds, uint8[] memory minedJpegIds)
    {
        // Skip time
        nftsToLock.timeElapsed = uint40(
            _bound(
                nftsToLock.timeElapsed,
                0,
                type(uint40).max - block.timestamp
            )
        );
        skip(nftsToLock.timeElapsed);

        // Lock NFTs
        uint256 numButerinCards = _BUTERIN_CARDS.balanceOf(nft_user) <
            nftsToLock.numButerinCards
            ? _BUTERIN_CARDS.balanceOf(nft_user)
            : nftsToLock.numButerinCards;
        uint256 numMinedJpegs = _MINED_JPEG.balanceOf(nft_user) <
            nftsToLock.numMinedJpegs
            ? _MINED_JPEG.balanceOf(nft_user)
            : nftsToLock.numMinedJpegs;

        // TokenIds of NFTs to be locked
        buterinCardIds = new uint16[](numButerinCards);
        for (uint256 j = 0; j < numButerinCards; j++) {
            buterinCardIds[j] = uint16(
                _BUTERIN_CARDS.tokenOfOwnerByIndex(nft_user, j)
            );
        }
        minedJpegIds = new uint8[](numMinedJpegs);
        for (uint256 j = 0; j < numMinedJpegs; j++) {
            minedJpegIds[j] = uint8(
                _MINED_JPEG.tokenOfOwnerByIndex(nft_user, j)
            );
        }
    }

    function _approveStablecoins() private {
        SafeERC20.forceApprove(_USDT, address(sale), type(uint256).max);
        _USDC.approve(address(sale), type(uint256).max);
        _DAI.approve(address(sale), type(uint256).max);
    }

    function _dealStablecoins(uint24 amountNoDecimals) private {
        deal(address(_USDT), nft_user, uint256(amountNoDecimals) * 1e6, true);
        deal(address(_USDC), nft_user, uint256(amountNoDecimals) * 1e6, true);
        deal(address(_DAI), nft_user, uint256(amountNoDecimals) * 1e18, true);
    }
}
