// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library StableSwapMath {
    function getD(uint256[] memory _balances, uint256 A, uint256 n) internal pure returns (uint256) {
        uint256 sum = 0;
        uint256 Ann = A;
        bool allZero = true;
        for (uint256 i = 0; i < n; i++) {
            uint256 bal = _balances[i];
            if (bal != 0) allZero = false;
            else bal = 1;
            sum += bal;
            Ann *= n;
        }
        if (allZero) return 0;

        uint256 D = sum;
        for (uint256 i = 0; i < 255; i++) {
            uint256 pD = D;
            for (uint256 j = 0; j < n; j++) {
                pD = (pD * D) / (_balances[j] * n);
            }
            uint256 prevD = D;
            D = ((Ann * sum + pD * n) * D) / ((Ann - 1) * D + (n + 1) * pD);
            if (D > prevD && D - prevD <= 1 || D <= prevD && prevD - D <= 1) break;
        }
        return D;
    }

    function getY(
        uint256[] memory _balances,
        uint256 _j,
        uint256 _D,
        uint256 A,
        uint256 n
    )
        internal
        pure
        returns (uint256)
    {
        uint256 c = _D;
        uint256 S_ = 0;
        uint256 Ann = A;
        for (uint256 i = 0; i < n; i++) {
            Ann *= n;
            if (i == _j) continue;
            S_ += _balances[i];
            c = (c * _D) / (_balances[i] * n);
        }
        c = (c * _D) / (Ann * n);
        uint256 b = S_ + (_D / Ann);
        uint256 y = _D;
        for (uint256 i = 0; i < 255; i++) {
            uint256 prevY = y;
            y = (y * y + c) / (y * 2 + b - _D);
            if (y > prevY && y - prevY <= 1 || y <= prevY && prevY - y <= 1) break;
        }
        return y;
    }
}
