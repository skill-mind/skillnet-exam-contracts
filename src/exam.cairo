use starknet::ContractAddress;
#[starknet::interface] // interface of GidaToken
pub trait ISkillnetNft<TContractState> {
    // NFT contract
    fn mint(ref self: TContractState, recipient: ContractAddress, token_id: u256);
}

#[starknet::contract]
pub mod Exam {
    use core::array::ArrayTrait;
    // oz imports
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{Map, MutableVecTrait, Vec, VecTrait, StoragePointerReadAccess, StoragePointerWriteAccess};
    use starknet::{ContractAddress, get_block_timestamp, get_caller_address, get_contract_address};
    use crate::base::types::{Exam, ExamStats, Question, Student};
    use crate::interfaces::IExam::IExam;
    use super::ISkillnetNftDispatcherTrait;

    // Validator role
    const VALIDATOR_ROLE: felt252 = selector!("VALIDATOR_ROLE");

    // components definition
    component!(path: AccessControlComponent, storage: accesscontrol, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // AccessControl
    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = AccessControlComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
   pub struct Storage {
        exams: Map<u256, Exam>,
        next_exam_id: u256,
        next_question_id: Map<u256, u256>,
        exam_questions: Map<(u256, u256), Question>,
        exam_enrollments: Map<(u256, ContractAddress), bool>,
        exam_stats: Map<u256, ExamStats>,
        course_nft_contract_address: ContractAddress,
        students_to_exam_scores: Map<(ContractAddress, u256), u256>,
        #[substorage(v0)]
        pub accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        validators: Vec<ContractAddress>,
        students_passed: Map<(ContractAddress, u256), bool>,
        //tracks all minted nft id minted by events
        track_minted_nft_id: Map<(u256, ContractAddress), u256>,
        scores_uploaded: Map<u256, bool>,
        students: Student,
        strk_token_address: ContractAddress,
        skillnet_account: ContractAddress,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ExamCreated: ExamCreated,
        QuestionAdded: QuestionAdded,
        StudentEnrolled: StudentEnrolled,
        ExamStatusChanged: ExamStatusChanged,
        CourseCertClaimed: CourseCertClaimed,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
    }

    #[derive(Drop, Serde, starknet::Event)]
    struct ExamCreated {
        exam_id: u256,
        title: ByteArray,
        creator: ContractAddress,
        datetime: u64,
        duration: u64,
        is_active: bool,
    }

    #[derive(starknet::Event, Clone, Debug, Drop)]
    pub struct CourseCertClaimed {
        pub course_identifier: u256,
        pub candidate: ContractAddress,
    }
    #[derive(Drop, Serde, starknet::Event)]
    struct QuestionAdded {
        exam_id: u256,
        question_id: u256,
    }

    #[derive(Drop, Serde, starknet::Event)]
    struct StudentEnrolled {
        exam_id: u256,
        student: ContractAddress,
    }

    #[derive(Drop, Serde, starknet::Event)]
    struct ExamStatusChanged {
        exam_id: u256,
        new_status: bool,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        self.next_exam_id.write(0_u256);
    }

    #[abi(embed_v0)]
    impl ExamImpl of IExam<ContractState> {
        fn create_exam(
            ref self: ContractState,
            title: ByteArray,
            duration: u64,
            is_active: bool,
            is_paid: bool,
            price: u256,
        ) -> Exam {
            let creator = get_caller_address();
            let datetime = get_block_timestamp();
            let exam_id = self.next_exam_id.read();

            self.next_exam_id.write(exam_id + 1_u256);

            let exam = Exam {
                exam_id,
                title: title.clone(),
                creator,
                datetime,
                duration,
                is_active,
                is_paid,
                price,
            };

            self.exams.write(exam_id, exam);
            self
                .exam_stats
                .write(exam_id, ExamStats { total_questions: 0_u256, total_students: 0_u256 });

            self.next_question_id.write(exam_id, 0_u256);

            let exam_data = self.exams.read(exam_id);

            self
                .emit(
                    Event::ExamCreated(
                        ExamCreated { exam_id, title, creator, datetime, duration, is_active },
                    ),
                );

            exam_data
        }

        fn add_question(
            ref self: ContractState,
            exam_id: u256,
            question: ByteArray,
            option_a: ByteArray,
            option_b: ByteArray,
            option_c: ByteArray,
            option_d: ByteArray,
            correct_option: u8,
        ) -> u256 {
            assert(correct_option >= 1_u8 && correct_option <= 4_u8, 'INVALID_OPTION');

            self.assert_exam_exists(exam_id);
            self.assert_exam_active(exam_id);

            let creator = get_caller_address();
            self.assert_is_exam_creator(exam_id, creator);

            let question_id = self.next_question_id.read(exam_id);
            self.next_question_id.write(exam_id, question_id + 1_u256);

            let question_data = Question {
                exam_id,
                question_id,
                question,
                option_a,
                option_b,
                option_c,
                option_d,
                correct_option,
            };

            self.exam_questions.write((exam_id, question_id), question_data);

            let mut stats = self.exam_stats.read(exam_id);
            stats.total_questions += 1_u256;
            self.exam_stats.write(exam_id, stats);

            self.emit(Event::QuestionAdded(QuestionAdded { exam_id, question_id }));

            question_id
        }

        fn enroll_in_exam(ref self: ContractState, exam_id: u256) {
            self.assert_exam_exists(exam_id);
            self.assert_exam_active(exam_id);

            let student = get_caller_address();

            let exam = self.exams.read(exam_id);

            let amount = exam.price;

            if (exam.is_paid) {
                self.collect_exam_fee(student, amount);
            } else {
                self.collect_exam_fee(get_contract_address(), amount);
            }

            let already_enrolled = self.exam_enrollments.read((exam_id, student));
            assert(!already_enrolled, 'ALREADY_ENROLLED');

            self.exam_enrollments.write((exam_id, student), true);

            let mut stats = self.exam_stats.read(exam_id);
            stats.total_students += 1_u256;
            self.exam_stats.write(exam_id, stats);

            self.emit(Event::StudentEnrolled(StudentEnrolled { exam_id, student }));
        }

        fn get_exam(ref self: ContractState, exam_id: u256) -> Exam {
            self.assert_exam_exists(exam_id);
            self.exams.read(exam_id)
        }

        fn get_exam_stats(ref self: ContractState, exam_id: u256) -> ExamStats {
            self.assert_exam_exists(exam_id);
            self.exam_stats.read(exam_id)
        }

        fn get_question(ref self: ContractState, exam_id: u256, question_id: u256) -> Question {
            self.assert_exam_exists(exam_id);
            self.exam_questions.read((exam_id, question_id))
        }

        fn is_enrolled(ref self: ContractState, exam_id: u256, student: ContractAddress) -> bool {
            self.exam_enrollments.read((exam_id, student))
        }

        fn toggle_exam_status(ref self: ContractState, exam_id: u256) {
            self.assert_exam_exists(exam_id);

            let creator = get_caller_address();
            self.assert_is_exam_creator(exam_id, creator);

            let mut exam = self.exams.read(exam_id);
            let new_status: bool = !exam.is_active;
            exam.is_active = new_status;

            self.exams.write(exam_id, exam);
            self.emit(Event::ExamStatusChanged(ExamStatusChanged { exam_id, new_status }));
        }

        fn claim_certificate(ref self: ContractState, exam_id: u256) {
            let student = get_caller_address();
            let eligible = self.students_passed.read((student, exam_id));

            if (eligible) {
                let nft_contract_address = self.course_nft_contract_address.read();

                let nft_dispatcher = super::ISkillnetNftDispatcher {
                    contract_address: nft_contract_address,
                };

                let nft_id = self.track_minted_nft_id.read((exam_id, nft_contract_address));

                nft_dispatcher.mint(get_caller_address(), nft_id);
                self.track_minted_nft_id.write((exam_id, nft_contract_address), nft_id + 1);
            } else {
                return;
            }
            self.emit(CourseCertClaimed { course_identifier: exam_id, candidate: student });
        }

        fn upload_student_score(
            ref self: ContractState,
            address: ContractAddress,
            exam_id: u256,
            score: u256,
            passMark: u256,
        ) -> bool {
            // Ensure is admin
            if (score > passMark) {
                self.students_passed.write((address, exam_id), true);
            }
            self.students_to_exam_scores.write((address, exam_id), score);
            self.scores_uploaded.write(exam_id, true);
            true
        }


        fn is_result_result(ref self: ContractState, exam_id: u256) {
            self.scores_uploaded.read(exam_id);
        }

        fn processExamPayment(
            ref self: ContractState, exam_id: u256, student_id: u256, isPaid: bool,
        ) -> bool {
            if (!isPaid) {
                true;
            }
            true
        }
    }

    #[generate_trait]
    impl PrivateImpl of PrivateTrait {
        fn assert_exam_exists(self: @ContractState, exam_id: u256) {
            let exam = self.exams.read(exam_id);
            assert(exam.duration > 0, 'EXAM_NOT_FOUND');
        }

        fn assert_is_exam_creator(self: @ContractState, exam_id: u256, caller: ContractAddress) {
            let exam = self.exams.read(exam_id);
            assert(exam.creator == caller, 'NOT_CREATOR');
        }

        fn assert_exam_active(self: @ContractState, exam_id: u256) {
            let exam = self.exams.read(exam_id);
            assert(exam.is_active, 'EXAM_INACTIVE');
        }


        fn collect_exam_fee(
            ref self: ContractState, payer: ContractAddress, amount: u256,
        ) { // TODO: Uncomment code after ERC20 implementation
            let token = self.strk_token_address.read();
            let recipient = self.skillnet_account.read();
            let amt = amount * 1_000_000_000_000_000_000;
            // let _success = IERC20Dispatcher { contract_address: token }
        //     .transfer_from(payer, recipient, amt);
        // assert(_success, 'token withdrawal fail...');
        }
    }
}
