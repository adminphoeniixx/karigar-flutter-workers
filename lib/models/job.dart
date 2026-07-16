part of '../main.dart';

class Job {
  const Job(
    this.title,
    this.category,
    this.employer,
    this.city,
    this.wage,
    this.rating,
    this.openings,
    this.skills,
    this.description, {
    this.id = 0,
  });
  final int id;
  final String title, category, employer, city, wage, rating, description;
  final int openings;
  final List<String> skills;

  factory Job.fromJson(Map<String, dynamic> json) {
    final employer = Map<String, dynamic>.from(json['employer'] as Map? ?? {});
    return Job(
      json['title']?.toString() ?? '',
      json['category']?.toString() ?? '',
      employer['name']?.toString() ?? '',
      json['location_label']?.toString() ??
          [json['city'], json['state']].where((e) => e != null).join(', '),
      json['wage_label']?.toString() ?? '',
      '0',
      (json['vacancies'] as num?)?.toInt() ?? 0,
      (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
      json['description']?.toString() ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
    );
  }

  factory Job.fromApi(ApiJobModel job) => Job(
    job.title,
    job.category,
    job.employer.name,
    job.locationLabel.isEmpty ? '${job.city}, ${job.state}' : job.locationLabel,
    job.wageLabel,
    '0',
    job.vacancies,
    job.skills,
    job.description,
    id: job.id,
  );
}

const jobs = [
  Job(
    'Plumber for Apartment Project',
    'Plumbing',
    'Sri Sai Constructions',
    'Chennai, TN',
    '₹800–1,000/day',
    '4.7',
    3,
    ['Plumbing', 'Pipe Fitting', 'Waterproofing'],
    'Experienced plumbers needed for a 12-floor residential project. Bathroom & kitchen line fitting, drainage and testing. 3 months of work with on-time daily payment.',
  ),
  Job(
    'Electrician — House Wiring',
    'Electrical',
    'Kumar Interiors',
    'Chennai, TN',
    '₹900–1,200/day',
    '4.9',
    2,
    ['Electrical Wiring', 'Electrician'],
    'Complete wiring for a 3BHK villa — DB board, fitting and testing. Tools provided.',
  ),
  Job(
    'Carpenter for Modular Kitchen',
    'Carpentry',
    'WoodCraft Studio',
    'Coimbatore, TN',
    '₹1,000–1,400/day',
    '4.6',
    1,
    ['Carpentry', 'Woodwork'],
    'Modular kitchen and wardrobe fitting with fine finishing. Please bring your own tools.',
  ),
  Job(
    'Painters — 2 needed (interior)',
    'Painting',
    'ColorHome Painters',
    'Chennai, TN',
    '₹700–850/day',
    '4.5',
    2,
    ['Painting', 'Wall Putty'],
    'Interior painting — putty, primer and 2 coats. About 10 days of work, paid every evening.',
  ),
  Job(
    'Mason for Compound Wall',
    'Masonry',
    'BuildRight',
    'Madurai, TN',
    '₹850–1,000/day',
    '4.4',
    4,
    ['Masonry', 'Plastering'],
    'Compound wall construction and plastering. A helper will be provided.',
  ),
  Job(
    'AC Technician — Split & Window',
    'AC Repair',
    'CoolFix Services',
    'Chennai, TN',
    '₹600–900/day',
    '4.8',
    2,
    ['AC Repair', 'Appliance Repair'],
    'AC installation, servicing and gas charging. Own bike required.',
  ),
];
