import os
import re

tabs = [
    ('Admin', 'admin_sheikhs_tab.dart', 'lib/screens/admin/tabs/admin_sheikhs_tab.dart'),
    ('Admin', 'admin_halaqat_tab.dart', 'lib/screens/admin/tabs/admin_halaqat_tab.dart'),
    ('Admin', 'admin_students_tab.dart', 'lib/screens/admin/tabs/admin_students_tab.dart'),
    ('Admin', 'admin_courses_tab.dart', 'lib/screens/admin/tabs/admin_courses_tab.dart'),
    ('Admin', 'admin_trips_tab.dart', 'lib/screens/admin/tabs/admin_trips_tab.dart'),
    ('Admin', 'admin_tracks_tab.dart', 'lib/screens/admin/tabs/admin_tracks_tab.dart'),
    ('Admin', 'admin_rewards_tab.dart', 'lib/screens/admin/tabs/admin_rewards_tab.dart'),
    ('Admin', 'admin_overview_tab.dart', 'lib/screens/admin/tabs/admin_overview_tab.dart'),
    ('Admin', 'admin_events_tab.dart', 'lib/screens/admin/tabs/admin_events_tab.dart'),
    ('Sheikh', 'sheikh_attendance_tab.dart', 'lib/screens/sheikh/tabs/sheikh_attendance_tab.dart'),
    ('Sheikh', 'sheikh_memorization_tab.dart', 'lib/screens/sheikh/tabs/sheikh_memorization_tab.dart'),
    ('Sheikh', 'sheikh_tracks_tab.dart', 'lib/screens/sheikh/tabs/sheikh_tracks_tab.dart'),
    ('Sheikh', 'sheikh_trips_tab.dart', 'lib/screens/sheikh/tabs/sheikh_trips_tab.dart'),
    ('Sheikh', 'sheikh_overview_tab.dart', 'lib/screens/sheikh/tabs/sheikh_overview_tab.dart'),
    ('Sheikh', 'sheikh_students_tab.dart', 'lib/screens/sheikh/tabs/sheikh_students_tab.dart'),
    ('Sheikh', 'sheikh_messages_tab.dart', 'lib/screens/sheikh/tabs/sheikh_messages_tab.dart'),
    ('Student', 'student_progress_tab.dart', 'lib/screens/student/tabs/student_progress_tab.dart'),
    ('Student', 'student_attendance_tab.dart', 'lib/screens/student/tabs/student_attendance_tab.dart'),
    ('Student', 'student_trips_tab.dart', 'lib/screens/student/tabs/student_trips_tab.dart'),
    ('Student', 'student_rewards_tab.dart', 'lib/screens/student/tabs/student_rewards_tab.dart'),
    ('Student', 'student_points_tab.dart', 'lib/screens/student/tabs/student_points_tab.dart'),
    ('Student', 'student_contact_tab.dart', 'lib/screens/student/tabs/student_contact_tab.dart'),
    ('Student', 'student_rankings_tab.dart', 'lib/screens/student/tabs/student_rankings_tab.dart'),
]

print(f"Total tabs: {len(tabs)}")
for role, name, path in tabs:
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    suspicious = [w for w in ['Mock', 'Fake', 'Stub', 'dummy', 'Unimplemented', 'throw Exception', 'TODO'] if w in content]
    calls = re.findall(r'(?:data|dataService)\.([a-zA-Z0-9_]+)\(', content)
    unique_calls = sorted(set(calls))
    models = [m for m in ['Mosque', 'Sheikh', 'Halaqa', 'Student', 'IntensiveCourse', 'Trip', 'RecitationTrack', 'Reward', 'CommunityEvent', 'AttendanceRecord', 'MemorizationRecord', 'AppMessage', 'PointsLog'] if m in content]
    
    sus_str = ", ".join(suspicious) if suspicious else "NONE"
    print(f"[{role}] {name} ({len(content.splitlines())} LOC):")
    print(f"   Models: {', '.join(models)}")
    print(f"   DataService calls: {', '.join(unique_calls) if unique_calls else 'passed down or reads model'}")
    print(f"   Suspicious tokens: {sus_str}")
