// Starknet related dependencies
export { hash } from "https://esm.sh/starknet@5.19.5";
export { uint256 } from "https://esm.sh/starknet@5.19.5";
export { formatUnits } from "https://esm.sh/ethers@6.7.1";

// Apibara types and interfaces
export type Block = {
  header?: {
    blockNumber: string;
    blockHash: string;
    parentHash: string;
    timestamp: string;
  };
  events: EventWithTransaction[];
};

export type EventWithTransaction = {
  event: {
    fromAddress: string;
    keys: string[];
    data: string[];
  };
  transaction?: {
    meta: {
      hash: string;
      // Add other transaction metadata as needed
    };
    // Add other transaction fields as needed
  };
  receipt?: {
    // Add receipt fields as needed
  };
};

// Utility functions
export function decodeToString(hex: string): string {
  // Remove '0x' prefix if present
  const cleanHex = hex.startsWith("0x") ? hex.slice(2) : hex;

  // Convert hex to ASCII
  let result = "";
  for (let i = 0; i < cleanHex.length; i += 2) {
    const hexChar = cleanHex.substr(i, 2);
    const charCode = parseInt(hexChar, 16);
    if (charCode > 0) {
      result += String.fromCharCode(charCode);
    }
  }

  return result;
}

// Utility to convert bigint to a more readable format
export function bigintToString(value: bigint): string {
  return value.toString();
}
