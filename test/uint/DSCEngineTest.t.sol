//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import { Test , console} from 'forge-std/src/Test.sol';
import { DSCEngine } from '../../src/DSCEngine.sol';
import { ERC20Mock } from '../Mocks/ERC20Mock.sol';
import { DeployDSC } from '../../script/DeployDSC.s.sol';
import { HelperConfig } from '../../script/HelperConfig.s.sol';
import { DecentralizedStableCoin } from '../../src/DecentralizedStableCoin.sol';




contract DSCEngineTest is Test {


    DecentralizedStableCoin Dsc;
    DeployDSC deployer ;
    HelperConfig config;
    address wethUsdPriceFee;
    address wbtcUsdPriceFee;
    address weth;
    DSCEngine Dsce;

    address public USER = makeAddr("Lhoussaine Ph");

    uint256 public constant STARTING_BALANCE = 10 ether ;


    function setUp() public {

        deployer = new DeployDSC();

        (Dsc , Dsce , config) = deployer.run();

        (wethUsdPriceFee ,wbtcUsdPriceFee,weth,,) = config.ActiveNetwork();

        ERC20Mock(weth).mint(USER , STARTING_BALANCE);


    }

    //////////////////////
    // constructor test //
    /////////////////////

    address[] tokenAddresses;
    address[] priceFeedAddresses;
    function testRevertIfTokenAndpriceFeedNotTheSame() public {

        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFee);
        priceFeedAddresses.push(wbtcUsdPriceFee);

        vm.expectRevert(DSCEngine.DSCEngine__tokenAddressesAndpriceFeedAddressesLengthMustBeTheSame.selector);

        new DSCEngine(tokenAddresses,priceFeedAddresses,address(Dsc));


    }
    /////////////////
    // Price Test //
    ///////////////

    function testgetUsdValue() public {

        uint256 Amount = 15e18;

        // 15e18 * 2000e8 = 30000e18
        uint256 expectAmount = 30000e18;

        uint256 actualAmount  = Dsce.getUsdValue(weth , Amount);

        assert(expectAmount == actualAmount);

    }


    function testgetTokenamountFromUser() public {

        uint256 Amount = 100 ether;
        uint256 expectAmount = 0.05 ether;

        uint256 actualAmount = Dsce.getTokenamountFromUser(weth , Amount);

        assert(expectAmount == actualAmount);
         
    }

    function testdipositCollateralRevertIfamounteZro() public {

        vm.prank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);

        Dsce.depositCollateral(weth , 0);
    }

    function testRevertsWithUnapprovedCollateral() public {

        ERC20Mock ranToken = new  ERC20Mock("RAN" , "RAN",USER,STARTING_BALANCE);

        vm.prank(USER);

        vm.expectRevert(DSCEngine.DSCEngine__NeedAllowedtoken.selector);
        Dsce.depositCollateral(address(ranToken),STARTING_BALANCE);

    }


    function testCanDepositcollateralandGetAmountInfo() public depositcollateral{

    ( uint256 totalDSCMinted , uint256 totalCollateralValueInUsd) = Dsce.getAccountUserInformation(USER);

        uint256 expecttotalDSCMinted = 0;

        uint256 expectDepositCollateral = Dsce.getTokenamountFromUser(weth , totalCollateralValueInUsd);

        assert(expecttotalDSCMinted == totalDSCMinted);
        assert(expectDepositCollateral == STARTING_BALANCE);

    }

    function testdepositCollateral() public depositcollateral{

        uint256 amountdeposited = Dsce.getCollateralBalanceOfUser(weth,USER);

    
        assert(amountdeposited == 1 ether);
    }

    modifier depositcollateral() {

        vm.startPrank(USER);

        ERC20Mock(weth).approve(address(Dsce) , STARTING_BALANCE);

        Dsce.depositCollateral(weth , STARTING_BALANCE);

        vm.stopPrank();

        _;

        
    }



/**
 @notice :
function testradomData(uint256 data) public {

// if in foundry put the data with no value foundry choose Random value to it 
    assert(Data == 1); 
}

 */






}   