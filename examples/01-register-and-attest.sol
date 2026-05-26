// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal end-to-end usage example.
///
/// Run with:
///   forge script examples/01-register-and-attest.sol \
///     --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
///
/// What this does:
///   1. Creates a new feed for "BTC/USD ref rate"
///   2. Registers msg.sender as the bonded agent on that feed (10 USDC bond)
///   3. Posts one attestation with a placeholder value
///   4. Logs the feedId so you can build your app on top
///
/// Replace the methodology string + value with your real feed parameters.

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Registry} from "../src/Registry.sol";
import {Attestation} from "../src/Attestation.sol";

contract RegisterAndAttest is Script {
    function run() external {
        Registry registry = Registry(vm.envAddress("REGISTRY"));
        Attestation attestation = Attestation(vm.envAddress("ATTESTATION"));
        address dispute = vm.envAddress("DISPUTE");
        IERC20 usdc = IERC20(vm.envAddress("USDC"));

        string memory methodology =
            "BTC/USD reference rate. Median of [Coinbase, Kraken, Binance, Bitstamp]. "
            "Daily at 14:00 UTC. Reject if inter-source spread > 2%.";
        bytes32 methodologyHash = keccak256(bytes(methodology));

        vm.startBroadcast();

        // 1. Create the feed
        bytes32 feedId = registry.createFeed(
            methodology,
            methodologyHash,
            10e6,              // min bond: 10 USDC
            1 hours,           // dispute window
            dispute
        );

        // 2. Approve + register as agent
        usdc.approve(address(registry), 10e6);
        registry.registerAgent(feedId, methodologyHash, 10e6);

        // 3. Attest a placeholder value (replace with real data)
        bytes32 inputHash = keccak256(abi.encode("placeholder"));
        attestation.attest(feedId, int256(75000e18), inputHash);

        vm.stopBroadcast();

        console2.log("Created feed:", uint256(feedId));
        console2.log("First attestation submitted for sender:", msg.sender);
    }
}
