//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.7;

contract Hostel {

    address payable tenant;
    address payable landlord;

    uint public no_of_rooms = 0;
    uint public no_of_agreements = 0;
    uint public no_of_rent = 0;

    struct Room{
        uint roomid;
        uint agreementid;
        string roomname;
        string roomaddress;
        uint rent_per_month;
        uint securityDeposit;
        uint timestamp;
        bool vacant;
        address payable landlord;
        address payable currentTenant; 
    }

    mapping(uint => Room) public Room_by_No; //questo mapping non specifica quale int immettere, in teoria potrebbe essere qualsiasi, provo a vedere

     struct RoomAgreement{
        uint roomid;
        uint agreementid;
        string Roomname; //come mai questa volta il nome e' con la maiuscola?
        string RoomAddresss; //come mai questa volta il nome e' con la maiuscola?
        uint rent_per_month;
        uint securityDeposit;
        uint lockInPeriod;
        uint timestamp;
        address payable tenantAddress;
        address payable landlordAddress;
    }

    mapping(uint => RoomAgreement) public RoomAgreement_by_No;

    struct Rent{
        uint rentno;
        uint roomid;
        uint agreementid;
        string Roomname;
        string RoomAddresss;
        uint rent_per_month;
        uint timestamp;
        address payable tenantAddress;
        address payable landlordAddress;
    }

    mapping(uint => Rent) public Rent_by_No;

    //here below we create some modifiers that will help you verify a few things before running the functions.
    modifier onlyLandlord(uint _index){
        require(msg.sender == Room_by_No[_index].landlord, "Only landlord can access this");
        _;
    }

    modifier notLandLord(uint _index) {
        require(msg.sender != Room_by_No[_index].landlord, "Only Tenant can access this");
        _;
    }

    modifier OnlyWhileVacant(uint _index){
        require(Room_by_No[_index].vacant == true, "Room is currently Occupied.");
        _;
    }

    modifier enoughRent(uint _index) {
        require(msg.value >= uint(Room_by_No[_index].rent_per_month), "Not enough Ether in your wallet");
        _;
    }

    modifier enoughAgreementfee(uint _index) {
        require(msg.value >= uint(uint(Room_by_No[_index].rent_per_month) + uint(Room_by_No[_index].securityDeposit)), "Not enough Ether in your wallet");
        _;
    }

    modifier sameTenant(uint _index) {
        require(msg.sender == Room_by_No[_index].currentTenant, "No previous agreement found with you & landlord");
        _;
    }

    modifier AgreementTimesLeft(uint _index) {
        uint _AgreementNo = Room_by_No[_index].agreementid;
        uint time = RoomAgreement_by_No[_AgreementNo].timestamp + RoomAgreement_by_No[_AgreementNo].lockInPeriod;
        require(block.timestamp < time, "Agreement already Ended");
        _;
    }

    modifier AgreementTimesUp(uint _index) {
        uint _AgreementNo = Room_by_No[_index].agreementid;
        uint time = RoomAgreement_by_No[_AgreementNo].timestamp + RoomAgreement_by_No[_AgreementNo].lockInPeriod;
        require(block.timestamp > time, "Time is left for contract to end");
        _;
    }

    modifier RentTimesUp(uint _index) {
        uint time = Room_by_No[_index].timestamp + 30 days;
        require(block.timestamp >= time, "Time left to pay Rent");
        _;
    }

    //here below we create some functions.

    function addRoom(string memory _roomname, string memory _roomaddress, uint _rentcost, uint _securitydeposit) public {
        require(msg.sender != address(0));
        no_of_rooms ++;
        bool _vacancy = true;
        Room_by_No[no_of_rooms] = Room(no_of_rooms,0,_roomname,_roomaddress, _rentcost,_securitydeposit,0,_vacancy, payable(msg.sender), payable(address(0))); 
        //praticalmente il no_of_rooms e' semplicemente un room_id incrementale
        //attenzione che devo typecast the address to address payable (for both msg.sender and address(0), because the function accepts address payable as the argument. However, msg.sender and address(0) are not payable by default (since Solidity 0.8.0). 
    }

    function signAgreement(uint _index) public payable notLandLord(_index) enoughAgreementfee(_index) OnlyWhileVacant(_index) {
        require(msg.sender != address(0));
        address payable _landlord = Room_by_No[_index].landlord;
        uint totalfee = Room_by_No[_index].rent_per_month + Room_by_No[_index].securityDeposit;
        _landlord.transfer(totalfee);
        no_of_agreements++;
        Room_by_No[_index].currentTenant = payable(msg.sender);
        Room_by_No[_index].vacant = false;
        Room_by_No[_index].timestamp = block.timestamp;
        Room_by_No[_index].agreementid = no_of_agreements;
        RoomAgreement_by_No[no_of_agreements]=RoomAgreement(_index,no_of_agreements,Room_by_No[_index].roomname,Room_by_No[_index].roomaddress,Room_by_No[_index].rent_per_month,Room_by_No[_index].securityDeposit,365 days,block.timestamp,payable(msg.sender),_landlord);
        no_of_rent++;
        Rent_by_No[no_of_rent] = Rent(no_of_rent,_index,no_of_agreements,Room_by_No[_index].roomname,Room_by_No[_index].roomaddress,Room_by_No[_index].rent_per_month,block.timestamp,payable(msg.sender),_landlord);
    }

    function payRent(uint _index) public payable sameTenant(_index) RentTimesUp(_index) enoughRent(_index){
        require(msg.sender != address(0));
        address payable _landlord = Room_by_No[_index].landlord;
        uint _rent = Room_by_No[_index].rent_per_month;
        _landlord.transfer(_rent);
        Room_by_No[_index].currentTenant = payable(msg.sender);
        Room_by_No[_index].vacant = false;
        no_of_rent++;
        Rent_by_No[no_of_rent] = Rent(no_of_rent,_index,Room_by_No[_index].agreementid,Room_by_No[_index].roomname,Room_by_No[_index].roomaddress,_rent,block.timestamp,payable(msg.sender),Room_by_No[_index].landlord);
    }

    function agreementCompleted(uint _index) public payable onlyLandlord(_index) AgreementTimesUp(_index){
    require(msg.sender != address(0));
    require(Room_by_No[_index].vacant == false, "Room is currently Occupied.");
    Room_by_No[_index].vacant = true;
    address payable _Tenant = Room_by_No[_index].currentTenant;
    uint _securitydeposit = Room_by_No[_index].securityDeposit;
    _Tenant.transfer(_securitydeposit);
}

    function agreementTerminated(uint _index) public onlyLandlord(_index) AgreementTimesLeft(_index){
        require(msg.sender != address(0));
        Room_by_No[_index].vacant = true;
    }





}