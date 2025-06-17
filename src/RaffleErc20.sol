pragma solidity 0.8.24;

import "./RaffleAdminPayTaxVrf.sol";
import {IswapContract} from "./IswapContract.sol";

/**
 * @title RaffleErc20
 * @author LEBEAU Pacôme
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
}
