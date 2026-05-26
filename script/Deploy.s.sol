// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Registry} from "../src/Registry.sol";
import {Attestation} from "../src/Attestation.sol";
import {Dispute} from "../src/Dispute.sol";
import {AgentIdentity} from "../src/AgentIdentity.sol";
import {MedianRule} from "../src/rules/MedianRule.sol";
import {TrimmedMeanRule} from "../src/rules/TrimmedMeanRule.sol";

/// @notice One-shot deploy of the bonded-agent oracle primitives.
///
/// What this deploys:
///   - Registry      : bond escrow + permissionless agent registration
///   - Attestation   : value writes + dispute-state-machine
///   - Dispute       : counter-bond + slashing
///   - AgentIdentity : global per-address profile (name / desc / url / contact)
///   - MedianRule    : onchain median computation (verifiable bytecode)
///   - TrimmedMeanRule(1000) : 10% per-tail trimmed mean
///
/// What this does NOT deploy:
///   - Any application layer (prediction markets, lending pools, credit systems).
///     The primitives are intentionally app-agnostic. See examples/ for forking patterns.
///
/// Run with:
///   USDC=0x... forge script script/Deploy.s.sol \
///     --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
contract Deploy is Script {
    function run()
        external
        returns (
            Registry registry,
            Attestation attestation,
            Dispute dispute,
            AgentIdentity identity,
            MedianRule medianRule,
            TrimmedMeanRule trim10
        )
    {
        address usdc = vm.envAddress("USDC");
        require(usdc != address(0), "USDC not configured");

        vm.startBroadcast();

        registry = new Registry(IERC20(usdc));
        attestation = new Attestation(registry);
        dispute = new Dispute(registry, attestation, IERC20(usdc));
        registry.wire(address(attestation), address(dispute));
        attestation.wire(address(dispute));

        identity = new AgentIdentity();
        medianRule = new MedianRule();
        trim10 = new TrimmedMeanRule(1000); // 10% per-tail trim

        vm.stopBroadcast();

        console2.log("Registry        :", address(registry));
        console2.log("Attestation     :", address(attestation));
        console2.log("Dispute         :", address(dispute));
        console2.log("AgentIdentity   :", address(identity));
        console2.log("MedianRule      :", address(medianRule));
        console2.log("TrimmedMeanRule :", address(trim10));
    }
}
