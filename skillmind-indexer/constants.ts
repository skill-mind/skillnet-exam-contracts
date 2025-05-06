import { hash } from "./deps.ts";

// Format a big integer to a hex string
export function formatFelt(key: bigint): string {
  return "0x" + key.toString(16);
}

// Define event selectors
export const SELECTOR_KEYS = {
  TRANSFER: BigInt(hash.getSelectorFromName("Transfer")),
  // Education platform event selectors
  EXAM_CREATED: BigInt(hash.getSelectorFromName("ExamCreated")),
  QUESTION_ADDED: BigInt(hash.getSelectorFromName("QuestionAdded")),
  STUDENT_ENROLLED: BigInt(hash.getSelectorFromName("StudentEnrolled")),
  EXAM_STATUS_CHANGED: BigInt(hash.getSelectorFromName("ExamStatusChanged")),
  COURSE_CERT_CLAIMED: BigInt(hash.getSelectorFromName("CourseCertClaimed")),
  // SRC5 and Access Control events if needed
  ACCESS_CONTROL_EVENT: BigInt(hash.getSelectorFromName("AccessControlEvent")),
  SRC5_EVENT: BigInt(hash.getSelectorFromName("SRC5Event")),
};

// Environment variables
export const FINALITY = Deno.env.get("FINALITY") || "DATA_STATUS_ACCEPTED";
export const DB_CONNECTION_STRING = Deno.env.get("DB_CONNECTION_STRING") ||
  "postgres://postgres:password@localhost:5432/postgres";
export const CONTRACT_ADDRESS = Deno.env.get("CONTRACT_ADDRESS") || "";

// Token decimal places for formatting amounts
export const DECIMALS = 18;

// Get token contracts from environment variables
const TOKEN_CONTRACTS_LEN = parseInt(
  Deno.env.get("TOKEN_CONTRACTS_LEN") || "0",
);

// Dynamically retrieve each token contract
export const TOKEN_CONTRACTS: string[] = [];
for (let i = 0; i < TOKEN_CONTRACTS_LEN; i++) {
  const tokenContractEnvName = `TOKEN_CONTRACT_${i}`;
  const tokenContract = Deno.env.get(tokenContractEnvName) || "";
  if (tokenContract) {
    TOKEN_CONTRACTS.push(tokenContract);
  }
}

// Constants for pagination in API endpoints
export const DEFAULT_PAGE_SIZE = 50;
export const MAX_PAGE_SIZE = 100;

// Network configuration
export const NETWORK = Deno.env.get("NETWORK") || "mainnet";
export const STARTING_BLOCK = Number(Deno.env.get("STARTING_BLOCK") || "0");

// API configuration
export const API_PORT = Number(Deno.env.get("API_PORT") || "8000");
