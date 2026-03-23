// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

/**
 * @title IAcrossV3Receiver
 * @notice Interface for receiving messages from Across V3 bridge
 * @dev Defines the interface for contracts that can receive bridged tokens from Across V3 SpookyPool.
 * This interface is implemented by bridge adapters that need to handle incoming cross-chain transfers
 * from the Across protocol. The SpookyPool contract calls handleV3AcrossMessage when tokens are
 * successfully bridged to the destination chain. Implementations must validate that the caller is
 * the authorized SpookyPool and properly decode the message to extract recipient information.
 */
interface IAcrossV3Receiver {
    struct AcrossParams {
        address exclusiveRelayer;
        uint32 exclusiveDeadline;
        uint256 fee;
    }

    event SpookyPoolUpdated(address old, address new_);
    event FeeCapPctUpdated(uint256 old, uint256 new_);

    error OnlySpookyPool(address addr, address spookyPool);
    error FeeTooHigh(uint256 fee);
    error InvalidFeeCapPct(uint256 feeCapPct);

    /**
     * @notice Returns the address of the SpookyPool contract
     * @dev The SpookyPool is the Across V3 bridge pool that handles deposits and fills. This contract
     * is the only authorized caller for handleV3AcrossMessage. The pool address can be updated by
     * governance through setSpookyPool function.
     * @return The address of the SpookyPool contract
     */
    function spookyPool() external view returns (address);

    /**
     * @notice Handles incoming messages from Across V3 bridge
     * @dev Called by the SpookyPool when tokens are bridged to this contract. This function is invoked
     * on the destination chain after a relayer fills the deposit. The implementation must:
     * 1. Validate that msg.sender is the authorized SpookyPool
     * 2. Decode the message to extract the receiver address
     * 3. Transfer the received tokens to the intended recipient
     * The message parameter contains ABI-encoded data that includes the receiver address and any
     * additional context needed to complete the bridge transfer.
     * @param tokenSent The address of the token that was bridged
     * @param amount The amount of tokens received
     * @param relayer The address of the relayer that filled the deposit (unused in current implementation)
     * @param message Encoded message containing the receiver address and bridge context
     */
    function handleV3AcrossMessage(address tokenSent, uint256 amount, address relayer, bytes memory message) external;

    /**
     * @notice Sets the address of the SpookyPool contract
     * @dev Can only be called by addresses with the governance role. Updates the pool address used
     * for all bridge operations. This function should be used when upgrading to a new SpookyPool
     * contract or switching to a different Across V3 deployment. The new pool address must be validated
     * to ensure it's a legitimate SpookyPool contract.
     * @param _spookyPoolAddress The new address of the SpookyPool contract
     */
    function setSpookyPool(address _spookyPoolAddress) external;

    /**
     * @notice Sets the fee cap percentage
     * @dev Can only be called by addresses with the governance role. The fee cap is used to validate
     * that bridge fees do not exceed the configured maximum percentage of the bridged amount. This
     * protects users from excessive fees. The fee validation occurs in _validatePayload before
     * initiating a bridge transfer. The fee cap is specified in basis points where 10,000 = 100%.
     * For example, a value of 100 means fees cannot exceed 1% of the bridged amount.
     * @param _feeCapPct The new fee cap percentage in basis points (e.g., 100 = 1%)
     */
    function setFeeCapPct(uint256 _feeCapPct) external;
}
