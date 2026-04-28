import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_bottom_nav.dart';
import '../../data/firebase/auth_data_source.dart';
import '../../data/repoImp/auth_repository_firebase.dart';
import '../faq/faqs_page.dart';
import '../journey/journey_list_screen.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String userName = "";
  String joinedDate = "";
  int journeysCount = 0;
  int photosCount = 0;
  List<Map<String, dynamic>> userJourneys = [];
  List<Map<String, dynamic>> userFeedbacks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  String _formatDate(DateTime date) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[date.month - 1]} ${date.year}";
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        userName = data?['name'] ?? user.email?.split('@').first ?? "User";
        final joinedTimestamp = data?['joinedDate'] as Timestamp?;
        if (joinedTimestamp != null) {
          joinedDate = _formatDate(joinedTimestamp.toDate());
        } else {
          joinedDate = "Unknown";
        }
      } else {
        userName = user.email?.split('@').first ?? "User";
        joinedDate = "Unknown";
      }

      final userJourneysSnap = await _firestore
          .collection('user_journeys')
          .where('userId', isEqualTo: user.uid)
          .get();
      journeysCount = userJourneysSnap.docs.length;
      userJourneys = userJourneysSnap.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['journeyName'] ?? '',
          'date': data['date'] ?? '',
        };
      }).toList();

      final photosSnap = await _firestore
          .collection('photos')
          .where('userId', isEqualTo: user.uid)
          .get();
      photosCount = photosSnap.docs.length;

      final feedbacksSnap = await _firestore
          .collection('feedbacks')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      for (var doc in feedbacksSnap.docs) {
        final data = doc.data();
        final journeyId = data['journeyId'];
        String journeyName = "General";
        if (journeyId != null && journeyId != "all") {
          final journeyDoc = await _firestore.collection('journeys').doc(journeyId).get();
          if (journeyDoc.exists) {
            journeyName = journeyDoc.data()?['name'] ?? "Unknown Journey";
          }
        }
        userFeedbacks.add({
          'rating': data['overallRating'] ?? 0,
          'comment': data['overallComment'] ?? '',
          'date': (data['createdAt'] as Timestamp?)?.toDate(),
          'journeyName': journeyName,
        });
      }
    } catch (e) {
      print(e);
    }

    setState(() => _isLoading = false);
  }

  String _formatRelativeDate(DateTime? date) {
    if (date == null) return "";
    final diff = DateTime.now().difference(date).inDays;
    if (diff == 0) return "Today";
    if (diff == 1) return "Yesterday";
    return "$diff days ago";
  }

  Future<void> _logout() async {
    await AuthRepositoryFirebase(AuthDataSource()).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('images/image3.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _iconButton(Icons.settings, () {}),
                        const SizedBox(width: 16),
                        _iconButton(Icons.help_outline, () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const FaqsPage()),
                          );
                        }),
                      ],
                    ),
                    Row(
                      children: [
                        _iconButton(Icons.language, () {}),
                        const SizedBox(width: 16),
                        _iconButton(Icons.logout, _logout),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white.withOpacity(0.5),
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: AppColors.brown.withOpacity(0.7),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Hello, $userName!",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.brown,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            "Joined $joinedDate",
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.brown.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _statBox("$journeysCount", "JOURNEYS")),
                    const SizedBox(width: 16),
                    Expanded(child: _statBox("$photosCount", "PHOTOS")),
                  ],
                ),
                const SizedBox(height: 30),
                const Text(
                  "My Journey",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown,
                  ),
                ),
                const SizedBox(height: 12),
                userJourneys.isEmpty
                    ? _emptyBox("No journeys yet")
                    : SizedBox(
                        height: 130,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: userJourneys.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final journey = userJourneys[index];
                            return Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.brown.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    journey['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 12),
                                      const SizedBox(width: 6),
                                      Text(
                                        journey['date'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.brown.withOpacity(0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 30),
                const Text(
                  "Feedback",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown,
                  ),
                ),
                const SizedBox(height: 12),
                userFeedbacks.isEmpty
                    ? _emptyBox("No feedback yet")
                    : SizedBox(
                        height: 200,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: userFeedbacks.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final fb = userFeedbacks[index];
                            return Container(
                              width: 280,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.brown.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fb['journeyName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.brown,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: List.generate(5, (i) => Icon(
                                      i < fb['rating'] ? Icons.star : Icons.star_border,
                                      color: Colors.amber,
                                      size: 14,
                                    )),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    fb['comment'],
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppColors.brown),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatRelativeDate(fb['date']).toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.brown.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 30),
                const Text(
                  "Journey Memories",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brown,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.brown.withOpacity(0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("View All", style: TextStyle(fontSize: 14, color: AppColors.brown)),
                      Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.brown),
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 2,
        onHomeTap: () => Navigator.of(context).pop(),
        onActiveJourneysTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const JourneyListScreen()),
          );
        },
        onProfileTap: () {},
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.brown),
        onPressed: onPressed,
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.brown),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.brown.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brown.withOpacity(0.2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppColors.brown),
      ),
    );
  }
}