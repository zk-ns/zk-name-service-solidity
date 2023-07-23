// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

interface NGT {
    function poolMint(address to, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract Stake is Ownable {
    // pledge 
    //7 days 3%; 14 days 5%; 30 days 10%
    uint256 constant FIRSTDIFF = 7 * 24 * 3600;
    uint256 constant SECONDDIFF = 14 * 24 * 3600;
    uint256 constant THIRDDIFF = 30 * 24 * 3600;

    struct order{
        uint256 seedMoney;
        uint16 kinds;
        uint240 startTime;
    }

    NGT public NGTToken;

    mapping (address => order[]) private orders;

    function setNGTToken(address _token) public onlyOwner{
        NGTToken = NGT(_token);
    }

    function makeOrder(uint256 seedmoney, uint16 kinds) public{
        require(kinds == 1 || kinds == 2 || kinds == 3, "kinds not accept");
        NGTToken.transferFrom(msg.sender, address(this), seedmoney);
        order memory _order;
        _order = order(seedmoney, kinds, uint240(block.timestamp));
        orders[msg.sender].push(_order);
        
    }

    function claimOrder(uint256 index) public{
        uint256 len = orders[msg.sender].length;
        require(index < len, "index exceed");
        if(orders[msg.sender][index].kinds == 1){
            if((block.timestamp - orders[msg.sender][index].startTime) >= FIRSTDIFF){
                NGTToken.transfer(msg.sender, orders[msg.sender][index].seedMoney);
                NGTToken.poolMint(msg.sender, orders[msg.sender][index].seedMoney * 3 / 100);
            }else{
                NGTToken.transfer(msg.sender, orders[msg.sender][index].seedMoney * 97 / 100);
            }
        }else if(orders[msg.sender][index].kinds == 2){
            if((block.timestamp - orders[msg.sender][index].startTime) >= SECONDDIFF){
                NGTToken.transfer(msg.sender, orders[msg.sender][index].seedMoney);
                NGTToken.poolMint(msg.sender, orders[msg.sender][index].seedMoney * 5 / 100);
            }else{
                NGTToken.transfer(msg.sender, orders[msg.sender][index].seedMoney * 95 / 100);
            }
        }else if(orders[msg.sender][index].kinds == 3){
            if((block.timestamp - orders[msg.sender][index].startTime) >= THIRDDIFF){
                NGTToken.transfer(msg.sender, orders[msg.sender][index].seedMoney);
                NGTToken.poolMint(msg.sender, orders[msg.sender][index].seedMoney * 10 / 100);
            }else{
                NGTToken.transfer(msg.sender, orders[msg.sender][index].seedMoney * 90 / 100);
            }
        }
        orders[msg.sender][index].kinds = 0;
        orders[msg.sender][index].seedMoney = 0;
        orders[msg.sender][index].startTime = 0;
    }
    
    function getOrderInfo(address addrs) public view returns(order[] memory){
        return orders[addrs];

    }

}
