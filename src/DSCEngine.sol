//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import { ReentrancyGuard } from  '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';
import { DecentralizedStableCoin } from './DecentralizedStableCoin.sol';

import { OracleLib  } from './Libraries/OracleLib.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';

/**

* @title DSCEngine
* @author Lhoussaine Ait Aissa
* 
* The system is designed to be a minimal as possible , And had a mintean a 1 token == 1$ peg .
* This stablecoin has this properties :
* - Exogenous Collateral
* - Dollar Pegged
* - Algoritmically Stable
*
* It is simalar to DAI if DAI has  no governance , no fees , and has only backed by wETH and wBTC .
*
* Our DSC system should alwyse be "overCollateralized " . At no point , should the value of all the collateral <= the $value of all the  DSC.
*
* @notice This contrcat is the core of DSC system , It handles all the logic for mining and redeeming of DSC , as well as deposing & withdrowing the Collateral .
* @notice This contract is VERY loosely based on the MakerDAO DSS (DAI) system .

*/

contract DSCEngine is ReentrancyGuard {

    ///////////////////
    // Errors       //
    /////////////////

    error DSCEngine__MintFailed();
    error DSCEngine__FransferFailed();
    error DSCEngine__NeedAllowedtoken();
    error DSCEngine__HealthFactorISOk();
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__HealthFactorIsNotImprove();
    error DSCEngine__HealthFactorISBroken(uint256 healthFator);
    error DSCEngine__tokenAddressesAndpriceFeedAddressesLengthMustBeTheSame();

    ///////////////////
    // Types       //
    /////////////////

    using OracleLib for AggregatorV3Interface;


    //////////////////////
    // State Variables //  
    ////////////////////

    uint256 private constant ADDITIONAL_PEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATE_THRESHOLD = 50 ; // 200% collateral 
    uint256 private constant LIQUIDATE_PRECISION = 100 ;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18 ;
    uint256 private constant LIQUIDATE_BONUS = 10 ether ; // this means 10% bunos

    mapping (address token => address priceFeed ) private s_priceFeeds ; // token to priceFeed

    mapping (address user => mapping(address token => uint256 amount) ) private s_CollateralDepolsited ; 

    mapping (address user => uint256 amountDSCminted) private s_DSCMint ;
    DecentralizedStableCoin private immutable i_Dsc;
    address [] private s_CollateralTokens;

      ///////////////////
     // Events        //
     ///////////////////

     event CollateralDeposited(address indexed user , address indexed token , uint256 amount);
     event CollateralRedeemed(address indexed redeemedFrom , address indexed redeemedTo ,address indexed token , uint256 amount);

     ///////////////////
    // Modifiers     //
    //////////////////

    modifier MoreThanZero (uint256 amount) {

        if ( amount <= 0) {
        
            revert DSCEngine__NeedsMoreThanZero();
        
        }
        _;
    }

    modifier isAllowedtoken (address token) {

        if ( s_priceFeeds[token] == address(0) ){
        
            revert DSCEngine__NeedAllowedtoken();
        
        }
        _;
    }
    

     ///////////////////
    // Functions     //
    //////////////////

    constructor ( 
        address [] memory tokenAddresses ,
        address [] memory priceFeedAddresses,
        address Dsc
        ) {

            if (  tokenAddresses.length != priceFeedAddresses.length ) {

                revert DSCEngine__tokenAddressesAndpriceFeedAddressesLengthMustBeTheSame();
            }

            for ( uint256 i = 0 ; i < tokenAddresses.length ; i++) {

                s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
                s_CollateralTokens.push(tokenAddresses[i]);

            }

            i_Dsc = DecentralizedStableCoin(Dsc);

        }

      ///////////////////////
     // External Functions //  
    ///////////////////////

    /**
    * @notice This function is do diposit collateral and mint at the same time !
    * @param tokenCollateralAddress  The  address of the token to deposit as Collateral
    * @param amountCollateral        The  amount of Collateral to deposit
    * @param amountCollateraltoMint  The amount of decentralized stabelcoin to mint
    */

    function  depositCollateralAndMintDsc(

        address tokenCollateralAddress ,
        uint256 amountCollateral ,
        uint256 amountCollateraltoMint
        
        ) external {

            depositCollateral(tokenCollateralAddress,amountCollateral);
            mintDsc(amountCollateraltoMint);

        }

    /**
    * @notice The function follows CEI
    * @param tokenCollateralAddress  The  address of the token to deposit as Collateral
    * @param amountCollateral        The  amount of Collateral to deposit
    */

    function depositCollateral(

        address tokenCollateralAddress ,
        uint256 amountCollateral

    ) 
    public MoreThanZero( amountCollateral ) isAllowedtoken(tokenCollateralAddress) nonReentrant
    
    {

        s_CollateralDepolsited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender , tokenCollateralAddress ,amountCollateral);
        
        bool success =  IERC20(tokenCollateralAddress).transferFrom(msg.sender , address(this) , amountCollateral);

        if (! success) {

            revert DSCEngine__FransferFailed();

        }


    }
    
    
        // $100 ETH / $10 DSC 
        // 100  Break
        // 1. burn DSC
        // 2. Redeem ETH
        
    /**

    * @notice The function Burn Dsc and redeem underlying Collateral in one transation
    * @param tokenCollateralAddress  The  address of the token to redeem as Collateral
    * @param amountCollateral        The  amount of Collateral to redeem
    * @param  amountCollateralDsctoBurn  The amount of dsc to burn 

    */


    function  redeemCollateralforDsc(

        address tokenCollateralAddress ,
        uint256 amountCollateral,
        uint256 amountCollateralDsctoBurn
        
        ) external {

            burnDsc(amountCollateralDsctoBurn);

            redeemCollateral(tokenCollateralAddress , amountCollateral);

        }

    /**
    * @notice in order to redeem collateral :
    * 1 . healt factor must be over then 1
    * DRY : Don't repeat yourself
     */

    function  redeemCollateral(

        address tokenCollateralAddress ,
        uint256 amountCollateral

     )  public MoreThanZero(amountCollateral) nonReentrant {

        _redeemCollateral(msg.sender , msg.sender , tokenCollateralAddress , amountCollateral);

        _revetifHealthfactorisBroken(msg.sender);



    }

    function  burnDsc( uint256 amount) public {

      _burnDsc(msg.sender , msg.sender ,amount); 
        
        _revetifHealthfactorisBroken(msg.sender); // I don't think this would ever hit...

    }

    /**
    * @notice The function follows CEI
    * @param amountCollateraltoMint   The amount of decentralized stabelcoin to mint
    * @notice They must have more collateral than the miniment Threshold
    */

    function  mintDsc( uint256 amountCollateraltoMint ) public MoreThanZero(amountCollateraltoMint) nonReentrant {

        s_DSCMint[msg.sender] += amountCollateraltoMint ;
        // if they mint too much ($150 DSC , 100 ETH) 
        _revetifHealthfactorisBroken(msg.sender);

        bool minted = i_Dsc.mint(msg.sender , amountCollateraltoMint );

        if ( !minted ){

            revert DSCEngine__MintFailed();
        }

    }

