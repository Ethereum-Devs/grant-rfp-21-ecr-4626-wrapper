// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.12;

interface ITrancheWrapper {
    function vault() external view returns (address);
}
