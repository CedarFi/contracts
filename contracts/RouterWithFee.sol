pragma solidity ^0.8.0;

import {Router} from "./Router.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IPoolCallee} from "./interfaces/IPoolCallee.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract RouterWithFee is Router, IPoolCallee {
    using SafeERC20 for IERC20;

    address public owner;
    address public feeRecipient;
    uint256 public fee = 100; //  1% as fee

    constructor(
        address _factoryRegistry,
        address _factory,
        address _voter,
        address _weth,
        address _feeRecipient
    ) Router(_factoryRegistry, _factory, _voter, _weth) {
        feeRecipient = _feeRecipient;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(owner == msg.sender);
        _;
    }

    function _swap(uint256[] memory amounts, Route[] memory routes, address _to) internal virtual override {
        uint256 _length = routes.length;
        for (uint256 i = 0; i < _length; i++) {
            (address token0, ) = sortTokens(routes[i].from, routes[i].to);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = routes[i].from == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < routes.length - 1
                ? poolFor(routes[i + 1].from, routes[i + 1].to, routes[i + 1].stable, routes[i + 1].factory)
                : address(this);
            bytes memory _bytes = to == address(this) ? abi.encode(_to) : new bytes(0);
            IPool(poolFor(routes[i].from, routes[i].to, routes[i].stable, routes[i].factory)).swap(
                amount0Out,
                amount1Out,
                to,
                _bytes
            );
        }
    }

    function _swapSupportingFeeOnTransferTokens(Route[] memory routes, address _to) internal virtual override {
        uint256 _length = routes.length;
        for (uint256 i; i < _length; i++) {
            (address token0, ) = sortTokens(routes[i].from, routes[i].to);
            address pool = poolFor(routes[i].from, routes[i].to, routes[i].stable, routes[i].factory);
            uint256 amountInput;
            uint256 amountOutput;
            {
                // stack too deep
                (uint256 reserveA, ) = getReserves(routes[i].from, routes[i].to, routes[i].stable, routes[i].factory); // getReserves sorts it for us i.e. reserveA is always for from
                amountInput = IERC20(routes[i].from).balanceOf(pool) - reserveA;
            }
            amountOutput = IPool(pool).getAmountOut(amountInput, routes[i].from);
            (uint256 amount0Out, uint256 amount1Out) = routes[i].from == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < routes.length - 1
                ? poolFor(routes[i + 1].from, routes[i + 1].to, routes[i + 1].stable, routes[i + 1].factory)
                : address(this);
            bytes memory _bytes = to == address(this) ? abi.encode(_to) : new bytes(0);
            IPool(pool).swap(amount0Out, amount1Out, to, _bytes);
        }
    }

    function hook(address, uint256 amount0, uint256 amount1, bytes calldata data) external {
        IPool lp = IPool(msg.sender);
        address token0 = lp.token0();
        address token1 = lp.token1();
        address recipient = abi.decode(data, (address)); // Swap recipient

        // Conditional (necessary to handle ERC20 => ETH swaps)
        if (recipient != address(this)) {
            if (amount0 > 0) {
                uint256 _fee = (fee * amount0) / 10000; // Fee for recipient
                uint256 amountOut = amount0 - _fee;
                IERC20(token0).safeTransfer(recipient, amountOut); // Transfer to recipient
                IERC20(token0).safeTransfer(feeRecipient, _fee); // Transfer fee
            }

            if (amount1 > 0) {
                uint256 _fee = (fee * amount1) / 10000; // Fee for recipient
                uint256 amountOut = amount1 - _fee;
                IERC20(token1).safeTransfer(recipient, amountOut); // Transfer to recipient
                IERC20(token1).safeTransfer(feeRecipient, _fee); // Transfer fee
            }
        } else {
            if (amount0 > 0) {
                // Just send out fee since contract would handle the other disbursements
                uint256 _fee = (fee * amount0) / 10000; // Fee for recipient
                IERC20(token0).safeTransfer(feeRecipient, _fee); // Transfer fee
            }

            if (amount1 > 0) {
                // Just send out fee since contract would handle the other disbursements
                uint256 _fee = (fee * amount1) / 10000; // Fee for recipient
                IERC20(token1).safeTransfer(feeRecipient, _fee); // Transfer fee
            }
        }
    }

    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    function setFee(uint256 _fee) external onlyOwner {
        require(_fee <= 400); // Fee must be at most 4%
        fee = _fee;
    }

    function _transferOwnership(address newOwner) internal {
        owner = newOwner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        _transferOwnership(newOwner);
    }

    function relinquishOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }
}