/**
* If we start nearing underCollateralization we need someone to liquidate the postion
* $100 ETH backing $50
* $20 ETH back $50 DSC <- dsc isn't worth $1 !!!
* $75 backing $50 DSC
* Liquidator take $75 backing and burns off the $50 DSC
* If someone is almost collaterunderCollateralized , we will pat to liquidate them. 

 */

 /**
 
 * @param collateral the erc20 collateral address to liquidate from the user 
 * @param user The user who has broken the health factor . Their _healthFactor should be below  MIN_HEALTH_FACTOR 
 * @param debtToCover The amount of DSC you want to burn to improve the users health factor
 * @notice You can partially liquidate a user 
 * @notice You will get a liquidation bonus for taking the users funds 
 * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order for this to work.
 *  @notice A known bug would be if the protocol were 100%  or less collateralized , then we wouldn't be able to incentive the liquidators .
 * For exemple , if the price of the collateral plummeted before anyone could be liquidated .

  */
    function  lequidate( address collateral , address user , uint256 debtToCover) external  MoreThanZero(debtToCover) nonReentrant{

        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR){

            revert DSCEngine__HealthFactorISOk();

        }

        // we want to burn thier DSC "debt"
        // And take thier collateral 
        // Bad User : $140 ETH , $100 DSC
        // debtToCover = $100
        // $100 of DSC == ??? ETH

        uint256 tokenAmountFromDebtCovered = getTokenamountFromUser(collateral,debtToCover);

        //  And give them a 10% bonus
        // So we are giving the liquidator $110 of weth for 100 dsc
        // we should implement a feature to liquidate in the event the protocol is insolvent 
        // And sweep extra amounts into a treasury
        // 0.05 * 0.1 = 0.005 . Getting 0.055

        uint256 bunosCollateral = (tokenAmountFromDebtCovered * LIQUIDATE_BONUS) / LIQUIDATE_PRECISION ;

        uint256 totalCollateraltoRedeem = tokenAmountFromDebtCovered + bunosCollateral;

        _redeemCollateral(user , msg.sender , collateral , totalCollateraltoRedeem);

        // we need to burn DSC
        _burnDsc(user,msg.sender,debtToCover);

        
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor){

            revert DSCEngine__HealthFactorIsNotImprove();

        }

        _revetifHealthfactorisBroken(msg.sender);
    }

    function  getHealthFactor() external {}


    //////////////////////////////////
    // Private & internal Functions //
    /////////////////////////////////


    /**
    
    *@dev Low-Level Function , do not call unless the functio  calling it is
    * Checking for health factor being broken 

    */ 
    function  _burnDsc( address onBehalfof , address dscFrom ,uint256 amountDscToBurn ) private {

            s_DSCMint[onBehalfof] -= amountDscToBurn ;

        bool success = i_Dsc.transferFrom(dscFrom , address(this) , amountDscToBurn);
        if ( !success) {

            revert DSCEngine__FransferFailed();

        }

        i_Dsc.burn(amountDscToBurn);

    }

    function _redeemCollateral( address from , address to, address tokenCollateralAddress , uint256 amountCollateral ) private {


        s_CollateralDepolsited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from ,to, tokenCollateralAddress ,amountCollateral);

        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);

        if (! success) {

            revert DSCEngine__FransferFailed();

        }


    }

    function _getAccountUserInformation(address user) 
    internal 
    view 
    returns( uint256 totalDSCMinted , uint256 totalCollateralValueInUsd)
    {
         totalDSCMinted = s_DSCMint[user];
 
        totalCollateralValueInUsd = getAccountCollateralValue(user);

        return( totalDSCMinted , totalCollateralValueInUsd);
    }


    /**
    * Return how to close a liquidation a user is
    * If a user goes a below 1 , then  they can get liquidated 
    */

    function _healthFactor(address user) internal view returns(uint256) {
        // total DSC Minted
        // total collateral VALUE

        (uint256 totalDSCMinted , uint256 totalCollateralValueInUsd ) = _getAccountUserInformation(user);

        uint256 CollateralAdjustedForThreshold =  (totalCollateralValueInUsd * LIQUIDATE_THRESHOLD) /  LIQUIDATE_PRECISION;

        // 1000 ETH / 100 DSC = 10
        // 1000 ETH * 50  = 50000 / 100  = (500 /100) > 1 good one

        // 150 ETH / 100 DSC = 1.5
        // 150 * 50 = 7400 / 100 = (74 / 100) < 1  bad one 

        return (CollateralAdjustedForThreshold * PRECISION) / totalDSCMinted ; 

    }

    function _revetifHealthfactorisBroken(address user) internal view {
        // check the heath  factor (they have enough Collateral ? ) 
       
       uint256 userHealthFactor  = _healthFactor(user);

       if (userHealthFactor < MIN_HEALTH_FACTOR ){

            revert DSCEngine__HealthFactorISBroken(userHealthFactor);
       }

    }

    ///////////////////////////////////////
    // Public  & internal view Functions //
    //////////////////////////////////////

    function getAccountUserInformation(address user)  external view 
    returns( uint256 totalDSCMinted , uint256 totalCollateralValueInUsd)
    {

        ( totalDSCMinted , totalCollateralValueInUsd)= _getAccountUserInformation(user);

        return( totalDSCMinted , totalCollateralValueInUsd);

    }

    function getTokenamountFromUser(address token  , uint256 amount) public returns(uint256){


        AggregatorV3Interface priceFee = AggregatorV3Interface(s_priceFeeds[token]);
        
        (, int256 price,,,) = priceFee.staleChecklatestRoundData();

         return (amount*PRECISION /(uint256(price) * ADDITIONAL_PEED_PRECISION));

    }
    function  getAccountCollateralValue( address user)  public view returns(uint256 totalCollateralValueInUsd){

        // loop through for  each collateral token , get the amount they have deposited and map it to 
        // the price to get the usd value 

        for ( uint256 i = 0 ; i < s_CollateralTokens.length ; i++ ){

            address token = s_CollateralTokens[i];
            uint256 amount = s_CollateralDepolsited[user][token];

            totalCollateralValueInUsd += getUsdValue(token , amount);


        }

        return totalCollateralValueInUsd;

    }

        function getUsdValue( address token , uint256 amount ) public view returns(uint256) {

            AggregatorV3Interface priceFee = AggregatorV3Interface(s_priceFeeds[token]);
            (, int256 price,,,) = priceFee.staleChecklatestRoundData();
            // 1 ETH = 1000 $
            // return ((1000 * 1e10)*amout)/1e18 

            return ((uint256(price) * ADDITIONAL_PEED_PRECISION)*amount)/PRECISION ;
        }

        function getCollateralTokens() external view returns(address [] memory){

            return s_CollateralTokens;
        }
        function getCollateralBalanceOfUser( address user , address token ) external view returns(uint256){

            return s_CollateralDepolsited[user][token];
        }

        function getCollateralTokenPriceFeed(address token ) external view returns(address){

            return s_priceFeeds[token];
        }

}