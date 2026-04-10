// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BridgeAdapter} from "@shift-defi/core/BridgeAdapter.sol";
import {Errors} from "@shift-defi/core/libraries/Errors.sol";

import {IAcrossV3Receiver} from "./dependencies/interfaces/IAcrossV3Receiver.sol";
import {ISpookyPool} from "./dependencies/interfaces/ISpookyPool.sol";

/**
 * @title AcrossBridgeAdapter
 * @notice Bridge adapter for Across V3 protocol
 * @dev Implements bridge functionality for Across V3 by interacting with the SpookyPool contract.
 * Handles token deposits and receives bridged tokens through the Across V3 message system.
 */
contract AcrossBridgeAdapter is BridgeAdapter, IAcrossV3Receiver {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public constant MAX_FEE_CAP_BPS = 1e18; // 100%

    address public spookyPool;
    uint256 public feeCapPct;

    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the AcrossBridgeAdapter contract.
     * @dev Sets up the bridge adapter contract with the specified admin roles, configuration parameters, SpookyPool address, and fee cap.
     * This function can only be called once during contract deployment (initializer).
     * @param _defaultAdmin The address assigned the default admin role responsible for overall contract management.
     * @param _bridgeAdapterManager The address assigned the bridge adapter manager role, authorized to update bridge adapter settings.
     * @param _cacheManager The address assigned the cache manager role, authorized to manage cache-related logic.
     * @param _slippageCapPct The maximum allowed slippage.
     * @param _maxCacheSize The maximum amount of bridge instruction stored in cache.
     * @param _spookyPool The address of the Across V3 SpookyPool contract, which facilitates cross-chain transfers.
     * @param _feeCapPct The maximum fee, allowed for bridging operations.
     */
    function initialize(
        address _defaultAdmin,
        address _bridgeAdapterManager,
        address _cacheManager,
        uint256 _slippageCapPct,
        uint256 _maxCacheSize,
        address _spookyPool,
        uint256 _feeCapPct
    ) external initializer {
        __BridgeAdapter_init(_defaultAdmin, _bridgeAdapterManager, _cacheManager, _slippageCapPct, _maxCacheSize);
        _setAcrossSpookyPool(_spookyPool);
        _setFeeCapPct(_feeCapPct);
    }

    /// @inheritdoc IAcrossV3Receiver
    function setSpookyPool(address _spookyPoolAddress) external onlyRole(BRIDGE_ADAPTER_MANAGER_ROLE) {
        _setAcrossSpookyPool(_spookyPoolAddress);
    }

    /// @inheritdoc IAcrossV3Receiver
    function setFeeCapPct(uint256 _feeCapPct) external onlyRole(BRIDGE_ADAPTER_MANAGER_ROLE) {
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

        require(acrossPayload.fee * MAX_FEE_CAP_BPS <= feeCapPct * instruction.amount, FeeTooHigh(acrossPayload.fee));

        IERC20(instruction.token).forceApprove(spookyPool, instruction.amount);
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
