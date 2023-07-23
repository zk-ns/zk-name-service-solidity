// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
interface NGT {
    function mint(address to, uint256 amount) external;
}

contract ZKns is Ownable {
    struct entry{
        address resolving;
        uint32 year;
        uint256 registerDate;
    }

    mapping (bytes32 => entry) private entries;
    mapping (address => string) private reZKns;

    mapping (address => address) public myRecommend; // who invite me
    mapping (address => address) public myCommunity; // who is my Community Leader
    // mapping (address => address[]) private myInvites; // I invite some address
    // mapping (address => address[]) private communityInvites; // Community invite some address
    mapping (address => bool) private recommendEffect;
    mapping (address => uint256) private myReward;

    // bytes32 constant private BNULL = 0x0000000000000000000000000000000000000000000000000000000000000000;

    uint256 public constant YEARS = 365 * 24 * 3600;
    uint256 public basePrice = 10 * (10 ** 14);
    uint256 public renewPrice = 10 * (10 ** 14);
    uint256 public communityLeaderPrice = 1 * (10 ** 16);
    uint256 public profitPercent = 10;
    uint256 public baseToken = 1000 * (10 ** 18);
    uint256 private total_ns;
    bool public allowRenew = false;
    bool public allowTransfer = false;

    ERC20 public Token;
    NGT public NGTToken;

    bool internal locked;

    modifier noReentrant() {
        require(!locked, "No re-entrancy");
        locked = true;
        _;
        locked = false;
    }

    event registerInfo(address indexed from, string str, uint32 year, uint256 registerDate);
    event renewInfo(address indexed from, string str, uint32 year, uint256 renewDate);
    event inviteInfo(address indexed original_address, address indexed invite_address, uint256 time);
    event communityInfo(address indexed community_address, address indexed member_address, uint256 time);
    event inviteEarnInfo(address indexed from, address indexed earnAddress, uint32 kind, uint256 amount, uint256 time);
    event nodeEarnInfo(address indexed from, address indexed earnAddress, uint32 kind, uint256 amount, uint256 time);

    constructor(){
        recommendEffect[msg.sender] = true;
        myCommunity[msg.sender] = msg.sender;
        total_ns = 0;
    }

    function register(string memory str, uint32 year) public payable noReentrant{
        require(year >= 1 && year <=5, 'year not allow');
        bytes memory _bstr = bytes(str);
        require(_bstr.length >=2, 'str length not allow');
        uint256 _price = basePrice;
        if(_bstr.length == 2){
            _price = basePrice * 5;
        }else if(_bstr.length == 3){
            _price = basePrice * 4;
        }else if(_bstr.length == 4){
            _price = basePrice * 3;
        }else if(_bstr.length == 5){
            _price = basePrice * 2;
        }
        require(msg.value >= _price * year, "not enough pay");
        
        if(msg.value > _price * year){
            // payable (msg.sender).transfer(msg.value - _price * year);
            (bool success,) = (msg.sender).call{value: (msg.value - _price * year)}("");
            if(!success){
                revert('call failed');
            }
        }
        string memory suffix =strAppend(str, '.pzk');
        bytes32 bytestr = keccak256(abi.encodePacked(suffix));
        require(entries[bytestr].resolving == address(0), "already register");
        require(bytes(reZKns[msg.sender]).length == 0, "address already register");
        entry memory _entry;
        _entry = entry(msg.sender, year, block.timestamp);
        entries[bytestr] = _entry;
        reZKns[msg.sender] = suffix;
        myReward[msg.sender] += (_price / basePrice) * year * baseToken;
        total_ns += 1;
        emit registerInfo(msg.sender, suffix, year, block.timestamp);
    }

    receive() external payable {}
    fallback() external payable {}

    function tranferZKns(string memory str, address recev) public{
        require(allowTransfer, 'transfer not allow');
        bytes32 bytestr = keccak256(abi.encodePacked(str));
        require(entries[bytestr].resolving == msg.sender, "not owner");
        if(keccak256(abi.encodePacked(reZKns[msg.sender])) == keccak256(abi.encodePacked(str))){
            reZKns[msg.sender] = '';
        }
        entries[bytestr].resolving = recev;
    }

    function resolving(string memory str) public{
        require(allowTransfer, 'transfer & resolving not allow');
        bytes32 bytestr = keccak256(abi.encodePacked(str));
        require(entries[bytestr].resolving == msg.sender, "not owner");
        reZKns[msg.sender] = str;
    }

    function renewZKns(string memory str, uint32 year) public payable noReentrant{
        require(allowRenew, 'renew not allow');
        require(year >= 1 && year <=5, 'year not allow');
        bytes memory _bstr = bytes(str);
        require(_bstr.length >=2, 'str length not allow');
        uint256 _price = renewPrice;
        if(_bstr.length == 2){
            _price = basePrice * 5;
        }else if(_bstr.length == 3){
            _price = basePrice * 4;
        }else if(_bstr.length == 4){
            _price = basePrice * 3;
        }else if(_bstr.length == 5){
            _price = basePrice * 2;
        }
        require(msg.value >= _price * year, "not enough pay");
        
        if(msg.value > _price * year){
            // payable (msg.sender).transfer(msg.value - _price * year);
            (bool success,) = (msg.sender).call{value: (msg.value - _price * year)}("");
            if(!success){
                revert('call failed');
            }
        }
        string memory suffix =strAppend(str, '.pzk');
        bytes32 bytestr = keccak256(abi.encodePacked(suffix));
        require(entries[bytestr].resolving == msg.sender, "not belong");
        uint256 expire_time = entries[bytestr].year * YEARS + entries[bytestr].registerDate;
        uint256 mid_time = entries[bytestr].year * YEARS/2 + entries[bytestr].registerDate;
        require(expire_time > block.timestamp && mid_time < block.timestamp, "time not allow");
        entries[bytestr].year += year;
        emit renewInfo(msg.sender, suffix, year, block.timestamp);
    }

    function cancelbyAdmin(string memory str) public onlyOwner{
        bytes32 bytestr = keccak256(abi.encodePacked(str));
        require((block.timestamp - entries[bytestr].registerDate) > (entries[bytestr].year * YEARS), "time not allow");
        address _addrs = entries[bytestr].resolving;
        entries[bytestr].resolving = address(0);
        entries[bytestr].year = 0;
        entries[bytestr].registerDate = 0; 
        if(keccak256(abi.encodePacked(reZKns[_addrs])) == keccak256(abi.encodePacked(str))){
            reZKns[_addrs] = '';
        }
        if(total_ns >= 1){
           total_ns -= 1;
        }
    }

    function setToken(address _token) public onlyOwner{
        Token = ERC20(_token);
    }
    function setNGTToken(address _token) public onlyOwner{
        NGTToken = NGT(_token);
    }
    function setbasePrice(uint256 price) public onlyOwner{
        basePrice = price;
    }
    function setrenewPrice(uint256 price) public onlyOwner{
        renewPrice = price;
    }
    function setallowRenew(bool _allow) public onlyOwner{
        allowRenew = _allow;
    }
    function setallowTransfer(bool _allow) public onlyOwner{
        allowTransfer = _allow;
    }
    function setcommunityLeaderPrice(uint256 price) public onlyOwner{
        communityLeaderPrice = price;
    }
    function setprofitPercent(uint256 percent) public onlyOwner{
        profitPercent = percent;
    }
    function setbaseToken(uint256 amount) public onlyOwner{
        baseToken = amount;
    }

    function claim() public onlyOwner{
        uint256 balance = address(this).balance;
        payable (msg.sender).transfer(balance);
    }
    function claimToken() public onlyOwner{
        uint256 balance = Token.balanceOf(address(this));
        Token.transfer(msg.sender,balance);
    }
    function userclaimToken(address recommend) public{
        require(myReward[msg.sender] > 0, "not enough");
        if(myRecommend[msg.sender] == address(0)){
            require(recommendEffect[recommend], "recommend not allow");
            myRecommend[msg.sender] = recommend;
            // myInvites[recommend].push(msg.sender);
            emit inviteInfo(recommend, msg.sender, block.timestamp);
        }
        if(myCommunity[msg.sender] == address(0)){
            if(myCommunity[recommend] == address(0)){
                myCommunity[msg.sender] = address(this);
                // communityInvites[address(this)].push(msg.sender);
            }else{
                myCommunity[msg.sender] = myCommunity[recommend];
                // communityInvites[myCommunity[recommend]].push(msg.sender);
                emit communityInfo(myCommunity[recommend], msg.sender, block.timestamp);
            }   
        }
        if(!recommendEffect[msg.sender]){
            recommendEffect[msg.sender] = true;
        }
        uint256 balance = myReward[msg.sender];
        myReward[msg.sender] = 0;
        NGTToken.mint(msg.sender, balance * (100 - 2 * profitPercent) /100);
        NGTToken.mint(myRecommend[msg.sender], (balance * profitPercent) /100);
        NGTToken.mint(myCommunity[msg.sender], (balance * profitPercent) /100);

        emit inviteEarnInfo(msg.sender, myRecommend[msg.sender], 1, (balance * profitPercent) /100, block.timestamp);
        emit nodeEarnInfo(msg.sender, myCommunity[msg.sender], 1, (balance * profitPercent) /100, block.timestamp);
    }

    function becomeCommunityLeader() public payable noReentrant{
        require(recommendEffect[msg.sender], "not effect address");
        require(myCommunity[msg.sender] != address(0) && myRecommend[msg.sender] != address(0), "claim token first");
        require(myCommunity[msg.sender] != msg.sender, "already node");
        require(msg.value >= communityLeaderPrice, "not enough pay");
        if(msg.value > communityLeaderPrice){
            // payable (msg.sender).transfer(msg.value - communityLeaderPrice);
            (bool success,) = (msg.sender).call{value: (msg.value - communityLeaderPrice)}("");
            if(!success){
                revert('call failed');
            }
        }
        // payable (myRecommend[msg.sender]).transfer(communityLeaderPrice * profitPercent / 100);
        // payable (myCommunity[msg.sender]).transfer(communityLeaderPrice * profitPercent / 100);
        (bool success1,) = (myRecommend[msg.sender]).call{value: (communityLeaderPrice * profitPercent / 100)}("");
        if(!success1){
            revert('call failed');
        }
        (bool success2,) = (myCommunity[msg.sender]).call{value: (communityLeaderPrice * profitPercent / 100)}("");
        if(!success2){
            revert('call failed');
        }

        emit inviteEarnInfo(msg.sender, myRecommend[msg.sender], 2, (communityLeaderPrice * profitPercent) /100, block.timestamp);
        emit nodeEarnInfo(msg.sender, myCommunity[msg.sender], 2, (communityLeaderPrice * profitPercent) /100, block.timestamp);

        myCommunity[msg.sender] = msg.sender;

    }

    function strAppend(string memory _a, string memory _b) internal pure returns (string memory){
        bytes memory _ba = bytes(_a);
        bytes memory _bb = bytes(_b);
        string memory ret = new string(_ba.length + _bb.length);
        bytes memory bret = bytes(ret);
        uint k = 0;
        for (uint256 i = 0; i < _ba.length; i++) bret[k++] = _ba[i];
        for (uint256 i = 0; i < _bb.length; i++) bret[k++] = _bb[i];
        return string(ret);
    }

    function getEntries(string memory str) public view returns(entry memory){
        bytes32 bytestr = keccak256(abi.encodePacked(str));
        return entries[bytestr];
    }
    function getZKns(address addrs) public view returns(string memory){
        return reZKns[addrs];
    }
    function getmyReward(address addrs) public view returns(uint256){
        return myReward[addrs];
    }
    function get_total_ns() public view returns(uint256){
        return total_ns;
    }
    function checkrecommendEffect(address addrs) public view returns(bool){
        return recommendEffect[addrs];
    }
    function checkCommunity(address addrs) public view returns(bool){
        return (myCommunity[addrs] == addrs);
    }
    function getStrByteLength(string memory str) public pure returns(uint256){
        bytes memory _bstr = bytes(str);
        return _bstr.length;
    }

}
