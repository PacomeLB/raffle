// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {AbstractRaffleOptimized} from "./AbstractRaffleOptimized.sol";
import {IraffleVRF} from "../interfaces/IraffleVRF.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "forge-std/console.sol";

/**
 * @title RaffleAdminTax
 * @author Pacome LEBEAU https://github.com/PacomeLB
 * @notice Raffle contract managed by owner adress, defined when deploying the contract
 * the benefit of the raffle is also defined when deploying the contract, be sure where to send the benefit
 * Send the taxRate(%) of the benefit to address tax
 */
contract RaffleAdminPayTaxVrf is AbstractRaffleOptimized, ERC721URIStorage {
    address payable public immutable benefit;
    address payable public immutable tax;

    // Address of the random number generator
    address public immutable vrfContractAddress;
    IraffleVRF immutable vrfContract;

    error TokenURIlengthMustMatchMaxTickets(
        uint8 tokenURIlength,
        uint8 maxTickets
    );

    uint8 private immutable taxRate;
    uint256 public vrfRequestId;
    bool private isVrfRequested = false;

    event RaffleAdminTaxDeployed(
        string message,
        address _owner,
        address _benfit,
        address _tax,
        uint8 _taxRate,
        string _NFTName
    );

    event RaffleAdminTaxPaid(
        string message,
        uint256 taxAmount,
        address taxSentTo
    );

    /**
     * @notice Contrustor for a raffle with VRF from Chainlink
     * @param _maxTickets Number of tickets of the raffle (max 255)
     * @param _prize Prize to win in Wei
     * @param _ticketPrice Price of one ticket in Wei
     * @param _owner Owner address of the raffle
     * @param _benefit Benefit address of the raffle, after paying tax and winner
     * Benefit will get the benefit of the raffle
     * @param _taxRate Tax rate of the benefit to pay in %
     * @param _tax Address to send the tax to
     * @param _name NFT token name
     * @param _tokenURIHashs Array of the URI hash associated with the raffle NFT
     * @param _vrf Address of the VRF interface contract to get a random number
     */
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
        address _vrf
    )
        AbstractRaffleOptimized(
            _maxTickets,
            _prize,
            _ticketPrice,
            _name,
            _owner
        )
    {
        require(
            _maxTickets * _ticketPrice > _prize,
            "Prize must superior to the sum of all tickets"
        );
        // Get array length to save gas as reading length cost
        uint8 tokenURIlength = uint8(_tokenURIHashs.length);

        // Check that that we have an uri for each tickets that will be minted
        if (tokenURIlength != _maxTickets) {
            revert TokenURIlengthMustMatchMaxTickets({
                tokenURIlength: tokenURIlength,
                maxTickets: _maxTickets
            });
        }
        benefit = payable(_benefit);
        tax = payable(_tax);
        taxRate = _taxRate;
        vrfContractAddress = _vrf;
        vrfContract = IraffleVRF(vrfContractAddress);

        // Map token's uri as we will mint nft from 0 to max tickets
        for (uint8 i = 0; i < tokenURIlength; i++) {
            super._setTokenURI(i, string.concat("ipfs://", _tokenURIHashs[i]));
        }
        emit RaffleAdminTaxDeployed(
            "Raffle has been deployed",
            owner(),
            benefit,
            tax,
            taxRate,
            _name
        );
    }

    /**
     * @notice Launch the raffle to get a winner
     */
    function launchRaffle() public virtual override onlyOwner nonReentrant {
        require(
            isRaffleFinished == false,
            "Raffle is finished yet, come back later!"
        );
        require(
            currentTickets == maxTickets,
            "Not all tickets have been sold!"
        );
        require(
            isVrfRequested == false,
            "Raffle has a pending VRF request pending, wait for the oracle to reply"
        );
        //// Will revert if vrfRequestId is not found
        //(uint256 paid, bool fulfilled, uint256[] memory randomWords) = vrfContract.getRequestStatus(vrfRequestId);
        //require(fulfilled == false, "Request already fullfilled, wait the raffle to finish!");

        // Random number has been requested
        isVrfRequested = true;
        vrfRequestId = vrfContract.requestRandomWords(true);
    }

    /**
     * @notice Ensure that benefit are only sent to the address defined when deploying contract
     */
    function withdrawBenefit(
        address payable /*_unused*/
    ) public override onlyOwner nonReentrant {
        require(
            isRaffleFinished == true,
            "Raffle is not yet finished, contract balance will be available once a winner has been drawn"
        );
        console.log("Ballance: %s", address(this).balance);
        console.log("Tax to pay: %s", getTaxAmount());

        uint256 taxAmountToSend = getTaxAmount();
        (bool success, ) = tax.call{value: taxAmountToSend}("");
        require(success, "Tax sent failed");

        uint256 benefitToSend = address(this).balance;
        (success, ) = benefit.call{value: benefitToSend}("");
        require(success, "Benefit sent failed");

        emit RaffleAdminTaxPaid("Tax paid!", taxAmountToSend, tax);
        emit WithdrawBallance(
            "Benefit of the Raffle has been withdraw to",
            benefitToSend,
            benefit
        );
        _resetContract();
    }

    /**
     * @dev Reset the raffle to its initial state
     */
    function _resetContract() internal override {
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
     * @notice Reset the contract to its initial state
     * @dev For test purpose only
     */
    function resetContract() external override onlyOwner nonReentrant {
        withdrawContract();
        isRaffleFinished = false;
        _resetNTFTickets();
        currentTickets = 0;
        isVrfRequested = false;
        vrfRequestId = 0;
    }

    /**
     * @dev Withdraw the raffle contract to the owner
     * Security function for test purpose only
     */
    function withdrawContract() internal {
        uint256 benefitToSend = address(this).balance;
        (bool success, ) = payable(owner()).call{value: benefitToSend}("");
        require(success, "Contract withdraw failed");
    }

    /**
     * @notice Calculate the tax amount to send to the government
     * @dev benefit * (%)tax level
     */
    function getTaxAmount() private view returns (uint256 taxAmountToSend) {
        return (((maxTickets * ticketPrice) - prize) * taxRate) / 100;
    }

    /**
     * @dev Resolve multiple inheritance
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Resolve multiple inheritance
     */
    function tokenURI(
        uint256 _tokenId
    )
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_tokenId);
    }

    /**
     * @dev Actually useless
     */
    function _safeMinter(address _sender, uint256 _tokenID) internal override {
        super._safeMinter(_sender, _tokenID);
    }

    /**
     * @dev Allows oracle VRF to set the random number, used as an interface
     * @param _requestId The id of the chainlink request
     * @param _randomNumbers Array of random numbers
     */
    function setRandomNumber(
        uint256 _requestId,
        uint256[] calldata _randomNumbers
    )
        external
        onlyRaffleVRF("Only VRF contract can set the random number")
        nonReentrant
    {
        require(
            _requestId == vrfRequestId,
            "Random  number request does not match current request!"
        );
        getWinner(_randomNumbers[0]);
    }

    /**
     * @dev Get a winner and send the prize
     * @param _randomNumber Random number to get the winner
     */
    function getWinner(uint256 _randomNumber) internal {
        uint8 winnerTicket = uint8(_randomNumber % maxTickets);

        console.log("Winner ticket is: %s", winnerTicket);
        console.log("Winner address is: %s", _ownerOf(winnerTicket));

        address payable winner = payable(_ownerOf(winnerTicket));
        emit RaffleWinner("Raffle has a winner!", winnerTicket, prize, winner);
        // Send prize to the winner address
        (bool success, ) = winner.call{value: prize}("");
        require(success, "Sending prize failed! Winner loose the prize!");

        isRaffleFinished = true;
    }

    /**
     * @dev Authorize only from the vrfContractAddress
     */
    modifier onlyRaffleVRF(string memory _refusedMessage) {
        require(msg.sender == vrfContractAddress, _refusedMessage);
        _;
    }
}
