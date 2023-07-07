// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC20} from "../../lib/solmate/src/tokens/ERC20.sol";

import {Permit2} from "../Permit2.sol";
import {IDAIPermit} from "../interfaces/IDAIPermit.sol";
import {IAllowanceTransfer} from "../interfaces/IAllowanceTransfer.sol";
import {SafeCast160} from "../libraries/SafeCast160.sol";

/// @title Permit2Lib
/// @notice Enables efficient transfers and EIP-2612/DAI
/// permits for any token by falling back to Permit2.
library Permit2LibWithCustomPermit2Address {
    using SafeCast160 for uint256;
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev The unique EIP-712 domain domain separator for the DAI token contract.
    bytes32 internal constant DAI_DOMAIN_SEPARATOR = 0xdbb8cf42e1ecb028be3f3dbc922e1d878b963f411dc388ced501601c60f7c6f7;

    /// @dev The address of the Permit2 contract the library will use.
    Permit2 internal constant PERMIT2 = Permit2(address(0x28D81506519D32a212fB098658abf4a9CCe60d59));

    /// @notice Transfer a given amount of tokens from one user to another.
    /// @param token The token to transfer.
    /// @param from The user to transfer from.
    /// @param to The user to transfer to.
    /// @param amount The amount to transfer.
    function transferFrom2(ERC20 token, address from, address to, uint256 amount) internal {
        // Generate calldata for a standard transferFrom call.
        bytes memory inputData = abi.encodeCall(ERC20.transferFrom, (from, to, amount));

        bool success; // Call the token contract as normal, capturing whether it succeeded.
        assembly {
            success :=
                and(
                    // Set success to whether the call reverted, if not we check it either
                    // returned exactly 1 (can't just be non-zero data), or had no return data.
                    or(eq(mload(0), 1), iszero(returndatasize())),
                    // Counterintuitively, this call() must be positioned after the or() in the
                    // surrounding and() because and() evaluates its arguments from right to left.
                    // We use 0 and 32 to copy up to 32 bytes of return data into the first slot of scratch space.
                    call(gas(), token, 0, add(inputData, 32), mload(inputData), 0, 32)
                )
        }

        // We'll fall back to using Permit2 if calling transferFrom on the token directly reverted.
        if (!success) PERMIT2.transferFrom(from, to, amount.toUint160(), address(token));
    }

    /*//////////////////////////////////////////////////////////////
                              PERMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Permit a user to spend a given amount of
    /// another user's tokens via the owner's EIP-712 signature.
    /// @param token The token to permit spending.
    /// @param owner The user to permit spending from.
    /// @param spender The user to permit spending to.
    /// @param amount The amount to permit spending.
    /// @param deadline  The timestamp after which the signature is no longer valid.
    /// @param v Must produce valid secp256k1 signature from the owner along with r and s.
    /// @param r Must produce valid secp256k1 signature from the owner along with v and s.
    /// @param s Must produce valid secp256k1 signature from the owner along with r and v.
    function permit2(
        ERC20 token,
        address owner,
        address spender,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        // Generate calldata for a call to DOMAIN_SEPARATOR on the token.
        bytes memory inputData = abi.encodeWithSelector(ERC20.DOMAIN_SEPARATOR.selector);

        bool success; // Call the token contract as normal, capturing whether it succeeded.
        bytes32 domainSeparator; // If the call succeeded, we'll capture the return value here.
        assembly {
            success :=
                and(
                    // Should resolve false if its not 32 bytes or its first word is 0.
                    and(iszero(iszero(mload(0))), eq(returndatasize(), 32)),
                    // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                    // Counterintuitively, this call must be positioned second to the and() call in the
                    // surrounding and() call or else returndatasize() will be zero during the computation.
                    staticcall(gas(), token, add(inputData, 32), mload(inputData), 0, 32)
                )

            domainSeparator := mload(0) // Copy the return value into the domainSeparator variable.
        }

        // If the call to DOMAIN_SEPARATOR succeeded, try using permit on the token.
        if (success) {
            // We'll use DAI's special permit if it's DOMAIN_SEPARATOR matches,
            // otherwise we'll just encode a call to the standard permit function.
            inputData = domainSeparator == DAI_DOMAIN_SEPARATOR
                ? abi.encodeCall(IDAIPermit.permit, (owner, spender, token.nonces(owner), deadline, true, v, r, s))
                : abi.encodeCall(ERC20.permit, (owner, spender, amount, deadline, v, r, s));

            assembly {
                success := call(gas(), token, 0, add(inputData, 32), mload(inputData), 0, 0)
            }
        }

        if (!success) {
            // If the initial DOMAIN_SEPARATOR call on the token failed or a
            // subsequent call to permit failed, fall back to using Permit2.

            (,, uint48 nonce) = PERMIT2.allowance(owner, address(token), spender);

            PERMIT2.permit(
                owner,
                IAllowanceTransfer.PermitSingle({
                    details: IAllowanceTransfer.PermitDetails({
                        token: address(token),
                        amount: amount.toUint160(),
                        // Use an unlimited expiration because it most
                        // closely mimics how a standard approval works.
                        expiration: type(uint48).max,
                        nonce: nonce
                    }),
                    spender: spender,
                    sigDeadline: deadline
                }),
                bytes.concat(r, s, bytes1(v))
            );
        }
    }
}