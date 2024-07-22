//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import { Test , console} from 'forge-std/src/Test.sol';
import { StdInvariant } from 'forge-std/src/StdInvariant.sol';
import { DSCEngine } from '../../src/DSCEngine.sol';
import { Handler } from './Handler.t.sol';
import { DeployDSC } from '../../script/DeployDSC.s.sol';
import { HelperConfig } from '../../script/HelperConfig.s.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { DecentralizedStableCoin } from '../../src/DecentralizedStableCoin.sol';

contract InvariantsTest is StdInvariant , Test {

    DecentralizedStableCoin Dsc;
    DeployDSC deployer ;
    HelperConfig config;
    DSCEngine Dsce;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() public {

        deployer = new DeployDSC();

        (Dsc , Dsce , config) = deployer.run();
        (,,weth ,wbtc,) = config.ActiveNetwork();
        handler =new Handler(Dsce , Dsc);
        // targetContract(address(Dsce));
        targetContract(address(handler));


    }

    function invariant_protocolMustHaveMorevaluethantotalSupply()public {

        uint256 totalSupply = Dsc.totalSupply();

        uint256 totalwethDeposietd = IERC20(weth).balanceOf(address(Dsce));
        uint256 totalwbtcDeposietd = IERC20(wbtc).balanceOf(address(Dsce));
    
        uint256 wethValue = Dsce.getUsdValue(weth , totalwethDeposietd );
        uint256 wbtcValue = Dsce.getUsdValue(wbtc , totalwbtcDeposietd );

        console.log("time : " , handler.timeMintIsCalled());
        console.log("totalSupplay :  " ,totalSupply );

        assert ( wethValue + wbtcValue >= totalSupply);

    }

}