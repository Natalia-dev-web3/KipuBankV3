// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./KipuBankV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @notice Interface de Uniswap V2 Router para realizar swaps
 * @dev Usamos solo las funciones necesarias para optimizar gas y claridad
 */
interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,  
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] calldata path)
        external
        view
        returns (uint[] memory amounts);
}

/**
 * @title KipuBankV3
 * @author Natalia Avila
 * @notice Extensión de KipuBankV2 con integración a Uniswap V2 para swaps automáticos
 * @dev Permite depositar cualquier token ERC-20 y automáticamente lo convierte a USDC vía Uniswap
 * 
 * CONCEPTOS DEMOSTRADOS:
 * ✅ Herencia de contratos (extends KipuBankV2)
 * ✅ Integración con protocolos DeFi (Uniswap V2)
 * ✅ Composabilidad (swap + deposit en una transacción atómica)
 * ✅ Protección contra slippage (5% máximo)
 * ✅ Manejo de deadlines para prevenir front-running
 * ✅ Checks-Effects-Interactions pattern
 * ✅ Seguridad: NonReentrant, validaciones múltiples
 */
contract KipuBankV3 is KipuBankV2 {
    using SafeERC20 for IERC20;

    // ============================================
    // VARIABLES DE ESTADO
    // ============================================
    
    /// @notice Router de Uniswap V2 para realizar swaps
    IUniswapV2Router02 public immutable uniswapRouter;
    
    /// @notice Dirección del token USDC (token de destino para todos los swaps)
    address public immutable usdcAddress;
    
    /// @notice Slippage máximo permitido en basis points (500 = 5%)
    uint256 public constant MAX_SLIPPAGE_BPS = 500;
    
    /// @notice Deadline por defecto para transacciones Uniswap (15 minutos)
    uint256 public constant DEFAULT_DEADLINE = 15 minutes;

    // ============================================
    // MAPPINGS
    // ============================================
    
    /// @notice Path de swap personalizado para cada token → USDC
    mapping(address => address[]) private s_swapPaths;

    // ============================================
    // EVENTOS
    // ============================================
    
    event TokenSwapped(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOutUSDC
    );
    
    event SwapPathSet(address indexed token, address[] path);

    // ============================================
    // ERRORES PERSONALIZADOS
    // ============================================
    
    error KipuBankV3__InvalidRouter();
    error KipuBankV3__InvalidUSDC();
    error KipuBankV3__SwapPathNotSet();
    error KipuBankV3__InvalidSwapPath();
    error KipuBankV3__SlippageTooHigh(uint256 expected, uint256 minimum);
    error KipuBankV3__SwapFailed();
    error KipuBankV3__InsufficientOutputAmount();

    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    /**
     * @notice Constructor de KipuBankV3
     * @param bankCapUSD Límite máximo del banco en USD (6 decimales)
     * @param withdrawalLimitUSD Límite de retiro por transacción en USD (6 decimales)
     * @param ethUsdFeed Dirección del oráculo Chainlink ETH/USD
     * @param admin Dirección del administrador inicial
     * @param _uniswapRouter Dirección del Uniswap V2 Router
     * @param _usdc Dirección del token USDC
     */
    constructor(
        uint256 bankCapUSD,
        uint256 withdrawalLimitUSD,
        address ethUsdFeed,
        address admin,
        address _uniswapRouter,
        address _usdc
    ) KipuBankV2(bankCapUSD, withdrawalLimitUSD, ethUsdFeed, admin, _usdc) {
        if (_uniswapRouter == address(0)) revert KipuBankV3__InvalidRouter();
        if (_usdc == address(0)) revert KipuBankV3__InvalidUSDC();
        
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        usdcAddress = _usdc;
    }

    // ============================================
    // FUNCIONES EXTERNAS - DEPÓSITOS CON SWAP
    // ============================================
    
    /**
     * @notice Deposita cualquier token ERC-20, lo swapea a USDC y deposita en el banco
     * @dev FUNCIÓN CORE DE V3 - Demuestra composabilidad DeFi
     * 
     * FLUJO COMPLETO (Checks-Effects-Interactions):
     * 1. CHECKS: Valida path y slippage
     * 2. INTERACTIONS: Recibe tokens del usuario
     * 3. INTERACTIONS: Ejecuta swap en Uniswap
     * 4. EFFECTS: Deposita USDC usando función interna de V2
     * 5. EVENTS: Emite eventos para tracking
     * 
     * @param tokenIn Token que el usuario quiere depositar
     * @param amountIn Cantidad del token a depositar
     * @param minAmountOut Cantidad mínima de USDC esperada (protección contra slippage)
     */
    function depositTokenWithSwap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) external nonReentrant amountGreaterThanZero(amountIn) {
        // CHECKS - Validaciones iniciales
        address[] memory path = s_swapPaths[tokenIn];
        if (path.length == 0) revert KipuBankV3__SwapPathNotSet();
        
        uint256 expectedOut = _getExpectedOutput(tokenIn, amountIn);
        _validateSlippage(expectedOut, minAmountOut);
        
        // INTERACTIONS 1 - Recibir tokens del usuario
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        
        // INTERACTIONS 2 - Ejecutar swap a USDC
        uint256 usdcReceived = _swapToUSDC(tokenIn, amountIn, minAmountOut);
        
        // EFFECTS - Depositar USDC usando función interna de V2
        uint256 amountUSD = usdcReceived;
        _depositUSDCInternal(msg.sender, amountUSD);
        
        // EVENTS
        emit TokenSwapped(msg.sender, tokenIn, amountIn, usdcReceived);
    }

    // ============================================
    // FUNCIONES ADMINISTRATIVAS
    // ============================================
    
    /**
     * @notice Configura el path de swap para un token específico
     * @dev Solo ADMIN puede configurar paths
     * @param token Token de origen
     * @param path Array de direcciones representando la ruta de swap
     */
    function setSwapPath(address token, address[] calldata path)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (path.length < 2) revert KipuBankV3__InvalidSwapPath();
        if (path[0] != token) revert KipuBankV3__InvalidSwapPath();
        if (path[path.length - 1] != usdcAddress) revert KipuBankV3__InvalidSwapPath();
        
        s_swapPaths[token] = path;
        
        emit SwapPathSet(token, path);
    }

    // ============================================
    // FUNCIONES DE VISTA
    // ============================================
    
    /**
     * @notice Obtiene el path de swap configurado para un token
     * @param token Token a consultar
     * @return Array con el path de swap
     */
    function getSwapPath(address token) external view returns (address[] memory) {
        return s_swapPaths[token];
    }
    
    /**
     * @notice Simula cuánto USDC se recibiría por un swap
     * @param tokenIn Token de entrada
     * @param amountIn Cantidad a swapear
     * @return Cantidad estimada de USDC
     */
    function getExpectedOutput(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return _getExpectedOutput(tokenIn, amountIn);
    }

    // ============================================
    // FUNCIONES INTERNAS
    // ============================================
    
    /**
     * @dev Ejecuta el swap de token → USDC en Uniswap V2
     * @param tokenIn Token de entrada
     * @param amountIn Cantidad a swapear
     * @param minAmountOut Mínimo USDC esperado
     * @return Cantidad de USDC recibida
     */
    function _swapToUSDC(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut
    ) private returns (uint256) {
        address[] memory path = s_swapPaths[tokenIn];
        
        IERC20(tokenIn).forceApprove(address(uniswapRouter), amountIn);
        
        uint256 deadline = block.timestamp + DEFAULT_DEADLINE;
        
        try uniswapRouter.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            address(this),
            deadline
        ) returns (uint[] memory amounts) {
            uint256 usdcReceived = amounts[amounts.length - 1];
            
            if (usdcReceived < minAmountOut) {
                revert KipuBankV3__InsufficientOutputAmount();
            }
            
            return usdcReceived;
        } catch {
            revert KipuBankV3__SwapFailed();
        }
    }
    
    /**
     * @dev Obtiene la cantidad esperada de output de un swap
     * @param tokenIn Token de entrada
     * @param amountIn Cantidad de entrada
     * @return Cantidad estimada de USDC
     */
    function _getExpectedOutput(address tokenIn, uint256 amountIn)
        private
        view
        returns (uint256)
    {
        address[] memory path = s_swapPaths[tokenIn];
        if (path.length == 0) return 0;
        
        try uniswapRouter.getAmountsOut(amountIn, path) returns (
            uint[] memory amounts
        ) {
            return amounts[amounts.length - 1];
        } catch {
            return 0;
        }
    }
    
    /**
     * @dev Valida que el slippage no excede el máximo permitido
     * @param expected Cantidad esperada
     * @param minimum Cantidad mínima aceptable
     */
    function _validateSlippage(uint256 expected, uint256 minimum) private pure {
        if (minimum > expected) {
            revert KipuBankV3__SlippageTooHigh(expected, minimum);
        }
        
        uint256 slippageBps = ((expected - minimum) * 10000) / expected;
        
        if (slippageBps > MAX_SLIPPAGE_BPS) {
            revert KipuBankV3__SlippageTooHigh(expected, minimum);
        }
    }
}
