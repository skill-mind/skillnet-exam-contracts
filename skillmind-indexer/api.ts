// api.ts - API server for the indexer
import { Application, Router } from "https://deno.land/x/oak@v12.6.1/mod.ts";
import { PostgresClient } from "./db.ts";
// import { config } from "./constants.ts";

// Initialize the database client
const db = new PostgresClient();

// Create a new router
const router = new Router();

// Define routes

// Health check endpoint
router.get("/health", (ctx) => {
  ctx.response.body = { status: "ok", timestamp: new Date().toISOString() };
});

// Exams endpoints
router.get("/exams", async (ctx) => {
  try {
    const exams = await db.getExams(
      ctx.request.url.searchParams.get("limit") || 100,
      ctx.request.url.searchParams.get("offset") || 0,
      ctx.request.url.searchParams.get("creator"),
    );
    ctx.response.body = exams;
  } catch (error) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

router.get("/exams/:examId", async (ctx) => {
  try {
    const { examId } = ctx.params;
    if (!examId) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Exam ID is required" };
      return;
    }

    const exam = await db.getExamById(examId);
    if (!exam) {
      ctx.response.status = 404;
      ctx.response.body = { error: "Exam not found" };
      return;
    }

    // Get questions for this exam
    const questions = await db.getQuestionsByExamId(examId);

    // Get enrollments for this exam
    const enrollments = await db.getEnrollmentsByExamId(examId);

    ctx.response.body = {
      exam,
      questions,
      enrollments,
      questionCount: questions.length,
      enrollmentCount: enrollments.length,
    };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

// Questions endpoints
router.get("/questions/:examId", async (ctx) => {
  try {
    const { examId } = ctx.params;
    if (!examId) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Exam ID is required" };
      return;
    }

    const questions = await db.getQuestionsByExamId(examId);
    ctx.response.body = { questions };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

// Enrollments endpoints
router.get("/enrollments/exam/:examId", async (ctx) => {
  try {
    const { examId } = ctx.params;
    if (!examId) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Exam ID is required" };
      return;
    }

    const enrollments = await db.getEnrollmentsByExamId(examId);
    ctx.response.body = { enrollments };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

router.get("/enrollments/student/:student", async (ctx) => {
  try {
    const { student } = ctx.params;
    if (!student) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Student address is required" };
      return;
    }

    const enrollments = await db.getEnrollmentsByStudent(student);
    ctx.response.body = { enrollments };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

// Certificates endpoints
router.get("/certificates/:student", async (ctx) => {
  try {
    const { student } = ctx.params;
    if (!student) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Student address is required" };
      return;
    }

    const certificates = await db.getCertificatesByStudent(student);
    ctx.response.body = { certificates };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

// Transaction endpoints
router.get("/transactions/address/:address", async (ctx) => {
  try {
    const { address } = ctx.params;
    if (!address) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Address is required" };
      return;
    }

    const limit = ctx.request.url.searchParams.get("limit")
      ? parseInt(ctx.request.url.searchParams.get("limit")!)
      : 100;
    const offset = ctx.request.url.searchParams.get("offset")
      ? parseInt(ctx.request.url.searchParams.get("offset")!)
      : 0;

    const transactions = await db.getTransactionsByAddress(
      address,
      limit,
      offset,
    );
    ctx.response.body = { transactions };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

router.get("/transactions/token/:token", async (ctx) => {
  try {
    const { token } = ctx.params;
    if (!token) {
      ctx.response.status = 400;
      ctx.response.body = { error: "Token address is required" };
      return;
    }

    const limit = ctx.request.url.searchParams.get("limit")
      ? parseInt(ctx.request.url.searchParams.get("limit")!)
      : 100;
    const offset = ctx.request.url.searchParams.get("offset")
      ? parseInt(ctx.request.url.searchParams.get("offset")!)
      : 0;

    const transactions = await db.getTransactionsByToken(token, limit, offset);
    ctx.response.body = { transactions };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

// Statistics endpoints
router.get("/stats", async (ctx) => {
  try {
    const client = await db.getClient();

    // Get exam count
    const examResult = await client.queryObject(
      `SELECT COUNT(*) as exam_count FROM exams`,
    );
    const examCount = examResult.rows[0]?.exam_count || 0;

    // Get question count
    const questionResult = await client.queryObject(
      `SELECT COUNT(*) as question_count FROM questions`,
    );
    const questionCount = questionResult.rows[0]?.question_count || 0;

    // Get enrollment count
    const enrollmentResult = await client.queryObject(
      `SELECT COUNT(*) as enrollment_count FROM enrollments`,
    );
    const enrollmentCount = enrollmentResult.rows[0]?.enrollment_count || 0;

    // Get certificate count
    const certificateResult = await client.queryObject(
      `SELECT COUNT(*) as certificate_count FROM certificates`,
    );
    const certificateCount = certificateResult.rows[0]?.certificate_count || 0;

    // Get transaction count
    const transactionResult = await client.queryObject(
      `SELECT COUNT(*) as transaction_count FROM transactions`,
    );
    const transactionCount = transactionResult.rows[0]?.transaction_count || 0;

    // Get latest block number
    const blockResult = await client.queryObject(`
      SELECT MAX(block_number) as latest_block 
      FROM (
        SELECT MAX(block_number) as block_number FROM exams
        UNION 
        SELECT MAX(block_number) as block_number FROM questions
        UNION
        SELECT MAX(block_number) as block_number FROM enrollments
        UNION
        SELECT MAX(block_number) as block_number FROM exam_status_changes
        UNION
        SELECT MAX(block_number) as block_number FROM certificates
        UNION
        SELECT MAX(block_number) as block_number FROM transactions
      ) as blocks
    `);
    const latestBlock = blockResult.rows[0]?.latest_block || 0;

    client.release();

    ctx.response.body = {
      stats: {
        exams: examCount,
        questions: questionCount,
        enrollments: enrollmentCount,
        certificates: certificateCount,
        transactions: transactionCount,
        latestBlock,
      },
      timestamp: new Date().toISOString(),
    };
  } catch (error: any) {
    ctx.response.status = 500;
    ctx.response.body = { error: error.message };
  }
});

// Initialize the Oak application
const app = new Application();

// Error handling middleware
app.use(async (ctx, next) => {
  try {
    await next();
  } catch (err) {
    console.error(err);
    ctx.response.status = 500;
    ctx.response.body = { error: "Internal server error" };
  }
});

// Logger middleware
app.use(async (ctx, next) => {
  const start = Date.now();
  await next();
  const ms = Date.now() - start;
  console.log(`${ctx.request.method} ${ctx.request.url.pathname} - ${ms}ms`);
});

// CORS middleware
app.use(async (ctx, next) => {
  ctx.response.headers.set("Access-Control-Allow-Origin", "*");
  ctx.response.headers.set(
    "Access-Control-Allow-Methods",
    "GET, POST, OPTIONS",
  );
  ctx.response.headers.set("Access-Control-Allow-Headers", "Content-Type");

  if (ctx.request.method === "OPTIONS") {
    ctx.response.status = 204;
    return;
  }

  await next();
});

// Add the router
app.use(router.routes());
app.use(router.allowedMethods());

// Start the server
const PORT = Deno.env.get("PORT") || "8080";
console.log(`API server running on http://localhost:${PORT}`);

await app.listen({ port: parseInt(PORT) });
