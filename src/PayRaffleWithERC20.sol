// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.24;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
//import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";



contract PayRaffleWithERC20 is ConfirmedOwner{
    
    //using SafeERC20 for IERC20;

    //// Address LINK - hardcoded for Sepolia
    //address public linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    event LinkReceived(string message, uint256 amount, address _from);

    // Token struct for
    struct contractInfo {
        string tokenName;
        address tokenAddress;
    }

    //ERC677
    mapping(string => address) public addressERC677;
    // Map address to function selector
    mapping(address => bytes4) public functionERC677;

    //ERC20
    mapping(string => address) public addressERC20;


    //IERC677 public constant link = IERC677(0x779877A7B0D9E8603169DdbD7836e478b4624789);

    constructor(contractInfo[] memory _contractERC677, contractInfo[] memory _contractERC20) 
        ConfirmedOwner(msg.sender)
    {
        uint256 length = _contractERC677.length;
        for (uint256 i = 0; i < length; i++)
        {
            addressERC677[_contractERC677[i].tokenName] = _contractERC677[i].tokenAddress;
        }

        setFunctionERC677(addressERC677['link'], "tokenLinkReceived(address,uint256)");

        length = _contractERC20.length;
        for (uint256 i = 0; i < length; i++)
        {
            addressERC20[_contractERC20[i].tokenName] = _contractERC20[i].tokenAddress;
        }
    }

    /**
     * 
     * @param _contractTokenAddress address of the token contract ERC677
     * @param _functionSignature signature of the function to associate with the address
     */
    function setFunctionERC677(address _contractTokenAddress, string memory _functionSignature) internal 
    {
        // Get function selector
        bytes4 selector = bytes4(keccak256(bytes(_functionSignature)));
        // Add selector to mapping with the address of the contract
        functionERC677[_contractTokenAddress] = selector;
    }

    // Fonction pour appeler dynamiquement une fonction
    function callFunctionForAddress(address _addrTokenContract, address _tokenFrom, uint256 _amount) internal  {
        bytes4 selector = functionERC677[_addrTokenContract];
        require(selector != 0, "No function set for this address");

        (bool success, ) = address(this).call(abi.encodeWithSelector(
            selector,
            _tokenFrom,
            _amount));

        require(success, "Function tokenLinkReceived failed");
    }



    // Fonction pour recevoir des tokens et exécuter une action
    function buyWithLinkToken(uint256 _amount) external  { // payable pas sur?
        IERC20 linkToken = IERC20(addressERC20['link']);
        require(_amount > 0, "Amount should be greater than 0");
        
        // need as safeTransferFrom is not available in solc ^0.7.0
        require(linkToken.allowance(msg.sender, address(this)) >= _amount, "Not enough token allowed");
        require(linkToken.balanceOf(msg.sender) >= _amount, "Not enough token in wallet");

        // Using lib SafeERC20 for, implicit pass the caller object as 1st argument
        linkToken.transferFrom(msg.sender, address(this),  _amount);
        
        tokenLinkReceived(msg.sender, _amount);
    }

    /**
     * Manage Link token to participate in the raffle
     * @param _amount amout of Link received
     * @param _from address of the sender
     * signature : "tokenLinkReceived(address,uint256,bytes)"
     */
    function tokenLinkReceived(address _from, uint256 _amount) internal returns (bool)
    {
        emit LinkReceived("Some Link token have been received", _amount, _from);
        //uint256 linkEthPrice = getLinkEthPriceWeiWtihTick(600);
        //swapLinkforETH(_amount, linkEthPrice);

        return true;
    }
  

    // Fonction à exécuter lors de la réception des tokens
    // Called by the token contract automatically
    function onTokenTransfer(address from, uint256 amount, bytes memory /* unused */) external {
        // Logique à exécuter lors de la réception des tokens
        // Par exemple, enregistrer le transfert ou effectuer une action spécifique
        callFunctionForAddress(msg.sender, from, amount);
    }


       /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner 
    {
        LinkTokenInterface link = LinkTokenInterface(addressERC677['link']);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /**
     * Withdraw eth to the owner of the contract
     */
    function withdrawEth() public onlyOwner 
    {
        uint256 value = address(this).balance;
        address owner = payable(owner());
        (bool success, ) = owner.call{value: value}("");
        require(success, "Eth withdraw");
    }

}

