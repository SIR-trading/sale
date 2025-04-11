// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {TransferHelper} from "solidity-lib/TransferHelper.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin/access/Ownable2Step.sol";
import {SaleStructsV2} from "./SaleStructsV2.sol";

/** @notice Sale contract for SIR. Accepts USDT, USDC & DAI.
 *  Users can withdraw their deposits before 24 hours have passed.
 *  @dev Based on BaseSale.sol but without the NFTs.
 */
abstract contract BaseSaleV2 is SaleStructsV2, Ownable2Step {
    address internal immutable _USDT;
    address internal immutable _USDC;
    address internal immutable _DAI;

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
        address DAI_
    ) Ownable(msg.sender) {
        _USDT = USDT_;
        _USDC = USDC_;
        _DAI = DAI_;
    }

    /** @notice Deposits USDT, USDC or DAI. Users can deposit multiple times
        @dev Once one stablecoin is deposited, the user cannot deposit another stablecoin
        @param stablecoin The stablecoin to deposit
        @param amountNoDecimals The amount to deposit in the stablecoin without decimals
     */
    function deposit(Stablecoin stablecoin, uint24 amountNoDecimals) external {
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

            // Save contribution and _state
            _state = state_;
            _contributions[msg.sender] = contribution;

            // Emit event
            emit Deposit(msg.sender, stablecoin, amountNoDecimals);

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
        emit Withdrawal(
            msg.sender,
            contribution.stablecoin,
            amountWithdrawableNoDecimals
        );

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
