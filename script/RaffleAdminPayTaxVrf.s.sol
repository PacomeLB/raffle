// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RaffleAdminPayTaxVrf} from "../src/core/RaffleAdminPayTaxVrf.sol";

contract RaffleAdminPayTaxVrfScript is Script {
    RaffleAdminPayTaxVrf public raffleAdminPayTaxVrf;

    uint8 constant _maxTickets = 4;
    uint256 constant _priz = 1000000000000000;
    uint256 constant _ticketPrice = 500000000000000;
    address constant _admin = 0x7a79A7c9338032B116051e9CC4459600F95fc35E;
    address constant _benefit = 0x7a79A7c9338032B116051e9CC4459600F95fc35E;
    uint8 constant _taxRate = 20; // Classic 20% tax rate
    address constant _tax = 0x7a79A7c9338032B116051e9CC4459600F95fc35E;
    string constant _name = "Raffle with Vrf ChainLink";
    string[] _tokenURIHashs = [
        "QmTYMZkJB3hmmamegfZfxAeqZCUBCyB4B5hpEdoHLFtynR",
        "QmQBNLAJQjT5aSSRTo1PnDzKu7kgvxFhTKKmwaAMFJmNmA",
        "QmTYMZkJB3hmmamegfZfxAeqZCUBCyB4B5hpEdoHLFtynR",
        "QmQBNLAJQjT5aSSRTo1PnDzKu7kgvxFhTKKmwaAMFJmNmA"
    ];
    address constant _addressVrf = 0xc67f000FEaaBdFb06D049795b4E02174528Eac9C;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        raffleAdminPayTaxVrf = new RaffleAdminPayTaxVrf(
            _maxTickets,
            _priz,
            _ticketPrice,
            _admin,
            _benefit,
            _taxRate,
            _tax,
            _name,
            _tokenURIHashs,
            _addressVrf
        );

        vm.stopBroadcast();
    }
}
