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

contract SyntheticCDPHookTest is Test, Deployers {
    SyntheticCDPHook public hook;
    address public deployer = address(11);

    function setUp() public {
        vm.label(deployer, "Deployer");
        vm.startPrank(deployer);

        deployFreshManagerAndRouters();
        (currency0, currency1) = deployMintAndApprove2Currencies();
        vm.label(Currency.unwrap(key.currency0), "ERC20-C0");
        vm.label(Currency.unwrap(key.currency1), "ERC20-C1");

        address hookAddress = address(
            uint160(
                Hooks.BEFORE_INITIALIZE_FLAG |
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.BEFORE_SWAP_FLAG
            )
        );

        IERC20[] memory _pooledTokens = new IERC20[](2);

        _pooledTokens[0] = IERC20(Currency.unwrap(currency0));
        _pooledTokens[1] = IERC20(Currency.unwrap(currency1));

        uint8[] memory _decimals = new uint8[](2);
        _decimals[0] = uint8(18);
        _decimals[1] = uint8(18);

        deployCodeTo(
            "SyntheticCDPHook.sol:SyntheticCDPHook",
            abi.encode(manager),
            hookAddress
        );

        hook = SyntheticCDPHook(hookAddress);

        vm.stopPrank();
    }

    function testBeforeInitialize() public {
        address currency0 = address(0x1);
        address currency1 = address(0x2);
        uint24 fee = 3000;
        int24 tickSpacing = 60;

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(hook))
        });

        string memory dataKey = "Memecoin Index";
        string memory tokenName = "Memecoin Index";
        string memory tokenSymbol = "MEME";
        uint160 sqrtPriceX96 = 1 << 96; // 1.0 as Q64.96
        bytes memory hookData = abi.encode(dataKey, tokenName, tokenSymbol);

        bytes4 returnValue = hook.beforeInitialize(
            address(this),
            key,
            sqrtPriceX96,
            hookData
        );
        assertEq(
            returnValue,
            SyntheticCDPHook.beforeInitialize.selector,
            "Incorrect return value"
        );

        bytes32 encodedKey = keccak256(abi.encode(key));
        assertEq(
            hook.poolToDataKey(encodedKey),
            dataKey,
            "Data key not set correctly"
        );

        address syntheticTokenAddress = address(
            hook.poolToSyntheticToken(encodedKey)
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

    // function testBeforeInitializeWithInvalidData() public {
    //     PoolKey memory key = PoolKey({
    //         currency0: Currency.wrap(address(0x1)),
    //         currency1: Currency.wrap(address(0x2)),
    //         fee: 3000,
    //         tickSpacing: 60,
    //         hooks: IHooks(address(hook))
    //     });

    //     bytes memory invalidHookData = abi.encode("Invalid Data");

    //     vm.expectRevert(); // Expect the function to revert due to invalid data
    //     hook.beforeInitialize(address(this), key, 1 << 96, invalidHookData);
    // }

    // function testBeforeInitializeMultiplePools() public {
    //     PoolKey memory key1 = PoolKey({
    //         currency0: Currency.wrap(address(0x1)),
    //         currency1: Currency.wrap(address(0x2)),
    //         fee: 3000,
    //         tickSpacing: 60,
    //         hooks: IHooks(address(hook))
    //     });

    //     PoolKey memory key2 = PoolKey({
    //         currency0: Currency.wrap(address(0x3)),
    //         currency1: Currency.wrap(address(0x4)),
    //         fee: 500,
    //         tickSpacing: 10,
    //         hooks: IHooks(address(hook))
    //     });

    //     bytes memory hookData1 = abi.encode("ETH_USD", "Synthetic ETH/USD", "sETHUSD");
    //     bytes memory hookData2 = abi.encode("BTC_USD", "Synthetic BTC/USD", "sBTCUSD");

    //     hook.beforeInitialize(address(this), key1, 1 << 96, hookData1);
    //     hook.beforeInitialize(address(this), key2, 1 << 96, hookData2);

    //     bytes32 encodedKey1 = keccak256(abi.encode(key1));
    //     bytes32 encodedKey2 = keccak256(abi.encode(key2));

    //     assertEq(hook.poolToDataKey(encodedKey1), "ETH_USD", "Data key for pool 1 not set correctly");
    //     assertEq(hook.poolToDataKey(encodedKey2), "BTC_USD", "Data key for pool 2 not set correctly");

    //     assertTrue(address(hook.poolToSyntheticToken(encodedKey1)) != address(0), "Synthetic token for pool 1 not created");
    //     assertTrue(address(hook.poolToSyntheticToken(encodedKey2)) != address(0), "Synthetic token for pool 2 not created");
    // }
}
