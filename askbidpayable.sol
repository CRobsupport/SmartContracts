pragma solidity >=0.4.22 <0.6.0;

contract askbidpayable { using SafeMath for uint256 ;

   //  Version 0.4.1- 03/02/2020 flattened.

    /*
    Ethereum in mem/ganache dev/testing and ETH
    Then for Hedera with HBAR then for deploy to testnet.

    ETH and denominations are treated as HBAR in Hedera's EVM version scVM
    global variables in solidity ie block.timestamp is the Hedera consensus timestamp
    when executed via the scVM.

    Parameters of the simple valid annuity trade contract. Times are either
    absolute unix timestamps (seconds since 1970-01-01)
    or time periods in seconds.

    C.Robinson - Trade ask/bid example contractr deploy to hedera hashgraph testnet

    More of an Annuity than a annuity.. but.. an example of a immutable loaded instrument

    ** No suicide of contract by owner - the annuity once created and even sold and empty- matured.. will remain for Audit purposes, immutable.
    Done on Hedera with a autornew period and paying balance sufficient for legal statute for such a contract

    owner is initial deployer for this example and is 'asker' ie seller

    contract is locked open upon delploy and subsequent loading with ETH above ask value,
    for release for sale into the market, open to bids

    Bidder is wallet/account dApp address of bidding entity.. who, what, when ..

    A fixed annuity with monthly payouts for the monthly term. The payouts are drawn from the locked ETH balance
    in the contract ETH amount, timestamp nd sale - held for public record and proof of bid and sale
    transaction as public state held on ledger.

    This example demonstrates Bids with HARD value ie REAL currency of $ worth
    ie Bidders bid with hard transactions of crypto

    upon unsuccessful bid to ask, the bid is returned to the bidder account.

    Only the owner ie seller, can adjust their 'ASK' value at any time.

    upon successful bid the annuity is then locked as sold and the bidder is then
    the legal owner and the new owner account receives their first payment and
    the seller receives the full cash-balance payout of the bid.

    **  note for security the payout to seller has to be withdrawn specifically from the annuity at their behest
    **  note for security the monthly payouts have to be withdraw by the new owner on or after each payout period passing.

    Events are triggered and the DApp front end will be able to send msg/ indicate that payouts are ready for withdrawal.

    The difference held in the balance Net value - bidder price, in the contract is the premium that the
    new owner receives on its regular new monthly payouts.

    ** Of course no sane bidder will bid on a annuity at or above its net present value - so the Ask price set by seller
    will have to be substantially lower than the present value held, in order to attract bidders

    Any bidder ie account, calling the contract can send in any ETH bid value at any time as long as annuity is not sold state status
    If less than the ask then bid is returned, but others can publicly see the last higest value bid by any other account.


     Only Owner can recind the sale (by LOCKING it for sale.. but not locking the annuity for payout, obviously)

     Status state locking is the most powerful switch of contracts.
     ie this is a State machine with status of the annuity.. boolean locking.

     The New owner can then sell on the contract on existing logic terms by releasing the lock
     via markforsale method.

     There is no time limit .. once it is deployed it is OPEN until FILLED (sold) or
     removed from sale by owner.

      */
    // state locks

    bool public annuityforsale;
    bool public annuityjustcreated;

    // use to payout to the owner the full value of the bid upon sale.
    // necessary due to beneficiary being the old owner after sale tran

    address payable public beneficiaryowner;

    // Who owns legally, the annuity at any time.

    address public owner;
    // record of seller after sale.- for audit
    address public soldfromaddress;

    // publicly exposed data of annuity value, asking value, date of new monthly payment, monthly payout amount
    // value of the last bid

    string public annuityname;
    address public annuitycontractaddress;
    bytes32 public ipfshashlink_legaldocs;
    address private platformaddress;
    uint public annuityvalueETH;
    uint public onthdate_ofnewpaymentschedule;
    uint public monthlypayoutamount;
    uint public payout_term;
    uint public payout_monthsleft;
    uint public newaskprice;
    uint public askvalueETH;
    bool public annuitymatured;
    bool public sellerwithdrawnfunds;
    bool public commissiontaken;
    uint public commissionrate;

    // Current state of the trading state -public so all can see - market tranparancey

    uint public valueethbid;
    address payable public highestBidder;
    uint public highestBid;


    // Payable fallback function is not enabled - this contract cannot accept ETH without a call specifically
    // to the initial load the annuity action and the bid function.
    // For this example annuity creator is the owner - not true in reality - why would you create a note for sale at discount
    // with fund you presently own..  but assume for this example.

    // The creator/owner  must mark for sale ie call that function after creation to be open to bids
    // The annuity must then be loaded with hard value ETH above ask value
    // The markforsale function call then sets status

    constructor(string memory _annuityname, bytes32 _hashlink_to_IPFS_legeldocs, address payable _beneficiaryowner, uint _initalETHaskvalue, uint _payoutyearterm, uint _platform_commission_rate) public {
        annuityforsale = false;
        annuityjustcreated = true;
        commissiontaken =  true;
        commissionrate = _platform_commission_rate;
        ipfshashlink_legaldocs = _hashlink_to_IPFS_legeldocs;
        annuityname = _annuityname;
        annuitycontractaddress = address(this);
        askvalueETH = _initalETHaskvalue*10**18 ;
        beneficiaryowner = _beneficiaryowner;
        owner = msg.sender;
        platformaddress = msg.sender;
        payout_term = _payoutyearterm;
        payout_monthsleft = payout_term.mul(12);
        annuitymatured = false;
        sellerwithdrawnfunds = true;
        emit annuitycreated(annuitycontractaddress);

    }

         // Events and modifiers only here..

       event annuitycreated(address contractaddress);
       event annuitybidreturned(address bidder, uint bidvalue);
       event annuitybidsuccessful(address bidder);
       event annuitybidhighest(address highestbidder, uint bidvalue);
       event Buyersbid_availableforwithdrawl(address highestbidder, uint value);
       event Buyers_monthly_payment_paidout(address buyer, uint mnthamount);
       event Sellerwithrawnfunds_ok(address benowner, uint highbid);
       event annuity_matured(address contractaddress, uint payoutleft);
       event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

       // to make these mods consistent

        modifier commissionisdue() {
            require (commissiondue(), "Cannot send commssion to platform if no sale event");
            _;
        }

        modifier commissionnotaken() {
            require ((commissiontaken == false), "Cannot send commission more than once for a sale!");
            _;
        }

        modifier isnotmatured() {
            require((annuitymatured == false), "annuity is already matured and is empty");
            _;
        }

        modifier sellerhaswithdrawnfunds(){
            require((sellerwithdrawnfunds == true), "New owner cannot mark annuity for sale until prior seller withdraw funds");
            _;
        }


        modifier onlysuccessfulseller(){
              require(isseller(), "Caller is not the successfull seller");
              _;
        }

        modifier onlyforsalestatus() {
            require(isforsale()," annuity must be marked for sale by owner");
            _;
        }

          modifier currforsalestatus() {
            require((annuityforsale == false), "annuity status is already marked for Sale by Owner");
            _;
        }

         modifier currnotforsalestatus() {
            require(isnotforsale(),"annuity must NOT be for currently sale for Owner to sell it");
               _;
            }

        modifier onlyOwner() {
            require(isOwner(), "Ownable: caller is not the owner");
            _;
        }

        modifier notowner() {
            require(isnotOwner(),"Ownable: Caller is the owner & cannot bid on own annuity");
            _;
        }

       // depends on time format and how scVM sees the keyword 'now' .. TBD

        modifier onlypermonth() {
             require(now > (onthdate_ofnewpaymentschedule+30 days), "Can only withdraw every month from purchase date");
                  _;
        }

        function isforsale() public view returns (bool) {
            return annuityforsale == true;
        }

        function isnotforsale() public view returns (bool) {
            return annuityforsale == false;
        }

         function isseller() public view returns (bool) {
            return msg.sender == soldfromaddress;
        }


        function isnotOwner() public view returns (bool) {
            return msg.sender != owner;
        }

        /**  Standard code o/src for contract owner handling/ can import **
         * @dev Returns true if the caller is the current owner.
         */
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
         * @dev Transfers ownership of the contract to a newannuity account (`newOwner`).
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

    function updateIPFS_hashlink(bytes32 _newhashlink) public onlyOwner currnotforsalestatus {
        require(_newhashlink.length > 0 , "Hash Link cannot be empty");
        ipfshashlink_legaldocs = _newhashlink;
    }

    // Set the annuity to initial value by loading with ETH by owner

    function loadtheannuity() public payable onlyOwner {
            require(annuityjustcreated = true, " cannot load a annuity that is not just created");
            require(msg.value >askvalueETH ,"ETH sent to load annuity must be greater than ask initial value");


            annuityjustcreated = false;
            annuityvalueETH = address(this).balance;
            monthlypayoutamount = annuityvalueETH.div(payout_term);
            onthdate_ofnewpaymentschedule = now;

        }

    // Set the annuity for sale status with by owner -  must be loaded with ETH value


        function markforsale() public onlyOwner currnotforsalestatus sellerhaswithdrawnfunds {

            require(annuityvalueETH!=0," annuity must be loaded with ETH first ");

            annuityjustcreated = false;
            annuityforsale = true;
            beneficiaryowner = msg.sender;

        }




    // For the current owner to rescind the sale..

    function withdrawsale() public onlyOwner onlyforsalestatus {
        annuityforsale = false;
    }


    // only the Owner can repeatedly call and change the ask price

      function ask(uint _askprice) public onlyOwner onlyforsalestatus {
          newaskprice = _askprice * 10**18;
            require(newaskprice <= address(this).balance ,"Asking ETH price cannot be more than current value of annuity in ETH");
          askvalueETH = newaskprice;


      }


      function bid() public payable onlyforsalestatus notowner{

        //notowner to add
        /* onlyforsalestatus not owner.. cannot bid on your own annuity!

         No arguments are necessary, all
         information is already part of
         the transaction. The keyword payable
         is required for the function to
         be able to receive Ether but it cannot PAYOUT from this call.
         For security only the parties must be notified then call methods
         to withdraw their funds. ie seller

        */
        valueethbid = msg.value;

       /*
         emit event informing owner that annuity is sold

         emit event informing bidder that annuity is theirs now

         and immediate first month payout for buying annuity
         is available for withdrawl by new owner ie bidder.

          depends on terms.. e.g.  annuity TERMS of PAYOUTS over 3 years

         If the bid is not same or higher than ask send the ETH back
        */

        require(msg.value !=0,"ETH bid cannot be zero");

        // for display information only ie will show publicly the highest bid

        if ( msg.value >= highestBid)  {

             highestBidder = msg.sender;
             highestBid = msg.value;
             emit annuitybidhighest(msg.sender, msg.value);


        }


        //  Winning bid at or over ask

        if ( msg.value >= askvalueETH) {


        // set flags status for annuity sold and payouts readies to seller
        // and successful buyer is now the annuity owner.

                   annuityforsale = false;
                   soldfromaddress = owner;
                   sellerwithdrawnfunds = false;
                   owner = msg.sender;
                   annuityvalueETH = address(this).balance;

                   // sets new montly payment to new owner  msg.balance/term
                   // Buyer can withdraw EVEN if seller fails to withdraw the bid value

                   monthlypayoutamount = msg.value.div(payout_term);
                    // resets payment term to 35 months left

                   ownerwithdrawfirstpayment();

                   commissiontaken = false;
                   platformwithdraw();  // commission


                   emit annuitybidsuccessful(msg.sender);
                   emit Buyersbid_availableforwithdrawl(soldfromaddress, msg.value);

        }

            // else send the bid back to bidder

            else {

                    /* re-entrancy here can be potential, in this simple example - if this example made more complex with account for
                       prior bid that is kept in contract but a higher bid comes in from same bidder and needs mapping struct
                       - Withdrawl function then needed to permit unsuccessful bidder withdrawl before sale completion
                       - for enhancement if needed, for this simple contract.
                    */

                msg.sender.transfer(msg.value);
                emit annuitybidreturned(msg.sender, msg.value);

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
                annuityvalueETH = address(this).balance;

                sellerwithdrawnfunds = true;
                emit Sellerwithrawnfunds_ok(beneficiaryowner, highestBid);



        }

     function platformwithdraw() public commissionisdue commissionnotaken {

         //  send commission rate of askvalueETH and send to platformaddress

         commissiontaken = true ;
     }



     function ownerwithdrawfirstpayment() public onlyOwner currforsalestatus {


                payout_monthsleft = payout_monthsleft.sub(1);

                if (payout_monthsleft == 0) {
                    // last payment
                    annuitymatured = true;
                    annuityforsale = false;
                    emit annuity_matured(annuitycontractaddress, payout_monthsleft);
                }

                msg.sender.transfer(monthlypayoutamount);

                // set today as the monthly day of payout until annuity exhausted.

                onthdate_ofnewpaymentschedule = now;

                emit Buyers_monthly_payment_paidout(msg.sender, monthlypayoutamount);



        }

        function ownerwithdrawmonthlypayment() public onlyOwner onlypermonth currforsalestatus {

                // Cannot withdraw any payments while annuity is for sale

                // pay the monthly payout  ETH held balance deducted of course.

                payout_term = payout_term.sub(1);

                if (payout_term == 0) {
                    // last payment
                    annuitymatured = true;
                    annuityforsale = false;
                    emit annuity_matured(annuitycontractaddress, payout_monthsleft);
                }

                msg.sender.transfer(monthlypayoutamount);

                // set today as the monthly day of payout until annuity exhausted.

                onthdate_ofnewpaymentschedule = now;

                payout_monthsleft = payout_monthsleft.sub(1);

                emit Buyers_monthly_payment_paidout(msg.sender, monthlypayoutamount);



        }

     // additional function can be set with a Oraclize call every ie a oraclized Clock triugger to pay monthly sums to owner





}


library SafeMath {

     // SAFE MATH functions

      /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot overflow.
     *
     * _Available since v2.4.0._
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     *
     * _Available since v2.4.0._
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }

}
