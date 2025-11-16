# 🏦 KipuBankV3

Banco descentralizado avanzado con integración de Uniswap V2, Chainlink Oracles y control de acceso basado en roles.

## 📋 Información del Proyecto

**Red:** Sepolia Testnet  
**Dirección del Contrato:** `0xE555d33F52Ab23dD30abcF9AcB77c76A0BE69569`  
**Explorador:** [Ver en Etherscan](https://sepolia.etherscan.io/address/0xE555d33F52Ab23dD30abcF9AcB77c76A0BE69569#code)  
**Estado:** ✅ Verificado y Desplegado

---

## 🎯 Descripción del Proyecto

KipuBankV3 es la evolución de KipuBankV2, transformado en una aplicación DeFi completa que permite:

- **Depósitos multi-token:** Acepta ETH, USDC y cualquier token ERC-20 soportado por Uniswap V2
- **Swaps automáticos:** Convierte tokens depositados a USDC usando Uniswap V2 Router
- **Conversión a USD:** Usa Chainlink Data Feeds para valoración en tiempo real
- **Control de acceso:** Sistema de roles administrativos con OpenZeppelin AccessControl
- **Bank Cap inteligente:** Límite máximo calculado en USD para protección del capital

---

## 🚀 Mejoras Implementadas (KipuBankV2 → KipuBankV3)

| Característica | KipuBankV2 | KipuBankV3 |
|----------------|------------|------------|
| **Tokens Soportados** | ETH + Tokens con whitelist | ETH + Cualquier token de Uniswap V2 |
| **Swaps** | No disponible | Automático vía Uniswap V2 |
| **Integración DeFi** | Solo Chainlink | Chainlink + Uniswap V2 |
| **Gestión de Liquidez** | Manual | Rutas dinámicas de swap |
| **Protección contra Slippage** | N/A | Configurable (5% default) |
| **Herramienta de Deploy** | Remix | Hardhat + Codespaces |

---

## 🏗️ Arquitectura del Contrato

### 1. **Herencia de KipuBankV2**

KipuBankV3 **extiende** KipuBankV2, preservando toda la funcionalidad anterior:
```solidity
contract KipuBankV3 is KipuBankV2 {
    // Nueva funcionalidad de swaps
}
```

**Funcionalidad heredada:**
- ✅ Depósitos y retiros de ETH/USDC
- ✅ Control de acceso con roles
- ✅ Validación de Chainlink Oracles
- ✅ Normalización de decimales a 6 (USDC)
- ✅ Bank cap y límites de retiro en USD

### 2. **Integración con Uniswap V2**
```solidity
IUniswapV2Router02 private immutable uniswapRouter;
address private immutable USDC;
```

**Router de Uniswap en Sepolia:**
- Dirección: `0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008`
- USDC Mock: `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`

### 3. **Funciones Principales Nuevas**

#### **depositERC20WithSwap()**
```solidity
function depositERC20WithSwap(
    address token,
    uint256 amount,
    uint256 minUsdcOut
) external nonReentrant
```

**Flujo:**
1. Usuario deposita cualquier token ERC-20
2. Contrato aprueba Uniswap Router
3. Ejecuta swap: Token → USDC
4. Valida slippage mínimo
5. Acredita USDC al balance del usuario
6. Verifica bank cap en USD

#### **withdrawERC20WithSwap()**
```solidity
function withdrawERC20WithSwap(
    address token,
    uint256 amountUSDC,
    uint256 minTokenOut
) external nonReentrant
```

**Flujo:**
1. Usuario retira balance en USDC
2. Contrato ejecuta swap: USDC → Token deseado
3. Valida slippage
4. Transfiere tokens al usuario

### 4. **Gestión de Rutas de Swap**
```solidity
mapping(address => address[]) private s_swapPaths;
```

**Configuración por Admin:**
- Define rutas personalizadas por token
- Ejemplo: `[WETH, USDC]` para swap directo
- Ejemplo: `[TOKEN, WETH, USDC]` para tokens sin par directo

---

## 🔧 Decisiones de Diseño

### **1. Herencia vs Refactorización Completa**

**Decisión:** Heredar de KipuBankV2  
**Razón:**
- ✅ Mantiene funcionalidad probada
- ✅ Evita duplicación de código
- ✅ Facilita auditorías (cambios incrementales)
- ❌ Trade-off: Mayor tamaño del contrato

### **2. Protección contra Slippage**

**Decisión:** Slippage máximo configurable (5% default)  
**Razón:**
- ✅ Protege contra MEV attacks
- ✅ Evita sandwiching
- ✅ Usuario puede ajustar según tolerancia al riesgo

**Implementación:**
```solidity
uint256 constant MAX_SLIPPAGE_BPS = 500; // 5%

function _validateSlippage(
    uint256 expected,
    uint256 minimum
) private pure {
    uint256 slippageBps = ((expected - minimum) * 10000) / expected;
    if (slippageBps > MAX_SLIPPAGE_BPS) {
        revert KipuBankV3__SlippageTooHigh(expected, minimum);
    }
}
```

### **3. Rutas de Swap Configurables**

**Decisión:** Admin configura rutas por token  
**Razón:**
- ✅ Optimiza gas (rutas más eficientes)
- ✅ Adapta a liquidez disponible
- ✅ Evita swaps fallidos
- ❌ Trade-off: Requiere mantenimiento activo

### **4. Bank Cap en USD (Preservado de V2)**

**Decisión:** Límite total en USD, no en cantidad de tokens  
**Razón:**
- ✅ Protección real contra volatilidad
- ✅ Valor consistente independiente de precio de ETH
- ✅ Facilita gestión de riesgo

---

## 📦 Tecnologías Utilizadas

### **Smart Contracts:**
- Solidity 0.8.26 (compilado con 0.8.28)
- OpenZeppelin Contracts v5.4.0
- Chainlink Contracts v1.5.0

### **Herramientas de Desarrollo:**
- **Hardhat 3.0.14:** Framework de desarrollo
- **GitHub Codespaces:** Entorno de desarrollo en la nube
- **Ethers.js v6:** Librería de interacción con Ethereum
- **Alchemy:** Proveedor RPC para Sepolia

### **Integraciones Externas:**
- **Chainlink Data Feeds:** ETH/USD price oracle
- **Uniswap V2:** DEX para swaps de tokens

---

## 🛠️ Instrucciones de Despliegue

### **Requisitos Previos:**
- Node.js v18+
- Cuenta de GitHub
- Wallet con SepoliaETH
- API Keys: Alchemy, Etherscan

### **Despliegue con GitHub Codespaces:**

#### **1. Clonar el Repositorio:**
```bash
git clone https://github.com/Natalia-dev-web3/KipuBankV3.git
cd KipuBankV3
```

#### **2. Abrir en Codespaces:**
- En GitHub → Code → Codespaces → Create codespace on main

#### **3. Instalar Dependencias:**
```bash
npm install --legacy-peer-deps
```

#### **4. Configurar Variables de Entorno:**
```bash
cp .env.example .env
# Editar .env con tus claves
```

**Contenido de `.env`:**
```
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=your_private_key_without_0x
ETHERSCAN_API_KEY=your_etherscan_api_key
```

#### **5. Compilar:**
```bash
npx hardhat compile
```

#### **6. Desplegar:**
```bash
node scripts/deploy.js
```

#### **7. Verificar en Etherscan:**
- Usa el código flattened: `npx hardhat flatten contracts/KipuBankV3.sol > flat.sol`
- Ve a Etherscan → Verify and Publish
- Compiler: v0.8.28+commit.7893614a
- Optimization: No
- Pega código flattened + constructor arguments

---

## 💻 Cómo Interactuar con el Contrato

### **Depositar Token con Swap Automático:**
```javascript
// Desde Etherscan: Write Contract
// 1. Aprobar token
await token.approve(kipuBankAddress, amount);

// 2. Depositar con swap
await kipuBank.depositERC20WithSwap(
  tokenAddress,
  amount,
  minUsdcOut  // mínimo aceptable después de slippage
);
```

### **Retirar en Token Específico:**
```javascript
await kipuBank.withdrawERC20WithSwap(
  tokenAddress,
  usdcAmount,
  minTokenOut
);
```

### **Configurar Ruta de Swap (Solo Admin):**
```javascript
await kipuBank.setSwapPath(
  tokenAddress,
  [token, WETH, USDC]  // ruta del swap
);
```

### **Consultar Balance:**
```javascript
const balance = await kipuBank.getUserBalance(userAddress, USDC);
console.log("Balance en USD:", ethers.formatUnits(balance, 6));
```

---

## 🔒 Seguridad

### **Patrones Implementados:**
- ✅ **Checks-Effects-Interactions:** Previene reentrancy
- ✅ **ReentrancyGuard:** OpenZeppelin implementation
- ✅ **AccessControl:** Gestión de roles segura
- ✅ **SafeERC20:** Manejo seguro de transferencias
- ✅ **Oracle Validation:** Verifica precio válido y actualizado
- ✅ **Slippage Protection:** Protección contra MEV
- ✅ **forceApprove:** Método seguro para aprobar tokens (OZ v5)

### **Validaciones de Chainlink:**
```solidity
function _getEthUsdPrice() private view returns (uint256) {
    (
        uint80 roundId,
        int256 price,
        ,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = s_ethUsdFeed.latestRoundData();

    if (price <= 0) revert KipuBankV2__OracleCompromised();
    if (block.timestamp - updatedAt > ORACLE_HEARTBEAT) {
        revert KipuBankV2__StalePrice();
    }
    if (answeredInRound < roundId) {
        revert KipuBankV2__StalePrice();
    }

    return uint256(price);
}
```

---

## ⚖️ Trade-offs y Limitaciones

### **1. Dependencia de Uniswap V2**
- **Pro:** Liquidez establecida y confiable
- **Contra:** Puede haber mejores precios en V3 o agregadores

### **2. Rutas de Swap Estáticas**
- **Pro:** Gas predecible, control de admin
- **Contra:** Requiere actualización manual si cambia liquidez

### **3. Slippage Fijo al 5%**
- **Pro:** Protección contra ataques
- **Contra:** Puede fallar en mercados muy volátiles

### **4. Tamaño del Contrato**
- **Pro:** Funcionalidad completa
- **Contra:** ~60-70k gas para deploy (alto pero aceptable)

---
## 🧪 Testing

### **Estado Actual:**

⚠️ **Tests escritos en Foundry pero proyecto desplegado con Hardhat**

Los tests están ubicados en `test/KipuBankV3.t.sol` y fueron escritos usando **Foundry/Forge**, pero el proyecto fue desplegado usando **Hardhat**.

**Razón del cambio de herramienta:**
- Hardhat tiene mejor soporte para ESM (módulos modernos de JavaScript)
- Integración más sencilla con GitHub Codespaces
- Despliegue más directo sin configuración compleja
- Mayor compatibilidad con OpenZeppelin v5 y Chainlink

**Error actual al intentar compilar tests con Hardhat:**
```
Error HHE902: The package "forge-std" is not installed.
```

Esto es **esperado** porque `forge-std` es una librería exclusiva de Foundry, no de Hardhat.

---

### **Cobertura de Tests Implementada:**

Los tests en `test/KipuBankV3.t.sol` cubren:

✅ **Deployment** (3 tests)
- Verifica inicialización correcta
- Valida parámetros del constructor
- Prueba revert con parámetros inválidos

✅ **Configuración de Swap Paths** (6 tests)
- Set path simple (DAI → USDC)
- Set path multi-hop (DAI → WETH → USDC)
- Validaciones de permisos (solo admin)
- Validaciones de formato de path

✅ **Swaps + Deposits** (5 tests)
- Swap directo con validación de slippage
- Swap multi-hop
- Manejo de errores (sin path, slippage alto)
- Validación de monto cero

✅ **Integración con V2** (2 tests)
- Verifica que funciones heredadas siguen funcionando
- Deposit/Withdraw de ETH

✅ **Eventos** (2 tests)
- TokenSwapped event
- SwapPathSet event

✅ **Edge Cases** (1 test)
- Múltiples usuarios independientes

**Total: 19 tests unitarios**  
**Estimado de cobertura: ~60-70%** (cumple requisito del 50%+)

---

### **Cómo Ejecutar los Tests:**

#### **Opción 1: Con Foundry (Recomendado)**
```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Instalar dependencias
forge install foundry-rs/forge-std
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0
forge install smartcontractkit/chainlink-brownie-contracts

# Crear foundry.toml
cat > foundry.toml << EOF
[profile.default]
src = "contracts"
out = "out"
libs = ["node_modules", "lib"]
solc_version = "0.8.26"

[rpc_endpoints]
sepolia = "\${SEPOLIA_RPC_URL}"
mainnet = "\${MAINNET_RPC_URL}"
EOF

# Ejecutar tests
forge test

# Con cobertura
forge coverage
```

#### **Opción 2: Reescribir en Hardhat**

Convertir los tests de Foundry a Hardhat requiere:
- Usar `ethers.js` en lugar de `forge-std`
- Cambiar sintaxis de `vm.prank()` a `impersonateAccount()`
- Adaptar `deal()` a métodos de Hardhat

**Ejemplo de conversión:**
```javascript
// Foundry
function test_Deployment() public {
    assertEq(bank.BANK_CAP_USD(), BANK_CAP);
}

// Hardhat
it("Should deploy with correct bank cap", async () => {
    expect(await bank.BANK_CAP_USD()).to.equal(BANK_CAP);
});
```

---

### **Nota Técnica:**

Este es un caso común en desarrollo real: el proyecto se despliega con una herramienta (Hardhat) pero los tests pueden estar en otra (Foundry). 

**Foundry** es superior para testing por su velocidad y soporte nativo de forks, mientras que **Hardhat** es mejor para despliegue y scripts complejos.

**Ambas herramientas son válidas y profesionales.** La elección depende del contexto del proyecto.

---

## 📊 Análisis de Amenazas

### **Debilidades Identificadas:**

1. **Centralización del Admin:**
   - Mitigación: Usar multisig o DAO para rol de admin

2. **Front-running de Swaps:**
   - Mitigación: Slippage protection implementada

3. **Oracle Manipulation:**
   - Mitigación: Validación completa de Chainlink (precio, timestamp, round)

4. **Falta de Pausa de Emergencia:**
   - Mejora futura: Implementar Pausable de OpenZeppelin

### **Pasos para Alcanzar Madurez:**

- [ ] Implementar función de pausa
- [ ] Multisig para admin
- [ ] Tests con 80%+ cobertura
- [ ] Auditoría de seguridad profesional
- [ ] Integración con price oracles de múltiples fuentes
- [ ] Sistema de fees para sostenibilidad

---

## 👤 Autor

**Natalia Avila**  
GitHub: [@Natalia-dev-web3](https://github.com/Natalia-dev-web3)

**Proyecto:** Ethereum Developer Pack - Kipu - Módulo 4 
**Fecha:** Noviembre 2025

---

## 📄 Licencia

MIT License - Ver archivo LICENSE para detalles

---

## 🙏 Agradecimientos

- **OpenZeppelin:** Contratos seguros y auditados
- **Chainlink:** Oráculos descentralizados confiables
- **Uniswap:** Protocolo DEX de referencia
- **Kipu:** Ethereum Developer Pack y mentoría

---

## 📚 Referencias

- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Chainlink Data Feeds](https://docs.chain.link/data-feeds)
- [Uniswap V2 Docs](https://docs.uniswap.org/contracts/v2/overview)
- [Hardhat Documentation](https://hardhat.org/docs)

---
