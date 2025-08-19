// SPDX-License-Identifier: MIT-1.1
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "forge-std/StdJson.sol";
import "../script/DeployV2.s.sol";
import "../script/DeployGaugesAndPoolsV2.s.sol";
import "../script/DeployGovernors.s.sol";

import "./BaseTest.sol";

contract TestDeploy is BaseTest {
    using stdJson for string;
    using stdStorage for StdStorage;

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public jsonConstants;

    address public feeManager;
    address public team;
    address public emergencyCouncil;
    address public constant testDeployer = address(1);

    struct PoolV2 {
        bool stable;
        address tokenA;
        address tokenB;
    }

    struct PoolCEDAV2 {
        bool stable;
        address token;
    }

    // Scripts to test
    DeployV2 deployV2;
    DeployGaugesAndPoolsV2 deployGaugesAndPoolsV2;
    DeployGovernors deployGovernors;

    constructor() {
        deploymentType = Deployment.CUSTOM;
    }

    function _setUp() public override {
        _forkSetupBefore();

        deployV2 = new DeployV2();
        deployGaugesAndPoolsV2 = new DeployGaugesAndPoolsV2();
        deployGovernors = new DeployGovernors();

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/constants/");
        path = string.concat(path, constantsFilename);

        jsonConstants = vm.readFile(path);

        WETH = IWETH(abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address)));
        team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));
        emergencyCouncil = abi.decode(vm.parseJson(jsonConstants, ".emergencyCouncil"), (address));

        // Use test account for deployment
        stdstore.target(address(deployV2)).sig("deployerAddress()").checked_write(testDeployer);
        stdstore.target(address(deployGaugesAndPoolsV2)).sig("deployerAddress()").checked_write(testDeployer);
        stdstore.target(address(deployGovernors)).sig("deployerAddress()").checked_write(testDeployer);
        vm.deal(testDeployer, TOKEN_10K);
    }

    function testLoadedState() public {
        // If tests fail at this point- you need to set the .env and the constants used for deployment.
        // Refer to script/README.md
        assertTrue(address(WETH) != address(0));
        assertTrue(team != address(0));
        assertTrue(feeManager != address(0));
        assertTrue(emergencyCouncil != address(0));
    }

    function testDeployScript() public {
        deployV2.run();
        deployGaugesAndPoolsV2.run();

        assertEq(deployV2.voter().epochGovernor(), team);
        assertEq(deployV2.voter().governor(), team);

        // DeployV2 checks

        // ensure all tokens are added to voter
        address[] memory _tokens = abi.decode(vm.parseJson(jsonConstants, ".whitelistTokens"), (address[]));
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            assertTrue(deployV2.voter().isWhitelistedToken(token));
        }
        assertTrue(deployV2.voter().isWhitelistedToken(address(deployV2.CEDA())));

        assertTrue(address(deployV2.WETH()) == address(WETH));

        // PoolFactory
        assertEq(deployV2.factory().voter(), address(deployV2.voter()));
        assertEq(deployV2.factory().stableFee(), 5);
        assertEq(deployV2.factory().volatileFee(), 30);

        // v2 core
        // From _coreSetup()
        assertTrue(address(deployV2.forwarder()) != address(0));
        assertEq(address(deployV2.artProxy().ve()), address(deployV2.escrow()));
        assertEq(deployV2.escrow().voter(), address(deployV2.voter()));
        assertEq(deployV2.escrow().artProxy(), address(deployV2.artProxy()));
        assertEq(address(deployV2.distributor().ve()), address(deployV2.escrow()));
        assertEq(deployV2.router().defaultFactory(), address(deployV2.factory()));
        assertEq(deployV2.router().voter(), address(deployV2.voter()));
        assertEq(address(deployV2.router().weth()), address(WETH));
        assertEq(deployV2.distributor().minter(), address(deployV2.minter()));
        assertEq(deployV2.CEDA().minter(), address(deployV2.minter()));

        assertEq(deployV2.voter().minter(), address(deployV2.minter()));
        assertEq(address(deployV2.minter().CEDA()), address(deployV2.CEDA()));
        assertEq(address(deployV2.minter().voter()), address(deployV2.voter()));
        assertEq(address(deployV2.minter().ve()), address(deployV2.escrow()));
        assertEq(address(deployV2.minter().rewardsDistributor()), address(deployV2.distributor()));

        // Permissions
        assertEq(address(deployV2.minter().pendingTeam()), team);
        assertEq(deployV2.escrow().team(), team);
        assertEq(deployV2.escrow().allowedManager(), team);
        assertEq(deployV2.factory().pauser(), team);
        assertEq(deployV2.voter().emergencyCouncil(), emergencyCouncil);
        assertEq(deployV2.voter().governor(), team);
        assertEq(deployV2.voter().epochGovernor(), team);
        assertEq(deployV2.factoryRegistry().owner(), team);
        assertEq(deployV2.factory().feeManager(), feeManager);

        // DeployGaugesAndPoolsV2 checks

        // Validate non-CEDA pools and gauges
        PoolV2[] memory poolsV2 = abi.decode(jsonConstants.parseRaw(".poolsV2"), (PoolV2[]));
        for (uint256 i = 0; i < poolsV2.length; i++) {
            PoolV2 memory p = poolsV2[i];
            address poolAddr = deployV2.factory().getPool(p.tokenA, p.tokenB, p.stable);
            assertTrue(poolAddr != address(0));
            address gaugeAddr = deployV2.voter().gauges(poolAddr);
            assertTrue(gaugeAddr != address(0));
        }

        // validate CEDA pools and gauges
        PoolCEDAV2[] memory poolsCEDAV2 = abi.decode(jsonConstants.parseRaw(".poolsCEDAV2"), (PoolCEDAV2[]));
        for (uint256 i = 0; i < poolsCEDAV2.length; i++) {
            PoolCEDAV2 memory p = poolsCEDAV2[i];
            address poolAddr = deployV2.factory().getPool(address(deployV2.CEDA()), p.token, p.stable);
            assertTrue(poolAddr != address(0));
            address gaugeAddr = deployV2.voter().gauges(poolAddr);
            assertTrue(gaugeAddr != address(0));
        }
    }

    function testDeployGovernors() public {
        deployGovernors.run();

        governor = deployGovernors.governor();
        epochGovernor = deployGovernors.epochGovernor();

        assertEq(address(governor.ve()), address(deployGovernors.escrow()));
        assertEq(address(governor.token()), address(deployGovernors.escrow()));
        assertEq(governor.vetoer(), address(testDeployer));
        assertEq(governor.pendingVetoer(), address(deployGovernors.vetoer()));
        assertEq(governor.team(), address(testDeployer));
        assertEq(governor.pendingTeam(), address(deployGovernors.team()));
        assertEq(address(governor.escrow()), address(deployGovernors.escrow()));
        assertEq(address(governor.voter()), address(deployGovernors.voter()));

        assertEq(address(epochGovernor.token()), address(deployGovernors.escrow()));
        assertEq(epochGovernor.minter(), address(deployGovernors.minter()));
        assertTrue(epochGovernor.isTrustedForwarder(address(deployGovernors.forwarder())));
        assertEq(address(governor.escrow()), address(deployGovernors.escrow()));
        assertEq(address(governor.voter()), address(deployGovernors.voter()));
    }
}
