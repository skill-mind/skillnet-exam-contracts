import { Pool, PoolClient } from "https://deno.land/x/postgres@v0.17.0/mod.ts";
import { DB_CONNECTION_STRING } from "./constants.ts";

// Define the type of transaction data we'll store
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

export class PostgresClient {
    private pool: Pool;

    constructor() {
        this.pool = new Pool(DB_CONNECTION_STRING, 10);
        this.initialize();
    }

    // Initialize database tables if they don't exist
    private async initialize() {
        const client = await this.pool.connect();
        try {
            // Create tables for education platform events
            await client.queryObject("BEGIN");

            // Exams table
            await client.queryObject(`
        CREATE TABLE IF NOT EXISTS exams (
          id SERIAL PRIMARY KEY,
          exam_id TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          creator TEXT NOT NULL,
          datetime BIGINT NOT NULL,
          duration BIGINT NOT NULL,
          is_active BOOLEAN NOT NULL,
          timestamp BIGINT NOT NULL,
          block_number BIGINT NOT NULL,
          tx_hash TEXT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          _cursor INT8RANGE
        );
        
        CREATE INDEX IF NOT EXISTS idx_exams_cursor ON exams(_cursor);
        CREATE INDEX IF NOT EXISTS idx_exams_exam_id ON exams(exam_id);
        CREATE INDEX IF NOT EXISTS idx_exams_creator ON exams(creator);
      `);

            // Questions table
            await client.queryObject(`
        CREATE TABLE IF NOT EXISTS questions (
          id SERIAL PRIMARY KEY,
          exam_id TEXT NOT NULL,
          question_id TEXT NOT NULL,
          timestamp BIGINT NOT NULL,
          block_number BIGINT NOT NULL,
          tx_hash TEXT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(exam_id, question_id),
          _cursor INT8RANGE
        );
        
                CREATE INDEX IF NOT EXISTS idx_questions_cursor ON questions(_cursor);
        CREATE INDEX IF NOT EXISTS idx_questions_exam_id ON questions(exam_id);
      `);

            // Enrollments table
            await client.queryObject(`
        CREATE TABLE IF NOT EXISTS enrollments (
          id SERIAL PRIMARY KEY,
          exam_id TEXT NOT NULL,
          student TEXT NOT NULL,
          timestamp BIGINT NOT NULL,
          block_number BIGINT NOT NULL,
          tx_hash TEXT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(exam_id, student),
          _cursor INT8RANGE
        );
        
                CREATE INDEX IF NOT EXISTS idx_enrollments_cursor ON enrollments(_cursor); 
        CREATE INDEX IF NOT EXISTS idx_enrollments_exam_id ON enrollments(exam_id); 
        CREATE INDEX IF NOT EXISTS idx_enrollments_student ON enrollments(student); 
      `);

            // Exam status changes table
            await client.queryObject(`
        CREATE TABLE IF NOT EXISTS exam_status_changes (
          id SERIAL PRIMARY KEY,
          exam_id TEXT NOT NULL,
          is_active BOOLEAN NOT NULL,
          timestamp BIGINT NOT NULL,
          block_number BIGINT NOT NULL,
          tx_hash TEXT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          _cursor INT8RANGE
        );
        
                CREATE INDEX IF NOT EXISTS idx_exam_status_changes_cursor ON exam_status_changes(_cursor);
        CREATE INDEX IF NOT EXISTS idx_exam_status_changes_exam_id ON exam_status_changes(exam_id);
      `);

            // Certificates table
            await client.queryObject(`
        CREATE TABLE IF NOT EXISTS certificates (
          id SERIAL PRIMARY KEY,
          cert_id TEXT NOT NULL UNIQUE,
          student TEXT NOT NULL,    
          timestamp BIGINT NOT NULL,
          block_number BIGINT NOT NULL,
          tx_hash TEXT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          _cursor INT8RANGE
        );
        
                CREATE INDEX IF NOT EXISTS idx_certificates_cursor ON certificates(_cursor);
        CREATE INDEX IF NOT EXISTS idx_certificates_student ON certificates(student);
      `);

            // Create a generic transactions table for other events
            await client.queryObject(`
        CREATE TABLE IF NOT EXISTS transactions (
          id SERIAL PRIMARY KEY,
          tx_hash TEXT NOT NULL,
          from_address TEXT NOT NULL,
          to_address TEXT NOT NULL,
          amount NUMERIC(78, 18) NOT NULL,
          token TEXT NOT NULL,    
          timestamp BIGINT NOT NULL,
          block_number BIGINT NOT NULL,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
          _cursor INT8RANGE
        );
        
        -- Create indexes for faster queries
                CREATE INDEX IF NOT EXISTS idx_transactions_cursor ON transactions(_cursor);
        CREATE INDEX IF NOT EXISTS idx_transactions_tx_hash ON transactions(tx_hash);
        CREATE INDEX IF NOT EXISTS idx_transactions_from_address ON transactions(from_address);
        CREATE INDEX IF NOT EXISTS idx_transactions_to_address ON transactions(to_address);
        CREATE INDEX IF NOT EXISTS idx_transactions_token ON transactions(token);
        CREATE INDEX IF NOT EXISTS idx_transactions_block_number ON transactions(block_number);
      `);

            console.log("Database initialized successfully");
        } catch (error) {
            console.error("Error initializing database:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Save multiple transactions in a single batch
    async saveTransactions(transactions: TransactionDocument[]): Promise<void> {
        if (transactions.length === 0) return;

        const client = await this.pool.connect();
        try {
            // Begin transaction
            await client.queryObject("BEGIN");

            for (const tx of transactions) {
                await client.queryObject(
                    `
          INSERT INTO transactions 
          (tx_hash, from_address, to_address, amount, token, timestamp, block_number)
          VALUES ($1, $2, $3, $4, $5, $6, $7)
        `,
                    [
                        tx.tx_hash,
                        tx.from_address,
                        tx.to_address,
                        tx.amount.toString(), // Convert to string for NUMERIC type
                        tx.token,
                        tx.timestamp,
                        tx.block_number,
                    ],
                );
            }

            // Commit transaction
            await client.queryObject("COMMIT");
        } catch (error) {
            await client.queryObject("ROLLBACK");
            console.error("Error saving transactions:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get transactions by address (either sender or receiver)
    async getTransactionsByAddress(
        address: string,
        limit = 100,
        offset = 0,
    ): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT * FROM transactions
        WHERE from_address = $1 OR to_address = $1
        ORDER BY block_number DESC, timestamp DESC
        LIMIT $2 OFFSET $3
      `,
                [address, limit, offset],
            );

            return result.rows;
        } catch (error) {
            console.error("Error fetching transactions:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get transactions for a specific token
    async getTransactionsByToken(
        token: string,
        limit = 100,
        offset = 0,
    ): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT * FROM transactions
        WHERE token = $1
        ORDER BY block_number DESC, timestamp DESC
        LIMIT $2 OFFSET $3
      `,
                [token, limit, offset],
            );

            return result.rows;
        } catch (error) {
            console.error("Error fetching token transactions:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Save exam creation data
    async saveExam(exam: ExamDocument): Promise<void> {
        const client = await this.pool.connect();
        try {
            await client.queryObject(
                `
        INSERT INTO exams 
        (exam_id, title, creator, datetime, duration, is_active, timestamp, block_number, tx_hash)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (exam_id) DO NOTHING
      `,
                [
                    exam.exam_id,
                    exam.title,
                    exam.creator,
                    exam.datetime,
                    exam.duration,
                    exam.is_active,
                    exam.timestamp,
                    exam.block_number,
                    exam.tx_hash,
                ],
            );
        } catch (error) {
            console.error("Error saving exam:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Save question data
    async saveQuestion(question: QuestionDocument): Promise<void> {
        const client = await this.pool.connect();
        try {
            await client.queryObject(
                `
        INSERT INTO questions 
        (exam_id, question_id, timestamp, block_number, tx_hash)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (exam_id, question_id) DO NOTHING
      `,
                [
                    question.exam_id,
                    question.question_id,
                    question.timestamp,
                    question.block_number,
                    question.tx_hash,
                ],
            );
        } catch (error) {
            console.error("Error saving question:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Save enrollment data
    async saveEnrollment(enrollment: EnrollmentDocument): Promise<void> {
        const client = await this.pool.connect();
        try {
            await client.queryObject(
                `
        INSERT INTO enrollments 
        (exam_id, student, timestamp, block_number, tx_hash)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (exam_id, student) DO NOTHING
      `,
                [
                    enrollment.exam_id,
                    enrollment.student,
                    enrollment.timestamp,
                    enrollment.block_number,
                    enrollment.tx_hash,
                ],
            );
        } catch (error) {
            console.error("Error saving enrollment:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Save exam status change
    async saveExamStatus(status: ExamStatusDocument): Promise<void> {
        const client = await this.pool.connect();
        try {
            await client.queryObject(
                `
        INSERT INTO exam_status_changes 
        (exam_id, is_active, timestamp, block_number, tx_hash)
        VALUES ($1, $2, $3, $4, $5)
      `,
                [
                    status.exam_id,
                    status.is_active,
                    status.timestamp,
                    status.block_number,
                    status.tx_hash,
                ],
            );

            // Also update the is_active status in the exams table
            await client.queryObject(
                `
        UPDATE exams
        SET is_active = $1
        WHERE exam_id = $2
      `,
                [status.is_active, status.exam_id],
            );
        } catch (error) {
            console.error("Error saving exam status:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Save certificate data
    async saveCertificate(cert: CertificateDocument): Promise<void> {
        const client = await this.pool.connect();
        try {
            await client.queryObject(
                `
        INSERT INTO certificates 
        (cert_id, student, timestamp, block_number, tx_hash)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (cert_id) DO NOTHING
      `,
                [
                    cert.cert_id,
                    cert.student,
                    cert.timestamp,
                    cert.block_number,
                    cert.tx_hash,
                ],
            );
        } catch (error) {
            console.error("Error saving certificate:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get exams
    async getExams(limit = 100, offset = 0, creator = ""): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            let query = `
            SELECT * FROM exams
            WHERE upper_inf(_cursor)
        `;
            const params: any[] = [];

            if (creator) {
                query += ` AND creator = $${params.length + 1}`;
                params.push(creator);
            }

            query += `
            ORDER BY datetime DESC
            LIMIT $${params.length + 1}
            OFFSET $${params.length + 2}
        `;
            params.push(limit, offset);

            const result = await client.queryObject(query, params);
            return result.rows;
        } catch (error) {
            console.error("Error fetching exams:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get exam by ID
    async getExamById(examId: string): Promise<any> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT * FROM exams
        WHERE exam_id = $1
      `,
                [examId],
            );

            if (result.rows.length === 0) {
                return null;
            }

            return result.rows[0];
        } catch (error) {
            console.error("Error fetching exam by ID:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get questions by exam ID
    async getQuestionsByExamId(examId: string): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT * FROM questions
        WHERE exam_id = $1
        ORDER BY question_id
      `,
                [examId],
            );

            return result.rows;
        } catch (error) {
            console.error("Error fetching questions by exam ID:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get enrollments by exam ID
    async getEnrollmentsByExamId(examId: string): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT * FROM enrollments
        WHERE exam_id = $1
      `,
                [examId],
            );

            return result.rows;
        } catch (error) {
            console.error("Error fetching enrollments by exam ID:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get enrollments by student
    async getEnrollmentsByStudent(student: string): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT e.*, exams.title, exams.datetime, exams.duration, exams.is_active
        FROM enrollments e
        JOIN exams ON e.exam_id = exams.exam_id
        WHERE e.student = $1
        ORDER BY exams.datetime DESC
      `,
                [student],
            );

            return result.rows;
        } catch (error) {
            console.error("Error fetching enrollments by student:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    // Get certificates by student
    async getCertificatesByStudent(student: string): Promise<any[]> {
        const client = await this.pool.connect();
        try {
            const result = await client.queryObject(
                `
        SELECT * FROM certificates
        WHERE student = $1
        ORDER BY timestamp DESC
      `,
                [student],
            );

            return result.rows;
        } catch (error) {
            console.error("Error fetching certificates by student:", error);
            throw error;
        } finally {
            client.release();
        }
    }

    async getClient(): Promise<PoolClient> {
        return await this.pool.connect();
    }

    // Close the database connection pool
    async close() {
        await this.pool.end();
    }
}
