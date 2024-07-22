//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import { Test , console} from 'forge-std/src/Test.sol';
import { DSCEngine } from '../../src/DSCEngine.sol';
import { DeployDSC } from '../../script/DeployDSC.s.sol';
import { MockV3Aggregator } from '../Mocks/MockV3Aggregator.sol';

import { ERC20Mock } from '../Mocks/ERC20Mock.sol';
import { DecentralizedStableCoin } from '../../src/DecentralizedStableCoin.sol';

contract Handler is Test {

    DSCEngine Dsce;
    DecentralizedStableCoin Dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator public ethUsdPriceFeed;

    uint256 public timeMintIsCalled;

    address[] public usersWithCollateralDeposited ;


    uint96 private constant MAX_DEPOSIT_SIZE = type(uint96).max; // max value in uint96

    constructor (DSCEngine dsce , DecentralizedStableCoin dsc) {

        Dsce = dsce;
        Dsc = dsc ;

        address[] memory Collateral = Dsce.getCollateralTokens();

        weth = ERC20Mock(Collateral[0]);
        wbtc = ERC20Mock(Collateral[1]);

        ethUsdPriceFeed =  MockV3Aggregator(Dsce.getCollateralTokenPriceFeed(address(weth)));
    }


    // redeemcollateral <- 

    function depositCollateral( uint256 CollateralSeed , uint256 amountDeposit) public {

        ERC20Mock Collateral = _getCollateralFromdSeed(CollateralSeed);

        amountDeposit = bound(amountDeposit , 1 , MAX_DEPOSIT_SIZE); // 1 < amount < MAX..

        vm.startPrank(msg.sender);

        Collateral.mint(msg.sender , amountDeposit);
        Collateral.approve(address(Dsce) , amountDeposit);
        Dsce.depositCollateral(address(Collateral),amountDeposit);

        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);

        
    }


    function redeemCollateral( uint256 CollateralSeed , uint256 amountRedeem) public {

        ERC20Mock Collateral = _getCollateralFromdSeed(CollateralSeed);

        uint256 maxCollateralToRedeem = Dsce.getCollateralBalanceOfUser(address(Collateral) , msg.sender ) ;

        amountRedeem = bound(amountRedeem , 0 , maxCollateralToRedeem); // 1 < amount < MAX..

        if ( amountRedeem == 0 ){
            return;
        }

        Dsce.redeemCollateral(address(Collateral) , amountRedeem);
    }



    function mintDsc(uint256 amount , uint256 addressSeed) public {

        if (usersWithCollateralDeposited.length == 0){

            return;
        }

        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length ];



       ( uint256 totalDSCMinted , uint256 totalCollateralValueInUsd) = Dsce.getAccountUserInformation(sender);

       int256 maxDscMint = (int256(totalCollateralValueInUsd) / 2 ) - int256(totalDSCMinted);

        // 100 10 
        // 5 - 100 = -95
       if (maxDscMint < 0) {

        return;

       }

       amount = bound(amount , 0 , uint256(maxDscMint));

       if (amount == 0 ) {

        return;

       }

       vm.startPrank(sender);

       Dsce.mintDsc(amount);

       vm.stopPrank();

        timeMintIsCalled++;

    }

    function updateCollateral(uint96 price) public {

        int256 pricefeed = int256(uint256(price));
        
        ethUsdPriceFeed.updateAnswer(pricefeed);


    }
    // Helper Funs
    function _getCollateralFromdSeed( uint256 CollateralSeed ) public view returns(ERC20Mock) {

        if ( CollateralSeed % 2 == 0 ){

            return weth;

        }

        return wbtc;
    }
}