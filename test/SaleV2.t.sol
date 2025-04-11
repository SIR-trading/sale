// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/SaleV2.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {SaleStructsV2} from "../src/SaleStructsV2.sol";

contract SaleTest is SaleStructsV2, Test {
    SaleV2 sale;

    uint40 timeSaleStarted;

    address alice;

    function setUp() public {
        sale = new SaleV2();
        timeSaleStarted = uint40(block.timestamp);

        alice = address(0x123);
    }

    function test_initialParams() public view {
        assertEq(sale.owner(), address(this));
        assertEq(sale.MAX_CONTRIBUTIONS_NO_DECIMALS(), 1e5);

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

    function testFuzz_withdrawExoticERC20ByWrongCaller(
        address caller,
        uint256 amount
    ) public {
        vm.assume(caller != address(this));

        // Deploy ERC20
        address erc20 = address(new MockToken(address(sale), amount));

        // Withdraw
        vm.prank(caller);
        vm.expectRevert();
        sale.withdrawExoticERC20(erc20);
    }

    function testFuzz_withdrawExoticERC20WhenSaleIsLive(uint256 amount) public {
        // Deploy ERC20
        address erc20 = address(new MockToken(address(sale), amount));

        // Withdraw
        vm.expectRevert(SaleIsLive.selector);
        sale.withdrawExoticERC20(erc20);
    }

    function testFuzz_withdrawExoticERC20(uint256 amount) public {
        // Deploy ERC20
        MockToken erc20 = new MockToken(address(sale), amount);

        // End sale
        sale.endSale();

        // Withdraw
        sale.withdrawExoticERC20(address(erc20));

        // Check balance
        assertEq(erc20.balanceOf(address(this)), amount);
    }
}

contract SaleTestTokens is SaleStructsV2, Test {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    ERC20 private constant _USDT =
        ERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    ERC20 private constant _USDC =
        ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 private constant _DAI =
        ERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

    uint8 private _USDT_DECIMALS;
    uint8 private _USDC_DECIMALS;
    uint8 private _DAI_DECIMALS;

    SaleV2 sale;

    uint40 timeSaleStarted;

    address alice;

    function setUp() public {
        vm.createSelectFork("mainnet", 20568633);

        sale = new SaleV2();
        timeSaleStarted = uint40(block.timestamp);

        alice = address(0x123);

        // Get decimals
        _USDT_DECIMALS = _USDT.decimals();
        _USDC_DECIMALS = _USDC.decimals();
        _DAI_DECIMALS = _DAI.decimals();
    }

    function testFuzz_depositNothing(uint256 stablecoin) public {
        stablecoin = _bound(stablecoin, 0, 2);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(alice);
        _approveStablecoins();

        // Deposit
        vm.expectRevert(NullDeposit.selector);
        sale.deposit(Stablecoin(stablecoin), 0);
    }

    function testFuzz_depositWhenSaleIsOver(
        uint256 stablecoin,
        uint24 amountNoDecimals
    ) public {
        stablecoin = _bound(stablecoin, 0, 2);

        amountNoDecimals = uint24(
            _bound(amountNoDecimals, 1, type(uint24).max)
        );

        // End sale
        vm.stopPrank();
        vm.prank(address(this));
        sale.endSale();

        // Approve sale contract to transfer stablecoin
        vm.startPrank(alice);
        _approveStablecoins();

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimals);

        // Deposit and lock NFTs
        vm.expectRevert(SaleIsOver.selector);
        sale.deposit(Stablecoin(stablecoin), amountNoDecimals);
    }

    function testFuzz_deposit(
        uint256 stablecoin,
        uint24 amountNoDecimals
    ) public returns (uint24) {
        stablecoin = _bound(stablecoin, 0, 2);

        amountNoDecimals = uint24(
            _bound(amountNoDecimals, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );

        // Approve sale contract to transfer stablecoin
        vm.startPrank(alice);
        _approveStablecoins();

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimals);
        uint256 oldBalance = (
            stablecoin == 0
                ? _USDT
                : stablecoin == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);

        // Deposit
        emit Deposit(alice, Stablecoin(stablecoin), amountNoDecimals);
        sale.deposit(Stablecoin(stablecoin), amountNoDecimals);

        // Check if deposit was substracted from the user's oldBalance
        uint256 newBalance = (
            stablecoin == 0
                ? _USDT
                : stablecoin == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);
        assertEq(
            newBalance,
            oldBalance - _addDecimals(stablecoin, amountNoDecimals)
        );

        vm.stopPrank();
        return amountNoDecimals;
    }

    function testFuzz_depositEndsSale(
        uint256 stablecoin,
        uint24 amountNoDecimals
    ) public {
        stablecoin = _bound(stablecoin, 0, 2);

        amountNoDecimals = uint24(
            _bound(
                amountNoDecimals,
                MAX_CONTRIBUTIONS_NO_DECIMALS,
                type(uint24).max
            )
        );

        // Approve sale contract to transfer stablecoin
        vm.startPrank(alice);
        _approveStablecoins();

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimals);
        uint256 oldBalance = (
            stablecoin == 0
                ? _USDT
                : stablecoin == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);

        // Deposit and lock NFTs
        if (amountNoDecimals > MAX_CONTRIBUTIONS_NO_DECIMALS) {
            vm.expectEmit();
            emit DepositWasReduced();
        }
        vm.expectEmit();
        emit SaleEnded(uint40(block.timestamp));
        vm.expectEmit();
        emit Deposit(
            alice,
            Stablecoin(stablecoin),
            MAX_CONTRIBUTIONS_NO_DECIMALS
        );
        sale.deposit(Stablecoin(stablecoin), amountNoDecimals);

        // Check if deposit was substracted from the user's oldBalance
        uint256 newBalance = (
            stablecoin == 0
                ? _USDT
                : stablecoin == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);
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

        // Check contributor's state
        Contribution memory contribution = sale.contributions(alice);
        assertEq(
            contribution.amountFinalNoDecimals,
            MAX_CONTRIBUTIONS_NO_DECIMALS
        );
        assertEq(contribution.amountWithdrawableNoDecimals, 0);
    }

    function testFuzz_redepositWrongStablecoin(
        uint256 stablecoin1,
        uint24 amountNoDecimals1,
        uint256 stablecoin2,
        uint24 amountNoDecimals2
    ) public {
        stablecoin1 = _bound(stablecoin1, 0, 2);

        amountNoDecimals1 = testFuzz_deposit(stablecoin1, amountNoDecimals1);

        stablecoin2 = _bound(stablecoin2, 0, 2);
        vm.assume(stablecoin1 != stablecoin2);

        amountNoDecimals2 = uint24(
            _bound(amountNoDecimals2, 1, type(uint24).max)
        );

        // Approve sale contract to transfer stablecoin
        vm.startPrank(alice);
        _approveStablecoins();

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimals2);

        // Deposit and lock NFTs
        vm.expectRevert(WrongStablecoin.selector);
        sale.deposit(Stablecoin(stablecoin2), amountNoDecimals2);
    }

    function testFuzz_redeposit(
        uint256 stablecoin1,
        uint24 amountNoDecimals1,
        uint256 stablecoin2,
        uint24 amountNoDecimals2
    ) public {
        stablecoin1 = _bound(stablecoin1, 0, 2);

        amountNoDecimals1 = testFuzz_deposit(stablecoin1, amountNoDecimals1);

        stablecoin2 = stablecoin1;

        amountNoDecimals2 = uint24(
            _bound(amountNoDecimals2, 1, type(uint24).max)
        );

        // Approve sale contract to transfer stablecoin
        vm.startPrank(alice);
        _approveStablecoins();

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimals2);
        uint256 oldBalance = (
            stablecoin2 == 0
                ? _USDT
                : stablecoin2 == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);

        // Deposit
        bool depositReduced = uint256(amountNoDecimals1) + amountNoDecimals2 >
            MAX_CONTRIBUTIONS_NO_DECIMALS;
        if (depositReduced) {
            vm.expectEmit();
            emit DepositWasReduced();
        }

        vm.expectEmit();
        emit Deposit(
            alice,
            Stablecoin(stablecoin2),
            uint256(amountNoDecimals1) + amountNoDecimals2 >
                MAX_CONTRIBUTIONS_NO_DECIMALS
                ? MAX_CONTRIBUTIONS_NO_DECIMALS - amountNoDecimals1
                : amountNoDecimals2
        );
        sale.deposit(Stablecoin(stablecoin2), amountNoDecimals2);

        // Check if deposit was substracted from the user's oldBalance
        uint256 newBalance = (
            stablecoin2 == 0
                ? _USDT
                : stablecoin2 == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);
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
        uint24 amountNoDecimals
    ) public {
        testFuzz_depositEndsSale(stablecoin, amountNoDecimals);

        // Withdraw
        vm.prank(alice);
        vm.expectRevert(SaleIsOver.selector);
        sale.withdraw();
    }

    function test_withdrawFailsCuzNoDeposit() public {
        // Withdraw
        vm.prank(alice);
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
        vm.startPrank(alice);
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
            _dealStablecoins(alice, amountNoDecimals[i]);

            // Deposit
            sale.deposit(Stablecoin(stablecoin), amountNoDecimals[i]);

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
            stablecoin == 0
                ? _USDT
                : stablecoin == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);

        // Withdraw
        if (cumulativeWithdrawableAmountNoDecimals == 0) {
            vm.expectRevert(NullDeposit.selector);
        } else {
            vm.expectEmit();
            emit Withdrawal(
                alice,
                Stablecoin(stablecoin),
                cumulativeWithdrawableAmountNoDecimals
            );
        }
        sale.withdraw();

        // New balance
        uint256 newBalance = (
            stablecoin == 0
                ? _USDT
                : stablecoin == 1
                    ? _USDC
                    : _DAI
        ).balanceOf(alice);
        assertEq(
            newBalance,
            oldBalance +
                (
                    stablecoin == 0
                        ? 10 ** _USDT_DECIMALS
                        : stablecoin == 1
                            ? 10 ** _USDC_DECIMALS
                            : 10 ** _DAI_DECIMALS
                ) *
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
        vm.startPrank(alice);
        _approveStablecoins();

        amountNoDecimalsA = uint24(
            _bound(amountNoDecimalsA, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimalsA);

        // Deposit
        sale.deposit(Stablecoin(stablecoinA), amountNoDecimalsA);

        // Withdraw
        sale.withdraw();

        // Skip time
        skip(timeElapsedA);

        amountNoDecimalsB = uint24(
            _bound(amountNoDecimalsB, 1, MAX_CONTRIBUTIONS_NO_DECIMALS - 1)
        );

        // Deal stablecoin
        _dealStablecoins(alice, amountNoDecimalsB);

        // Deposit
        sale.deposit(Stablecoin(stablecoinB), amountNoDecimalsB);
    }

    function testFuzz_withdrawFundsWhileSaleIsLive(
        uint256 stablecoin,
        uint24 amountNoDecimals
    ) public {
        // Deposit and lock NFTs
        testFuzz_deposit(stablecoin, amountNoDecimals);

        // Withdraw
        vm.expectRevert(SaleIsLive.selector);
        sale.withdrawFunds();
    }

    function testFuzz_withdrawFundsByWrongCaller(
        uint256 stablecoin,
        uint24 amountNoDecimals,
        address caller
    ) public {
        vm.assume(caller != address(this));

        // Deposit and lock NFTs
        testFuzz_depositEndsSale(stablecoin, amountNoDecimals);

        // Withdraw
        vm.prank(caller);
        vm.expectRevert();
        sale.withdrawFunds();
    }

    function testFuzz_withdrawFunds(
        uint256 stablecoinA,
        uint24 amountNoDecimalsA,
        address user,
        uint256 stablecoinB,
        uint24 amountNoDecimalsB
    ) public {
        user = address(uint160(_bound(uint160(user), 2, type(uint160).max))); // Prevents address 0 and 1. Address 1 fails with USDT

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
        testFuzz_deposit(stablecoinA, amountNoDecimalsA);

        // Deal stablecoins
        _dealStablecoins(user, amountNoDecimalsB);

        // Approve sale contract to transfer stablecoin
        vm.startPrank(user);
        SafeERC20.forceApprove(
            stablecoinB == 0
                ? _USDT
                : stablecoinB == 1
                    ? _USDC
                    : _DAI,
            address(sale),
            type(uint256).max
        );

        // User deposits and lock NFTs
        sale.deposit(Stablecoin(stablecoinB), amountNoDecimalsB);
        vm.stopPrank();

        // Withdraw
        uint256 usdtBalance = _USDT.balanceOf(address(this));
        uint256 usdcBalance = _USDC.balanceOf(address(this));
        uint256 daiBalance = _DAI.balanceOf(address(this));
        sale.withdrawFunds();

        // Check balances
        if (stablecoinA == stablecoinB) {
            uint256 balanceOld = (
                stablecoinA == 0
                    ? usdtBalance
                    : stablecoinA == 1
                        ? usdcBalance
                        : daiBalance
            );
            ERC20 stablecoin = stablecoinA == 0
                ? _USDT
                : stablecoinA == 1
                    ? _USDC
                    : _DAI;
            assertEq(
                stablecoin.balanceOf(address(this)),
                balanceOld +
                    _addDecimals(stablecoinA, MAX_CONTRIBUTIONS_NO_DECIMALS)
            );
        } else {
            {
                uint256 balanceOldA = (
                    stablecoinA == 0
                        ? usdtBalance
                        : stablecoinA == 1
                            ? usdcBalance
                            : daiBalance
                );
                ERC20 stableA = stablecoinA == 0
                    ? _USDT
                    : stablecoinA == 1
                        ? _USDC
                        : _DAI;
                assertEq(
                    stableA.balanceOf(address(this)),
                    balanceOldA + _addDecimals(stablecoinA, amountNoDecimalsA)
                );
            }
            uint256 balanceOldB = (
                stablecoinB == 0
                    ? usdtBalance
                    : stablecoinB == 1
                        ? usdcBalance
                        : daiBalance
            );
            ERC20 stableB = stablecoinB == 0
                ? _USDT
                : stablecoinB == 1
                    ? _USDC
                    : _DAI;
            assertEq(
                stableB.balanceOf(address(this)),
                balanceOldB +
                    _addDecimals(
                        stablecoinB,
                        MAX_CONTRIBUTIONS_NO_DECIMALS - amountNoDecimalsA
                    )
            );
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    /////////////////////// P R I V A T E  F U N C T I O N S //////////////////////
    //////////////////////////////////////////////////////////////////////////////

    function _addDecimals(
        uint256 stablecoin,
        uint amountNoDecimals
    ) private view returns (uint256) {
        if (stablecoin > 2) revert("Invalid stablecoin");
        return
            amountNoDecimals *
            (
                stablecoin == 0
                    ? 10 ** _USDT_DECIMALS
                    : stablecoin == 1
                        ? 10 ** _USDC_DECIMALS
                        : 10 ** _DAI_DECIMALS
            );
    }

    function _approveStablecoins() private {
        SafeERC20.forceApprove(_USDT, address(sale), type(uint256).max);
        _USDC.approve(address(sale), type(uint256).max);
        _DAI.approve(address(sale), type(uint256).max);
    }

    function _dealStablecoins(address to, uint24 amountNoDecimals) private {
        deal(
            address(_USDT),
            to,
            uint256(amountNoDecimals) * 10 ** _USDT_DECIMALS,
            true
        );
        deal(
            address(_USDC),
            to,
            uint256(amountNoDecimals) * 10 ** _USDC_DECIMALS,
            true
        );
        deal(
            address(_DAI),
            to,
            uint256(amountNoDecimals) * 10 ** _DAI_DECIMALS,
            true
        );
    }
}

contract MockToken is ERC20 {
    constructor(address to, uint256 amount) ERC20("Mock Token", "MOCK") {
        _mint(to, amount);
    }
}
