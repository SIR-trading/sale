// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SaleStructs {
    uint24 public constant MAX_CONTRIBUTIONS_NO_DECIMALS = 500_000; // [$]

    event SaleEnded(uint40 timeSaleEnded);
    event DepositWasReduced();

    event Deposit(Stablecoin stablecoin, uint24 amountNoDecimals); // NOT USED YET!
    event Withdrawal(Stablecoin stablecoin, uint24 amountNoDecimals);
    event ButerinCardLocked(uint16 tokenId);
    event MinedJpegLocked(uint8 tokenId);
    event ButerinCardUnlocked(uint16 tokenId);
    event MinedJpegUnlocked(uint8 tokenId);

    error WrongStablecoin();
    error NullDeposit();
    error NullAddress();
    error SaleIsOver();
    error TooManyNfts();
    error NftsLocked();
    error SaleIsLive();
    error NoNfts();

    enum Stablecoin {
        USDT,
        USDC,
        DAI
    }

    struct LockedButerinCards {
        uint8 number;
        uint16[5] ids;
    }

    struct LockedMinedJpegs {
        uint8 number;
        uint8[5] ids;
    }

    struct Contribution {
        Stablecoin stablecoin;
        uint24 amountFinalNoDecimals;
        uint24 amountWithdrawableNoDecimals;
        uint40 timeLastContribution;
        LockedButerinCards lockedButerinCards;
        LockedMinedJpegs lockedMinedJpegs;
    }

    struct SaleState {
        uint24 totalContributionsNoDecimals;
        uint40 timeSaleEnded;
    }
}
