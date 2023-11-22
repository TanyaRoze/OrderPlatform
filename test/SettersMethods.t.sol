// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import { OrderPlatform } from "../src/OrderPlatform.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract SettersMethodsTest is Test {

    OrderPlatform public platform;
    OrderPlatform.OrderParam public orderParam;

    MockERC20 public TST;
    address public alice;
    address public bob;
    address public judge;

    uint price = 1e4;

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
            amount: price,
            executor: bob,
            title: 'Test service'
        });

        vm.startPrank(alice);

        platform.createOrder(orderParam, 0);
        platform.createOrder(orderParam, 1);

        uint fullPrice = platform.previewFullPriceOrder(price*2);
        TST.approve(address(platform), fullPrice);

        platform.depositOrder(0);
        platform.depositOrder(1);

        platform.confirmOrder(alice, 0);
        vm.stopPrank();

        vm.prank(bob);
        platform.confirmOrder(alice, 0);

    }

    

    function test_changeAdmin() public {
        address newAdmin = vm.addr(1234);

        platform.changeAdmin(newAdmin);

        address currAdmin = platform.getAdmin();

        assertEq(currAdmin, newAdmin);
    }

    function test_addJudge() public {
        address[] memory currJudgeList = platform.getListJudges();
        assertEq(currJudgeList.length, 0);

        platform.addJudge(judge);

        address[] memory newJudgeList = platform.getListJudges();
        assertEq(newJudgeList.length, 1);
        assertEq(newJudgeList[0], judge);
    }

    function test_removeJudge() public {
        platform.addJudge(judge);
        address[] memory currJudgeList = platform.getListJudges();
        assertEq(currJudgeList.length, 1);
        assertEq(currJudgeList[0], judge);

        platform.removeJudge(0);
        
        address[] memory newJudgeList = platform.getListJudges();
        assertEq(newJudgeList.length, 0);
        
    }

    function test_changeFee() public {
        uint[2] memory currFees = platform.getFees();
        assertEq(currFees[0], 200);
        assertEq(currFees[1], 100);

        platform.changeFeeOrder(500);
        platform.changeFeeJudge(200);
        uint[2] memory newFees = platform.getFees();
        assertEq(newFees[0], 500);
        assertEq(newFees[1], 200);
    }
    
    function test_changeJudgeOrder() public {
        vm.prank(alice);
        platform.confirmOrder(alice, 1);

        vm.prank(bob);
        platform.declineOrder(alice, 1);

        OrderPlatform.Order memory order1 = platform.getOrder(alice, 1);

        address currJudge = order1.judge;

        assertEq(currJudge, address(this));

        platform.addJudge(judge);

        platform.changeJudgeOrder(alice, 1);

        OrderPlatform.Order memory order2 = platform.getOrder(alice, 1);

        address newJudge = order2.judge;

        assertEq(newJudge, judge);
    }


}
