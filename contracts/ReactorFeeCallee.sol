pragma solidity ^0.8.0;

import {IPoolCallee} from "./interfaces/IPoolCallee.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ReactorFeeCallee is IPoolCallee, Ownable {
    using SafeERC20 for IERC20;

    address public feeRecipient;
    address public WETH;
    address public routerWithoutFee;

    constructor(address _feeRecipient, address _newOwner, address _WETH, address _routerWithoutFee) Ownable() {
        feeRecipient = _feeRecipient;
        WETH = _WETH;
        routerWithoutFee = _routerWithoutFee;
        _transferOwnership(_newOwner);
    }

    function hook(address, uint256 amount0, uint256 amount1, bytes calldata data) external {
        IPool lp = IPool(msg.sender);
        (address receiver, uint256 feePercentage) = abi.decode(data, (address, uint256));
        bytes memory selectorWithArguments;
        uint256 fee;

        if (amount0 > 0) {
            fee = (amount0 * feePercentage) / 10000;
            uint256 out = amount0 - fee;
            IERC20(lp.token0()).safeTransfer(receiver, out);
            IRouter.Route[] memory routes = new IRouter.Route[](1);
            routes[0].from = lp.token0();
            routes[0].to = lp.token1();
            routes[0].stable = lp.stable();
            routes[0].factory = lp.factory();
            bytes4 selector = routes[0].to == WETH
                ? IRouter.swapExactTokensForETHSupportingFeeOnTransferTokens.selector
                : IRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens.selector;
            selectorWithArguments = abi.encodeWithSelector(
                selector,
                fee,
                0,
                routes,
                feeRecipient,
                block.timestamp + 20 minutes
            );
        } else if (amount1 > 0) {
            fee = (amount1 * feePercentage) / 10000;
            uint256 out = amount1 - fee;
            IERC20(lp.token1()).safeTransfer(receiver, out);
            IRouter.Route[] memory routes = new IRouter.Route[](1);
            routes[0].from = lp.token1();
            routes[0].to = lp.token0();
            routes[0].stable = lp.stable();
            routes[0].factory = lp.factory();
            bytes4 selector = routes[0].to == WETH
                ? IRouter.swapExactTokensForETHSupportingFeeOnTransferTokens.selector
                : IRouter.swapExactTokensForTokensSupportingFeeOnTransferTokens.selector;
            selectorWithArguments = abi.encodeWithSelector(
                selector,
                fee,
                0,
                routes,
                feeRecipient,
                block.timestamp + 20 minutes
            );
        }

        (bool success, ) = routerWithoutFee.call(selectorWithArguments);
        require(success, "LLC");
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        require(_feeRecipient != feeRecipient, "FR");
        feeRecipient = _feeRecipient;
    }
}
