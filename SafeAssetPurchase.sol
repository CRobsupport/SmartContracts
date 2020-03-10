pragma solidity >=0.4.22 <0.6.0;

contract SafeAssetPurchase {

   //  Version 0.0.5 - 03/10/2020 flattened.


    // state locks

    bool public assetforsale;
    bool public assetjustcreated;

    // use to payout to the owner the full value of the bid upon sale - less commission of trade platform.
    // necessary due to beneficiary being the old owner after sale transaction complete and

    address payable public beneficiaryowner;

    // Who owns legally, the asset at any time.

    address public owner;
    // record of seller after sale.- for audit
    address public soldfromaddress;

    // publicly exposed data of asset value, asking value, date of new monthly payment, monthly payout amount
    // value of the last bid

    string public assetname;
    address public assetcontractaddress;
    string public ipfshashlink_legaldocs;

    uint public assetvalueETH;
    uint public onthdate_ofnewpaymentschedule;
    uint public monthlypayoutamount;
    uint public payout_term_months;
    uint public payout_monthsleft;
    uint public newaskprice;
    uint public askvalueETH;
    bool public assetmatured;
    bool public sellerwithdrawnfunds;
    bool public commissiontaken;
    uint public commission_sum;

    // Commission rate % for each trade will be paid to Platform Wallet at time of successful bid
    // Commission sum will come from the sellers sale funds

    uint public commissionrate;
    address payable public platformaddress;

    // Current state of the trading state -public so all can see - market tranparancey

    uint public valueethbid;
    address payable public highestBidder;
    uint public highestBid;


    // Payable fallback function is not enabled - this contract cannot accept ETH without a call specifically
    // to the initial load the asset action and the bid function.
    // For this example asset creator is the owner - not true in reality - why would you create a note for sale at discount
    // with fund you presently own..  but assume for this example.

    // The creator/owner  must mark for sale ie call that function after creation to be open to bids
    // The asset must then be loaded with hard value ETH above ask value
    // The markforsale function call then sets status
    // example IPFS hash - assume a link to a binding legal document for this Annunity  QmTfCejgo2wTwqnDJs8Lu1pCNeCrCDuE4GAwkna93zdd7d
    // IPFS hash is 34 bytes  - store as string for this sample.- refine for ultr low gas costs - phase II.

    // to ..put and get a file from IPFS - & daemon must be installed.
    // ipfs cat Qmd4PvCKbFbbB8krxajCSeHdLXQamdt7yFxFxzTbedwiYM
    // curl https://ipfs.io/ipfs/Qmd4PvCKbFbbB8krxajCSeHdLXQamdt7yFxFxzTbedwiYM


    constructor(string memory _assetname, address payable _beneficiary_owner_ofasset_sale,  string memory _hashlink_to_IPFS_legaldocs,  uint _inital_HBAR_askvalue,  uint _platform_commission_rate_percent, address payable _tanzletrade_wallet_address) public {
        assetforsale = true;
        assetjustcreated = true;
        commissiontaken =  true;
        commissionrate = _platform_commission_rate_percent;
        ipfshashlink_legaldocs = _hashlink_to_IPFS_legaldocs;
        assetname = _assetname;
        assetcontractaddress = address(this);
        askvalueETH = _inital_HBAR_askvalue*10**18 ;
        beneficiaryowner = _beneficiary_owner_ofasset_sale;
        owner = msg.sender;
        platformaddress = _tanzletrade_wallet_address;
        payout_term_months = _payout_years_term.mul(12);
        payout_monthsleft = payout_term_months;
        assetmatured = false;
        sellerwithdrawnfunds = true;
        emit assetcreated(assetcontractaddress);

    }

         // Events and modifiers only here..

       event assetcreated(address contractaddress);
       event assetbidreturned(address bidder, uint bidvalue);
       event assetbidsuccessful(address bidder);
       event assetbidhighest(address highestbidder, uint bidvalue);
       event Sellerwithrawnfunds_ok(address benowner, uint highbid);
       event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

        modifier commissionisdue() {
            require (commissiondue(), "Cannot send commssion to platform if no sale has occured yet");
            _;
        }

        // to make these mods more consistent with meu1pCNeCrCDuE4GAwkna93zdd7dthod returns.

        modifier commissionnotaken() {
            require ((commissiontaken == false), "Cannot send commission more than once for this contract");
            _;
        }


        modifier onlysuccessfulseller(){
              require(isseller(), "Caller is not the successfull seller");
              _;
        }

        modifier onlyforsalestatus() {
            require(isforsale()," Asset must be marked for sale by owner");
            _;
        }

          modifier currforsalestatus() {
            require((assetforsale == false), "asset status is marked for Sale by Owner, no montly payment withdraws permitted while on market");
            _;
        }

         modifier currnotforsalestatus() {
            require(isnotforsale(),"asset must NOT be for currently sale for Owner to sell it");
               _;
            }

        modifier onlyOwner() {
            require(isOwner(), "Ownable: caller is not the owner");
            _;
        }

        modifier notowner() {
            require(isnotOwner(),"Ownable: Caller is the owner & cannot bid on own asset");
            _;
        }

       // depends on time format and how the scVM sees the keyword 'now' .. TBD

        modifier onlypermonth() {
             require(now > (onthdate_ofnewpaymentschedule+30 days), "Can only withdraw >30 days from last monthly payout or initial purchase date payment");
                  _;
        }

        function isforsale() public view returns (bool) {
            return assetforsale == true;
        }

        function isnotforsale() public view returns (bool) {
            return assetforsale == false;
        }

         function isseller() public view returns (bool) {
            return msg.sender == soldfromaddress;
        }

        function isnotOwner() public view returns (bool) {
            return msg.sender != owner;
        }

        function isOwner() public view returns (bool) {
            return msg.sender == owner;
        }

        function commissiondue() public view returns (bool) {
            return soldfromaddress != address(0);
        }

        /**
         * @dev Leaves the contract without owner. It will not be possible to call
         * `onlyOwner` functions anymore. Can only be called by the current owner.
         *
         * NOTE: Renouncing ownership will leave the contract without an owner,
         * thereby removing any functionality that is only available to the owner.
         */

        function renounceOwnership() public onlyOwner {
            emit OwnershipTransferred(owner, address(0));
            owner = address(0);
        }

        /**
         * @dev Transfers ownership of the contract to a newasset account (`newOwner`).
         * Can only be called by the current owner.
         */
        function transferOwnership(address _newOwner) public onlyOwner {
            _transferOwnership(_newOwner);
        }

        /**
         * @dev Transfers ownership of the contract to a new account (`newOwner`).
         */
        function _transferOwnership(address _newOwner) internal {
            require(_newOwner != address(0), "Ownable: new owner is the zero address");

            emit OwnershipTransferred(owner, _newOwner);
            owner = _newOwner;

        }

    // Only the owner can update the legally bound document copies on IPFS to this Annunity contract
    // and thus publicly linkable and display by any bidding entity

    function update_docs_link(string memory _newhashlink) public onlyOwner currnotforsalestatus {
        bytes memory tempEmptyStringTest = bytes(_newhashlink);
        require(tempEmptyStringTest.length >0 , "Hash Link cannot be empty");
        ipfshashlink_legaldocs = _newhashlink;
    }



      // For the current owner to rescind the sale..

    function withdrawsale() public onlyOwner onlyforsalestatus {
        assetforsale = false;
        }

     // only the Owner can repeatedly call and change the ask price

      function setnew_ask_price(uint _askprice) public onlyOwner onlyforsalestatus {
          askvalueHBARS = _askprice * 10**18;
        }


      function buy_asset() public payable onlyforsalestatus notowner{

        valueethbid = msg.value;

        require(msg.value !=0,"HBAR bid cannot be zero");


        //  Winning bid at or over ask

        if ( msg.value >= askvalueETH) {


        // set flags status for asset sold and payouts readies to seller
        // and successful buyer is now the asset owner.

                   assetforsale = false;
                   soldfromaddress = owner;
                   sellerwithdrawnfunds = false;
                   owner = msg.sender;
                   assetvalueETH = address(this).balance;

                   // sets new montly payment to new owner  msg.balance/term
                   // Buyer can withdraw EVEN if seller fails to withdraw the bid value

                   monthlypayoutamount = msg.value.div(payout_term_months);
                    // resets payment term to smaller amount over reset of payout_term in months



                   commissiontaken = false;
                   commission_withdraw();  // commission due

                   emit assetbidsuccessful(msg.sender);
                   emit Buyersbid_availableforwithdrawl(soldfromaddress, msg.value);

        }

            // else send the bid back to bidder

            else {

            //   return the buyers Hbars

                msg.sender.transfer(msg.value);
                emit assetbidreturned(msg.sender, msg.value);

            }



      }



        function sellerwithdrawfunds() public onlysuccessfulseller {

         // only prevowner can withdraw even as newowner is successful bidder

         // check flags and set new owner (successful bidder) and send ETH to seller


                beneficiaryowner.transfer(highestBid);
                highestBid = 0;
                highestBidder = address(0);
                soldfromaddress = address(0);
                beneficiaryowner = address(0);
                askvalueETH = 0;
                assetvalueETH = address(this).balance;

                sellerwithdrawnfunds = true;
                emit Sellerwithrawnfunds_ok(beneficiaryowner, highestBid);



        }

     function commission_withdraw() private commissionisdue commissionnotaken {

         //  send commission rate % of askvalueETH and send to platformaddress

        commissiontaken = true ;
        commission_sum = askvalueETH.mul(commissionrate);
        commission_sum = commission_sum.div(100);
        askvalueETH = askvalueETH.sub(commission_sum);

        platformaddress.transfer(commission_sum);

         }



}
