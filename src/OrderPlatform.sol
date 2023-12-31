// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC20} from "@solady/tokens/ERC20.sol";

contract OrderPlatform {
    uint8 constant MAX_COUNT_ORDER = 10;
    uint8 constant CONFIRM_FLAG = 1;
    uint8 constant DECLINE_FLAG = 2;

    bool reentrancyLock = false;

    uint feeOrder = 200;
    uint feeJudge = 100;

    address admin;
    address[] judgeMembers;

    event CreatedOrder(address indexed customer, address indexed executor, string title);
    event DepositedOrder(address indexed customer, address indexed executor, string title);
    event NewJudgeOrder(address indexed customer, address indexed executor, address indexed judge, string title);
    event SubmittedOrder(address indexed customer, address indexed executor, string title);
    event DeclinedOrder(address indexed customer, address indexed executor, string title);
    event ClosedOrder(address indexed customer, address indexed executor, string title);

    mapping(address => Order[MAX_COUNT_ORDER]) OrdersList;
    mapping(address user => mapping(address token => uint balance)) balanceUser;

    mapping(address => uint[2]) healthScoreCustomer; //count confirmed/refunded orders
    mapping(address => uint[2]) healthScoreExecutor; 
    mapping(address => uint[2]) healthScoreJudge; 

    constructor(address _admin) {
        admin = _admin;
    }

    struct OrderParam {
        address customer;
        address token;
        uint amount;
        address executor;
        string title;
    }

    struct Order {
        OrderParam param;
        uint timestamp;
        uint8 confirmCustomer;
        uint8 confirmExecutor;
        address judge;
        uint8 confirmJudge;
        bool isActive;
    }

    error E_Reentrancy();
    error E_Unauthorized();
    error E_NotEnoughBalance();
    error E_NoActiveOrder();
    error E_IndexList();
    

    modifier onlyOwner {
        if(msg.sender != admin) revert E_Unauthorized();
        _;
    }

    modifier nonReentrancy {
        if (reentrancyLock != false) revert E_Reentrancy();

        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    //order's functions
    function previewOrder(OrderParam memory param, uint indexOrder) public view returns(bool){
        if(indexOrder >= MAX_COUNT_ORDER) revert E_IndexList();
        require(param.executor != address(0), "Executor address incorrect!");
        require(param.customer != address(0), "Customer address incorrect!");
        require(param.customer == msg.sender, "Only customer can create order!");
        require(param.amount != 0, "Amount cannot be zero!");
        require(!OrdersList[msg.sender][indexOrder].isActive, "Order cannot be placed in that index");

        return true;
    }
    
    function createOrder(OrderParam memory param, uint indexOrder) external nonReentrancy returns(Order memory) {
        previewOrder(param, indexOrder);

        Order memory newOrder;
        newOrder.param = param;
        newOrder.timestamp = block.timestamp;

        OrdersList[msg.sender][indexOrder] = newOrder;

        emit CreatedOrder(param.customer, param.executor, param.title);

        return OrdersList[msg.sender][indexOrder];
    }

    function depositOrder(uint indexOrder) external nonReentrancy returns(bool status) {
        if(indexOrder >= MAX_COUNT_ORDER) revert E_IndexList();
        Order memory order = OrdersList[msg.sender][indexOrder];

        require(order.param.customer == msg.sender, "Not created order!");
        require(!order.isActive, "Order already is active");

        uint value = previewFullPriceOrder(order.param.amount);

        status = _deposit(order.param.token, order.param.customer, value);
        
        OrdersList[msg.sender][indexOrder].isActive = true;

        emit DepositedOrder(order.param.customer, order.param.executor, order.param.title);
    }

    function confirmOrder(address customer, uint indexOrder) external nonReentrancy returns(Order memory) {
        if(indexOrder >= MAX_COUNT_ORDER) revert E_IndexList();
        Order memory order = OrdersList[customer][indexOrder];
        
        if(!order.isActive) revert E_NoActiveOrder();
        if(!(msg.sender == order.param.executor || msg.sender == order.param.customer || msg.sender == order.judge)) revert E_Unauthorized();

        if(order.param.executor == msg.sender) OrdersList[customer][indexOrder].confirmExecutor = CONFIRM_FLAG;
        if(order.param.customer == msg.sender) OrdersList[customer][indexOrder].confirmCustomer = CONFIRM_FLAG;
        if(order.judge == msg.sender) OrdersList[customer][indexOrder].confirmJudge = CONFIRM_FLAG;

        emit SubmittedOrder(order.param.customer, order.param.executor, order.param.title);

        _acceptOrder(customer, indexOrder);

        return OrdersList[customer][indexOrder];
    }

    function declineOrder(address customer, uint indexOrder) external nonReentrancy returns(Order memory) {
        if(indexOrder >= MAX_COUNT_ORDER) revert E_IndexList();
        Order memory order = OrdersList[customer][indexOrder];

        if(!order.isActive) revert E_NoActiveOrder();
        if(!(msg.sender == order.param.executor || msg.sender == order.param.customer || msg.sender == order.judge)) revert E_Unauthorized();
        
        if(order.param.executor == msg.sender) OrdersList[customer][indexOrder].confirmExecutor = DECLINE_FLAG;
        if(order.param.customer == msg.sender) OrdersList[customer][indexOrder].confirmCustomer = DECLINE_FLAG;
        if(order.judge == msg.sender) OrdersList[customer][indexOrder].confirmJudge = DECLINE_FLAG;

        emit DeclinedOrder(order.param.customer, order.param.executor, order.param.title);

        _acceptOrder(customer, indexOrder);

        return OrdersList[customer][indexOrder];
    }

    
    function withdrawBalance(address token, uint amount) external nonReentrancy returns(bool success){
        return _withdraw(token, msg.sender, amount);
    }

    function approveBalance(address spender, address token, uint amount) external onlyOwner returns(bool success){
        return _approve(spender, token, amount);
    }

    //getters

    function getListOrder(address customer) external view returns(Order[MAX_COUNT_ORDER] memory orders){
        return OrdersList[customer];
    }

    function getOrder(address customer,  uint indexOrder) external view returns(Order memory order){
        if(indexOrder >= MAX_COUNT_ORDER) revert E_IndexList();
        return OrdersList[customer][indexOrder];
    }

    function getListJudges() external view returns(address[] memory){
        return judgeMembers;
    }

    function previewFeeOrder(uint amount, uint fee) public pure returns(uint){
        return (amount * fee) / 10000;
    }

    function previewFullPriceOrder(uint amount) public view returns(uint){
        return amount + ((amount * feeOrder) / 10000);
    }

    function getBalance(address user, address token) external view returns(uint){
        return balanceUser[user][token];
    }

    function getHealhScoreJudge(address user) external view returns(uint[2] memory){
        return healthScoreJudge[user];
    }

    function getHealhScoreCustomer(address user) external view returns(uint[2] memory){
        return healthScoreCustomer[user];
    }

    function getHealhScoreExecutor(address user) external view returns(uint[2] memory){
        return healthScoreExecutor[user];
    }

    function getAdmin() external view returns(address){
        return admin;
    }

    function getFees() external view returns(uint[2] memory){
        return [feeOrder, feeJudge];
    }

    //setters

    function changeAdmin(address newAdmin) external onlyOwner returns(address){
        return admin = newAdmin;
    }

    function changeJudgeOrder(address customer, uint indexOrder) external onlyOwner returns(Order memory){
        Order memory order = OrdersList[customer][indexOrder];
        if(!order.isActive) revert E_NoActiveOrder();
        if(indexOrder >= MAX_COUNT_ORDER) revert E_IndexList();

        return _setNewJudgeOrder(customer, indexOrder);
    }

    function addJudge(address judge) external onlyOwner returns(address[] memory){
        judgeMembers.push(judge);
        return judgeMembers;
    }

    function removeJudge(uint indexJudge) external onlyOwner returns(address[] memory){
        judgeMembers[indexJudge] = judgeMembers[judgeMembers.length - 1];
        judgeMembers.pop();
        return judgeMembers;
    }

    function changeFeeOrder(uint newFee) external onlyOwner returns(uint){
        return feeOrder = newFee;
    }

    function changeFeeJudge(uint newFee) external onlyOwner returns(uint){
        require(newFee < feeOrder, "Judge fee must be less than order fee!");
        return feeJudge = newFee;
    }

    //internal

    function _acceptOrder(address customer, uint indexOrder) internal {
        Order memory order = OrdersList[customer][indexOrder];

        if(order.confirmCustomer == CONFIRM_FLAG && order.confirmExecutor == CONFIRM_FLAG){
            _closeOrder(customer, indexOrder, true);
        }

        if(order.confirmCustomer == DECLINE_FLAG && order.confirmExecutor == DECLINE_FLAG){
            _closeOrder(customer, indexOrder, false);
        }

        if(order.judge == address(0)){
            if(order.confirmCustomer != order.confirmExecutor && order.confirmCustomer != 0 && order.confirmExecutor != 0){
                _setNewJudgeOrder(customer, indexOrder);
            }
        }else{
            if(order.confirmJudge == CONFIRM_FLAG){
                _closeOrder(customer, indexOrder, true);
            }
            if(order.confirmJudge == DECLINE_FLAG){
                _closeOrder(customer, indexOrder, false);

            }
        }
    }

    function _changeHealhScoreExecutor(address executor, bool confirm) internal returns(uint) {
        if(confirm) return healthScoreExecutor[executor][0] += 1;
        else return healthScoreExecutor[executor][1] += 1;
    }

    function _changeHealhScoreCustomer(address customer, bool confirm) internal returns(uint) {
        if(confirm) return healthScoreCustomer[customer][0] += 1;
        else return healthScoreCustomer[customer][1] += 1;
    }

    function _changeHealhScoreJudge(address judge, bool confirm) internal returns(uint) {
        if(confirm) return healthScoreJudge[judge][0] += 1;
        else return healthScoreJudge[judge][1] += 1;
    }

    function _closeOrder(address customer, uint indexOrder, bool success) internal returns(Order memory){
        Order memory order = OrdersList[customer][indexOrder];
        uint fee;

        if(order.judge != address(0)){
            fee = previewFeeOrder(order.param.amount, feeOrder-feeJudge);
            balanceUser[address(this)][order.param.token] += fee;
            
            fee = previewFeeOrder(order.param.amount, feeJudge);
            balanceUser[order.judge][order.param.token] += fee;

            _changeHealhScoreJudge(order.judge, success);
        }else{
            fee = previewFeeOrder(order.param.amount, feeOrder);
            balanceUser[address(this)][order.param.token] += fee;
        }

        if(success){
            balanceUser[order.param.executor][order.param.token] += order.param.amount;
        }else{
            balanceUser[order.param.customer][order.param.token] += order.param.amount;
        }
        
        OrdersList[customer][indexOrder].isActive = false;

        _changeHealhScoreExecutor(order.param.executor, success);
        _changeHealhScoreCustomer(order.param.customer, success);

        emit ClosedOrder(order.param.customer, order.param.executor, order.param.title);

        return OrdersList[msg.sender][indexOrder];
    }

    function _setNewJudgeOrder(address customer, uint indexOrder) internal returns(Order memory order){
        address judge;
        if(judgeMembers.length == 0){
            judge = admin;
        }else{
            uint index = _random(judgeMembers.length);
            judge = judgeMembers[index];
        }
        OrdersList[customer][indexOrder].judge = judge;

        emit NewJudgeOrder(order.param.customer, order.param.executor, judge, order.param.title);

        return OrdersList[customer][indexOrder];
    }

    function _setStatusOrder(address customer, uint indexOrder, bool status) internal returns(bool){
        return OrdersList[customer][indexOrder].isActive = status;
    }

    function _withdraw(address token, address to, uint amount) internal returns(bool){
        if(balanceUser[to][token] < amount) revert E_NotEnoughBalance();
        bool status = ERC20(token).transfer(to, amount);
        balanceUser[to][token] -= amount;
        return status;
    }

    function _deposit(address token, address sender, uint amount) internal returns(bool){
        return ERC20(token).transferFrom(sender, address(this), amount);
    }

    function _approve(address spender, address token, uint amount) internal returns(bool){
        return ERC20(token).approve(spender, amount);
    }

    //pseudo random
    function _random(uint range) internal view returns(uint){
        uint256 randomSeed = uint(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, msg.sender)));
        return randomSeed % range;
    }

}
