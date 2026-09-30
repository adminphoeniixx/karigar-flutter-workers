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
    this.employerVerified = false,
    this.distanceKm,
    this.experienceLabel = '',
    this.shiftHoursLabel = '',
    this.latitude,
    this.longitude,
  });
  final bool employerVerified;
  final double? distanceKm;
  final String experienceLabel, shiftHoursLabel;
  final int id;
  final double? latitude, longitude;
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
      jobWageLabel(json),
      '0',
      (json['vacancies'] as num?)?.toInt() ?? 0,
      (json['skills'] as List? ?? []).map((e) => e.toString()).toList(),
      json['description']?.toString() ?? '',
      id: (json['id'] as num?)?.toInt() ?? 0,
      employerVerified: jsonBool(employer['verified']),
      distanceKm: num.tryParse('${json['distance_km']}')?.toDouble(),
      experienceLabel: json['experience_label']?.toString() ?? '',
      shiftHoursLabel: json['shift_hours_label']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
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
    employerVerified: job.employer.verified,
    distanceKm: job.distanceKm,
    experienceLabel: job.experienceLabel,
    shiftHoursLabel: job.shiftHoursLabel,
    latitude: job.latitude,
    longitude: job.longitude,
  );
}

const jobs = [
  Job(
    'Plumber for Apartment Project',
    'Plumbing',
    'Sri Sai Constructions',
    'Chennai, TN',
    '₹20,800–26,000/month',
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
    '₹23,400–31,200/month',
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
    '₹26,000–36,400/month',
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
    '₹18,200–22,100/month',
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
    '₹22,100–26,000/month',
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
    '₹15,600–23,400/month',
    '4.8',
    2,
    ['AC Repair', 'Appliance Repair'],
    'AC installation, servicing and gas charging. Own bike required.',
  ),
];
