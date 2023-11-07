// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import { OrderPlatform } from "../src/OrderPlatform.sol";
import { IOrderPlatform } from "../src/interfaces/IOrderPlatform.sol";
import {TestERC20} from "./mocks/TestERC20.sol";

contract OrderPlatformTest is Test {
    event CreatedOrder(address indexed customer, address indexed executor, string title);
    event SubmittedOrder(address indexed customer, address indexed executor, string title);
    event DeclinedOrder(address indexed customer, address indexed executor, string title);

    OrderPlatform public platform;
    OrderPlatform.OrderParam public orderParam;

    TestERC20 public TST;
    address public alice;
    address public bob;
    address public judge;

    function setUp() public {
        platform = new OrderPlatform();
        TST = new TestERC20("Test Token", "TST" , 18, false);

        alice = vm.addr(1000);
        bob = vm.addr(2000);
        judge = vm.addr(3000);
        
        TST.mint(bob, 1e18);
        TST.mint(alice, 1e18);

        vm.prank(alice);

        orderParam = OrderPlatform.OrderParam({
            customer: alice,
            token: address(TST),
            amount: 1e4,
            executor: bob,
            title: 'Test service'
        });
    }

    function test_createOrder() public {
        vm.expectEmit(true, true, false, true);
        emit CreatedOrder(alice, bob, "Test service");

        vm.prank(alice);
        platform.createOrder(orderParam, 0);
    }

    function test_depositOrder() public {
        uint indexOrder = 0;
        
        vm.prank(alice);
        platform.createOrder(orderParam, indexOrder);

        uint price = platform.previewFullPriceOrder(1e4);

        vm.prank(alice);
        TST.approve(address(platform), price);

        vm.prank(alice);
        platform.depositOrder(indexOrder);

        OrderPlatform.Order memory currOrder = platform.getOrder(alice, indexOrder);

        assertEq(currOrder.balance, price);
    }
    
}
