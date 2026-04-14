// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

import {AcrossBridgeAdapter} from "../../contracts/AcrossBridgeAdapter.sol";

import {Script} from "forge-std/Script.sol";

struct Roles {
    address deployer;
    address proxyAdminOwner;
    address defaultAdmin;
    address bridgeAdapterManager;
    address cacheManager;
}

contract DeployAcrossBridgeAdapter is Script {
    Roles public roles;

    address public SPOOKY_POOL;
    uint256 public SLIPPAGE_CAP_PCT;
    uint256 public MAX_CACHE_SIZE;
    uint256 public FEE_CAP_PCT;

    function _proxifyWithSalt(address implementation, bytes memory data) internal returns (address) {
        bytes32 saltHash = keccak256(abi.encodePacked(implementation, block.timestamp, block.chainid));
        return address(new TransparentUpgradeableProxy{salt: saltHash}(implementation, roles.proxyAdminOwner, data));
    }

    function _readRolesFromEnv() internal {
        roles.deployer = vm.envAddress("DEPLOYER");
        roles.proxyAdminOwner = vm.envAddress("PROXY_ADMIN_OWNER");
        roles.defaultAdmin = vm.envAddress("DEFAULT_ADMIN_ROLE");
        roles.bridgeAdapterManager = vm.envAddress("BRIDGE_ADAPTER_MANAGER_ROLE");
        roles.cacheManager = vm.envAddress("CACHE_MANAGER_ROLE");
    }

    function run() public {
        _readRolesFromEnv();

        SLIPPAGE_CAP_PCT = vm.envUint("SLIPPAGE_CAP_PCT");
        MAX_CACHE_SIZE = vm.envUint("MAX_CACHE_SIZE");
        SPOOKY_POOL = vm.envAddress("SPOOKY_POOL");
        FEE_CAP_PCT = vm.envUint("FEE_CAP_PCT");

        vm.startBroadcast();
        address implementation = address(new AcrossBridgeAdapter());
        _proxifyWithSalt(
            implementation,
            abi.encodeWithSelector(
                AcrossBridgeAdapter.initialize.selector,
                roles.defaultAdmin,
                roles.bridgeAdapterManager,
                roles.cacheManager,
                SLIPPAGE_CAP_PCT,
                MAX_CACHE_SIZE,
                SPOOKY_POOL,
                FEE_CAP_PCT
            )
        );
        vm.stopBroadcast();
    }
}
