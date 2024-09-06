// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "v4-core/src/types/PoolKey.sol";
import "v4-core/src/interfaces/IPoolManager.sol";
import "v4-core/src/interfaces/IProtocolFeeController.sol";
import "forge-std/console.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SyntheticCDPHook} from "../src/SyntheticCDPHook.sol";
import {SyntheticToken} from "../src/SyntheticToken.sol";
import {TestToken} from "../src/test/TestToken.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {PoolTestBase} from "v4-core/src/test/PoolTestBase.sol";

contract SyntheticCDPHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    SyntheticCDPHook public hook;
    address public deployer = address(11);
    TestToken collateralToken;
    SyntheticToken syntheticToken;

    struct CallbackData {
        address sender;
        PoolKey key;
        IPoolManager.ModifyLiquidityParams params;
        bytes hookData;
        bool settleUsingBurn;
        bool takeClaims;
    }

    function setUp() public {
        vm.label(deployer, "Deployer");
        vm.startPrank(deployer);

        deployFreshManagerAndRouters();

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG
            )
        );

        deployCodeTo(
            "SyntheticCDPHook.sol:SyntheticCDPHook",
            abi.encode(manager),
            hookAddress
        );

        hook = SyntheticCDPHook(hookAddress);

        collateralToken = new TestToken("USDC", "USDC");
        collateralToken.mint(address(this), 30000);
        syntheticToken = new SyntheticToken("Memecoin Index", "MEME", address(hook));

        vm.stopPrank();
    }

    function testBeforeInitialize() public {
        PoolKey memory key = defaultPool();

        string memory dataKey = "MemecoinIndex-1725612649";
        string memory tokenName = "Memecoin Index";
        string memory tokenSymbol = "MEME";
        uint160 sqrtPriceX96 = 1 << 96; // 1.0 as Q64.96
        bytes memory hookData = abi.encode(dataKey, tokenName, tokenSymbol);

        manager.initialize(key, sqrtPriceX96, hookData);

        // key.currency0 = Currency.wrap(
        //     0x732bBC31486A07346ec15afc74402FEE028527c4
        // );
        PoolId poolId = key.toId();
        assertEq(
            hook.poolToDataKey(poolId),
            dataKey,
            "Data key not set correctly"
        );

        address syntheticTokenAddress = address(
            hook.poolToSyntheticToken(poolId)
        );
        assertTrue(
            syntheticTokenAddress != address(0),
            "Synthetic token not created"
        );

        SyntheticToken syntheticToken = SyntheticToken(syntheticTokenAddress);
        assertEq(syntheticToken.name(), tokenName, "Incorrect token name");
        assertEq(
            syntheticToken.symbol(),
            tokenSymbol,
            "Incorrect token symbol"
        );
    }

    function testBeforeAddLiquidity() public {
        PoolKey memory key = defaultPool();

        string memory dataKey = "MemecoinIndex-1725612649";
        string memory tokenName = "Memecoin Index";
        string memory tokenSymbol = "MEME";
        uint160 sqrtPriceX96 = 1 << 96; // 1.0 as Q64.96
        manager.initialize(
            key,
            sqrtPriceX96,
            abi.encode(dataKey, tokenName, tokenSymbol)
        );

        // prepare test token
        collateralToken.approve(address(hook), 10000);

        bytes memory hookData = abi.encode(300);

        BalanceDelta delta = abi.decode(
            manager.unlock(
                abi.encode(
                    CallbackData(
                        msg.sender,
                        key,
                        LIQUIDITY_PARAMS,
                        hookData,
                        false,
                        false
                    )
                )
            ),
            (BalanceDelta)
        );
    }

    function unlockCallback(
        bytes calldata rawData
    ) external returns (bytes memory) {
        require(msg.sender == address(manager));

        CallbackData memory data = abi.decode(rawData, (CallbackData));
        (BalanceDelta delta, ) = manager.modifyLiquidity(
            data.key,
            data.params,
            data.hookData
        );
        return abi.encode(delta);
    }

    function defaultPool() internal returns (PoolKey memory key) {
        address currency0 = address(syntheticToken); // Synthetic Token
        address currency1 = address(collateralToken); // Collateral Token
        uint24 fee = 3000;
        int24 tickSpacing = 60;

        return
            PoolKey({
                currency0: Currency.wrap(currency0),
                currency1: Currency.wrap(currency1),
                fee: fee,
                tickSpacing: tickSpacing,
                hooks: IHooks(address(hook))
            });
    }
}
