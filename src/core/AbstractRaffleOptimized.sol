// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "forge-std/console.sol";

/**
 * @title AbstractRaffle
 * @author Pacome LEBEAU https://github.com/PacomeLB
 * @notice Abstract contract for the raffle
 * @dev Contract with gas optimization
 */

abstract contract AbstractRaffleOptimized is ERC721, ReentrancyGuard, Ownable {
    uint8 public immutable maxTickets; // Maximum ticket to sell
    uint256 public immutable prize; // Prize of the raffle
    uint8 public currentTickets = 0;
    uint256 public immutable ticketPrice; // Price of 1 ticket
    bool internal isRaffleFinished = false;

    event YourParticipation(address indexed _player, uint8 _NFTnumber);
    event RaffleWinner(
        string _message,
        uint8 _winnerTicket,
        uint256 _prize,
        address _winnerAddress
    );
    event RaffleReset(string _message);
    event WithdrawBallance(
        string _message,
        uint256 _benefitWei,
        address _benefitAddress
    );

    error ImpossibleToCreateNFTTicket(string message, address buyerAddress);

    constructor(
        uint8 _maxTickets,
        uint256 _prize,
        uint256 _ticketPrice,
        string memory _raffleName,
        address _owner
    ) ERC721(_raffleName, "RFFLNFT") Ownable(_owner) {
        maxTickets = _maxTickets;
        prize = _prize;
        ticketPrice = _ticketPrice;
    }

    /**
     * @notice Get the price of a unit ticket
     * @return The price of 1 ticket in Wei
     */
    function getTicketPrice() public view returns (uint256) {
        return ticketPrice;
    }

    /**
     * @notice Buy tickets with ether and mint nft
     * Send back the excess amount of ether
     * @param _nbTicketToBuyAsked Number of ticket that player wants to buy
     */
    function buyTickets(
        uint8 _nbTicketToBuyAsked
    ) public payable virtual nonReentrant {
        console.log(
            "Asking to get %s tickets from %s with amount %s",
            _nbTicketToBuyAsked,
            msg.sender,
            msg.value
        );
        require(
            !isRaffleFinished,
            "Raffle is finished yet! Please come again later"
        );
        require(currentTickets < maxTickets, "Raffle has sell all the tickets");
        require(
            msg.value >= _nbTicketToBuyAsked * ticketPrice,
            "Please send the a necessary amount or more to buy tickets, check 'getTicketPrice()'"
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
            if (!participateAndNFT(msg.sender)) {
                // Revert the whole transaction, ie all ticket
                revert ImpossibleToCreateNFTTicket({
                    message: "Can't participate because minting failed",
                    buyerAddress: msg.sender
                });
            }
        }

        excessEther = msg.value - ((ticketBuyable) * ticketPrice);
        if (excessEther > 0) {
            payable(msg.sender).transfer(excessEther);
            console.log(
                "Sending back amount %s to %s",
                excessEther,
                msg.sender
            );
        }
        console.log(
            "currentTickets :%s and maxTickets :%s",
            currentTickets,
            maxTickets
        );
    }

    /**
     * @notice Direct call to contract, try to buy as much as ticket as possible
     */
    receive() external payable virtual {
        uint256 maxTicketBuyable = msg.value / ticketPrice;

        if (maxTicketBuyable > 255) {
            maxTicketBuyable = 255;
        }

        buyTickets(uint8(maxTicketBuyable));
    }

    /**
     * @notice Get number of available tickets
     * @return The number of tickets that can be bought
     */
    function availableTickets() public view returns (uint8) {
        return maxTickets - currentTickets;
    }

    /**
     * @dev Allow to override the default behaviour in child contract
     * @param _sender Address to associate the NFT with
     * @param _tokenID The token to associate with the address (a ticket number here)
     */
    function _safeMinter(address _sender, uint256 _tokenID) internal virtual {
        super._safeMint(_sender, _tokenID);
    }

    /**
     * @dev Mint a NFT with _sender, the NFT is the ticket
     * @param _sender Address of the ticket buyer to associate with the NFT
     * @return True if the nft has been minted, false otherwise
     */
    function participateAndNFT(address _sender) internal returns (bool) {
        _safeMinter(_sender, currentTickets);

        // Check that token has been minted correctly
        if (_ownerOf(currentTickets) == _sender) {
            console.log(
                "A raffle ticket %s has been minted for owner %s",
                currentTickets,
                _sender
            );
            emit YourParticipation(_sender, currentTickets);
            currentTickets++;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Launch the raffle
     * Please add a modifier in child contract to limit usage
     * Emit event with the winner address and its prize
     */
    function launchRaffle() public virtual nonReentrant {
        require(
            isRaffleFinished == false,
            "Raffle is finished yet, come back later!"
        );
        require(
            currentTickets == maxTickets,
            "Not all tickets have been sold!"
        );
        // Not really random but should do the job
        // We can use block.prevrandao but with evm >=paris but still not really random
        uint8 winnerTicket = uint8(getRandom(0, maxTickets - 1));
        console.log("Winner ticket is: %s", winnerTicket);
        console.log("Winner address is: %s", _ownerOf(winnerTicket));
        address payable winner = payable(_ownerOf(winnerTicket));
        emit RaffleWinner("Raffle has a winner!", winnerTicket, prize, winner);
        // Send prize to the winner address
        winner.transfer(prize);
        isRaffleFinished = true;
    }

    /**
     * @notice Transfer the contract balance to _benefit address
     * @param _benefit To send the contract balance to
     */
    function withdrawBenefit(address payable _benefit) public virtual;

    /**
     * @dev Reset the raffle to its initial state
     */
    function _resetContract() internal virtual {
        require(
            isRaffleFinished == true,
            "You can only reset this contract once the raffle is finished."
        );
        _resetNTFTickets();
        currentTickets = 0;
        isRaffleFinished = false;
        emit RaffleReset("Raffle has been reset");
    }

    /**
     * @notice Reset the contract from outside
     * @dev Only for development purpose
     * Make sure to override it for production deployment
     */
    function resetContract() external virtual nonReentrant {
        _resetContract();
    }

    /**
     * @dev Reset / burn all nft that has been minted
     */
    function _resetNTFTickets() internal {
        for (uint8 i = 0; i < currentTickets; i++) {
            _burn(i);
        }
    }

    /**
     * @dev Get an "almost" random  number between _min and _max included
     * @param _min The minimum number to return (from 0)
     * @param _max The maximum number to return (until 255 included)
     * @return The random number generated
     */
    function getRandom(
        uint8 _min,
        uint8 _max
    ) internal virtual returns (uint8) {
        // Not really random but should do the job
        // We can use block.prevrandao but with evm >=paris but still not really random
        return
            uint8(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            block.timestamp,
                            block.prevrandao,
                            msg.sender
                        )
                    )
                ) % (_max - _min + 1)
            ) + _min;
    }
}
