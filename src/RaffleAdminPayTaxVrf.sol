// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import "./AbstractRaffleOptimized.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/**
 * @title RaffleAdminTax
 * @author LEBEAU Pacôme
 * @notice Raffle contract managed by admin adress, defined when deploying the contract
 * the benefit of the raffle is also defined when deploying the contract, be sure where to send the benefit
 * Send the taxRate(%) of the benefit to address tax
 */
contract RaffleAdminPayTaxVrf is AbstractRaffleOptimized, ERC721URIStorage {
    address payable public immutable admin;
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
        address _admin,
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
     * Contrustor for a raffle with VRF from Chainlink
     * @param _maxTickets number of tickets of the raffle (max 255)
     * @param _prize prize to win in Wei
     * @param _ticketPrice price of one ticket in Wei
     * @param _admin admin address of the raffle
     * @param _benefit benefit address of the raffle, after paying tax and winner, benefit will get the benefit of the raffle
     * @param _taxRate tax rate of the benefit to pay in %
     * @param _tax address to send the tax to
     * @param _name NFT token name
     * @param _tokenURIHashs array of the URI hash associated with the raffle NFT
     * @param _vrf address of the VRF interface contract to get a random number
     */
    constructor(
        uint8 _maxTickets,
        uint256 _prize,
        uint256 _ticketPrice,
        address _admin,
        address _benefit,
        uint8 _taxRate,
        address _tax,
        string memory _name,
        string[] memory _tokenURIHashs,
        address _vrf
    ) AbstractRaffleOptimized(_maxTickets, _prize, _ticketPrice, _name) {
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
        admin = payable(_admin);
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
            "Raffle admin has been deployed",
            admin,
            benefit,
            tax,
            taxRate,
            _name
        );
    }

    /**
     * Launch the raffle to get a winner
     */
    function launchRaffle()
        public
        override
        onlyAdmin("Only admin can launch raffle")
        nonReentrant
    {
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
     * Ensure that benefit are only sent to the address defined when deploying contract
     */
    function withdrawBenefit(
        address payable /*_unused*/
    )
        public
        override
        onlyAdmin("Only admin can withdraw benefits")
        nonReentrant
    {
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

    modifier onlyAdmin(string memory _refusedMessage) {
        require(msg.sender == admin, _refusedMessage);
        _;
    }

    /**
     * Reset the raffle to its initial state
     */
    function _resetContract() internal override {
        require(
            isRaffleFinished == true,
            "You can only reset this contract once the raffle is finished."
        );
        resetNTFTickets();
        currentTickets = 0;
        isRaffleFinished = false;
        emit RaffleReset("Raffle has been reset");
    }

    /**
     * For dev only
     * Reset the contract to its initial state
     */
    function resetContract()
        external
        override
        onlyAdmin("Only admin can reset the contract")
        nonReentrant
    {
        withdrawContract();
        isRaffleFinished = false;
        resetNTFTickets();
        currentTickets = 0;
        isVrfRequested = false;
        vrfRequestId = 0;
    }

    /**
     * Withdraw the raffle contract to the administrator
     * Security function for testing purposes
     */
    function withdrawContract() internal {
        uint256 benefitToSend = address(this).balance;
        (bool success, ) = admin.call{value: benefitToSend}("");
        require(success, "Contract withdraw failed");
    }

    /**
     * Calculate the tax amount to send to the government
     * benefit * (%)tax level
     */
    function getTaxAmount() private view returns (uint256 taxAmountToSend) {
        return (((maxTickets * ticketPrice) - prize) * taxRate) / 100;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

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

    // Actually useless
    function safeMint(address _sender, uint256 _tokenID) internal override {
        super.safeMint(_sender, _tokenID);
    }

    /**
     * This function allows oracle VRF to set the random number
     * Used as an interface
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
     * Get a winner and send the prize
     * @param _randomNumber random number to get the winner
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
     * Authorize only from the vrfContractAddress
     */
    modifier onlyRaffleVRF(string memory _refusedMessage) {
        require(msg.sender == vrfContractAddress, _refusedMessage);
        _;
    }
}

/**
 * Interface to the random number generator
 */
interface IraffleVRF {
    function requestRandomWords(
        bool enableNativePayment
    ) external returns (uint256);

    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords);
}
