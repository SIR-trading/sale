// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract SaleStructsV2 {
    uint24 public constant MAX_CONTRIBUTIONS_NO_DECIMALS = 100_000; // [$]

    event SaleEnded(uint40 timeSaleEnded);
    event DepositWasReduced();

    event Deposit(
        address indexed contributor,
        Stablecoin stablecoin,
        uint24 amountNoDecimals
    );
    event Withdrawal(
        address indexed contributor,
        Stablecoin stablecoin,
        uint24 amountNoDecimals
    );

    error WrongStablecoin();
    error NullDeposit();
    error SaleIsOver();
    error SaleIsLive();

    enum Stablecoin {
        USDT,
        USDC,
        DAI
    }

    struct Contribution {
        Stablecoin stablecoin;
        uint24 amountFinalNoDecimals;
        uint24 amountWithdrawableNoDecimals;
        uint40 timeLastContribution;
    }

    struct SaleState {
        uint24 totalContributionsNoDecimals;
        uint40 timeSaleEnded;
    }
}
