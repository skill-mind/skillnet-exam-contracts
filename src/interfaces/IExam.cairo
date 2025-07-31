use starknet::ContractAddress;
use crate::base::types::{Exam, ExamResult, ExamStats, ExamSubmitted};


#[starknet::interface]
pub trait IExam<TContractState> {
    // Creates a new exam and returns the created exam
    fn create_exam(
        ref self: TContractState,
        title: ByteArray,
        duration: u64,
        is_active: bool,
        is_paid: bool,
        price: u256,
        passmark_percent: u16,
    ) -> Exam;

    // Adds a question to an exam and returns the question ID
    // Uploads all questions for an exam using an IPFS URI
    fn add_questions(
        ref self: TContractState, total_questions: u32, exam_id: u256, questions_uri: ByteArray,
    );

    // Enrolls the caller in an exam
    fn enroll_in_exam(ref self: TContractState, exam_id: u256);

    // Gets exam details by ID
    fn get_exam(ref self: TContractState, exam_id: u256) -> Exam;

    // gets an array of all exams
    fn get_all_exams(ref self: TContractState) -> Array<Exam>;

    // gets a list of all students enrolled in a specific exam
    fn get_students_enrolled_in_exam(
        ref self: TContractState, exam_id: u256,
    ) -> Array<ContractAddress>;

    // gets a list of all exams submitted by a student
    fn get_exams_submitted_by_student(
        ref self: TContractState, student: ContractAddress,
    ) -> Array<ExamSubmitted>;

    // gets a list of all submit for an exam
    fn get_all_submits_for_exam(ref self: TContractState, exam_id: u256) -> Array<ExamSubmitted>;

    // Gets exam statistics by ID
    fn get_exam_stats(ref self: TContractState, exam_id: u256) -> ExamStats;

    fn get_questions(ref self: TContractState, exam_id: u256) -> ByteArray;

    // Checks if a student is enrolled in an exam
    fn is_enrolled(ref self: TContractState, exam_id: u256, student: ContractAddress) -> bool;

    // Toggles an exam's active status
    fn toggle_exam_status(ref self: TContractState, exam_id: u256);

    fn submit_exam(
        ref self: TContractState, exam_id: u256, exam_uri: ByteArray, exam_video: ByteArray,
    );

    fn student_have_nft(
        ref self: TContractState,
        token_id: u256,
        exam_id: u256,
        nft_contract_address: ContractAddress,
        student: ContractAddress,
    ) -> bool;

    fn upload_student_result(
        ref self: TContractState,
        address: ContractAddress,
        exam_id: u256,
        result_uri: ByteArray,
        passed: bool,
    ) -> bool;

    fn get_student_result(
        ref self: TContractState, exam_id: u256, address: ContractAddress,
    ) -> ExamResult;

    fn get_student_exams(ref self: TContractState, address: ContractAddress) -> Array<Exam>;

    fn claim_certificate(ref self: TContractState, exam_id: u256);

    fn is_result_out(ref self: TContractState, exam_id: u256) -> bool;

    fn collect_exam_fee(
        ref self: TContractState, payer: ContractAddress, amount: u256, recipient: ContractAddress,
    );

    fn get_addresses(ref self: TContractState) -> (ContractAddress, ContractAddress);
}

