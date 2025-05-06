import {
  CONTRACT_ADDRESS,
  DB_CONNECTION_STRING,
  DECIMALS,
  FINALITY,
  formatFelt,
  SELECTOR_KEYS,
  TOKEN_CONTRACTS,
} from "./constants.ts";
import { Block, EventWithTransaction, formatUnits, uint256 } from "./deps.ts";
import type {
  Config,
  NetworkOptions,
  SinkOptions,
} from "https://esm.sh/@apibara/indexer";
import { PostgresClient } from "./db.ts";

// Define the events you want to track from your contract
const events = [
  {
    fromAddress: CONTRACT_ADDRESS,
    keys: [formatFelt(SELECTOR_KEYS.EXAM_CREATED)],
    includeTransaction: true,
    includeReceipt: false,
  },
  {
    fromAddress: CONTRACT_ADDRESS,
    keys: [formatFelt(SELECTOR_KEYS.QUESTION_ADDED)],
    includeTransaction: true,
    includeReceipt: false,
  },
  {
    fromAddress: CONTRACT_ADDRESS,
    keys: [formatFelt(SELECTOR_KEYS.STUDENT_ENROLLED)],
    includeTransaction: true,
    includeReceipt: false,
  },
  {
    fromAddress: CONTRACT_ADDRESS,
    keys: [formatFelt(SELECTOR_KEYS.EXAM_STATUS_CHANGED)],
    includeTransaction: true,
    includeReceipt: false,
  },
  {
    fromAddress: CONTRACT_ADDRESS,
    keys: [formatFelt(SELECTOR_KEYS.COURSE_CERT_CLAIMED)],
    includeTransaction: true,
    includeReceipt: false,
  },
  // Add more events as needed
];

// Add token contract events if needed
for (const tokenContract of TOKEN_CONTRACTS) {
  events.push({
    fromAddress: tokenContract,
    keys: [formatFelt(SELECTOR_KEYS.TRANSFER)],
    includeTransaction: false,
    includeReceipt: false,
  });
}

// Create the filter for Apibara
const filter = {
  header: { weak: true },
  events,
};

// Export the configuration for Apibara
export const config: Config<NetworkOptions, SinkOptions> = {
  streamUrl: Deno.env.get("STREAM_URL_SEPOLIA"),
  startingBlock: Number(Deno.env.get("STARTING_BLOCK")),
  network: "starknet",
  filter,
  sinkType: "postgres",
  finality: FINALITY,
  sinkOptions: {
    // Connection string for PostgreSQL
    connectionString: Deno.env.get("DB_CONNECTION_STRING"),
    database: "postgres",

    noTls: true, // Disable TLS for local development

    // Default mode: uses insertMany to insert data into tables
    entityMode: true,
  },
};

// Define types for each event
type TransactionDocument = {
  tx_hash: string;
  from_address: string;
  to_address: string;
  amount: number;
  token: string;
  timestamp: number;
  block_number: number;
};

type ExamDocument = {
  exam_id: string;
  title: string;
  creator: string;
  datetime: number;
  duration: number;
  is_active: boolean;
  timestamp: number;
  block_number: number;
  tx_hash: string;
};

type QuestionDocument = {
  exam_id: string;
  question_id: string;
  timestamp: number;
  block_number: number;
  tx_hash: string;
};

type EnrollmentDocument = {
  exam_id: string;
  student: string;
  timestamp: number;
  block_number: number;
  tx_hash: string;
};

type ExamStatusDocument = {
  exam_id: string;
  is_active: boolean;
  timestamp: number;
  block_number: number;
  tx_hash: string;
};

type CertificateDocument = {
  cert_id: string;
  student: string;
  timestamp: number;
  block_number: number;
  tx_hash: string;
};

// Initialize database connection
const db = new PostgresClient();

// Main transform function that processes incoming events
export default async function transform({ header, events }: Block) {
  if (!header) return [];

  const timestamp = Math.floor(new Date(header.timestamp).getTime() / 1000);
  const blockNumber = Number(header.blockNumber);

  // Process the events
  const result = await processEvents(timestamp, blockNumber, events);

  console.log(`Processed ${events.length} events from block ${blockNumber}`);

  if (result.examsCreated > 0) {
    console.log(`Saved ${result.examsCreated} new exams`);
  }

  if (result.questionsAdded > 0) {
    console.log(`Saved ${result.questionsAdded} questions`);
  }

  if (result.studentsEnrolled > 0) {
    console.log(`Saved ${result.studentsEnrolled} enrollments`);
  }

  if (result.statusChanges > 0) {
    console.log(`Saved ${result.statusChanges} exam status changes`);
  }

  if (result.certificatesClaimed > 0) {
    console.log(`Saved ${result.certificatesClaimed} certificates`);
  }

  if (result.transfers > 0) {
    console.log(`Saved ${result.transfers} token transfers`);
  }
}

// Helper function to convert ByteArray to string
function decodeByteArray(data: string): string {
  try {
    // Remove '0x' prefix if present
    const cleanHex = data.startsWith("0x") ? data.slice(2) : data;

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
  } catch (error) {
    console.error("Error decoding ByteArray:", error);
    return "[Decoding Error]";
  }
}

