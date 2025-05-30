// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TransferHelper} from "solidity-lib/TransferHelper.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "openzeppelin/token/ERC721/IERC721.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {SaleStructs} from "./SaleStructs.sol";

/** @notice Sale contract for SIR
    @notice Accepts USDT, USDC & DAI
    @notice Users can lock up to 5 Buterin Cards or Mined JPEGs to boost their token allocations
    @notice Users can withdraw their deposits before 24 hours have passed
    @notice Users can withdraw their NFTs 1 year after the sale ended
 */
abstract contract BaseSale is SaleStructs, Ownable {
    address internal immutable _USDT;
    address internal immutable _USDC;
    address internal immutable _DAI;

    IERC721 internal immutable _BUTERIN_CARDS;
    IERC721 internal immutable _MINED_JPEG;

    uint8 private constant _USDT_DECIMALS = 6;
    uint8 private constant _USDC_DECIMALS = 6;
    uint8 private constant _DAI_DECIMALS = 18;

    SaleState private _state;

    mapping(address contributor => Contribution) private _contributions;

    ////////////////////////////////////////////////////////////////////////////////
    //////////////// S T A T E - C H A N G I N G  F U N C T I O N S ///////////////
    //////////////////////////////////////////////////////////////////////////////

    constructor(
        address USDT_,
        address USDC_,
        address DAI_,
        address buterinCards,
        address minedJPEG
    ) Ownable(msg.sender) {
        _USDT = USDT_;
        _USDC = USDC_;
        _DAI = DAI_;
        _BUTERIN_CARDS = IERC721(buterinCards);
        _MINED_JPEG = IERC721(minedJPEG);
    }

    /** @notice Deposits USDT, USDC or DAI and, optionally, locks up to 5 Buterin Cards or Mined JPEGs
        @notice Users can deposit multiple times
        @notice Once one stablecoin is deposited, the user cannot deposit another stablecoin
        @param stablecoin The stablecoin to deposit
        @param amountNoDecimals The amount to deposit in the stablecoin without decimals
        @param buterinCardIds The IDs of the Buterin Cards to lock
        @param minedJpegIds The IDs of the Mined JPEGs to lock
     */
    function depositAndLockNfts(
        Stablecoin stablecoin,
        uint24 amountNoDecimals,
        uint16[] calldata buterinCardIds,
        uint8[] calldata minedJpegIds
    ) external {
        // maxAmountNoDecimals ensures that the total contributions do not exceed MAX_CONTRIBUTIONS_NO_DECIMALS
        unchecked {
            if (amountNoDecimals == 0) revert NullDeposit();

            // Revert if sale is over
            SaleState memory state_ = _state;
            if (state_.timeSaleEnded > 0) revert SaleIsOver();

            // Limit the contribution if it exceeds the maximum
            uint24 maxAmountNoDecimals = MAX_CONTRIBUTIONS_NO_DECIMALS -
                state_.totalContributionsNoDecimals;
            if (amountNoDecimals >= maxAmountNoDecimals) {
                if (amountNoDecimals > maxAmountNoDecimals) {
                    // Truncate the contribution
                    amountNoDecimals = maxAmountNoDecimals;

                    // Emit event
                    emit DepositWasReduced();
                }

                // End sale
                _endSale(state_);
            }

            // Update _state
            state_.totalContributionsNoDecimals += amountNoDecimals;

            // Update contribution
            Contribution memory contribution = contributions(msg.sender);
            if (
                contribution.amountFinalNoDecimals +
                    contribution.amountWithdrawableNoDecimals ==
                0
            ) {
                // 1st contribution
                contribution.stablecoin = stablecoin;
            } else if (stablecoin != contribution.stablecoin) {
                revert WrongStablecoin();
            }
            contribution.amountWithdrawableNoDecimals += amountNoDecimals;
            contribution.timeLastContribution = uint40(block.timestamp);

            // Lock NFTs
            _lockNfts(buterinCardIds, minedJpegIds, contribution);

            // Save contribution and _state
            _state = state_;
            _contributions[msg.sender] = contribution;

            // Emit event
            emit Deposit(stablecoin, amountNoDecimals);

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
    }

    /** @notice Contributors can withdraw their deposits before 24 hours have passed
     */
    function withdraw() external {
        // Revert if sale is over
        SaleState memory state_ = _state;
        if (state_.timeSaleEnded > 0) revert SaleIsOver();

        // Revert if the user has made no contribution in the last 24 hours
        Contribution memory contribution = contributions(msg.sender);
        if (contribution.amountWithdrawableNoDecimals == 0)
            revert NullDeposit();

        // Update contribution
        uint24 amountWithdrawableNoDecimals = contribution
            .amountWithdrawableNoDecimals;
        contribution.amountWithdrawableNoDecimals = 0;
        _contributions[msg.sender] = contribution;

        // Update _state
        unchecked {
            // amountWithdrawableNoDecimals is always less than or equal to totalContributionsNoDecimals
            state_.totalContributionsNoDecimals -= amountWithdrawableNoDecimals;
        }
        _state = state_;

        // Emit event
        emit Withdrawal(contribution.stablecoin, amountWithdrawableNoDecimals);

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

    /** @notice Locks up to 5 Buterin Cards or Mined JPEGs
        @param buterinCardIds The IDs of the Buterin Cards to lock
        @param minedJpegIds The IDs of the Mined JPEGs to lock
     */
    function lockNfts(
        uint16[] calldata buterinCardIds,
        uint8[] calldata minedJpegIds
    ) external {
        // Revert if sale is over
        SaleState memory state_ = _state;
        if (state_.timeSaleEnded > 0) revert SaleIsOver();

        // Lock NFTs
        Contribution memory contribution = contributions(msg.sender);
        _lockNfts(buterinCardIds, minedJpegIds, contribution);

        // Save contribution
        _contributions[msg.sender] = contribution;
    }

    /** @notice Withdraws the Buterin Cards and Mined JPEGs locked by the user
        @notice Users can withdraw their NFTs 1 year after the sale ended
     */
    function withdrawNfts() external {
        // i++ will never overflow
        unchecked {
            // Revert if it is less than 1 year since the sale ended
            uint40 timeSaleEnded = _state.timeSaleEnded;
            if (
                timeSaleEnded == 0 || block.timestamp < timeSaleEnded + 365 days
            ) revert NftsLocked();

            // Withdraw NFTs
            Contribution memory contribution = contributions(msg.sender);
            LockedButerinCards memory lockedButerinCards = contribution
                .lockedButerinCards;
            LockedMinedJpegs memory lockedMinedJpegs = contribution
                .lockedMinedJpegs;

            if (lockedButerinCards.number == 0 && lockedMinedJpegs.number == 0)
                revert NoNfts();

            // Transfer Buterin Cards
            for (uint256 i = 0; i < lockedButerinCards.number; ++i) {
                _BUTERIN_CARDS.transferFrom(
                    address(this),
                    msg.sender,
                    lockedButerinCards.ids[i]
                );
                emit ButerinCardUnlocked(lockedButerinCards.ids[i]);
            }

            // Transfer Mined JPEGs
            for (uint256 i = 0; i < lockedMinedJpegs.number; ++i) {
                _MINED_JPEG.transferFrom(
                    address(this),
                    msg.sender,
                    lockedMinedJpegs.ids[i]
                );
                emit MinedJpegUnlocked(lockedMinedJpegs.ids[i]);
            }

            // Update contribution
            contribution.lockedButerinCards.number = 0;
            contribution.lockedMinedJpegs.number = 0;

            // Save contribution
            _contributions[msg.sender] = contribution;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    ///////////////////////// O W N E R  F U N C T I O N S ////////////////////////
    //////////////////////////////////////////////////////////////////////////////

    /** @notice Ends the sale prematurely
     */
    function endSale() external onlyOwner {
        // Get _state
        SaleState memory state_ = _state;

        // Revert if sale is already over
        if (state_.timeSaleEnded > 0) revert SaleIsOver();

        // End sale
        _endSale(state_);

        // Update _state
        _state = state_;
    }

    /** @notice Withdraws all USDT, USDC & DAI from the contract if the sale is over
     */
    function withdrawFunds() external onlyOwner {
        // Revert if sale is live
        SaleState memory state_ = _state;
        if (state_.timeSaleEnded == 0) revert SaleIsLive();

        // Withdraw USDT
        TransferHelper.safeTransfer(
            _USDT,
            msg.sender,
            IERC20(_USDT).balanceOf(address(this))
        );

        // Withdraw USDC
        TransferHelper.safeTransfer(
            _USDC,
            msg.sender,
            IERC20(_USDC).balanceOf(address(this))
        );

        // Withdraw DAI
        TransferHelper.safeTransfer(
            _DAI,
            msg.sender,
            IERC20(_DAI).balanceOf(address(this))
        );
    }

    /** @notice Withdraws any ERC20 token in case any worthy token (that is not USDT, USDC or DAI) was sent to the contract
     */
    function withdrawExoticERC20(address token) external onlyOwner {
        // Revert if sale is live
        SaleState memory state_ = _state;
        if (state_.timeSaleEnded == 0) revert SaleIsLive();

        TransferHelper.safeTransfer(
            token,
            msg.sender,
            IERC20(token).balanceOf(address(this))
        );
    }

    /** @notice Just in case something goes wrong, owner can unlock all NFTs
     */
    function unlockAllNfts() external onlyOwner {
        // It simulates that the sale ended on Jan 1, 1970, which effectively allows every contributor to withdraw their NFTs
        // It also haults deposits.
        _state.timeSaleEnded = 1;
    }

    ////////////////////////////////////////////////////////////////////////////////
    //////////////////// R E A D -  O N L Y  F U N C T I O N S ////////////////////
    //////////////////////////////////////////////////////////////////////////////

    function state() public view returns (SaleState memory) {
        return _state;
    }

    /** @notice Returns the contribution of a user including stablecoin of choice, (un)withdrawable amounts, and locked NFTs
        @param contributor The address of the contributor
     */
    function contributions(
        address contributor
    ) public view returns (Contribution memory) {
        unchecked {
            Contribution memory contribution = _contributions[contributor];
            if (
                block.timestamp >=
                contribution.timeLastContribution + 24 hours ||
                _state.timeSaleEnded > 0
            ) {
                // If 24 hours have passed since the last deposit, the user cannot withdraw the previous deposit
                contribution.amountFinalNoDecimals += contribution
                    .amountWithdrawableNoDecimals;
                contribution.amountWithdrawableNoDecimals = 0;
            }
            return contribution;
        }
    }

    ////////////////////////////////////////////////////////////////////////////////
    ////////////////////// P R I V A T E  F U N C T I O N S ///////////////////////
    //////////////////////////////////////////////////////////////////////////////

    function _endSale(SaleState memory state_) private {
        // Update last deposit time
        state_.timeSaleEnded = uint40(block.timestamp);

        // Emit event
        emit SaleEnded(uint40(block.timestamp));
    }

    function _lockNfts(
        uint16[] calldata buterinCardIds,
        uint8[] calldata minedJpegIds,
        Contribution memory contribution
    ) private {
        // Revert if the total of locked NFTs exceeds 5
        if (
            buterinCardIds.length +
                minedJpegIds.length +
                contribution.lockedButerinCards.number +
                contribution.lockedMinedJpegs.number >
            5
        ) revert TooManyNfts();

        // ++i will never overflow
        unchecked {
            // Update contribution
            for (uint256 i = 0; i < buterinCardIds.length; ++i) {
                contribution.lockedButerinCards.ids[
                    contribution.lockedButerinCards.number++
                ] = buterinCardIds[i];
                emit ButerinCardLocked(buterinCardIds[i]);
            }

            for (uint256 i = 0; i < minedJpegIds.length; ++i) {
                contribution.lockedMinedJpegs.ids[
                    contribution.lockedMinedJpegs.number++
                ] = minedJpegIds[i];
                emit MinedJpegLocked(minedJpegIds[i]);
            }

            // Transfer Buterin Cards
            for (uint256 i = 0; i < buterinCardIds.length; ++i) {
                _BUTERIN_CARDS.transferFrom(
                    msg.sender,
                    address(this),
                    buterinCardIds[i]
                );
            }

            // Transfer Mined JPEGs
            for (uint256 i = 0; i < minedJpegIds.length; ++i) {
                _MINED_JPEG.transferFrom(
                    msg.sender,
                    address(this),
                    minedJpegIds[i]
                );
            }
        }
    }

    function _addDecimals(
        Stablecoin stablecoin,
        uint256 amountNoDecimals
    ) private pure returns (uint256) {
        unchecked {
            if (stablecoin == Stablecoin.USDT) {
                return amountNoDecimals * 10 ** _USDT_DECIMALS;
            }
            if (stablecoin == Stablecoin.USDC) {
                return amountNoDecimals * 10 ** _USDC_DECIMALS;
            }
            return amountNoDecimals * 10 ** _DAI_DECIMALS;
        }
    }
}
