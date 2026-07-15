class RegistrationCollegeCourses {
  const RegistrationCollegeCourses({
    required this.department,
    required this.courses,
  });

  final String department;
  final List<String> courses;
}

const staffDepartmentOptions = [
  'Administration',
  'Registrar',
  'Finance',
  'Library',
  'Guidance/PACC',
  'Health Services',
  'IT/MIS',
  'Maintenance/Facilities',
  'Security',
  'Other',
];

const registrationCollegeCourseOptions = [
  RegistrationCollegeCourses(
    department: 'College of Accountancy and Business Administration',
    courses: ['BS Accountancy', 'BS Business Administration', 'BS Management'],
  ),
  RegistrationCollegeCourses(
    department: 'College of Arts and Sciences / College of Arts and Languages',
    courses: [
      'BA Communication / Mass Communication',
      'BA English',
      'BA Filipino',
      'BA Political Science',
      'BA Psychology',
    ],
  ),
  RegistrationCollegeCourses(
    department:
        'College of Information and Technology Education / College of Computer Studies',
    courses: [
      'BS Information Technology',
      'Bachelor of Library and Information Science',
      'Associate in Computer Technology',
    ],
  ),
  RegistrationCollegeCourses(
    department: 'College of Criminology',
    courses: ['BS Criminology'],
  ),
  RegistrationCollegeCourses(
    department: 'College of Education / College of Teacher Education',
    courses: [
      'Bachelor of Elementary Education - Preschool Ed, Primary Ed',
      'Bachelor of Secondary Education - English, Filipino, Mathematics, Science, Social Studies',
      'Bachelor in Physical Education',
      'Bachelor in Music',
      'Bachelor in Fine Arts',
    ],
  ),
  RegistrationCollegeCourses(
    department: 'College of Engineering and Architecture',
    courses: [
      'BS Architecture',
      'BS Civil Engineering',
      'BS Computer Engineering',
      'BS Electrical Engineering / Electronic Engineering',
      'BS Mechanical Engineering',
    ],
  ),
  RegistrationCollegeCourses(
    department: 'College of Law',
    courses: ['Juris Doctor'],
  ),
  RegistrationCollegeCourses(
    department: 'College of Nursing',
    courses: ['BS Nursing'],
  ),
  RegistrationCollegeCourses(
    department: 'College of Pharmacy',
    courses: ['BS Pharmacy'],
  ),
  RegistrationCollegeCourses(
    department: 'College of Science and Mathematics',
    courses: ['BS Mathematics', 'BS Biology / Natural Sciences'],
  ),
  RegistrationCollegeCourses(
    department: 'College of Social Work',
    courses: ['BS Social Work'],
  ),
  RegistrationCollegeCourses(
    department: 'Graduate School / Institute of Graduate and Advanced Studies',
    courses: [
      'Doctor of Education',
      'Master of Arts in Education - all major fields',
      'Master in Business Administration',
      'Master of Arts in Nursing',
    ],
  ),
  RegistrationCollegeCourses(
    department:
        'School of Hotel and Restaurant Services and Tourism Management',
    courses: ['BS Hotel and Restaurant Management', 'BS Tourism Management'],
  ),
  RegistrationCollegeCourses(
    department: 'School of Midwifery',
    courses: ['Midwifery Program'],
  ),
];

List<String> registrationCoursesForDepartment(String? department) {
  if (department == null) return const [];
  for (final option in registrationCollegeCourseOptions) {
    if (option.department == department) return option.courses;
  }
  return const [];
}
