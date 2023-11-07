// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOrderPlatform {
    event CreatedOrder(address indexed customer, address indexed executor, string title);
    event NewJudgeOrder(address indexed customer, address indexed executor, address indexed judge, string title);
    event SubmittedOrder(address indexed customer, address indexed executor, string title);
    event DeclinedOrder(address indexed customer, address indexed executor, string title);

    error E_Reentrancy();
    error E_Unauthorized();
    error E_NotEnoughBalance();

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
        uint balance;
        uint8 confirmCustomer;
        uint8 confirmExecutor;
        address judge;
        uint8 confirmJudge;
        bool active;
    }
    //orders
    function previewOrder(OrderParam memory param, uint indexOrder) external view returns(bool);
    function createOrder(OrderParam memory param, uint indexOrder) external returns(Order memory);
    function depositOrder(uint indexOrder) external returns(bool status);
    function confirmOrder(address customer, uint indexOrder) external returns(Order memory);
    function declineOrder(address customer, uint indexOrder) external returns(Order memory);
    function withdrawBalance(address token, uint amount) external returns(bool);

    //getters
    function getListOrder(address customer) external view returns(Order[] memory);
    function getOrder(address customer, uint indexOrder) external view returns(Order memory);
    function getListJudges() external view returns(address[] memory);
    function previewFeeOrder(uint amount, uint fee) external pure returns(uint);
    function previewFullPriceOrder(uint amount) external view returns(uint);
    function getBalance(address user, address token) external view returns(uint);
    
    //setters
    function changeAdmin(address newAdmin) external returns(address);
    function changeJudgeOrder(address customer, uint indexOrder) external returns(Order memory);
    function addJudge(address judge) external returns(address[] memory);
    function removeJudge(uint indexJudge) external returns(address[] memory);
    function changeFeeOrder(uint newFee) external returns(uint);
    function changeJudgeOrder(uint newFee) external returns(uint);
}
