// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import { OrderPlatform } from "../src/OrderPlatform.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract ConditionTest is Test {
    OrderPlatform public platform;
    OrderPlatform.OrderParam public orderParam;

    MockERC20 public TST;
    address public alice;
    address public bob;
    address public judge;
    uint indexOrder;

    function setUp() public {
        platform = new OrderPlatform(address(this));
        TST = new MockERC20("Test Token", "TST" , 18);

        alice = vm.addr(1000);
        bob = vm.addr(2000);
        judge = vm.addr(3000);
        
        TST.mint(bob, 1e18);
        TST.mint(alice, 1e18);

        orderParam = OrderPlatform.OrderParam({
            customer: alice,
            token: address(TST),
            amount: 1e4,
            executor: bob,
            title: 'Test service'
        });

        indexOrder = 0;

        vm.prank(alice);
        platform.createOrder(orderParam, indexOrder);
    }

    function test_CloseOrder_TT_Condition() public {
        uint price = platform.previewFullPriceOrder(1e4);

        vm.prank(alice);
        TST.approve(address(platform), price);

        vm.prank(alice);
        platform.depositOrder(indexOrder);

        vm.prank(alice);
        platform.confirmOrder(alice, indexOrder);

        vm.prank(bob);
        platform.confirmOrder(alice, indexOrder);

        
        uint balanceBob = platform.getBalance(bob, address(TST));
        uint balance = platform.getBalance(address(platform), address(TST));

        assertEq(balanceBob + balance, price);
    }

    function test_CloseOrder_FF_Condition() public {
        uint price = platform.previewFullPriceOrder(1e4);

        vm.prank(alice);
        TST.approve(address(platform), price);

        vm.prank(alice);
        platform.depositOrder(indexOrder);

        vm.prank(alice);
        platform.declineOrder(alice, indexOrder);

        vm.prank(bob);
        platform.declineOrder(alice, indexOrder);

        
        uint balanceBob = platform.getBalance(alice, address(TST));
        uint balance = platform.getBalance(address(platform), address(TST));

        assertEq(balanceBob + balance, price);
    }

    function test_CloseOrder_TFT_Condition() public {
        uint price = platform.previewFullPriceOrder(1e4);

        vm.prank(alice);
        TST.approve(address(platform), price);

        vm.prank(alice);
        platform.depositOrder(indexOrder);

        vm.prank(alice);
        platform.declineOrder(alice, indexOrder);

        vm.prank(bob);
        platform.confirmOrder(alice, indexOrder);

        platform.confirmOrder(alice, indexOrder);

        uint balanceBob = platform.getBalance(bob, address(TST));
        uint balanceJudge = platform.getBalance(address(this), address(TST));
        uint balance = platform.getBalance(address(platform), address(TST));

        assertEq(balanceBob + balance + balanceJudge, price);
    }

    function test_CloseOrder_TFF_Condition() public {
        uint price = platform.previewFullPriceOrder(1e4);

        vm.prank(alice);
        TST.approve(address(platform), price);

        vm.prank(alice);
        platform.depositOrder(indexOrder);

        vm.prank(alice);
        platform.declineOrder(alice, indexOrder);

        vm.prank(bob);
        platform.confirmOrder(alice, indexOrder);

        vm.prank(address(this));
        platform.declineOrder(alice, indexOrder);

        uint balanceAlice = platform.getBalance(alice, address(TST));
        uint balanceJudge = platform.getBalance(address(this), address(TST));
        uint balance = platform.getBalance(address(platform), address(TST));

        assertEq(balanceAlice + balance + balanceJudge, price);
    }
    
}