// Complete the processEvents function to handle all event types
async function processEvents(
  timestamp: number,
  blockNumber: number,
  events: EventWithTransaction[],
): Promise<{
  examsCreated: number;
  questionsAdded: number;
  studentsEnrolled: number;
  statusChanges: number;
  certificatesClaimed: number;
  transfers: number;
}> {
  let examsCreated = 0;
  let questionsAdded = 0;
  let studentsEnrolled = 0;
  let statusChanges = 0;
  let certificatesClaimed = 0;
  let transfers = 0;

  // Process each event
  for (const { event, transaction } of events) {
    if (!event || !event.keys || event.keys.length === 0) continue;

    const key = BigInt(event.keys[0]);
    const txHash = transaction?.meta?.hash || "";

    try {
      switch (key) {
        case SELECTOR_KEYS.EXAM_CREATED: {
          if (!event.data || event.data.length < 6) continue;

          // Parse ExamCreated event
          // [exam_id_low, exam_id_high, title, creator, datetime, duration, is_active]
          const examIdLow = event.data[0];
          const examIdHigh = event.data[1];
          const examId = uint256.uint256ToBN({
            low: BigInt(examIdLow),
            high: BigInt(examIdHigh),
          }).toString();

          const title = decodeByteArray(event.data[2]);
          const creator = event.data[3];
          const datetime = BigInt(event.data[4]).toString();
          const duration = BigInt(event.data[5]).toString();
          const isActive = event.data[6] === "0x1"; // Convert hex to boolean

          const examDoc: ExamDocument = {
            exam_id: examId,
            title,
            creator,
            datetime: parseInt(datetime),
            duration: parseInt(duration),
            is_active: isActive,
            timestamp,
            block_number: blockNumber,
            tx_hash: txHash,
          };

          await db.saveExam(examDoc);
          examsCreated++;
          break;
        }

        case SELECTOR_KEYS.QUESTION_ADDED: {
          if (!event.data || event.data.length < 4) continue;

          // Parse QuestionAdded event
          // [exam_id_low, exam_id_high, question_id_low, question_id_high]
          const examIdLow = event.data[0];
          const examIdHigh = event.data[1];
          const examId = uint256.uint256ToBN({
            low: BigInt(examIdLow),
            high: BigInt(examIdHigh),
          }).toString();

          const questionIdLow = event.data[2];
          const questionIdHigh = event.data[3];
          const questionId = uint256.uint256ToBN({
            low: BigInt(questionIdLow),
            high: BigInt(questionIdHigh),
          }).toString();

          const questionDoc: QuestionDocument = {
            exam_id: examId,
            question_id: questionId,
            timestamp,
            block_number: blockNumber,
            tx_hash: txHash,
          };

          await db.saveQuestion(questionDoc);
          questionsAdded++;
          break;
        }

        case SELECTOR_KEYS.STUDENT_ENROLLED: {
          if (!event.data || event.data.length < 3) continue;

          // Parse StudentEnrolled event
          // [exam_id_low, exam_id_high, student_address]
          const examIdLow = event.data[0];
          const examIdHigh = event.data[1];
          const examId = uint256.uint256ToBN({
            low: BigInt(examIdLow),
            high: BigInt(examIdHigh),
          }).toString();

          const student = event.data[2];

          const enrollmentDoc: EnrollmentDocument = {
            exam_id: examId,
            student,
            timestamp,
            block_number: blockNumber,
            tx_hash: txHash,
          };

          await db.saveEnrollment(enrollmentDoc);
          studentsEnrolled++;
          break;
        }

        case SELECTOR_KEYS.EXAM_STATUS_CHANGED: {
          if (!event.data || event.data.length < 3) continue;

          // Parse ExamStatusChanged event
          // [exam_id_low, exam_id_high, is_active]
          const examIdLow = event.data[0];
          const examIdHigh = event.data[1];
          const examId = uint256.uint256ToBN({
            low: BigInt(examIdLow),
            high: BigInt(examIdHigh),
          }).toString();

          const isActive = event.data[2] === "0x1"; // Convert hex to boolean

          const statusDoc: ExamStatusDocument = {
            exam_id: examId,
            is_active: isActive,
            timestamp,
            block_number: blockNumber,
            tx_hash: txHash,
          };

          await db.saveExamStatus(statusDoc);
          statusChanges++;
          break;
        }

        case SELECTOR_KEYS.COURSE_CERT_CLAIMED: {
          if (!event.data || event.data.length < 3) continue;

          // Parse CourseCertClaimed event
          // [cert_id_low, cert_id_high, student_address]
          const certIdLow = event.data[0];
          const certIdHigh = event.data[1];
          const certId = uint256.uint256ToBN({
            low: BigInt(certIdLow),
            high: BigInt(certIdHigh),
          }).toString();

          const student = event.data[2];

          const certDoc: CertificateDocument = {
            cert_id: certId,
            student,
            timestamp,
            block_number: blockNumber,
            tx_hash: txHash,
          };

          await db.saveCertificate(certDoc);
          certificatesClaimed++;
          break;
        }

        case SELECTOR_KEYS.TRANSFER: {
          if (!event.data || event.data.length < 5) continue;

          // Parse Transfer event from ERC20 tokens
          // [from, to, amount_low, amount_high]
          const fromAddress = event.data[0];
          const toAddress = event.data[1];
          const amountLow = event.data[2];
          const amountHigh = event.data[3];
          const amount = uint256.uint256ToBN({
            low: BigInt(amountLow),
            high: BigInt(amountHigh),
          });

          // Format amount with proper decimals
          const formattedAmount = parseFloat(formatUnits(amount, DECIMALS));

          // Get token address from the event
          const tokenAddress = event.fromAddress;

          const transferDoc: TransactionDocument = {
            tx_hash: txHash,
            from_address: fromAddress,
            to_address: toAddress,
            amount: formattedAmount,
            token: tokenAddress,
            timestamp,
            block_number: blockNumber,
          };

          // Save transfer
          await db.saveTransactions([transferDoc]);
          transfers++;
          break;
        }
      }
    } catch (error) {
      console.error(
        `Error processing event with key ${key.toString(16)}:`,
        error,
      );
    }
  }

  return {
    examsCreated,
    questionsAdded,
    studentsEnrolled,
    statusChanges,
    certificatesClaimed,
    transfers,
  };
}
