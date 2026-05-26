// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Verifiable-aggregation example.
///
/// Registers an agent that binds to MedianRule at registration time. After
/// registration, attestations don't take a final value — they take the raw
/// input vector, and the rule contract computes the value deterministically
/// onchain. Anyone watching the chain can re-execute the rule from calldata
/// and confirm the stored value byte-for-byte.
///
/// This is the "methodology IS the bytecode" pattern.

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Registry} from "../src/Registry.sol";
import {Attestation} from "../src/Attestation.sol";

contract RuleBoundAgent is Script {
    function run() external {
        Registry registry = Registry(vm.envAddress("REGISTRY"));
        Attestation attestation = Attestation(vm.envAddress("ATTESTATION"));
        address dispute = vm.envAddress("DISPUTE");
        address medianRule = vm.envAddress("MEDIAN_RULE");
        IERC20 usdc = IERC20(vm.envAddress("USDC"));

        string memory methodology =
            "Kraków residential PLN/sqm. Median of last 7 days of Otodom listings, "
            "rule-bound to MedianRule.sol onchain. Methodology IS the bytecode.";
        bytes32 methodologyHash = keccak256(bytes(methodology));

        vm.startBroadcast();

        bytes32 feedId = registry.createFeed(
            methodology, methodologyHash, 25e6, 1 hours, dispute
        );

        // Approve + register WITH a rule. After this, attestWithRule is the
        // only valid attestation path; spoofing a final value is impossible.
        usdc.approve(address(registry), 25e6);
        registry.registerAgentWithRule(feedId, methodologyHash, 25e6, medianRule);

        // Attest using rawInputs. MedianRule.submit() computes the value
        // onchain — any observer can reproduce it byte-for-byte.
        int256[] memory rawInputs = new int256[](7);
        rawInputs[0] = 12000;
        rawInputs[1] = 13000;
        rawInputs[2] = 14500;
        rawInputs[3] = 13800;
        rawInputs[4] = 14100;
        rawInputs[5] = 13200;
        rawInputs[6] = 14000;
        attestation.attestWithRule(feedId, rawInputs);

        vm.stopBroadcast();

        console2.log("Rule-bound feed created:", uint256(feedId));
        console2.log("Median (computed onchain) of inputs above will be 13800 PLN/sqm");
    }
}
