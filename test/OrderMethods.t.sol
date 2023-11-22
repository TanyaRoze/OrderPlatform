// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import { OrderPlatform } from "../src/OrderPlatform.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract OrderPlatformTest is Test {

    event CreatedOrder(address indexed customer, address indexed executor, string title);
    event DepositedOrder(address indexed customer, address indexed executor, string title);
    event NewJudgeOrder(address indexed customer, address indexed executor, address indexed judge, string title);
    event SubmittedOrder(address indexed customer, address indexed executor, string title);
    event DeclinedOrder(address indexed customer, address indexed executor, string title);
    event ClosedOrder(address indexed customer, address indexed executor, string title);

    OrderPlatform public platform;
    OrderPlatform.OrderParam public orderParam;

    MockERC20 public TST;
    address public alice;
    address public bob;
    address public judge;

    function setUp() public {
        platform = new OrderPlatform(address(this));
        TST = new MockERC20("Test Token", "TST" , 18);

        alice = vm.addr(1000);
        bob = vm.addr(2000);
        judge = vm.addr(3000);
        
        TST.mint(alice, 1e18);

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

        vm.expectEmit(true, true, false, true);
        emit DepositedOrder(alice, bob, "Test service");

        vm.prank(alice);
        platform.depositOrder(indexOrder);
 
    }

    function  test_withdrawBalance()  public {
        uint indexOrder = 0;
        
        vm.prank(alice);
        platform.createOrder(orderParam, indexOrder);

        uint price = platform.previewFullPriceOrder(1e4);

        vm.prank(alice);
        TST.approve(address(platform), price);

        vm.prank(alice);
        platform.depositOrder(indexOrder);

        vm.expectEmit(true, true, false, true);
        emit SubmittedOrder(alice, bob, "Test service");

        vm.prank(alice);
        platform.confirmOrder(alice, indexOrder);

        vm.prank(bob);
        platform.confirmOrder(alice, indexOrder);

        uint balanceBob1 = platform.getBalance(bob, address(TST));

        vm.prank(bob);
        platform.withdrawBalance(address(TST), balanceBob1);

        uint balanceBob2 = TST.balanceOf(bob);

        assertEq(balanceBob1, balanceBob2);
    }

    function test_approveBalance() public {
        uint indexOrder = 0;
        
        vm.startPrank(alice);
        platform.createOrder(orderParam, indexOrder);

        uint price = platform.previewFullPriceOrder(1e4);
        TST.approve(address(platform), price);

        platform.depositOrder(indexOrder);
        platform.confirmOrder(alice, indexOrder);

        vm.stopPrank();

        vm.prank(bob);
        platform.confirmOrder(alice, indexOrder);

        uint balancePlatform = platform.getBalance(address(platform), address(TST));

        platform.approveBalance(address(this), address(TST), balancePlatform);

        uint allowance = TST.allowance(address(platform), address(this));

        assertEq(balancePlatform, allowance);

    }

}
