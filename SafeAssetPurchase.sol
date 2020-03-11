pragma solidity >=0.4.22 <0.6.0;

contract SafeAssetPurchase {

   //  Version 0.1.1 - 03/10/2020 flattened.


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

    uint public assetvalue_in_HBAR_heldin_contract;
    uint public newaskprice;
    uint public askvalueHBAR;
    bool public sellerwithdrawnfunds;
    bool public commissiontaken;
    uint public commission_sum;

    // Commission rate % upon successful sale will be paid to Platform Wallet


    uint public commissionrate;
    address payable public platformaddress;

    // Example IPFS hash - assume a link to a binding legal document for this Annunity  QmTfCejgo2wTwqnDJs8Lu1pCNeCrCDuE4GAwkna93zdd7d
    // IPFS hash is 34 bytes  - store as string for this sample.- refine for ultr low gas costs - phase II.

    // to ..put and get a file from IPFS - & daemon must be installed.
    // ipfs cat Qmd4PvCKbFbbB8krxajCSeHdLXQamdt7yFxFxzTbedwiYM
    // curl https://ipfs.io/ipfs/Qmd4PvCKbFbbB8krxajCSeHdLXQamdt7yFxFxzTbedwiYM


    constructor(string memory _assetname, address payable _beneficiary_owner_ofasset_sale,  string memory _hashlink_to_IPFS_legaldocs,  uint _inital_HBAR_askvalue,  uint _platform_commission_rate_percent, address payable _tanzletrade_commission_wallet_address) public {
        assetforsale = true;
        assetjustcreated = true;
        commissiontaken =  false;
        commissionrate = _platform_commission_rate_percent;
        ipfshashlink_legaldocs = _hashlink_to_IPFS_legaldocs;
        assetname = _assetname;
        assetcontractaddress = address(this);
        askvalueHBAR = _inital_HBAR_askvalue*10**18 ;
        beneficiaryowner = _beneficiary_owner_ofasset_sale;
        owner = msg.sender;
        platformaddress = _tanzletrade_commission_wallet_address;
        sellerwithdrawnfunds = true;
        emit assetcreated(assetcontractaddress);

    }

    // Constructor method deploys the instance - Asset ready for sale - set to true.

       event assetcreated(address contractaddress);
       event asset_buy_HBARS_returned(address bidder, uint bidvalue);
       event asset_purchase_successful(address bidder);
       event assetbidhighest(address highestbidder, uint bidvalue);
       event Sellerwithrawnfunds_ok(address benowner, uint highbid);
       event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
       event commission_paid(address platformaddress);

       modifier onlysuccessfulseller(){
              require(isseller(), "Caller is not the successfull seller");
              _;
        }

        modifier onlyforsalestatus() {
            require(isforsale()," Asset must be marked for sale by owner");
            _;
        }

          modifier currforsalestatus() {
            require((assetforsale == false), "Asset status is marked for Sale by Owner");
            _;
        }

         modifier currnotforsalestatus() {
            require(isnotforsale(),"Asset must NOT be for current sale for Owner to sell it");
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


        function renounceOwnership() public onlyOwner {
            emit OwnershipTransferred(owner, address(0));
            owner = address(0);
        }

        function _transferOwnership(address _newOwner) internal {
            require(_newOwner != address(0), "Ownable: new owner is the zero address");

            emit OwnershipTransferred(owner, _newOwner);
            owner = _newOwner;

        }

    // Only the owner can update the legally bound document copies on IPFS/Hedera FileService to this Annunity contract
    // and thus publicly linkable and display by any interested purchasing Entity

    function update_docs_link(string memory _newhashlink) public onlyOwner currnotforsalestatus {
        bytes memory tempEmptyStringTest = bytes(_newhashlink);
        require(tempEmptyStringTest.length >0 , "Hash Link cannot be empty");
        ipfshashlink_legaldocs = _newhashlink;
    }


    function withdrawsale() public onlyOwner onlyforsalestatus {
        assetforsale = false;
        }

     // only the Seller (contract opwner ie Asset owner) can call and change the selling price

      function setnew_ask_price(uint _askprice) public onlyOwner onlyforsalestatus {
          askvalueHBAR = _askprice * 10**18;
        }


      function buy_asset() public payable onlyforsalestatus notowner{


        require(msg.value !=0,"HBAR sent in cannot be zero");


        //  Successful purchase

        if ( msg.value >= askvalueHBAR) {


        // set flags status for asset sold and payouts readies to seller
        // and successful buyer is now the asset owner.

                   assetforsale = false;
                   soldfromaddress = owner;
                   sellerwithdrawnfunds = false;
                   owner = msg.sender;
                   assetvalue_in_HBAR_heldin_contract = address(this).balance;
                   commission_withdraw();  // commission due

                   emit asset_purchase_successful(msg.sender);


        }

            // else send the buyers HBAR back

            else {

                msg.sender.transfer(msg.value);
                emit asset_buy_HBARS_returned(msg.sender, msg.value);

            }



      }



        function sellerwithdrawfunds() public onlysuccessfulseller {

        // only prevowner can withdraw HBAR sale funds.. less than the commission -taken first

        // the remaining balance of the contract is sent to the seller (ie value less commission already taken at sale)

                beneficiaryowner.transfer(address(this).balance);
                soldfromaddress = address(0);
                beneficiaryowner = address(0);
                askvalueHBAR = 0;
                assetvalue_in_HBAR_heldin_contract = address(this).balance;

                sellerwithdrawnfunds = true;
                emit Sellerwithrawnfunds_ok(beneficiaryowner, address(this).balance);



        }

     function commission_withdraw() private {

         //  send commission rate % from balance held to the platforms address /wallet.

        commissiontaken = true ;
        commission_sum = askvalueHBAR * commissionrate;
        commission_sum = commission_sum / 100;
        askvalueHBAR = askvalueHBAR - commission_sum;

        platformaddress.transfer(commission_sum);

        emit commission_paid(platformaddress);
         }



}
