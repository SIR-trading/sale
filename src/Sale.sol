// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {TransferHelper} from "solidity-lib/TransferHelper.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";

/**
    - Accepts USDT, USDC & DAI
    - Users can lock Buterin Cards or Mined JPEGs
    - Create withdrawal function for any ERC20 token for safety
    - BC or MJ can be locked up to 5 at any time before the sale, after that the contract stops.
    - Sale is over once we got 500k USDT+USDC+DAI, no more tokens are accepted.
    - Sale can be ended by the owner
    - Use events to track deposits
    - Users can withdraw funds up to 24 after depositing.
    - Min bits for storing balances:
        - USDT: 6 → 10^6 * 0.5*10^5 <= 2^40 → 40 bits 
        - USDC: 6 → 10^6 * 0.5*10^5 <= 2^40 → 40 bits
        - DAI: 18 → 10^18 * 0.5*10^5 <= 2^80 → 80 bits
 */
contract Sale {
    event SaleEnded();
    event DepositGotTruncated();

    error WrongStablecoin();
    error NullDeposit();
    error SaleIsOver();

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
        uint40 lastDepositTime;
        LockedButerinCards lockedButerinCards;
        LockedMinedJpegs lockedMinedJpegs;
    }

    struct SaleState {
        uint24 totalContributionsNoDecimals;
        bool saleIsOver;
    }

    address private constant _USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address private constant _USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant _DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint8 private constant _USDT_DECIMALS = 6;
    uint8 private constant _USDC_DECIMALS = 6;
    uint8 private constant _DAI_DECIMALS = 18;

    IERC721 private _buterinCard =
        IERC721(0x5726C14663A1EaD4A7D320E8A653c9710b2A2E89);
    IERC721 private _minedJpeg =
        IERC721(0x7cd51FA7E155805C34F333ba493608742A67Da8e);

    uint24 public constant MAX_CONTRIBUTIONS_NO_DECIMALS = 500_000; // [$]

    SaleState public state;

    mapping(address contributor => Contribution) private _contributions;

    function deposit(Stablecoin stablecoin, uint24 amountNoDecimals) public {
        if (amountNoDecimals == 0) revert NullDeposit();

        // Revert if sale is over
        SaleState memory state_ = state;
        if (state_.saleIsOver) revert SaleIsOver();

        // Limit the contribution if it exceeds the maximum
        uint24 maxAmountNoDecimals = MAX_CONTRIBUTIONS_NO_DECIMALS -
            state_.totalContributionsNoDecimals;
        if (amountNoDecimals >= maxAmountNoDecimals) {
            if (amountNoDecimals > maxAmountNoDecimals) {
                // Truncate the contribution
                amountNoDecimals = maxAmountNoDecimals;

                // Emit event
                emit DepositGotTruncated();
            }

            // End the sale
            state_.saleIsOver = true;

            // Emit event
            emit SaleEnded();
        }

        // Update state
        state_.totalContributionsNoDecimals += amountNoDecimals;
        state = state_;

        // Update contribution
        Contribution memory contribution = contributions(msg.sender);
        if (
            contribution.amountFinalNoDecimals +
                contribution.amountWithdrawableNoDecimals ==
            0
        ) {
            // 1st time contributor
            contribution.stablecoin = stablecoin;
        } else if (stablecoin != contribution.stablecoin) {
            revert WrongStablecoin();
        }
        contribution.amountWithdrawableNoDecimals += amountNoDecimals;
        contribution.lastDepositTime = uint40(block.timestamp);
        _contributions[msg.sender] = contribution;

        // Transfer tokens to the contract
        TransferHelper.safeTransferFrom(
            stablecoin == Stablecoin.USDT
                ? _USDT
                : stablecoin == Stablecoin.USDC
                ? _USDC
                : _DAI,
            msg.sender,
            address(this),
            _addDecimals(stablecoin, amountNoDecimals)
        );
    }

    function withdraw() external {
        // Revert if sale is over
        SaleState memory state_ = state;
        if (state_.saleIsOver) revert SaleIsOver();

        // Revert if the user has made no contribution in the last 24 hours
        Contribution memory contribution = contributions(msg.sender);
        if (contribution.amountWithdrawableNoDecimals == 0)
            revert NullDeposit();

        // Update contribution
        uint24 amountWithdrawableNoDecimals = contribution
            .amountWithdrawableNoDecimals;
        contribution.amountWithdrawableNoDecimals = 0;
        _contributions[msg.sender] = contribution;

        // Update total contributions
        state_.totalContributionsNoDecimals -= amountWithdrawableNoDecimals;

        // Transfer tokens to the user
        TransferHelper.safeTransfer(
            contribution.stablecoin == Stablecoin.USDT
                ? _USDT
                : contribution.stablecoin == Stablecoin.USDC
                ? _USDC
                : _DAI,
            msg.sender,
            _addDecimals(contribution.stablecoin, amountWithdrawableNoDecimals)
        );
    }

    // // TO INSPECT!!
    // function lockNfts(
    //     uint256[] calldata buterinCardIds,
    //     uint256[] calldata minedJpegIds
    // ) public {
    //     // Revert if the sale has ended
    //     if (totalContributions18Decimals == MAX_CONTRIBUTIONS_18_DECIMALS)
    //         revert SaleIsOver();

    //     // Revert if the user has already locked 5 NFTs
    //     if (buterinCardIds.length + minedJpegIds.length > 5)
    //         revert SaleIsOver();

    //     // Lock Buterin Cards
    //     for (uint256 i = 0; i < buterinCardIds.length; i++) {
    //         _buterinCard.transferFrom(
    //             msg.sender,
    //             address(this),
    //             buterinCardIds[i]
    //         );
    //     }

    //     // Lock Mined JPEGs
    //     for (uint256 i = 0; i < minedJpegIds.length; i++) {
    //         _minedJpeg.transferFrom(msg.sender, address(this), minedJpegIds[i]);
    //     }
    // }

    function contributions(
        address contributor
    ) public view returns (Contribution memory) {
        Contribution memory contribution = _contributions[contributor];
        if (block.timestamp >= contribution.lastDepositTime + 24 hours) {
            // If 24 hours have passed since the last deposit, the user cannot withdraw the previous deposit
            contribution.amountFinalNoDecimals += contribution
                .amountWithdrawableNoDecimals;
            contribution.amountWithdrawableNoDecimals = 0;
        }
        return contribution;
    }

    function _addDecimals(
        Stablecoin stablecoin,
        uint256 amountNoDecimals
    ) private pure returns (uint256) {
        if (stablecoin == Stablecoin.USDT) {
            return amountNoDecimals * 10 ** _USDT_DECIMALS;
        }
        if (stablecoin == Stablecoin.USDC) {
            return amountNoDecimals * 10 ** _USDC_DECIMALS;
        }
        return amountNoDecimals * 10 ** _DAI_DECIMALS;
    }
}
