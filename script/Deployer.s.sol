//SPDX-Lincense-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";

import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/chains/evm/contracts/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/chains/evm/contracts/tokenAdminRegistry/TokenAdminRegistry.sol";

import {Vault} from "../src/Vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebasetokenPool.sol";

import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";

contract VaultDeployer is Script {
    function run(address _rabaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = new Vault(IRebaseToken(_rabaseToken));
        IRebaseToken(_rabaseToken).grantMintAndBurnRole(address(vault));
        vm.stopBroadcast();
    }
}

contract TokenAndPoolDeployer is Script {
    function run()
        public
        returns (RebaseToken rebaseToken, RebaseTokenPool rebaseTokenPool)
    {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork
            .getNetworkDetails(block.chainid);
        vm.startBroadcast();
        rebaseToken = new RebaseToken();
        rebaseTokenPool = new RebaseTokenPool(
            IERC20(address(rebaseToken)),
            new address[](0),
            networkDetails.rmnProxyAddress,
            networkDetails.routerAddress
        );
        rebaseToken.grantMintAndBurnRole(address(rebaseTokenPool));
        RegistryModuleOwnerCustom(
            networkDetails.registryModuleOwnerCustomAddress
        ).registerAdminViaOwner(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(rebaseToken));
        TokenAdminRegistry(networkDetails.tokenAdminRegistryAddress).setPool(
            address(rebaseToken),
            address(rebaseTokenPool)
        );
        vm.stopBroadcast();
    }
}
