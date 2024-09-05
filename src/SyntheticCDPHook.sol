// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.26;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IOracle} from "src/interface/IOracle.sol";
import {SyntheticToken} from "src/SyntheticToken.sol";

contract SyntheticCDPHook is BaseHook {
    IOracle public primaryOracle;
    IOracle public secondaryOracle;
    address public treasury;

    // PoolKey => string
    mapping(bytes32 => string) public poolToDataKey;
    mapping(bytes32 => SyntheticToken) public poolToSyntheticToken;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        // TODO
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

  function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, bytes calldata hookData)
        external
        override
        returns (bytes4)
    {
        (string memory dataKey, string memory tokenName, string memory tokenSymbol) = abi.decode(hookData, (string, string, string));
        bytes32 encodedKey = keccak256(abi.encode(key));
        poolToDataKey[encodedKey] = dataKey;
        SyntheticToken newToken = new SyntheticToken(tokenName, tokenSymbol);
        poolToSyntheticToken[encodedKey] = newToken;
        return BaseHook.beforeInitialize.selector;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // function beforeAddLiquidity(
    //     address,
    //     PoolKey calldata key,
    //     IPoolManager.ModifyLiquidityParams calldata,
    //     bytes calldata
    // ) external override returns (bytes4) {
    //     return BaseHook.beforeAddLiquidity.selector;
    // }

    // function beforeRemoveLiquidity(
    //     address,
    //     PoolKey calldata key,
    //     IPoolManager.ModifyLiquidityParams calldata,
    //     bytes calldata
    // ) external override returns (bytes4) {
    //     return BaseHook.beforeRemoveLiquidity.selector;
    // }
}
