// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title VrfRaffle
 * @author Pakish https://github.com/Pakish
 * @notice VrfRaffle contract that generate random number with oracle ChainLink VRF
 * @dev Only authorized address can use it
 */
contract VrfRaffle is VRFV2PlusWrapperConsumerBase, ConfirmedOwner {
    event RequestSent(uint256 requestId, uint32 numWords);
    event RequestFulfilled(
        uint256 requestId,
        uint256[] randomWords,
        uint256 payment
    );

    event AddingAuthorizedAddress(string message, address _authorized);

    struct RequestStatus {
        uint256 paid; // amount paid in link
        bool fulfilled; // whether the request has been successfully fulfilled
        uint256[] randomWords;
    }
    mapping(uint256 => RequestStatus)
        public s_requests; /* requestId --> requestStatus */

    // past requests Id.
    uint256[] public requestIds;
    uint256 public lastRequestId;

    mapping(uint256 => address)
        public s_consumers; /* requestId --> address consumers */

    mapping(address => bool)
        public authorizedConsumers; /* authorized consumers contract address to use this VRF */

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 public callbackGasLimit = 300000;

    // The default is 3, but you can set this higher.
    uint16 public requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFV2Wrapper.getConfig().maxNumWords.
    uint32 public numWords = 1;

    // Address LINK - hardcoded for Sepolia
    address public linkAddress = 0x779877A7B0D9E8603169DdbD7836e478b4624789;

    // address WRAPPER - hardcoded for Sepolia
    address public wrapperAddress = 0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1;

    constructor()
        ConfirmedOwner(msg.sender)
        VRFV2PlusWrapperConsumerBase(wrapperAddress)
    {
        setAuthorizedAddress(msg.sender);
    }

    function requestRandomWords(
        bool enableNativePayment
    ) external onlyAuthorized returns (uint256) {
        bytes memory extraArgs = VRFV2PlusClient._argsToBytes(
            VRFV2PlusClient.ExtraArgsV1({nativePayment: enableNativePayment})
        );
        uint256 requestId;
        uint256 reqPrice;
        if (enableNativePayment) {
            (requestId, reqPrice) = requestRandomnessPayInNative(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        } else {
            (requestId, reqPrice) = requestRandomness(
                callbackGasLimit,
                requestConfirmations,
                numWords,
                extraArgs
            );
        }
        s_requests[requestId] = RequestStatus({
            paid: reqPrice,
            randomWords: new uint256[](0),
            fulfilled: false
        });
        requestIds.push(requestId);
        lastRequestId = requestId;
        s_consumers[requestId] = msg.sender;
        emit RequestSent(requestId, numWords);
        return requestId;
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        require(s_requests[_requestId].paid > 0, "request not found");
        s_requests[_requestId].fulfilled = true;
        s_requests[_requestId].randomWords = _randomWords;
        emit RequestFulfilled(
            _requestId,
            _randomWords,
            s_requests[_requestId].paid
        );

        // Owner is a wallet address -> can't call interface method
        if (s_consumers[_requestId] != owner()) {
            IrandomNumberConsumer(s_consumers[_requestId]).setRandomNumber(
                _requestId,
                _randomWords
            );
        }
    }

    function getRequestStatus(
        uint256 _requestId
    )
        external
        view
        returns (uint256 paid, bool fulfilled, uint256[] memory randomWords)
    {
        require(s_requests[_requestId].paid > 0, "request not found");
        RequestStatus memory request = s_requests[_requestId];
        return (request.paid, request.fulfilled, request.randomWords);
    }

    /**
     * Allow withdraw of Link tokens from the contract
     */
    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(linkAddress);
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }

    /// @notice withdrawNative withdraws the amount specified in amount to the owner
    /// @param amount the amount to withdraw, in wei
    function withdrawNative(uint256 amount) external onlyOwner {
        (bool success, ) = payable(owner()).call{value: amount}("");
        // solhint-disable-next-line gas-custom-errors
        require(success, "withdrawNative failed");
    }

    event Received(address, uint256);

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * Set the callback gas limit
     * @param _gasLimit to set
     */
    function setcallbackGasLimit(uint32 _gasLimit) external onlyOwner {
        callbackGasLimit = _gasLimit;
    }

    /**
     * Add authorized address
     * @param _authorizedAddress contract address authorized to call the random number generator
     */
    function setAuthorizedAddress(address _authorizedAddress) public onlyOwner {
        authorizedConsumers[_authorizedAddress] = true;
        emit AddingAuthorizedAddress(
            "New authorized address",
            _authorizedAddress
        );
    }

    /**
     * Check that the address caller is in the authorized address list
     */
    modifier onlyAuthorized() {
        require(
            authorizedConsumers[msg.sender],
            "Only authorized consumers can ask for a random number."
        );
        _;
    }
}

interface IrandomNumberConsumer {
    function setRandomNumber(
        uint256 _requestId,
        uint256[] calldata _randomNumber
    ) external;
}
