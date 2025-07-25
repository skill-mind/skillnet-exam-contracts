use skillnet_exam::interfaces::IMockUsdc::{IMockUsdcDispatcher, IMockUsdcDispatcherTrait};
use skillnet_exam::interfaces::ISkillnetNft::{ISkillnetNftDispatcher, ISkillnetNftDispatcherTrait};


#[starknet::contract]
pub mod Exam {
    use core::array::ArrayTrait;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::storage::{Map, StoragePointerReadAccess, StoragePointerWriteAccess, Vec};
    use starknet::{
        ClassHash, ContractAddress, get_block_timestamp, get_caller_address, get_contract_address,
    };
    use crate::base::types::{Exam, ExamResult, ExamStats, Questions, Student};
    use crate::interfaces::IExam::IExam;
    use super::{IMockUsdcDispatcherTrait, ISkillnetNftDispatcherTrait};

    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    pub struct Storage {
        exams: Map<u256, Exam>,
        owner: ContractAddress,
        next_exam_id: u256,
        next_question_id: Map<u256, u256>,
        exam_questions: Map<u256, Questions>,
        exam_enrollments: Map<(u256, ContractAddress), bool>,
        exam_stats: Map<u256, ExamStats>,
        nft_contract_address: ContractAddress,
        students_to_exam_results: Map<(ContractAddress, u256), ExamResult>,
        validators: Vec<ContractAddress>,
        students_passed: Map<(ContractAddress, u256), bool>,
        //tracks all minted nft id minted by events
        track_minted_nft_id: Map<(u256, ContractAddress), u256>,
        scores_uploaded: Map<u256, bool>,
        students: Student,
        strk_token_address: ContractAddress,
        skillnet_account: ContractAddress,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ExamCreated: ExamCreated,
        QuestionsAdded: QuestionsAdded,
        StudentEnrolled: StudentEnrolled,
        ExamStatusChanged: ExamStatusChanged,
        CourseCertClaimed: CourseCertClaimed,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
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
    struct QuestionsAdded {
        exam_id: u256,
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
    fn constructor(
        ref self: ContractState,
        erc20: ContractAddress,
        skill: ContractAddress,
        nft: ContractAddress,
        owner: ContractAddress,
    ) {
        self.next_exam_id.write(0_u256);
        self.strk_token_address.write(erc20);
        self.skillnet_account.write(skill);
        self.nft_contract_address.write(nft);
        self.owner.write(owner);
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
            passmark_percent: u16,
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
                passmark_percent,
            };

            self.exams.write(exam_id, exam);
            self
                .exam_stats
                .write(exam_id, ExamStats { questions_uri: "0", total_students: 0_u256 });

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

        fn add_questions(
            ref self: ContractState, total_questions: u32, exam_id: u256, questions_uri: ByteArray,
        ) {
            self.assert_exam_exists(exam_id);
            self.assert_exam_active(exam_id);

            let creator = get_caller_address();
            self.assert_is_exam_creator(exam_id, creator);

            let question_data = Questions {
                exam_id, total_questions, questions_uri: questions_uri.clone(),
            };

            self.exam_questions.write(exam_id, question_data);

            let mut stats = self.exam_stats.read(exam_id);
            stats.questions_uri = questions_uri;
            self.exam_stats.write(exam_id, stats);

            self.emit(Event::QuestionsAdded(QuestionsAdded { exam_id }));
        }

        fn enroll_in_exam(ref self: ContractState, exam_id: u256) {
            self.assert_exam_exists(exam_id);
            self.assert_exam_active(exam_id);

            let student = get_caller_address();

            let exam = self.exams.read(exam_id);

            let amount = exam.price;

            let skillnet_revenue = self.skillnet_account.read();
            if (exam.is_paid) {
                let commision = amount / 10;

                let exam_fee = amount - commision;

                self.collect_exam_fee(get_caller_address(), exam_fee, get_contract_address());
                self.collect_exam_fee(get_caller_address(), commision, skillnet_revenue);
            } else {
                self.collect_exam_fee(get_contract_address(), amount, skillnet_revenue);
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

        fn get_questions(ref self: ContractState, exam_id: u256) -> ByteArray {
            self.assert_exam_exists(exam_id);

            self.exam_questions.read(exam_id).questions_uri
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
                let nft_contract_address = self.nft_contract_address.read();

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

        fn upload_student_result(
            ref self: ContractState,
            address: ContractAddress,
            exam_id: u256,
            result_uri: ByteArray,
            passed: bool,
        ) -> bool {
            assert(self.is_enrolled(exam_id, address), 'Not enrolled');
            self
                .students_to_exam_results
                .write(
                    (address, exam_id),
                    ExamResult {
                        exam_id,
                        student_address: address,
                        submit_timestamp: get_block_timestamp(),
                        result_uri,
                    },
                );

            self.students_passed.write((address, exam_id), passed);
            true
        }

        fn get_student_result(
            ref self: ContractState, exam_id: u256, address: ContractAddress,
        ) -> ExamResult {
            self.students_to_exam_results.read((address, exam_id))
        }

        fn collect_exam_fee(
            ref self: ContractState,
            payer: ContractAddress,
            amount: u256,
            recipient: ContractAddress,
        ) { // TODO: Uncomment code after ERC20 implementation
            let token = self.strk_token_address.read();

            let erc20_dispatcher = super::IMockUsdcDispatcher { contract_address: token };
            erc20_dispatcher.approve_user(get_contract_address(), amount);
            let contract_allowance = erc20_dispatcher.get_allowance(payer, get_contract_address());
            assert(contract_allowance >= amount, 'INSUFFICIENT_ALLOWANCE');
            let user_bal = erc20_dispatcher.get_balance(payer);
            assert(user_bal >= amount, 'Insufficient funds');
            let _success = erc20_dispatcher.transferFrom(payer, recipient, amount);
            assert(_success, 'token withdrawal fail...');
        }


        fn is_result_out(ref self: ContractState, exam_id: u256) -> bool {
            let suc = self.scores_uploaded.read(exam_id);
            suc
        }

        fn student_have_nft(
            ref self: ContractState,
            token_id: u256,
            exam_id: u256,
            nft_contract_address: ContractAddress,
            student: ContractAddress,
        ) -> bool {
            let nft_dispatcher = super::ISkillnetNftDispatcher {
                contract_address: nft_contract_address,
            };

            let owner = nft_dispatcher.is_owner(token_id);

            if (owner != student) {
                return false;
            }

            true
        }
        fn get_addresses(ref self: ContractState) -> (ContractAddress, ContractAddress) {
            let erc_20 = self.strk_token_address.read();
            let nft = self.nft_contract_address.read();
            (erc_20, nft)
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
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(get_caller_address() == self.owner.read(), 'UNAUTHORIZED CALLER');
            self.upgradeable.upgrade(new_class_hash);
        }
    }
}
