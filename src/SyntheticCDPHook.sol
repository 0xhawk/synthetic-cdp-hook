// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
// import {Hooks} from "v4-core/src/libraries/Hooks.sol";
// import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
// import {PoolKey} from "v4-core/src/types/PoolKey.sol";
// import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
// import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

contract SyntheticCDPHook is BaseHook {

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        // TODO
    }
}
