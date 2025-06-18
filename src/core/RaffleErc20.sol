// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./RaffleAdminPayTaxVrf.sol";
import {IswapContract} from "../interfaces/IswapContract.sol";

/**
 * @title RaffleErc20
 * @author Pakish https://github.com/Pakish
 * @notice Raffle contract managed by owner adress, defined when deploying the contract
 * the benefit of the raffle is also defined when deploying the contract, be sure where to send the benefit
 * Send the taxRate(%) of the benefit to address tax
 */

contract RaffleErc20 is RaffleAdminPayTaxVrf {
    address public immutable swapContractAddress;
    IswapContract immutable swapContract;

    constructor(
        uint8 _maxTickets,
        uint256 _prize,
        uint256 _ticketPrice,
        address _owner,
        address _benefit,
        uint8 _taxRate,
        address _tax,
        string memory _name,
        string[] memory _tokenURIHashs,
        address _vrf,
        address _swapContractAddress
    )
        RaffleAdminPayTaxVrf(
            _maxTickets,
            _prize,
            _ticketPrice,
            _owner,
            _benefit,
            _taxRate,
            _tax,
            _name,
            _tokenURIHashs,
            _vrf
        )
    {
        swapContractAddress = _swapContractAddress;
        swapContract = IswapContract(swapContractAddress);
    }

    /**
     * @notice Buy raffle ticket with an Erc20 token. Swap it and buy ticket with the swapped eth
     * @dev Performs a token swap using Permit2 for gasless approval
     * @param _nbTicketToBuyAsked number of ticket the buyer wants to buy
     * @param _signature The EIP712 signature for Permit2 authorization
     * @param _tokenErc20 The address of the ERC20 token to swap
     * @param _amountErc20In The exact amount of ERC20 tokens to swap
     * @param _nonce The unique nonce value for this signature
     * @param _deadline The expiration timestamp of the signature (UNIX timestamp)
     * @param _fee The fee tier for the liquidity pool (in basis points, e.g., 3000 = 0.3%)
     * @return uint8 the number of tickets bought
     */
    function buyTicketWithErc20(
        uint8 _nbTicketToBuyAsked,
        bytes calldata _signature,
        address _tokenErc20,
        uint256 _amountErc20In,
        uint256 _nonce,
        uint256 _deadline,
        uint24 _fee
    ) public nonReentrant returns (uint8) {
        // Calculate min amount out to buy the ticket
        uint256 minAmountOutEth = _nbTicketToBuyAsked * ticketPrice;
        uint256 receivedAmountOutEth = swapContract.swapErc20ToEthAndTransfer(
            _signature,
            msg.sender,
            _tokenErc20,
            _amountErc20In,
            minAmountOutEth,
            _nonce,
            _deadline,
            _fee,
            payable(address(this))
        );

        return
            _buyTickets(_nbTicketToBuyAsked, receivedAmountOutEth, msg.sender);
    }

    /**
     * Internal buy tickets with ether and mint nft
     * Should only be call after receiving eth from a swap
     * @param _nbTicketToBuyAsked number of ticket that player wants to buy
     * @param _swappedEthAmount the amount of wei eth we received from the swap
     * @param _buyerAddress the address of the ticket buyer
     */
    function _buyTickets(
        uint8 _nbTicketToBuyAsked,
        uint256 _swappedEthAmount,
        address _buyerAddress
    ) internal virtual returns (uint8) {
        console.log(
            "Internaly asking to get %s tickets from %s with amount %s",
            _nbTicketToBuyAsked,
            _buyerAddress,
            _swappedEthAmount
        );
        require(
            !isRaffleFinished,
            "Raffle is finished yet! Please come again later"
        );
        require(currentTickets < maxTickets, "Raffle has sell all the tickets");
        require(
            _swappedEthAmount >= _nbTicketToBuyAsked * ticketPrice,
            "The swap did not give enough Eth!"
        );

        uint256 excessEther;
        // Calculate the number to buy. In case of less tickets available than asked
        uint8 ticketBuyable;
        if (maxTickets - currentTickets < _nbTicketToBuyAsked) {
            ticketBuyable = maxTickets - currentTickets;
        } else {
            ticketBuyable = _nbTicketToBuyAsked;
        }

        for (uint8 i = 0; i < ticketBuyable; i++) {
            // Todo make participation ok if less tickets created, ie don't revert all
            if (!participateAndNFT(_buyerAddress)) {
                // Revert the whole transaction, ie all ticket
                revert ImpossibleToCreateNFTTicket({
                    message: "Can't participate because minting failed",
                    buyerAddress: _buyerAddress
                });
            }
        }

        excessEther = _swappedEthAmount - ((ticketBuyable) * ticketPrice);
        if (excessEther > 0) {
            payable(_buyerAddress).transfer(excessEther);
            console.log(
                "Internaly sending back amount %s to %s",
                excessEther,
                _buyerAddress
            );
        }
        console.log(
            "Internaly currentTickets :%s and maxTickets :%s",
            currentTickets,
            maxTickets
        );

        return ticketBuyable;
    }

    /**
     * Override receive to do nothing as we gonna receive eth from swap contract
     */
    receive() external payable override {}
}
