// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title ISpookyPool
 * @notice Interface for Across V3 SpookyPool bridge contract
 * @dev Defines the interface for interacting with the Across V3 bridge pool for depositing tokens.
 * The SpookyPool is the core contract of the Across V3 protocol that handles cross-chain token transfers.
 * It manages liquidity pools, coordinates relayers, and executes fills on destination chains. When
 * depositV3Now is called, the pool creates a deposit record that relayers can fill by providing
 * liquidity on the destination chain. The pool handles token conversions, fee calculations, and
 * message passing between chains.
 */
interface ISpookyPool {
    /**
     * @notice Deposits tokens into the bridge for immediate bridging
     * @dev Initiates a bridge transfer by depositing input tokens. The bridge will convert them
     * to output tokens on the destination chain. The depositor must approve this contract to spend
     * the input tokens before calling this function. This function creates a deposit record that
     * relayers can fill. The deposit includes parameters for exclusive relayer assignment, deadlines,
     * and minimum output amounts. The message parameter is passed to the receiver contract on the
     * destination chain when the deposit is filled. If exclusiveRelayer is set to address(0), any
     * relayer can fill the deposit. Otherwise, only the specified relayer can fill until the
     * exclusivityDeadline expires.
     * @param depositor The address that is depositing the tokens
     * @param recipient The address that will receive the tokens on the destination chain
     * @param inputToken The address of the token being deposited
     * @param outputToken The address of the token to be received on the destination chain
     * @param inputAmount The amount of input tokens to deposit
     * @param outputAmount The minimum amount of output tokens expected on the destination chain
     * @param destinationChainId The chain ID of the destination chain
     * @param exclusiveRelayer The address of the relayer that has exclusive rights to fill this deposit
     * @param fillDeadlineOffset Additional time buffer added to the fill deadline
     * @param exclusivityDeadline Timestamp after which any relayer can fill the deposit
     * @param message Additional data to be passed to the receiver contract on the destination chain
     */
    function depositV3Now(
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 fillDeadlineOffset,
        uint32 exclusivityDeadline,
        bytes calldata message
    ) external payable;

    /**
     * @notice Returns the current timestamp according to the pool
     * @dev Used to get the current time for deadline calculations. This may differ from block.timestamp
     * if the pool uses a different time source or has time manipulation protection mechanisms.
     * @return The current timestamp
     */
    function getCurrentTime() external view returns (uint256);

    /**
     * @notice Returns the fill deadline buffer
     * @dev The buffer time added to the current time to calculate the fill deadline. This buffer
     * provides additional time for relayers to fill deposits, accounting for network delays and
     * processing time. The fill deadline is calculated as getCurrentTime() + fillDeadlineBuffer().
     * @return The fill deadline buffer in seconds
     */
    function fillDeadlineBuffer() external view returns (uint32);
}
