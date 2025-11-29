// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title KipuBankV3Test
 * @notice Tests completos para KipuBankV3 con fork de Ethereum mainnet
 * @dev Usa fork para testear integración real con Uniswap V2
 */
contract KipuBankV3Test is Test {
    KipuBankV3 public bank;
    
    // Direcciones de Ethereum Mainnet
    address constant UNISWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant ETH_USD_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // Chainlink ETH/USD
    
    // Usuarios de prueba
    address public admin;
    address public user1;
    address public user2;
    
    // Configuración del banco
    uint256 constant BANK_CAP = 1000000e6; // 1M USD
    uint256 constant WITHDRAWAL_LIMIT = 10000e6; // 10k USD
    
    function setUp() public {
        // Crear fork de mainnet
        //vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        
        // Setup de usuarios
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy del banco
        vm.prank(admin);
        bank = new KipuBankV3(
            BANK_CAP,
            WITHDRAWAL_LIMIT,
            ETH_USD_FEED,
            admin,
            UNISWAP_ROUTER,
            USDC
        );
        
        // Dar DAI a user1 para tests
        deal(DAI, user1, 10000e18); // 10k DAI
        
        // Dar USDC a user2
        deal(USDC, user2, 10000e6); // 10k USDC
    }
    
    // ============================================
    // TESTS DE DEPLOYMENT
    // ============================================
    
    function test_Deployment() public {
        assertEq(address(bank.uniswapRouter()), UNISWAP_ROUTER);
        assertEq(bank.usdcAddress(), USDC);
        assertEq(bank.BANK_CAP_USD(), BANK_CAP);
        assertEq(bank.WITHDRAWAL_LIMIT_USD(), WITHDRAWAL_LIMIT);
    }
    
    function test_DeploymentWithZeroRouter() public {
        vm.expectRevert(KipuBankV3.KipuBankV3__InvalidRouter.selector);
        new KipuBankV3(
            BANK_CAP,
            WITHDRAWAL_LIMIT,
            ETH_USD_FEED,
            admin,
            address(0), // ← Router inválido
            USDC
        );
    }
    
    function test_DeploymentWithZeroUSDC() public {
        vm.expectRevert(KipuBankV3.KipuBankV3__InvalidUSDC.selector);
        new KipuBankV3(
            BANK_CAP,
            WITHDRAWAL_LIMIT,
            ETH_USD_FEED,
            admin,
            UNISWAP_ROUTER,
            address(0) // ← USDC inválido
        );
    }
    
    // ============================================
    // TESTS DE CONFIGURACIÓN DE PATHS
    // ============================================
    
    function test_SetSwapPath() public {
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        address[] memory savedPath = bank.getSwapPath(DAI);
        assertEq(savedPath.length, 2);
        assertEq(savedPath[0], DAI);
        assertEq(savedPath[1], USDC);
    }
    
    function test_SetSwapPathMultiHop() public {
        // Path: DAI → WETH → USDC
        address[] memory path = new address[](3);
        path[0] = DAI;
        path[1] = WETH;
        path[2] = USDC;
        
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        address[] memory savedPath = bank.getSwapPath(DAI);
        assertEq(savedPath.length, 3);
        assertEq(savedPath[0], DAI);
        assertEq(savedPath[1], WETH);
        assertEq(savedPath[2], USDC);
    }
    
    function test_SetSwapPathRevertsIfNotAdmin() public {
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        
        vm.prank(user1);
        vm.expectRevert();
        bank.setSwapPath(DAI, path);
    }
    
    function test_SetSwapPathRevertsIfPathTooShort() public {
        address[] memory path = new address[](1);
        path[0] = DAI;
        
        vm.prank(admin);
        vm.expectRevert(KipuBankV3.KipuBankV3__InvalidSwapPath.selector);
        bank.setSwapPath(DAI, path);
    }
    
    function test_SetSwapPathRevertsIfFirstTokenWrong() public {
        address[] memory path = new address[](2);
        path[0] = WETH; // ← Debería ser DAI
        path[1] = USDC;
        
        vm.prank(admin);
        vm.expectRevert(KipuBankV3.KipuBankV3__InvalidSwapPath.selector);
        bank.setSwapPath(DAI, path);
    }
    
    function test_SetSwapPathRevertsIfLastTokenNotUSDC() public {
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = WETH; // ← Debería ser USDC
        
        vm.prank(admin);
        vm.expectRevert(KipuBankV3.KipuBankV3__InvalidSwapPath.selector);
        bank.setSwapPath(DAI, path);
    }
    
    // ============================================
    // TESTS DE SWAP + DEPOSIT
    // ============================================
    
    function test_DepositTokenWithSwap() public {
        // Setup: Configurar path DAI → USDC
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        // Usuario aprueba DAI
        uint256 daiAmount = 1000e18; // 1000 DAI
        vm.startPrank(user1);
        IERC20(DAI).approve(address(bank), daiAmount);
        
        // Obtener output esperado
        uint256 expectedUSDC = bank.getExpectedOutput(DAI, daiAmount);
        uint256 minUSDC = (expectedUSDC * 95) / 100; // 5% slippage
        
        // Ejecutar swap + deposit
        bank.depositTokenWithSwap(DAI, daiAmount, minUSDC);
        vm.stopPrank();
        
        // Verificar que el usuario tiene balance en el banco
        uint256 userBalance = bank.getUserBalance(user1, USDC);
        assertGt(userBalance, 0);
        assertGe(userBalance, minUSDC);
    }
    
    function test_DepositTokenWithSwapMultiHop() public {
        // Setup: Path DAI → WETH → USDC (puede tener mejor liquidez)
        address[] memory path = new address[](3);
        path[0] = DAI;
        path[1] = WETH;
        path[2] = USDC;
        
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        uint256 daiAmount = 1000e18;
        vm.startPrank(user1);
        IERC20(DAI).approve(address(bank), daiAmount);
        
        uint256 expectedUSDC = bank.getExpectedOutput(DAI, daiAmount);
        uint256 minUSDC = (expectedUSDC * 95) / 100;
        
        bank.depositTokenWithSwap(DAI, daiAmount, minUSDC);
        vm.stopPrank();
        
        uint256 userBalance = bank.getUserBalance(user1, USDC);
        assertGt(userBalance, 0);
    }
    
    function test_DepositTokenWithSwapRevertsIfNoPath() public {
        uint256 daiAmount = 1000e18;
        
        vm.startPrank(user1);
        IERC20(DAI).approve(address(bank), daiAmount);
        
        vm.expectRevert(KipuBankV3.KipuBankV3__SwapPathNotSet.selector);
        bank.depositTokenWithSwap(DAI, daiAmount, 900e6);
        vm.stopPrank();
    }
    
    function test_DepositTokenWithSwapRevertsIfZeroAmount() public {
        // Setup path
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        vm.prank(user1);
        vm.expectRevert(); // KipuBankV2__AmountMustBeGreaterThanZero
        bank.depositTokenWithSwap(DAI, 0, 0);
    }
    
    function test_DepositTokenWithSwapRevertsIfSlippageTooHigh() public {
        // Setup path
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        uint256 daiAmount = 1000e18;
        vm.startPrank(user1);
        IERC20(DAI).approve(address(bank), daiAmount);
        
        uint256 expectedUSDC = bank.getExpectedOutput(DAI, daiAmount);
        uint256 minUSDC = (expectedUSDC * 90) / 100; // 10% slippage ← DEMASIADO
        
        vm.expectRevert(
            abi.encodeWithSelector(
                KipuBankV3.KipuBankV3__SlippageTooHigh.selector,
                expectedUSDC,
                minUSDC
            )
        );
        bank.depositTokenWithSwap(DAI, daiAmount, minUSDC);
        vm.stopPrank();
    }
    
    // ============================================
    // TESTS DE EXPECTED OUTPUT
    // ============================================
    
    function test_GetExpectedOutput() public {
        // Setup path
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        uint256 daiAmount = 1000e18;
        uint256 expectedUSDC = bank.getExpectedOutput(DAI, daiAmount);
        
        // USDC debería ser aproximadamente igual a DAI (ambos ~$1)
        // Verificamos que esté en rango razonable (950-1050 USDC por 1000 DAI)
        assertGt(expectedUSDC, 950e6);
        assertLt(expectedUSDC, 1050e6);
    }
    
    function test_GetExpectedOutputReturnsZeroIfNoPath() public {
        uint256 expectedUSDC = bank.getExpectedOutput(DAI, 1000e18);
        assertEq(expectedUSDC, 0);
    }
    
    // ============================================
    // TESTS DE INTEGRACIÓN CON V2
    // ============================================
    
    function test_DepositETHStillWorksFromV2() public {
        uint256 ethAmount = 1 ether;
        
        vm.deal(user1, ethAmount);
        vm.prank(user1);
        bank.depositETH{value: ethAmount}();
        
        uint256 balance = bank.getUserBalance(user1, address(0));
        assertGt(balance, 0);
    }
    
    function test_WithdrawETHStillWorksFromV2() public {
        // Primero depositar
        uint256 ethAmount = 1 ether;
        vm.deal(user1, ethAmount);
        vm.prank(user1);
        bank.depositETH{value: ethAmount}();
        
        // Guardar balance después del depósito
        uint256 balanceAfterDeposit = bank.getUserBalance(user1, address(0));
        assertGt(balanceAfterDeposit, 0);
        
        // Luego retirar
        uint256 withdrawAmount = 0.5 ether;
        vm.prank(user1);
        bank.withdrawETH(withdrawAmount);
        
        // Verificar que se redujo el balance
        uint256 balanceAfterWithdraw = bank.getUserBalance(user1, address(0));
        assertLt(balanceAfterWithdraw, balanceAfterDeposit);
    }
    
    // ============================================
    // TESTS DE EVENTOS
    // ============================================
    
    function test_EmitsTokenSwappedEvent() public {
        // Setup
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        uint256 daiAmount = 1000e18;
        vm.startPrank(user1);
        IERC20(DAI).approve(address(bank), daiAmount);
        
        uint256 expectedUSDC = bank.getExpectedOutput(DAI, daiAmount);
        uint256 minUSDC = (expectedUSDC * 95) / 100;
        
        // Expect event
        vm.expectEmit(true, true, false, false);
        emit KipuBankV3.TokenSwapped(user1, DAI, daiAmount, 0); // 0 porque no sabemos exacto
        
        bank.depositTokenWithSwap(DAI, daiAmount, minUSDC);
        vm.stopPrank();
    }
    
    function test_EmitsSwapPathSetEvent() public {
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        
        vm.expectEmit(true, false, false, true);
        emit KipuBankV3.SwapPathSet(DAI, path);
        
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
    }
    
    // ============================================
    // TESTS DE EDGE CASES
    // ============================================
    
    function test_MultipleUsersCanDepositIndependently() public {
        // Setup
        address[] memory path = new address[](2);
        path[0] = DAI;
        path[1] = USDC;
        vm.prank(admin);
        bank.setSwapPath(DAI, path);
        
        // User1 deposita
        deal(DAI, user1, 1000e18);
        vm.startPrank(user1);
        IERC20(DAI).approve(address(bank), 1000e18);
        uint256 expected1 = bank.getExpectedOutput(DAI, 1000e18);
        bank.depositTokenWithSwap(DAI, 1000e18, (expected1 * 95) / 100);
        vm.stopPrank();
        
        // User2 deposita
        deal(DAI, user2, 2000e18);
        vm.startPrank(user2);
        IERC20(DAI).approve(address(bank), 2000e18);
        uint256 expected2 = bank.getExpectedOutput(DAI, 2000e18);
        bank.depositTokenWithSwap(DAI, 2000e18, (expected2 * 95) / 100);
        vm.stopPrank();
        
        // Verificar balances independientes
        uint256 balance1 = bank.getUserBalance(user1, USDC);
        uint256 balance2 = bank.getUserBalance(user2, USDC);
        
        assertGt(balance1, 0);
        assertGt(balance2, 0);
        assertGt(balance2, balance1); // User2 depositó más
    }
}