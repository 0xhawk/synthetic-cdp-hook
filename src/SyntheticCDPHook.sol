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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

contract SyntheticCDPHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    IOracle public primaryOracle;
    IOracle public secondaryOracle;
    address public treasury;

    mapping(PoolId => string) public poolToDataKey;
    mapping(PoolId => SyntheticToken) public poolToSyntheticToken;
    mapping(address => mapping(PoolId => uint256)) public collateralDeposits;

    // Event
    event SyntheticTokenCreated(
        PoolId indexed poolId,
        string dataKey,
        string tokenName,
        string tokenSymbol
    );
    event CollateralDeposited(
        address indexed user,
        PoolId indexed poolId,
        uint256 amount
    );

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        // TODO
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: true,
                afterInitialize: false,
                beforeAddLiquidity: true,
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

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external override returns (bytes4) {
        (
            string memory dataKey,
            string memory tokenName,
            string memory tokenSymbol
        ) = abi.decode(hookData, (string, string, string));
        PoolId poolId = key.toId();
        poolToDataKey[poolId] = dataKey;
        SyntheticToken newToken = new SyntheticToken(tokenName, tokenSymbol);
        poolToSyntheticToken[poolId] = newToken;
        emit SyntheticTokenCreated(poolId, dataKey, tokenName, tokenSymbol);
        return BaseHook.beforeInitialize.selector;
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external override returns (bytes4) {
        PoolId poolId = key.toId();
        if (params.liquidityDelta > 0) {
            // Depositing collateral
            uint256 collateralAmount = abi.decode(hookData, (uint256));
            collateralDeposits[sender][poolId] += collateralAmount;
            require(
                IERC20(Currency.unwrap(key.currency0)).transferFrom(
                    sender,
                    address(this),
                    collateralAmount
                ),
                "Collateral transfer failed"
            );
            emit CollateralDeposited(sender, poolId, collateralAmount);
        } else {
            // Withdrawing collateral (implement later)
        }
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        bytes calldata
    ) external override returns (bytes4, BeforeSwapDelta, uint24) {
        return (
            BaseHook.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            0
        );
    }

    // function beforeRemoveLiquidity(
    //     address,
    //     PoolKey calldata key,
    //     IPoolManager.ModifyLiquidityParams calldata,
    //     bytes calldata
    // ) external override returns (bytes4) {
    //     return BaseHook.beforeRemoveLiquidity.selector;
    // }
}
