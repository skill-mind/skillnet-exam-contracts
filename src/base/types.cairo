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
    pub passmark_percent: u16,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Questions {
    pub exam_id: u256,
    pub total_questions: u32,
    pub questions_uri: ByteArray,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ExamStats {
    pub questions_uri: ByteArray,
    pub total_students: u256,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct Student {
    address: ContractAddress,
    exam_id: u256,
    is_registered: bool,
}

#[derive(Drop, Serde, starknet::Store)]
pub struct ExamResult {
    pub exam_id: u256,
    pub student_address: ContractAddress,
    pub submit_timestamp: u64,
    pub result_uri: ByteArray // for score
}
