//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import { Script } from 'forge-std/src/Script.sol';
import { HelperConfig } from './HelperConfig.s.sol';
import { DSCEngine } from '../src/DSCEngine.sol';
import { DecentralizedStableCoin } from '../src/DecentralizedStableCoin.sol';


contract DeployDSC is Script {

    HelperConfig helperconfig;

    DecentralizedStableCoin decentralizedStabelcion;

    DSCEngine DSC;

        address[] public tokenAddresses;
        address[] public priceFeedAddresses;

    function run() external returns(DecentralizedStableCoin,DSCEngine,HelperConfig)
    {

        helperconfig = new HelperConfig();

        (

        address wethUsdPriceFee ,
        address wbtcUsdPriceFee ,
        address weth ,
        address wbtc ,
        uint256 deployKey 

        ) = helperconfig.ActiveNetwork();

        tokenAddresses = [weth,wbtc];
        priceFeedAddresses = [wethUsdPriceFee , wbtcUsdPriceFee ];

        vm.startBroadcast(deployKey);

        decentralizedStabelcion = new DecentralizedStableCoin();

        DSC = new DSCEngine(tokenAddresses ,priceFeedAddresses , address(decentralizedStabelcion));

        decentralizedStabelcion.transferOwnership(address(DSC)); // because DSCEngine Ownable 

        vm.stopBroadcast();

    return(decentralizedStabelcion,DSC,helperconfig);
    }


}