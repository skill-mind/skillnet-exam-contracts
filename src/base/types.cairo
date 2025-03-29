use starknet::ContractAddress;

#[derive(Drop, Serde, starknet::Store)]
pub struct Exam {
    pub exam_id: u256,
    pub title: ByteArray,
    pub creator: ContractAddress,
    pub datetime: u64,
    pub duration: u64,
    pub is_active: bool,
    pub is_paid: bool,
    pub price: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Question {
    pub exam_id: u256,
    pub question_id: u256,
    pub question: ByteArray,
    pub option_a: ByteArray,
    pub option_b: ByteArray,
    pub option_c: ByteArray,
    pub option_d: ByteArray,
    pub correct_option: u8,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ExamStats {
    pub total_questions: u256,
    pub total_students: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Student {
    address: ContractAddress,
    exam_Id: u256,
    is_registered: bool,
}
