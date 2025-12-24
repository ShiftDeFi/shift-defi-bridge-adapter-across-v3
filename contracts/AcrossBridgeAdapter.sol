// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BridgeAdapter} from "@shift-defi/core/BridgeAdapter.sol";
import {Errors} from "@shift-defi/core/libraries/helpers/Errors.sol";
import {IAcrossV3Receiver} from "./dependencies/interfaces/IAcrossV3Receiver.sol";
import {ISpookyPool} from "./dependencies/interfaces/ISpookyPool.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AcrossBridgeAdapter
 * @notice Bridge adapter for Across V3 protocol
 * @dev Implements bridge functionality for Across V3 by interacting with the SpookyPool contract.
 * Handles token deposits and receives bridged tokens through the Across V3 message system.
 */
contract AcrossBridgeAdapter is BridgeAdapter, IAcrossV3Receiver {
    using Math for uint256;

    uint256 public constant MAX_FEE_CAP_BPS = 10_000; // 100%

    address public spookyPool;
    uint256 public feeCapPct;

    /**
     * @notice Initializes the AcrossBridgeAdapter contract
     * @dev Sets up the bridge adapter with default admin, governance, SpookyPool address, and fee cap.
     * Can only be called once during contract deployment.
     * @param _defaultAdmin The address that will have the default admin role
     * @param _governance The address that will have the governance role
     * @param _spookyPool The address of the Across V3 SpookyPool contract
     * @param _feeCapPct The maximum fee percentage allowed in basis points (e.g., 100 = 1%)
     */
    function initialize(
        address _defaultAdmin,
        address _governance,
        address _spookyPool,
        uint256 _feeCapPct
    ) external initializer {
        __BridgeAdapter_init(_defaultAdmin, _governance);
        _setAcrossSpookyPool(_spookyPool);
        _setFeeCapPct(_feeCapPct);
    }

    /// @inheritdoc IAcrossV3Receiver
    function setSpookyPool(address _spookyPoolAddress) external onlyRole(GOVERNANCE_ROLE) {
        _setAcrossSpookyPool(_spookyPoolAddress);
    }

    /// @inheritdoc IAcrossV3Receiver
    function setFeeCapPct(uint256 _feeCapPct) external onlyRole(GOVERNANCE_ROLE) {
        _setFeeCapPct(_feeCapPct);
    }

    /// @inheritdoc IAcrossV3Receiver
    function handleV3AcrossMessage(address token, uint256 amount, address, bytes memory message) external {
        require(msg.sender == spookyPool, OnlySpookyPool(msg.sender, spookyPool));
        _finalizeBridge(abi.decode(message, (address)), token, amount);
    }

    function _bridge(
        BridgeInstruction calldata instruction,
        address receiver,
        address peer
    ) internal override returns (uint256) {
        AcrossParams memory acrossPayload = abi.decode(instruction.payload, (AcrossParams));

        _validatePayload(instruction, acrossPayload);

        IERC20(instruction.token).approve(spookyPool, instruction.amount);
        uint256 minAmount = instruction.amount - acrossPayload.fee;
        bytes memory message = abi.encode(receiver);
        ISpookyPool(spookyPool).depositV3Now(
            address(this),
            peer,
            instruction.token,
            bridgePaths[instruction.token][instruction.chainTo],
            instruction.amount,
            minAmount,
            instruction.chainTo,
            acrossPayload.exclusiveRelayer,
            ISpookyPool(spookyPool).fillDeadlineBuffer(),
            acrossPayload.exclusiveDeadline,
            message
        );
        return minAmount;
    }

    function _validatePayload(BridgeInstruction calldata instruction, AcrossParams memory acrossParams) internal view {
        require(
            acrossParams.fillDeadline >= block.timestamp,
            DeadlineExceeded(uint32(block.timestamp), acrossParams.fillDeadline)
        );
        require(acrossParams.fee * MAX_FEE_CAP_BPS < feeCapPct * instruction.amount, FeeTooHigh(acrossParams.fee));
    }

    function _setAcrossSpookyPool(address newSpookyPool) private {
        require(newSpookyPool != address(0), Errors.ZeroAddress());
        address oldPool = address(spookyPool);
        require(oldPool != newSpookyPool, Errors.AlreadySet());
        spookyPool = newSpookyPool;
        emit SpookyPoolUpdated(oldPool, newSpookyPool);
    }

    function _setFeeCapPct(uint256 newFeeCapPct) private {
        require(newFeeCapPct <= MAX_FEE_CAP_BPS, InvalidFeeCapPct(newFeeCapPct));
        uint256 oldFeeCapPct = feeCapPct;
        require(oldFeeCapPct != newFeeCapPct, Errors.AlreadySet());
        feeCapPct = newFeeCapPct;
        emit FeeCapPctUpdated(oldFeeCapPct, newFeeCapPct);
    }
}
