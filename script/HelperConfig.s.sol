//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { Script } from 'forge-std/src/Script.sol';
import { MockV3Aggregator } from '../test/Mocks/MockV3Aggregator.sol';
import { ERC20Mock } from '../test/Mocks/ERC20Mock.sol';
contract HelperConfig is Script {


    Networkconfig public ActiveNetwork;

    

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private constant SEPOLIA_CHAINID = 11155111 ;
    uint8 public constant DECIMAL = 8;
    int256 public constant ETH_USD_PRICE= 2000e8;
    int256 public constant BTC_USD_PRICE= 1000e8;

    struct Networkconfig  {

        address wethUsdPriceFee ;
        address wbtcUsdPriceFee ;
        address weth ;
        address wbtc ;

        uint256 deployKey ;
    }

    
    constructor () {

        if( block.chainid == SEPOLIA_CHAINID){

            ActiveNetwork = getSepoliaConfig();

        }

        else {

            ActiveNetwork = getOrcreateAnvil();
            
        }
    }

    

    function getSepoliaConfig () public view returns(Networkconfig memory ){

        return Networkconfig({

        wethUsdPriceFee : 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ,
        wbtcUsdPriceFee  : 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        weth : 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        wbtc : 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        deployKey : vm.envUint('PRIVATE_KEY')

        });

    }


    function getOrcreateAnvil() public returns( Networkconfig memory) {

        if ( ActiveNetwork.wethUsdPriceFee != address(0)){
            return ActiveNetwork;

        }


        vm.startBroadcast();

        MockV3Aggregator wethUsdPriceFee = new MockV3Aggregator(DECIMAL , ETH_USD_PRICE);
        ERC20Mock weth = new ERC20Mock("WETH","WETH",msg.sender , 1000e8);
        vm.stopBroadcast();

        vm.startBroadcast();

        MockV3Aggregator wbtcUsdPriceFee = new MockV3Aggregator(DECIMAL ,BTC_USD_PRICE);
        ERC20Mock wbtc = new ERC20Mock("WBTC","WBTC", msg.sender ,1000e8);

        vm.stopBroadcast();

        return Networkconfig({

        wethUsdPriceFee : address(wethUsdPriceFee) ,
        wbtcUsdPriceFee  : address(wbtcUsdPriceFee),
        weth : address(weth),
        wbtc : address(wbtc),
        deployKey : DEFAULT_ANVIL_PRIVATE_KEY

        });
    }


}
